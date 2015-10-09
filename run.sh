#!/bin/bash

basedir=$(cd $(dirname "$0"); pwd)

# read configuration

source "${basedir}/_funcs.sh"

read_configuration

# run test from this project directory 

cd "${basedir}"

# cleanup

rm -rf "${dataDir}" "${backupDir}"
mkdir -p "${dataDir}" "${backupDir}"

# start mongo server

run_server

# create the oplog index

mongo_command "createOplogIndex('${dbName}')"

# set the initial state

mongo_command "setState('${dbName}', 'before')"

# spawn workers

for threadId in $(seq 1 $threads); do
  spawn_script "worker_insertTransaction.js" "threadId=$((${threadId}));"
  spawn_script "worker_createDocuments.js"   "threadId=$((${threadId} + ${threads}));"
  spawn_script "worker_deleteDocuments.js"   "threadId=$((${threadId} + ${threads} * 2));"
done

# run for a while

sleep ${loadForSeconds:-60}

# set backup rate

if ! [ "${backupThrottle}" == "0" ]; then
  mongo_command "db.runCommand({backupThrottle:${backupThrottle}})"
fi

# initiate the backup
spawn_script "worker_backup.js" "threadId=$((1 + ${threads} * 3)); basedir='${basedir}'"

# monitor status
while : ; do

  mongo_command "printjson(db.runCommand({backupStatus:1}))"
  echo "${mongo_command_result}" 

  sleep ${secondsBetweenStatus:-1}

done

# after traffic

sleep ${afterTraffic:-0}

# set the end state

mongo_command "setState('${dbName}', 'exit')"

# wait for children to exit

# shutdown_server


