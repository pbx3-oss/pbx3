date >>/var/log/recdump.log
#set this rsync to point to your offload or nearline media
#create directory tree if it doesn't exist
#
[ ! -d /opt/sark/media/recordings ] && mkdir -p /opt/sark/media/recordings
#Move the files
rsync  --remove-source-files -a /var/spool/asterisk/monout/ /opt/sark/media/recordings/`date +%d%m%y`/ >>/var/log/recdump.log 2>&1