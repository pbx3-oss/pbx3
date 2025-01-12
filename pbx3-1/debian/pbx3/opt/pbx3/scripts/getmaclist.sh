#!/bin/sh
# get a list of macs amd manufacturers from IEEE
# 

[ ! -e /opt/gcs/www/gcs-common/manuf.txt ]  && touch /opt/gcs/www/gcs-common/manuf.txt
chown www-data:www-data /opt/gcs/www/gcs-common/manuf.txt
curl -L -s "http://www.sailpbx.com/sail/public/manuf.txt" > /tmp/manuf.txt
ret=$?
if test "$ret" != "0"; then
     logger SARKgetmaclist - **** Link fail - Could not fetch new manufacturer MAC DB ****
     exit 4
fi   

if [ -s /tmp/manuf.txt ]; then
        diff /opt/gcs/www/gcs-common/manuf.txt /tmp/manuf.txt
        if [  "$?" -ne "0" ] ; then
                mv /tmp/manuf.txt /opt/gcs/www/gcs-common/manuf.txt
                logger SARKgetmaclist - updated manufacturer MAC DB
        else
                logger SARKgetmaclist - manufacturer MAC DB up to date
        fi
else
        logger SARKgetmaclist - **** Could not fetch new manufacturer MAC DB ****
fi