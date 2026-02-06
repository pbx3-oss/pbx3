<?php

/**
 * PBX3 system config file
 * N.B. !!!!
 * If you make changes to this config you MUST run 
 *  php genbashconfig.php 
 * to ripple the changes into the bash equivalent config
 */

/**
 * System
 */

define('CODENAME',                      'pbx3');
define('KEYTYPE',                       'pkey');
define('SYSAGI',                        'swarmcore');

define('SYSROOT',                       '/opt');
define('SYSPREFIX',                     '/pbx3');
define('SYSPATH',                       SYSROOT . SYSPREFIX);

define('INSTANCEID',                    SYSPATH . '/etc/identity/instance-id.txt');
define('DOMAINID',                      SYSPATH . '/etc/identity/domain-id.txt');

define('PHPDIR',                        SYSPATH . '/php');                   
define('SCRIPTS',                       SYSPATH . '/scripts');
define('BASHCONFIG',                    SCRIPTS . '/bashconfig');

define('CLASSES',                       PHPDIR . '/classes');
define('GENERATOR',                     PHPDIR . '/generator');
define('UTILITIES',                     PHPDIR . '/utilities');        

define('SNAPSHOTS', 			        SYSPATH . '/snap');
define('BACKUPS', 						SYSPATH . '/bkup');
define('CACHE', 						SYSPATH . '/cache');

define('DBPATH', 						SYSPATH . '/db');
define('DBNAME', 						'sqlite.db');

define('SYSDB',						    DBPATH .  "/" . DBNAME); 
define('DBDUMPS',						DBPATH .  '/db_database_dumps');
define('DBTABLEDUMPS',					DBPATH .  '/db_table_dumps');
define('DBSQL',						    DBPATH .  '/db_sql');
define('DBINSTANCESQL',				    DBSQL .  '/sqlite_create_instance.sql');
define('DBTENANTSQL',				    DBSQL .  '/sqlite_create_tenant.sql');
define('DBLEGACYSQL',				    DBSQL .  '/sqlite_create_legacy.sql');
define('DBMESSAGE',					    DBSQL .  '/sqlite_message.sql');

define('READONLY_DB',				    DBPATH .  '/sqlite.rdonly.db');
define('COPY_DB',				        DBPATH .  '/sqlite.copy.db');

define ('DBCLASS',                      CLASSES . '/DbClass');
define ('GENCLASS',                     CLASSES . '/GenClass');
define ('HELPER',                       CLASSES . '/HelperClass');
define ('LDAPHELPER',                   CLASSES . '/LDAPHelperClass');
define ('NETHELPER',                    CLASSES . '/NetHelperClass');

define('RELOADER',				        SCRIPTS . '/reloader.sh');
define('EXEC_DB_RELOAD',				RELOADER);		// alias for backward compatibility

define ('AMIHELPER',                    CLASSES . '/AmiHelperClass');
define ('ASTMANAGER',                   CLASSES . '/AsteriskManager.php');
define ('AMIUID',                       'pbx3');
define ('AMIPWD',                       'bgth7rf!');


define('ASTPATH',                       '/etc/asterisk');
define('ASTMPL',                        SYSPATH . ASTPATH . '/templates');
define('ASTLOCALCONF',                  SYSPATH . ASTPATH . '/configs');
define('ASTENDPOINTS',                  SYSPATH . ASTPATH . '/endpoints');
define('ASTQUEUES',                     SYSPATH . ASTPATH . '/queues');
define('ASTTRUNKS',                     SYSPATH . ASTPATH . '/trunks');
define('ASTIAX',                        SYSPATH . ASTPATH . '/iax_trunks');
define('ASTPARKS',                      SYSPATH . ASTPATH . '/callparks');

define('QUEUE',                         'queue.conf');
define('QUEUE_TEMPLATE',                ASTMPL . '/queue.tmpl');
define('READY_QUEUES',                  ASTLOCALCONF . '/ready_queues.conf');

define('PARK',                         'parking.conf');
define('PARK_TEMPLATE',                 ASTMPL . '/parking_lot.tmpl');
define('READY_PARKS',                   ASTLOCALCONF . '/ready_parks.conf');

define('IAX_TRUNK',					    'trunk.conf');
define('IAX_TRUNK_SNDREG_TEMPLATE',	    ASTMPL . '/iax_trunk_sndreg.tmpl');
define('IAX_TRUNK_RCVREG_TEMPLATE',	    ASTMPL . '/iax_trunk_rcvreg.tmpl');
define('IAX_TRUNK_TRUSTED_TEMPLATE',	ASTMPL . '/iax_trunk_trusted.tmpl');
define('IAX_READY_TRUNKS',              ASTLOCALCONF . '/iax_ready_trunks.conf');

define('ASTEXTCONF',                    ASTLOCALCONF . '/extensions.conf');
define('ASTEXEC',                       '/usr/sbin/asterisk');
define('ASTSHARE',                      '/usr/share/asterisk');
define('ASTSPOOL',                      '/var/spool/asterisk');
define('ASTLOGS',                       '/var/log/asterisk');
define('MONITOR',			            ASTSPOOL . '/monitor/');
define('MONOUT',		                ASTSPOOL . '/monout/');
define('MONSTAGE',						ASTSPOOL . '/monstage/');
define('CDR',						    ASTLOGS . '/cdr-csv/master.csv');
define ('BACKUP',                       '/backup');
define ('RECORDINGS',                   '/recordings');
define ('DELETES',                      '/deletes');
define ('ASTCDR',                       '/cdr');
define ('ASTLANG',                      'en-gb');

/**
 * S3 Creds
 */

define('AWS_KEY', "devuser");
define('AWS_SECRET', "devuserpwd");

/**
 * PJSIP files
 */

define('PJSIP', 						ASTLOCALCONF . '/pjsip.conf');

define('PJSIP_ANONYMOUS',				ASTLOCALCONF . '/pjsip_anonymous.conf');
define('PJSIP_GLOBALS', 				ASTLOCALCONF . '/pjsip_globals.conf');

define('PJSIP_PHONE',					'phone.conf');
define('PJSIP_PHONE_TEMPLATE',          ASTMPL . '/pjsip_phone.tmpl');
define('PJSIP_READY_PHONES',            ASTLOCALCONF . '/pjsip_ready_phones.conf');

define('PJSIP_WEBRTC',					'webrtc.conf');
define('PJSIP_WEBRTC_TEMPLATE',         ASTMPL . '/pjsip_webrtc.tmpl');
define('PJSIP_READY_WEBRTC',            ASTLOCALCONF . '/pjsip_ready_webrtc.conf');
	      
define('PJSIP_TRANSPORT',		        ASTLOCALCONF . '/pjsip_transport.conf');	
define('PJSIP_TRANSPORT_TEMPLATE',		ASTMPL . '/pjsip_transport.tmpl');

define('PJSIP_TRUNK',					'trunk.conf');
define('PJSIP_TRUNK_SNDREG_TEMPLATE',	ASTMPL . '/pjsip_trunk_sndreg.tmpl');
define('PJSIP_TRUNK_RCVREG_TEMPLATE',	ASTMPL . '/pjsip_trunk_rcvreg.tmpl');
define('PJSIP_TRUNK_TRUSTED_TEMPLATE',	ASTMPL . '/pjsip_trunk_trusted.tmpl');
define('PJSIP_READY_TRUNKS',            ASTLOCALCONF . '/pjsip_ready_trunks.conf');

define('SOUNDIR',                       '/usr/share/asterisk' . SYSPREFIX . '/sounds/');

/**
 * Shorewall
 */
define('SHOREWALL',                     '/etc/shorewall');
define('FW_RULES',                      '/etc/shorewall/pbx3_rules');

/**
 * BASH params
 */

define('LASTDB',                        DBDUMPS . '/last.db');               //pbx3 db previous iteration
define('CLEANDB',                       DBSQL . '/sqlite_clean.db');	    //factory reset copy of the db (created on first install, not in repo) 
define('LEGACY_DB',                     DBSQL . '/sqlite_create_legacy.sql');	    //old db create
define('INSTANCE_DB',                   DBSQL . '/sqlite_create_instance.sql');	    //installed db create
define('TENANT_DB',                     DBSQL . '/sqlite_create_tenant.sql');	    //installed db create
define('LARAVEL_DB',                    DBSQL . '/sqlite_create_laravel.sql');	    //installed db create
define('SYSTEMDB',                      DBSQL . '/sqlite_system.sql');		//installed db system data
define('SYSMSGDB',                      DBSQL . '/sqlite_message.sql');	    //installed db system messages
define('SYSINIDB',                      DBSQL . '/sqlite_inidat.sql');		//installed db defaults
define('SYSONCE',                       SYSPATH . '/once');				    //once directory
define('SYSALWAYS',                     SYSPATH . '/always');				//always directory
define('SYSONCEDONE',                   SYSPATH . '/oncedone');				//applied once files
define('CUSTDATA',                      DBDUMPS . '/last_data.sql');		//customer data previous iteration
define('LASTDEVICE',                    DBDUMPS . '/last_device.sql');		//device table previous iteration      
define('CUSTDEVICE',                    DBDUMPS . '/last_custdevice.sql');	//customer devices previous iteration
define('SIPLOG',                        DBPATH . '/var/log/siplog');	    //installed db create
define('DUMPER',                        UTILITIES . '/dumper.php'); 	    //loc. of the dumper
define('ASTGEN',                        GENERATOR . '/runAstGen.php');
define('SIPFIX',                        UTILITIES . '/sipiaxfix.php'); 	//loc. of the V6 sipiaxfixup routine
define('GENAST',                        SCRIPTS . '/genAst.sh');		//loc. of the generator
define('HTTPOWNER',                     'www-data:www-data');		//HTTP server user/group (Apache/nginx + PHP-FPM for API)