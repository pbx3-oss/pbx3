#!/bin/sh
# get the most recent phone images
[ -e /tmp/phoneimages.zip ] && rm -rf /tmp/phoneimages.zip
[ -e  /tmp/phoneimages ] && rm -rf /tmp/phoneimages

wget --timeout=10 --tries=3  -O /tmp/phoneimages.zip sailpbx.com/phoneimages.zip
[ ! -e /tmp/phoneimages.zip ] && logger 'pbx3getimages - could not retrieve phone images' && exit 4

unzip /tmp/phoneimages.zip -d /tmp

[ ! -e  /tmp/phoneimages ] &&  logger 'pbx3getimages - could not unzip  phone images' && exit 4

rsync -ai /tmp/phoneimages /opt/pbx3/cache/
chown -R www-data:www-data /opt/pbx3/cache/phoneimages
logger pbx3getimages - phone images up to date

