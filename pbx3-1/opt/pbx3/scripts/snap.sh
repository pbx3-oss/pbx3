#
#       SNAP HAS TO BE REWRIITEN FOR INDY-TENANTS IN PBX3
#
#!/bin/bash
#
# Spin off a snap of the database  
#
#/bin/cp -a $SYSDB $SYSPATH/snap/$DBNAME.`date +%s`
#/bin/ls -t $SYSPATH/snap/* | /bin/sed -e '1,9d' | /usr/bin/xargs -d '\n' /bin/rm > /dev/null 2>&1

