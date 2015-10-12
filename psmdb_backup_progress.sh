#!/bin/bash

# Usage:  psmdb_backup_progress.sh {db path} {backup path}

if [ $# -ne 2 ]; then
  echo "-1"
  exit 1;
fi

tmpfile=$(mktemp)
diff "${1}" "${2}" | grep "^Only in ${2}"| sed 's@^.*: @@' > "${tmpfile}"

sb=$(du -b ${1} | cut -f1)

db=$(du -b -X ${tmpfile} ${2} | cut -f1)
[ -e "${tmpfile}" ] && rm "${tmpfile}"

percent_complete=$(echo "printf(\"%d\n\",${db}/${sb}*100);" | perl -f-)

echo "${percent_complete}"

