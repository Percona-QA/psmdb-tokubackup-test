#!/bin/bash

basedir=$(cd $(dirname "$0"); pwd)

# read configuration

source "${basedir}/_funcs.sh"

read_configuration

# run test from this project directory 

cd "${basedir}"

# make sure there's no mongo stuff running

mongodb_is_running
if [ ${mongodb_is_running_result:=0} -gt 0 ]; then
  echo "failed: There are currently mongo processes running."
  echo "Please shutdown any existing mongo processes before"
  echo "running this test."
  exit 1;
fi

# cleanup

rm -rf "${dataDir}" "${backupDir}"
mkdir -p "${dataDir}" "${backupDir}"

# start mongo server

run_server

# create the oplog index

mongo_command "createOplogIndex('${dbName}')"

# start pre-load

echo "Loading some initial data (${loadForSeconds:=60} seconds)..."

# set the initial state

mongo_command "setState('${dbName}', 'before')"

# spawn workers

for (( threadId=1; threadId<=$threads; threadId++ )); do
  spawn_script "worker_insertTransaction.js" "threadId=$((${threadId}));"
  spawn_script "worker_createDocuments.js"   "threadId=$((${threadId} + ${threads}));"
  spawn_script "worker_deleteDocuments.js"   "threadId=$((${threadId} + ${threads} * 2));"
done

# run for a while

sleep ${loadForSeconds}

# set backup rate

if ! [ "${backupThrottle}" == "0" ]; then
  mongo_command "db.runCommand({backupThrottle:${backupThrottle}})"
fi

# initiate the backup

echo 'Starting backup...'

spawn_script "worker_backup.js" "threadId=$((1 + ${threads} * 3)); basedir='${basedir}'"

# monitor status - wait for inProgress: true then inProgress: false
# while displaying percent complete.
monitorState="before"
while : ; do

  mongo_command "printjson(db.runCommand({backupStatus:1}))"
  inProgress=$(echo "${mongo_command_result}" | awk 'BEGIN{FS=":";RS=","}/inProgress/{print $2}' | sed 's/ //' | cut -d'.' -f1)

  # wait for true then false
  [ "${inProgress:='false'}" == "true" ] && monitorState="active"
  [ ${monitorState} == "active" ] && [ "${inProgress}" == "false" ] && break;

  [ ${DEBUG} -gt "1" ] && echo "${mongo_command_result}"

  percentComplete=$(./psmdb_backup_progress.sh "${dataDir}" "${backupDir}")

  echo "Backup percent complete: ${percentComplete}"
  sleep ${secondsBetweenStatus:-1}

done

# after traffic

echo "After backup traffic (${afterTraffic:=60} seconds)..."

sleep ${afterTraffic}

# set the end state

mongo_command "setState('${dbName}', 'exit')"

# wait for children to exit

echo "Waiting for mongo shells to exit gracefully..."

for (( i=0; i<30; i++ )); do 
  mongodb_is_running
  [ ${mongodb_is_running_result:=0} -le 1 ] && break;
  sleep 1 
done

if [ ${mongodb_is_running_result} -gt 1 ]; then
  echo "failed: some mongo shells did not exit."
  exit 1;
fi

# TODO - record and report transaction and document statistics

# shutdown_server

echo "Shutting down server..."

shutdown_server

for (( i=0; i<30; i++ )); do 
  mongodb_is_running
  [ ${mongodb_is_running_result:=0} -eq 0 ] && break;
  sleep 1 
done

if [ ${mongodb_is_running_result} -gt 0 ]; then
  echo "failed: mongod server did not exit."
  exit 1;
fi

# 
