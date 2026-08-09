#!/bin/sh
# Optional phone-image cache refresh.
# No third-party image host is wired by default — set PBX3_PHONEIMAGES_URL to enable.
#
# Example:
#   PBX3_PHONEIMAGES_URL=https://example.com/phoneimages.zip sh /opt/pbx3/scripts/getimages.sh

URL="${PBX3_PHONEIMAGES_URL:-}"
if [ -z "$URL" ]; then
  logger 'pbx3getimages - skipped (PBX3_PHONEIMAGES_URL unset)'
  exit 0
fi

[ -e /tmp/phoneimages.zip ] && rm -rf /tmp/phoneimages.zip
[ -e /tmp/phoneimages ] && rm -rf /tmp/phoneimages

wget --timeout=10 --tries=3 -O /tmp/phoneimages.zip "$URL"
[ ! -e /tmp/phoneimages.zip ] && logger 'pbx3getimages - could not retrieve phone images' && exit 4

unzip /tmp/phoneimages.zip -d /tmp

[ ! -e /tmp/phoneimages ] && logger 'pbx3getimages - could not unzip phone images' && exit 4

rsync -ai /tmp/phoneimages /opt/pbx3/cache/
chown -R www-data:www-data /opt/pbx3/cache/phoneimages
logger pbx3getimages - phone images up to date
