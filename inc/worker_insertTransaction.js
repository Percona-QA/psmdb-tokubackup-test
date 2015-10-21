load(basedir+'/inc/_funcs.js');

setRandomSeed(threadId);

// load before
//
worker_insertTransactions('before');
worker_insertTransactions('during');
worker_insertTransactions('after');
