load('_funcs.js');

setRandomSeed(threadId);

// load before
//
worker_deleteDocuments('during');
worker_deleteDocuments('after');
