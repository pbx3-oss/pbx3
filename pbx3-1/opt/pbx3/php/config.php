<?php

/**
 * System
 */

define('SYSNAME',                       'sipblocks');
define('KEYTYPE',                       'pkey');
define('SYSAGI',                        'gcsagi');

define('SYSROOT',                       '/opt');
define('SYSPREFIX',                     '/gcs');
define('SYSPATH',                       SYSROOT . SYSPREFIX);

define('INSTANCEID',                    SYSPATH . '/etc/identity/instance-id.txt');
define('DOMAINID',                      SYSPATH . '/etc/identity/domain-id.txt');

define('PHP',                           SYSPATH . '/php');                   
define('SCRIPTS',                       SYSPATH . '/scripts');
define('BASHCONFIG',                    SCRIPTS . '/bashconfig');

define('CLASSES',                       PHP . '/classes');
define('GENERATOR',                     PHP . '/generator');
define('UTILITIES',                     PHP . '/utilities');        

define('SNAPSHOTS', 			        SYSPATH . '/snap');
define('BACKUPS', 						SYSPATH . '/bkup');
define('CACHE', 						SYSPATH . '/cache');

define('DBPATH', 						SYSPATH . '/db');
define('DBNAME', 						'/sqlite.db');
define('SYSDB',						    DBPATH .  DBNAME); 

define('READONLY_DB',				    DBPATH .  '/sqlite.rdonly.db');
define('COPY_DB',				        DBPATH .  '/sqlite.copy.db');

define ('AMIHELPER',                    CLASSES . '/AmiHelperClass');
define ('ASTMANAGER',                   CLASSES . '/AsteriskManager.php');
define ('DBCLASS',                      CLASSES . '/DbClass');
define ('GENCLASS',                     CLASSES . '/GenClass');
define ('HELPER',                       CLASSES . '/HelperClass');
define ('LDAPHELPER',                   CLASSES . '/LDAPHelperClass');
define ('NETHELPER',                    CLASSES . '/NetHelperClass');

define('EXEC_DB_RELOAD',				SCRIPTS . '/reloader.sh');

define('ASTCONF',                       '/etc/asterisk');
define('ASTMPL',                        SYSPATH . ASTCONF . '/templates');
define('ASTLOCALCONF',                  SYSPATH . ASTCONF . '/configs');
define('ASTENDPOINTS',                  SYSPATH . ASTCONF . '/endpoints');
define('ASTQUEUES',                     SYSPATH . ASTCONF . '/queues');
define('ASTTRUNKS',                     SYSPATH . ASTCONF . '/trunks');
define('ASTIAX',                        SYSPATH . ASTCONF . '/iax_trunks');
define('ASTPARKS',                      SYSPATH . ASTCONF . '/callparks');

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
 * BASH params
 */

define('LASTDB',                        DBPATH . '/db_vx_last.db');    //sark db previous iteration
define('CLEANDB',                       DBPATH . '/db_vx_clean.db');	//factory reset copy of the db 
define('CREATEDB',                      DBPATH . '/db_vx_create.sql');	    //installed db create
define('SYSTEMDB',                      DBPATH . '/db_vx_system.sql');		//installed db system data
define('SYSMSGDB',                      DBPATH . '/db_vx_message.sql');	    //installed db system messages
define('SYSINIDB',                      DBPATH . '/db_vx_inidat.sql');		//installed db defaults
define('SYSDEVICE',                     DBPATH . '/db_vx_device.sql');	    //installed db device table
define('SYSONCE',                       SYSPATH . '/once');				    //once directory
define('SYSALWAYS',                     SYSPATH . '/always');					//always directory
define('SYSONCEDONE',                   SYSPATH . '/oncedone');				//applied once files
define('CUSTDATA',                      DBPATH . '/last_data.sql');			//customer data previous iteration
define('LASTDEVICE',                    DBPATH . '/last_device.sql');			//device table previous iteration      
define('CUSTDEVICE',                    DBPATH . '/last_custdevice.sql');	    //customer devices previous iteration
define('DUMPER',                        GENERATOR . '/dumper.php'); 	//loc. of the dumper
define('ASTGEN',                        GENERATOR . '/runAstGen.php');
define('SIPFIX',                        UTILITIES . '/sipiaxfix.php'); 	//loc. of the V6 sipiaxfixup routine
define('GENAST',                        SCRIPTS . '/genAst.sh');		//loc. of the generator
define('HTTPOWNER',                     'www-data:www-data');		//apache user/group (Deb/Ubu)q