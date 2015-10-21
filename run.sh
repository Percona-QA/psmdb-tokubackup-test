#!/bin/bash

basedir=$(cd $(dirname "$0"); pwd)

# read configuration

source "${basedir}/inc/assert.sh"
source "${basedir}/inc/_funcs.sh"

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

# run the tests

for tscript in tests/*.sh; do
  source $tscript
done

