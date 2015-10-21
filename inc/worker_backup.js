load(basedir+'/inc/_funcs.js');

// since 'backupStart' is blocking we need to spawn
// it in a separate process.

// you need to pass threadId and basedir via --eval

setRandomSeed(threadId);

// load before
//
setState(dbName,'during');
if (DEBUG > 1) { print("backup dir: "+basedir + '/' + backupDir); }
printjson(db.getSiblingDB('admin').runCommand({ backupStart: basedir + '/' + backupDir }));
setState(dbName,'after');

