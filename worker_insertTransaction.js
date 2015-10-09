load('_funcs.js');

// load before
//
worker_insertTransactions('before');
worker_insertTransactions('during');
worker_insertTransactions('after');
