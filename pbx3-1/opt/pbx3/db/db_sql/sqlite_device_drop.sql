-- One-shot: drop legacy Device provisioning-template table (won't-do 2026-08-25).
-- New installs omit the table (sqlite_create_instance.sql). Existing DBs: run once.
-- ipphone.device (type label: General SIP / WebRTC / MAILBOX / vendor from MAC) is unrelated and stays.
DROP TABLE IF EXISTS device;
DROP TABLE IF EXISTS Device;
