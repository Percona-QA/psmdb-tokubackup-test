// psmdb-tokubackup-test javascript functions
//
// author: david. bennett at percona. com

// load configuration

if ( typeof CONF !== 'undefined' && CONF !== '' ) {
  load(CONF);
} else {
  load('conf/psmdb-tokubackup-test.conf');
}

/**
 * states
 */
states = {
  'before' : 'loading before copy',
  'during' : 'started during capture',
  'after'  : 'comleted after backup',
  'exit'   : 'exit at end'
};

/**
 * init random
 */
function setRandomSeed(thread) {
  if (randomSeed == -1) {
    Random.srand(new Date().getTime()+thread);
  } else {
    Random.srand(randomSeed+thread);
  }
}

/** 
 * create oplog index
 */
function createOplogIndex(dbName) {
  var ldb=db.getSiblingDB(dbName);
  ldb.oplog.createIndex({oid:1,op:1},{unique:1});
}

/**
 * set the test state
 * @param dbName database name
 * @param status the status to set before,started,ended,exit
 */
function setState(dbName, status) {
  var ldb=db.getSiblingDB(dbName);
  if (ldb.state.count() == 0) {
    ldb.state.insert({state:status});
  } else {
    ldb.state.update({},{state:status},{multi:true});
  }
  return status;
}

/**
 * get the test state
 * @return state before,started,ended exit
 */
function getState(dbName) {
  var ldb=db.getSiblingDB(dbName);
  return(ldb.state.findOne().state);
}

/**
 * insert a transaction
 * @param dbName - Database name
 * @param maxColl - maximum number of collections
 * @param maxAcct - maximum number of accounts
 * @param maxAmount - maximum transaction amount +/-
 * @param wc - WriteConcern setting
 */
function insertTransaction(dbName,maxColl,maxAcct,maxAmount,wc) {
  var ldb=db.getSiblingDB(dbName);

  var cNum=Math.floor(Random.rand() * maxColl + 1);
  var acctNum=Math.floor(dom.rand() * maxAcct + 1);
  var lcoll=db['acct'+cNum];

  // amount can be postive or negative
  var amt = Math.floor(Random.rand() * maxAmount + 1);
  if (Random.rand() * 2 > 1) amt = amt * -1;

  var ts = new Date().getTime();

  // transaction in a single document update
  lcoll.update(
    { _id: acctNum },
    {
      $inc: { total: amt },
      $set: { timestamp: ts },
      $set: { backupState: getState(dbName) },
      $addToSet: { transactions: {
        timestamp: ts,
        backupState: getState(dbName),
        amount: amt
      }}
    },
    {
      upsert: true,
      writeConcern: wc 
    }
  );
  
}

/**
 * create non-transactional record testing
 * @param dbName - Database name
 * @param maxColl - maximum number of collections
 * @param wc - WriteConcern setting
 */
function createDocument(dbName,maxColl,wc) {

  var ldb=db.getSiblingDB(dbName);

  var cNum=Math.floor(Random.rand() * maxColl + 1);

  var lcoll=db['coll'+cNum];

  var ts = new Date().getTime();

  var o = new ObjectId();

  lcoll.insert({_id: o, timestamp: ts});

  ldb.oplog.insert({oid: o, op:'c'});

}

/** delete non-transactional document testing
 * @param dbName - Database name
 * @param maxColl - maximum number of collections
 * @param wc - WriteConcern setting
 */
function deleteDocument(dbName,maxColl,wc) {

  var ldb=db.getSiblingDB(dbName);

  var cNum = Math.floor(Random.rand() * maxColl + 1);

  var lcoll = db['coll'+cNum];

  var cnt = lcoll.count();

  var skp = Math.floor(Random.rand() * cnt);

  var doc = lcoll.find().skip(skp).next();

  var oid = doc._id;

  lcoll.remove({_id: oid})

  ldb.oplog.insert({oid: oid, op: 'd'});

}

/**
 * pause for milliseconds
 * @param ms milliseconds 1000 is 1 second
 *
 * Thank you Pavel Bakhilau 
 */
function pausecomp(ms) {
  if (ms <= 0) return;
  ms += new Date().getTime();
  while (new Date() < ms){}
} 

/**
 * worker function for loading transactions
 *
 */
function worker_insertTransactions(state) {
  while (getState(dbName) == state) {
    for (var i=0; i < opBatch; i++) {
      insertTransaction(dbName,maxCollections,maxAccounts,maxAmount,writeConcern);
      pausecomp(opPause);
    }
  }
}

/**
 * worker function for create documents
 *
 */
function worker_createDocuments(state) {
  while (getState(dbName) == state) {
    for (var i=0; i < opBatch; i++) {
      createDocuments(dbName,maxCollections,writeConcern);
      pausecomp(opPause);
    }
  }
}

/**
 * worker function for delete documents
 *
 */
function worker_deleteDocuments(state) {
  while (getState(dbName) == state) {
    for (var i=0; i < opBatch; i++) {
      deleteDocuments(dbName,maxCollections,writeConcern);
      pausecomp(opPause);
    }
  }
}

