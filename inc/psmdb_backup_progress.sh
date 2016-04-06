#!/bin/bash

# Returns a number as percent complete 0-100 as progress
# of current PSMDB TokuBackup process
#
# author: david. bennett at percona. com
#
# Returns string '-1' on failure
#
# logic:
#   sb = total size in bytes of db directory (source)
#   db = total size in bytes of backup directory (destination)
#        (minus size in bytes of files that don't exist in db directory)
#   percent complete is integer part (floor) of ( db / sb * 100 )
#    
# requires perl interpreter for floating point math
#
# Note: backup must be in progress for percent to be accurate

# Usage:  psmdb_backup_progress.sh {db path} {backup path}

if [ $# -lt 2 ] || ! [ -d "$1" ] || ! [ -d "$2" ]; then
  echo "-1"
  echo "Usage: ./psmdb_backup_progress.sh {db path} {backup path}" > /dev/stderr
  exit 1;
fi

# temp files
s_files=$(mktemp)
d_files=$(mktemp)
d_not_in_s=$(mktemp)

# get lists of files and find those in destination but not source
ls -1 "${1}" | sort > "${s_files}"
ls -1 "${2}" | sort > "${d_files}"
diff -u "${s_files}" "${d_files}" | grep '^+[^+]' | sed 's/^\+//' > "${d_not_in_s}"

# get size of directories less dest not in src
sb=$(du -sb "${1}" | cut -f1)
db=$(du -sb -X "${d_not_in_s}" "${2}" | cut -f1)

# clean up temp files 
for tf in "${s_files}" "${d_files}" "${d_not_in_s}"; do
  [ -e "${tf}" ] && rm "${tf}"
done

# calcuate percent complete and output
percent_complete=$(echo "printf(\"%d\n\",${db}/${sb}*100);" | perl -f-)

echo "${percent_complete}"

