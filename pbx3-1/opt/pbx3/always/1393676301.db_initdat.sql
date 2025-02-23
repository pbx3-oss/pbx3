BEGIN TRANSACTION;


INSERT OR IGNORE INTO Route(pkey,active,auth,cluster,cname,dialplan,path1,path2,path3,path4) values ('DEFAULT','YES','NO','default','DEFAULT TRUNK','_XXXX.','None','None','None','None');
INSERT OR IGNORE INTO users (id,name,email,password,role) VALUES ('1','admin','admin@pbx3.com','$2y$12$IHbfUfGA3TOj2hnGld7TM.2gMqhyvQnWoAVmMwX3N5Uo7WNvaW85K','isAdmin');

/* This needs work abd should be in Always section */
INSERT OR IGNORE INTO globals(pkey) values ('global');
UPDATE globals SET OPERATOR=0 WHERE OPERATOR IS NULL OR OPERATOR=0;
UPDATE globals SET PWDLEN=12 WHERE PWDLEN IS NULL;
UPDATE globals SET RECLIMIT=1000 WHERE RECLIMIT IS NULL;
UPDATE globals SET TLSPORT=5061 WHERE TLSPORT IS NULL;

COMMIT;
