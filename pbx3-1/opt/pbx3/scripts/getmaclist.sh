#!/bin/sh
# get a list of macs amd manufacturers from IEEE
# 

[ ! -e /opt/pbx3/cache/manuf.txt ]  && touch /opt/pbx3/cache/manuf.txt
chown www-data:www-data /opt/pbx3/cache/manuf.txt
curl -L -s "http://www.sailpbx.com/sail/public/manuf.txt" > /tmp/manuf.txt
ret=$?
if test "$ret" != "0"; then
     logger pbx3getmaclist - **** Link fail - Could not fetch new manufacturer MAC DB ****
     exit 4
fi   

if [ -s /tmp/manuf.txt ]; then
        diff /opt/pbx3/cache/manuf.txt /tmp/manuf.txt
        if [  "$?" -ne "0" ] ; then
                mv /tmp/manuf.txt /opt/pbx3/cache/manuf.txt
                logger pbx3getmaclist - updated manufacturer MAC DB
        else
                logger pbx3getmaclist - manufacturer MAC DB up to date
        fi
else
        logger pbx3getmaclist - **** Could not fetch new manufacturer MAC DB ****
fi