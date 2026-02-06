BEGIN TRANSACTION;

/* SYSTEM TABLES - these are not backed up as part of a cluster backup */
/* abilities is JSON array for pbx3api auth; role is deprecated/unused (kept only for legacy DB compatibility) */
INSERT OR IGNORE INTO users (id,name,email,password,abilities,role) VALUES ('1','admin','admin@pbx3.com','$2y$12$IHbfUfGA3TOj2hnGld7TM.2gMqhyvQnWoAVmMwX3N5Uo7WNvaW85K','["admin"]',NULL);

/* This needs work abd should be in Always section */
INSERT OR IGNORE INTO globals(pkey) values ('global');
UPDATE globals SET operator=0 WHERE operator IS NULL OR operator=0;
UPDATE globals SET pwdlen=12 WHERE pwdlen IS NULL;
UPDATE globals SET reclimit=1000 WHERE reclimit IS NULL;
UPDATE globals SET tlsport=5061 WHERE tlsport IS NULL;

COMMIT;
