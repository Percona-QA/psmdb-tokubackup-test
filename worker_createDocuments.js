load('_funcs.js');

setRandomSeed(threadId);

// load before
//
worker_createDocuments('before');
worker_createDocuments('during');
worker_createDocuments('after');
