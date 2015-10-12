# bash controller functions

# author: david. bennett at percona. com

# read configuration

function read_configuration {
  basedir=$(cd $(dirname "$0"); pwd)

  cnf="$1"
  [ "${cnf}" == "" ] && cnf="${CONF}"
  [ "${cnf}" == "" ] && cnf="${basedir}/conf/psmdb-tokubackup-test.conf"

  while read line ; do
    if ! [[ "${line}" =~ ^[[:space:]]*// ]]; then
      eval "${line}"
    fi
  done < "${cnf}"

  # set binary names

  mongo="${binDir:-/usr/bin}/mongo"
  mongod="${binDir:-/usr/sbin}/mongod"

}

# check to see if mongo or mongod is running
# returns 0=not running, 1=server running, 2+=server and shell(s) running
function mongodb_is_running {
  mongodb_is_running_result=$(ps aux | grep '[m]ongod* ' | wc -l)
}


# Run the mongod server

function run_server {

  opts="$1"

  # disable transparent huge pages
  
  if [ -e /sys/kernel/mm/transparent_hugepage/enabled ]; then
    if grep -Fq '[always]' /sys/kernel/mm/transparent_hugepage/enabled; then
      echo never > /sys/kernel/mm/transparent_hugepage/enabled
      echo never > /sys/kernel/mm/transparent_hugepage/defrag
    fi
    # check to see if the settings took
    if grep -Fq '[always]' /sys/kernel/mm/transparent_hugepage/enabled; then
      echo "ERROR: Unable to disable transparent huge pages in the kernel."
      echo "You need to set this as root before running this script."
      echo "If you are running in a container, you need to set this in the"
      echo "host kernel."
      exit 1
    fi
  fi

  ${mongod} --dbpath=${dataDir} --storageEngine=${storageEngine} ${opts} > "${basedir}/mongod.log" 2>&1 &
  MONGOD_PID=$!
  MONGO_EXIT=$?

  # wait until server is listening

  tail -f "${basedir}/mongod.log" | while read LOGLINE
  do
     [[ "${LOGLINE}" == *"waiting for connections"* ]] && pkill -P $$ tail
  done

}

# Shutdown mongod using the command line option

function shutdown_server {

 ${mongod} --dbpath=${dataDir} --shutdown > /dev/null 2>&1
  MONGO_EXIT=$?

}

# mongo command

function mongo_command {
  cmd="$@"
  mongo_command_result=$(${mongo} --quiet --eval "CONF='${CONF}';load('${basedir}/_funcs.js');$cmd" admin)
}

# spawn a background script

function spawn_script {
  script="$1"
  params="$2"

  ${mongo} --quiet --eval "CONF='${CONF:-}';${params}" ${dbName} ${script} > /dev/null 2>&1 &
}

