#!/bin/bash

# Returns a number as percent complete 0-100 as progress
#
# logic:
#   sb = total size in bytes of db directory (source)
#   db = total size in bytes of backup directory (source)
#        (minus size in bytes of files that don't exist in db directory)
#   percent complete is integer part (floor) of ( db / sb * 100 )
#    

# Usage:  psmdb_backup_progress.sh {db path} {backup path}

if [ $# -lt 2 ] || ! [ -d "$1" ] || ! [ -d "$2" ]; then
  echo "-1"
  echo "Usage: ./psmdb_backup_progress.sh {db path} {backup path}" > /dev/stderr
  exit 1;
fi

tmpfile=$(mktemp)
diff "${1}" "${2}" | grep "^Only in ${2}"| sed 's@^.*: @@' > "${tmpfile}"

sb=$(du -b ${1} | cut -f1)

db=$(du -b -X ${tmpfile} "${2}" | cut -f1)
[ -e "${tmpfile}" ] && rm "${tmpfile}"

percent_complete=$(echo "printf(\"%d\n\",${db}/${sb}*100);" | perl -f-)

echo "${percent_complete}"

