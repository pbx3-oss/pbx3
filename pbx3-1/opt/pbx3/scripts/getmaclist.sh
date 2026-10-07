#!/bin/sh
# get a list of macs and manufacturers from IEEE
# 

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

logger "getmaclist - **** running ****"

curl -L -s "https://standards-oui.ieee.org/oui/oui.txt" > /tmp/oui.txt
ret=$?
if test "$ret" != "0"; then
     logger "getmaclist - **** Link fail - Could not fetch new manufacturer MAC DB ****"
     exit 4
fi
# Poly (HP) registers as bare "Poly"; keep Polycom for legacy OUIs.
grep -E -i -w 'Snom|Panasonic|Yealink|Polycom|Poly|Fanvil|Cisco|Gigaset|Aastra|Grandstream|Vtech' /tmp/oui.txt > /tmp/manuf0.txt

grep 'base 16' /tmp/manuf0.txt | sed -e 's/(base 16)//' |sed -e "s/\s\{3,\}/ /g" > /tmp/manuf1.txt

sed -e 's/\(^[0-9A-Fa-f]\{2\}\)\([0-9A-Fa-f]\{2\}\)/\1:\2:/g' -e 's/\(.*\):$/\1/' /tmp/manuf1.txt >/tmp/manuf.txt

touch /opt/pbx3/cache/manuf.txt

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