load('_funcs.js');

// since 'backupStart' is blocking we need to spawn
// it in a separate process.

// you need to pass threadId and basedir via --eval

setRandomSeed(threadId);

// load before
//
setState(dbName,'during');
print("backup dir:"+basedir + backupDir);
db.getSiblingDB('admin').runCommand({ backupStart: basedir + '/' + backupDir });
setState(dbName,'after');

