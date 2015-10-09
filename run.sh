#!/bin/bash

basedir=$(cd $(dirname "$0"); pwd)

# read configuration

source "${basedir}/_funcs.sh"

read_configuration

# set binary names
mongo="${binDir}/mongo"
mongod="${binDir}/mongod"

# run the backup test

cd "${basedir}"

# cleanup

rm -rf "${dataDir}" "${backupDir}"
mkdir -p "${dataDir}" "${backupDir}"

# start mongo server

run_server

# create the oplog index

mongo_command "createOplogIndex('${dbName}')"

# set the state

mongo_command "setState('${dbName}', 'xxx')"

mongo_command "getState('${dbName}')"

echo $mongo_command_result

shutdown_server

