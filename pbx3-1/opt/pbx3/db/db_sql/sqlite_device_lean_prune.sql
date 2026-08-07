-- One-shot: drop Device rows not needed without HTTP provisioner.
-- Safe with lean sqlite_device_data.sql keepers. Run on instance DB when convenient.
BEGIN TRANSACTION;
DELETE FROM Device WHERE pkey NOT IN ('General SIP', 'WebRTC', 'MAILBOX', 'Yealink', 'Cisco', 'Polycom', 'Fanvil', 'Gigaset', 'Aastra', 'Vtech', 'Panasonic');
COMMIT;
