#!/bin/bash

[ -z "${basedir}" ] && { echo "Run this test from ../run.sh"; exit 1; }

# cleanup

make_clean

# start mongo server

run_server

# create the oplog index

mongo_command "createOplogIndex('${dbName}')"

# start pre-load

echo "Loading some initial data (${loadForSeconds:=60} seconds)..."

# set the initial state

mongo_command "setState('${dbName}', 'before')"

# spawn workers

for (( ss=1; ss<=$threads; ss++ )); do
  spawn_script "inc/worker_insertTransaction.js"
  spawn_script "inc/worker_createDocuments.js"
  spawn_script "inc/worker_deleteDocuments.js"
done

# run for a while

sleep ${loadForSeconds}

# set backup rate

if ! [ "${backupThrottle}" == "0" ]; then
  mongo_command "db.runCommand({backupThrottle:${backupThrottle}})"
fi

# initiate the backup

echo 'Starting backup...'

spawn_script "inc/worker_backup.js"

# monitor status - wait for inProgress: true then inProgress: false
# while displaying percent complete.
monitorState="before"
while : ; do

  mongo_command "db.runCommand({backupStatus:1})"
  inProgress=$(echo "${mongo_command_result}" | awk 'BEGIN{FS=":";RS=","}/inProgress/{print $2}' | sed 's/ //' | cut -d'.' -f1)

  # wait for true then false
  [ "${inProgress:='false'}" == "true" ] && monitorState="active"
  [ ${monitorState} == "active" ] && [ "${inProgress}" == "false" ] && break;

  [ ${DEBUG} -gt "1" ] && echo "${mongo_command_result}"

  percentComplete=$(${basedir}/inc/psmdb_backup_progress.sh "${dataDir}" "${backupDir}")

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
