BEGIN TRANSACTION;

/* SYSTEM TABLES - these are not backed up as part of a cluster backup */
/* Admin SPA user is NOT seeded here: installer / bootstrap-admin-user.sh sets email+password on first provision. */

/* globals: single row is inserted by reloader with pkey=instance ksuid; we only set defaults here */
UPDATE globals SET operator=0 WHERE operator IS NULL OR operator=0;
UPDATE globals SET pwdlen=12 WHERE pwdlen IS NULL;
UPDATE globals SET reclimit=1000 WHERE reclimit IS NULL;
UPDATE globals SET tlsport=5061 WHERE tlsport IS NULL;

COMMIT;
