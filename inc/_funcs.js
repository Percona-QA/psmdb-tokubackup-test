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
  'after'  : 'completed after backup',
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
function setState(dbName, s) {
  var ts = new Date().getTime();
  var ldb=db.getSiblingDB(dbName);
  var wc=0;
  if (typeof writeConcern !== 'undefined')
    wc=writeConcern;
  ldb.state.update(
    { '_id': 1 },
    {
      $set: { 
        '_id': 1,
        'state': s,
        'timestamp': ts 
      },
      $addToSet: {
        'history': {
          'state': s,
          'timestamp': ts
        }
      }
    },
    {
      upsert: true,
      writeConcern: wc 
    }
  );
  return s;
}

/**
 * get the test state
 * @return state before,started,ended exit
 */
function getState(dbName) {
  var ldb=db.getSiblingDB(dbName);
  return(ldb.state.findOne({_id:1}).state);
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
  var acctNum=Math.floor(Random.rand() * maxAcct + 1);
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
      $set: { 
        timestamp: ts, 
        backupState: getState(dbName) 
      },
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
 * wait for state
 *
 */
function waitState(state) {
  while (getState(dbName) != state) {
    if (DEBUG > 2) { print("getState(dbName): "+getState(dbName)+", state: "+state); }
    pausecomp(stateCheckPause);
  }
}

/**
 * worker function for loading transactions
 *
 */
function worker_insertTransactions(state) {
  waitState(state);
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
  waitState(state);
  while (getState(dbName) == state) {
    for (var i=0; i < opBatch; i++) {
      createDocument(dbName,maxCollections,writeConcern);
      pausecomp(opPause);
    }
  }
}

/**
 * worker function for delete documents
 *
 */
function worker_deleteDocuments(state) {
  waitState(state);
  while (getState(dbName) == state) {
    for (var i=0; i < opBatch; i++) {
      deleteDocument(dbName,maxCollections,writeConcern);
      pausecomp(opPause);
    }
  }
}

