#!/bin/bash
#
# delete recordings older than $RECAGE days
#
# this works for multitenant and makes the Global value redundant
#
# N.B. MUST be run explicitly with the bash shell - e.g. sudo bash .....
#
RECDIR=/opt/gcs/media/$RECORDINGS
RECDELDIR=/opt/gcs/media/$DELETES

mkdir -p $RECDELDIR`date +%d%m%y`;

#
# Get the set of tenant keys and their recmaxage column from the table cluster
#
RECAGEARRAY=`sqlite3 /opt/gcs/db/sqlite.db "select pkey,recmaxage from cluster;"`

#
# Iterate over the table array and delete as necessary using find/mv to move the deleted files to the bin (DELDIR)
#
for row_str in $RECAGEARRAY; do
    IFS='|' read -r -a COLS <<< "$row_str"
    echo "agerecordings - Evaluating ${COLS[0]}, ${COLS[1]} \n"

    find $RECDIR  -type f -name "*${COLS[0]}*" -mtime  +"${COLS[1]}" -exec mv {} $RECDELDIR/`date +%d%m%y`/ \;
done