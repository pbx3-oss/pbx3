
CREATE DATABASE IF NOT EXISTS catalog /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci */


== CORE TABLES

--
-- Table structure for table Agent
--

DROP TABLE IF EXISTS Agent;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE Agent (
  id varchar(20) NOT NULL,
  pkey int(11) NOT NULL,
  cluster text DEFAULT 'default',
  conf text DEFAULT NULL,
  extlen int(11) DEFAULT NULL,
  name text DEFAULT '*NEW AGENT*',
  cname text DEFAULT '*NEW AGENT*',
  num text DEFAULT NULL,
  passwd text DEFAULT NULL,
  queue1 text DEFAULT 'None',
  queue2 text DEFAULT 'None',
  queue3 text DEFAULT 'None',
  queue4 text DEFAULT 'None',
  queue5 text DEFAULT 'None',
  queue6 text DEFAULT 'None',
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table Appl
--

DROP TABLE IF EXISTS Appl;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE Appl (
  id varchar(20) NOT NULL,
  pkey text NOT NULL,
  active text DEFAULT 'YES',
  cluster text DEFAULT 'default',
  description text DEFAULT NULL,
  directdial int(11) DEFAULT NULL,
  extcode text DEFAULT NULL,
  name text DEFAULT NULL,
  cname text DEFAULT NULL,
  span text DEFAULT 'Neither',
  striptags text DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table ast-full-logs
--

DROP TABLE IF EXISTS ast-full-logs;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE ast-full-logs (
  id varchar(20) NOT NULL,
  instance-id varchar(20) DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='MOH media';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table cdr-csv-logs
--

DROP TABLE IF EXISTS cdr-csv-logs;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE cdr-csv-logs (
  id varchar(20) NOT NULL,
  instance-id varchar(20) DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='MOH media';
/*!40101 SET character_set_client = @saved_cs_client */;


--
-- Table structure for table COS
--

DROP TABLE IF EXISTS COS;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE COS (
  id varchar(20) NOT NULL,
  pkey text NOT NULL,
  active text DEFAULT 'YES',
  cluster text DEFAULT NULL,
  cname text DEFAULT NULL,
  defaultclosed text DEFAULT 'NO',
  defaultopen text DEFAULT 'NO',
  description text DEFAULT NULL,
  dialplan text DEFAULT NULL,
  orideclosed text DEFAULT 'NO',
  orideopen text DEFAULT 'NO',
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table Cluster
--

DROP TABLE IF EXISTS Cluster;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE Cluster (
  id varchar(20) NOT NULL,
  pkey text NOT NULL,
  abstimeout int(11) DEFAULT 14400,
  acl tinyint(1) DEFAULT 0,
  allow_hash_xfer text DEFAULT 'enabled',
  blind_busy text DEFAULT NULL,
  bounce_alert text DEFAULT NULL,
  callrecord_1 text DEFAULT 'None',
  camp_on_q_onoff text DEFAULT NULL,
  camp_on_q_opt text DEFAULT NULL,
  cfwdextern_rule text DEFAULT 'YES',
  cfwd_progress text DEFAULT 'enabled',
  cfwd_answer text DEFAULT 'enabled',
  clusterclid text DEFAULT NULL,
  chanmax int(11) DEFAULT 3,
  countrycode int(11) DEFAULT 44,
  dynamicfeatures text DEFAULT NULL,
  description text DEFAULT NULL,
  devicerec text DEFAULT 'default',
  emailalert text DEFAULT NULL,
  emergency text DEFAULT '999 112 911',
  extblklist text DEFAULT NULL,
  ext_lim int(11) DEFAULT 0,
  ext_len int(11) DEFAULT 3,
  fqdn text DEFAULT NULL,
  fqdninspect tinyint(1) DEFAULT 0,
  include text DEFAULT NULL,
  int_ring_delay int(11) DEFAULT 20,
  ivr_key_wait int(11) DEFAULT 6,
  ivr_digit_wait int(11) DEFAULT 6000,
  language text DEFAULT 'en-gb',
  ldapanonbind text DEFAULT 'YES',
  ldapbase text DEFAULT 'dc=sark,dc=local',
  ldaphost text DEFAULT '127.0.0.1',
  ldapou text DEFAULT 'contacts',
  ldapuser text DEFAULT 'admin',
  ldappass text DEFAULT 'sarkadmin',
  ldaptls text DEFAULT 'off',
  localarea text DEFAULT NULL,
  localdplan text DEFAULT NULL,
  lterm int(11) DEFAULT 0,
  leasedhdtime int(11) DEFAULT 43200,
  masteroclo text DEFAULT NULL,
  maxin int(11) DEFAULT 30,
  maxout int(11) DEFAULT 30,
  mixmonitor text DEFAULT NULL,
  monitor_out text DEFAULT '/var/spool/asterisk/monout/',
  monitor_stage text DEFAULT '/var/spool/asterisk/monstage/',
  name text DEFAULT NULL,
  cname text DEFAULT NULL,
  number_range_regex text DEFAULT NULL,
  oclo text DEFAULT NULL,
  operator int(11) DEFAULT 100,
  padminpass int(11) DEFAULT 44068,
  puserpass int(11) DEFAULT 31524,
  pickupgroup text DEFAULT NULL,
  play_beep int(11) DEFAULT 1,
  play_busy int(11) DEFAULT 1,
  play_congested int(11) DEFAULT 1,
  play_transfer int(11) DEFAULT 1,
  rec_age int(11) DEFAULT 60,
  rec_final_dest text DEFAULT NULL,
  rec_grace int(11) DEFAULT 5,
  rec_limit int(11) DEFAULT NULL,
  rec_mount text DEFAULT NULL,
  recmaxage text DEFAULT '60',
  recmaxsize text DEFAULT '0',
  recused text DEFAULT '0',
  ringdelay int(11) DEFAULT 20,
  routeoverride text DEFAULT NULL,
  spy_pass text DEFAULT '3333',
  sysop int(11) DEFAULT NULL,
  syspass text DEFAULT '4444',
  usemohcustom text DEFAULT NULL,
  VDELAY int(11) DEFAULT 0,
  vmail_age int(11) DEFAULT 60,
  voice_instr int(11) DEFAULT 1,
  voip_max int(11) DEFAULT 30,
  vxt int(11) DEFAULT 0,
  PRIMARY KEY (id),
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;


--
-- Table structure for table customers
--

DROP TABLE IF EXISTS customers;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE customers (
  id varchar(20) NOT NULL,
  cname varchar(100) NOT NULL,
  cdate datetime DEFAULT curdate(),
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/* open/closed automation */
DROP TABLE IF EXISTS dateseg;
CREATE TABLE IF NOT EXISTS dateSeg (
id TEXT,
pkey INTEGER,             -- candidate to be removed
cluster TEXT DEFAULT 'default',
datemonth TEXT DEFAULT '*',
dayofweek TEXT DEFAULT '*',
description TEXT DEFAULT '*NEW RULE*',
month TEXT DEFAULT '*',
state TEXT DEFAULT 'IDLE',
timespan TEXT DEFAULT '*',
PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

/* system settings   - should be merged with or references from instance?  */
CREATE TABLE IF NOT EXISTS globals (
id TEXT PRIMARY KEY,
instance-id TEXT,
ABSTIMEOUT INTEGER DEFAULT 14400,   -- default abstimeout 4 hours **MOVED**
BINDADDR TEXT,                      -- NOT USED
BINDPORT TEXT DEFAULT 5060,			-- SIP BINDPORT
COSSTART TEXT DEFAULT 'ON',            -- COS onoff
EDOMAIN TEXT,                       -- external IP address of this server
EMERGENCY TEXT DEFAULT '999 112 911',  -- **MOVED**
EXTLEN INTEGER DEFAULT 5,				-- extension length - deprecated
FQDN TEXT,							-- FQDN - NEEDS TO MOVE
FQDNINSPECT TEXT DEFAULT 'NO',		-- Require FQDN in SIP Ops Shorewall 4.6+ 
FQDNPROV TEXT,						-- use FQDN in remote provisioning YES/NO
LANGUAGE TEXT DEFAULT 'en-gb',      -- used in extensions.conf 
LOCALIP TEXT,                       -- local ip address
LOGLEVEL INTEGER DEFAULT 0,				-- internal log level
LOGOPTS TEXT,
LOGSIPDISPSIZE INTEGER DEFAULT 2000,	-- number of SIP pcap lines to display
LOGSIPNUMFILES INTEGER DEFAULT 10,		-- number of SIP pcap spins to keep
LOGSIPFILESIZE INTEGER DEFAULT 20000,	-- SIP pcap max filesize (bytes)
MAXIN INTEGER DEFAULT 30,              -- maximum inbound calls
MAXOUT INTEGER DEFAULT 30,             -- maximum outbound calls
MYCOMMIT TEXT,                      -- commit outstanding
NATDEFAULT TEXT DEFAULT 'remote', 	-- V6 NAT defaiult local/remote
NATPARAMS TEXT DEFAULT 'force_rport,comedia', --V6 NAT default remote params
OPERATOR INTEGER DEFAULT 100,
PWDLEN INTEGER DEFAULT 12,				-- password length deprecated
RECFILEDLIM TEXT DEFAULT '_-_',     -- recordings filename delimiter
RECLIMIT TEXT,                      -- recording max size
RECMOUNT TEXT,                   	-- Recording folder mount command
RECQDITHER TEXT,                    -- dither (ms) on queuelog searches
RECQSEARCHLIM TEXT,                 -- search limit on queuelog
SESSIONTIMOUT INTEGER DEFAULT 600,  -- sessiontimeout (10minutes)
SENDEDOMAIN TEXT DEFAULT 'YES',  	-- Send public IP in SIP header YES/NO
SIPFLOOD TEXT DEFAULT 'NO',			-- detect SIP flood YES/NO
SIPDRIVER TEXT DEFAULT 'PJSIP',		-- SIP backend now PJSIP
SITENAME TEXT,                      -- Common name for this site 
STATICIPV4 TEXT DEFAULT NULL,		   -- Static IP to be started
SYSOP INTEGER DEFAULT 100,				-- system operator real extension
SYSPASS INTEGER DEFAULT 4444,			-- password for sysops **MOVED** BUT....
TLSPORT	INTEGER DEFAULT 5061,		-- TLS port (default 5061)
USEROTP TEXT DEFAULT NULL,			   -- V6 default OTP.  Seeded by the generator
VCL TEXT DEFAULT '1',			      -- V5 cloud enabled (1/0)
VOIPMAX INTEGER DEFAULT 30,			-- MAX outbound up calls 
PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

/* system greetings */
CREATE TABLE IF NOT EXISTS Greeting (
id TEXT,	
pkey TEXT,
cname TEXT,
directdial INTEGER,
filename TEXT,
cluster TEXT DEFAULT 'default',
description TEXT,
type TEXT,
PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

/* Holiday overrides */
CREATE TABLE IF NOT EXISTS Holiday (
id TEXT,
pkey TEXT,								      -- not really used but satisfies tuple builder
cluster TEXT DEFAULT 'default',			-- tenant
cname TEXT,
description TEXT,								-- Description						
route TEXT,								      -- Holiday scheduler route override
stime INTEGER,							      -- Epoch start
etime INTEGER,							      -- Epoch end
PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

--
-- Table structure for table instances
--

DROP TABLE IF EXISTS instances;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE instances (
  id varchar(20) NOT NULL,
  cname varchar(100) NOT NULL,
  cdate datetime DEFAULT curdate(),
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/* Extensions */
CREATE TABLE IF NOT EXISTS IPphone (
id TEXT,
pkey TEXT, 
abstimeout INTEGER DEFAULT 1440,
active TEXT DEFAULT 'YES',			      -- Active/inactive flag
basemacaddr TEXT,                      -- not used             
callerid TEXT,                         -- CLID
callbackto INTEGER DEFAULT 100,        -- who we callback (ext/cell)
cname TEXT,                            -- common name
callmax TEXT DEFAULT 3,				      -- PJSIP does not support call-limit so we have to do it using GROUP
cellphone TEXT,						      -- cellphone twin
celltwin TEXT,							      -- cell twin on/off
cluster TEXT DEFAULT 'default',        -- Tenant
-- desc is deprecated, use cname instead
desc TEXT,
description TEXT,                      -- asterisk username
device TEXT,                           -- device vendor
devicemodel TEXT,						      -- Harvested model number
devicerec TEXT DEFAULT 'default',      -- recopts
dvrvmail TEXT,                         -- mailbox
extalert TEXT,                         -- alert info
firstseen TEXT,						      -- first date provisioned (or NULL)
lastseen TEXT,							      -- last date provisioned (or NULL)
macaddr TEXT,                          -- mac address
passwd TEXT,                           -- asterisk password
protocol DEFAULT 'IPV4',			      -- IPV4/IPV6
pjsipuser TEXT,						      -- Asterisk PJSIP string							
provision TEXT,                        -- provisioning string 
provisionwith TEXT DEFAULT 'IP',	      -- how to provision my id - IP address or FQDN   
sndcreds TEXT DEFAULT 'Always',        -- send creds with provisioning
stealtime INTEGER,                     -- epoch time this extension was stolen by HD
stolen TEXT,                           -- HD thief 
technology TEXT,                       -- SIP/IAX2/DiD/CLiD/Class
tls TEXT,                              -- SSIP on/off
transport TEXT DEFAULT 'udp',		      -- transport(udp/tcp/tls/wss)
vmailfwd TEXT,
PRIMARY KEY (pkey,cluster)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

/* Class of service */
CREATE TABLE IF NOT EXISTS IPphoneCOSopen (
id TEXT,
cluster TEXT,
IPphone_pkey TEXT,
COS_pkey TEXT,
PRIMARY KEY (IPphone_pkey, COS_pkey)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

/* Class of service */
CREATE TABLE IF NOT EXISTS IPphoneCOSclosed (
id TEXT,
cluster TEXT,
IPphone_pkey TEXT,
COS_pkey TEXT,
PRIMARY KEY (IPphone_pkey, COS_pkey)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

/* IVR menus */
CREATE TABLE IF NOT EXISTS ivrmenu (
id TEXT,	
pkey TEXT NOT NULL,
alert0 TEXT,						-- Alertinfo for each keypress
alert1 TEXT,
alert10 TEXT,
alert11 TEXT,
alert2 TEXT,
alert3 TEXT,
alert4 TEXT,
alert5 TEXT,
alert6 TEXT,
alert7 TEXT,
alert8 TEXT,
alert9 TEXT,
cluster TEXT,
description TEXT DEFAULT 'None',
greetnum TEXT DEFAULT 'None',			-- greeting number to play
listenforext TEXT DEFAULT 'NO',
-- name is deprecated and will be dropped in a near release use cname instead
name TEXT,
cname TEXT,                            -- common name
option0 TEXT DEFAULT 'None',						      -- routed name for each keypress
option1 TEXT DEFAULT 'None',
option10 TEXT DEFAULT 'None',
option11 TEXT DEFAULT 'None',
option2 TEXT DEFAULT 'None',
option3 TEXT DEFAULT 'None',
option4 TEXT DEFAULT 'None',
option5 TEXT DEFAULT 'None',
option6 TEXT DEFAULT 'None',
option7 TEXT DEFAULT 'None',
option8 TEXT DEFAULT 'None',
option9 TEXT DEFAULT 'None',
tag0 TEXT,							      -- alphatag for each keypress
tag1 TEXT,
tag10 TEXT,
tag11 TEXT,
tag2 TEXT,
tag3 TEXT,
tag4 TEXT,
tag5 TEXT,
tag6 TEXT,
tag7 TEXT,
tag8 TEXT,
tag9 TEXT,
timeout TEXT,			               -- timeout name 					
PRIMARY KEY (pkey,cluster)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

/* trunks/gateways */
CREATE TABLE IF NOT EXISTS lineIO (
id TEXT,
pkey TEXT,
active TEXT DEFAULT 'YES',	-- Active/inactive flag
alertinfo TEXT,				-- distinctive ring
callback TEXT,				-- denotes callback trunk
callerid TEXT,				-- high-order (weak) CLID
callprogress TEXT DEFAULT 'YES',		-- send progress tones on dial
closeroute TEXT,			-- closed inbound route
cluster TEXT,				-- cluster (Tenant) this trunk belongs to
cname TEXT,
description TEXT,			-- weak Asterisk username 
devicerec TEXT,			-- RECOPTS
disa TEXT,					-- DISA capable trunk
disapass TEXT,				-- DISA password
host TEXT,					-- Host IP address
iaxreg TEXT DEFAULT NULL,	-- Asterisk IAX registration (SND/RCV/NULL)		
inprefix TEXT,				-- prepend prefix on inbound
match TEXT,					-- trunk seize sequence
moh TEXT DEFAULT 'NO',	-- play moh instead of ring
openroute TEXT,			-- open inbound route
password TEXT,				-- far end password
peername TEXT,				-- strong Asterisk username
pjsipreg TEXT DEFAULT NULL,	-- Asterisk pjsip registration (SND/RCV/NULL)									
privileged TEXT,			-- privileged ingress 
register TEXT,				-- registration string
swoclip TEXT DEFAULT 'YES',	-- Switch On CLIP
tag TEXT,					-- Alpha tag
technology TEXT,           -- SIP/IAX2/DiD/CLiD/Class
transform TEXT,				-- Transformation mask
transport TEXT DEFAULT 'udp',
trunkname TEXT,				-- freeform trunkname
username TEXT,				-- far end username
PRIMARY KEY ('id')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

/* page groups */
CREATE TABLE IF NOT EXISTS page (
pkey TEXT,
cluster TEXT,
cname TEXT,
pagegroup TEXT,
PRIMARY KEY ('id')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

/* conference rooms */
CREATE TABLE IF NOT EXISTS meetme (
id TEXT,
pkey INTEGER,
cluster TEXT DEFAULT 'default',
cname TEXT,
adminpin TEXT DEFAULT 'None',
description TEXT,
pin TEXT DEFAULT 'None',
type TEXT DEFAULT 'simple',
PRIMARY KEY ('id')
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


/* call queues */
CREATE TABLE IF NOT EXISTS Queue (
id TEXT,
pkey TEXT,
active TEXT DEFAULT 'YES',
alertinfo TEXT,
cluster TEXT,
description TEXT, 
devicerec TEXT,
divert INTEGER,
greetnum TEXT DEFAULT 'None',
greeting TEXT DEFAULT 'None',       --N.B. will replace greetnum
-- name is deprecated and will be dropped in a near release use cname instead
name TEXT,                      --Human readable name
cname TEXT,                            -- common name
members TEXT,                       --N.B. will replace OUT in speed
options TEXT DEFAULT 'CiIknrtT',
musicclass TEXT,
retry INTEGER DEFAULT 1,
wrapuptime INTEGER DEFAULT 0,
maxlen INTEGER DEFAULT 0,
outcome TEXT DEFAULT 'None',
outcomerouteclass TEXT,
strategy TEXT DEFAULT 'ringall',    -- fine selection, all of the Asterisk types
timeout INTEGER DEFAULT 30,
PRIMARY KEY (pkey,cluster)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


--
-- Table structure for table recordings
--

DROP TABLE IF EXISTS recordings;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE recordings (
  id varchar(20) NOT NULL,
  caller-id varchar(20) NOT NULL,
  callee-id varchar(20) NOT NULL,
  cdate datetime DEFAULT curdate(),
  tenant-id varchar(20) NOT NULL,
  s3key varchar(1024) NOT NULL,
  instance-id varchar(20) NOT NULL,
  PRIMARY KEY (id),
  KEY recordings_cdate_IDX (cdate) USING BTREE,
  KEY recordings_caller_id_IDX (caller-id) USING BTREE,
  KEY recordings_callee_id_IDX (callee-id) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

/* Outbound routing */
CREATE TABLE IF NOT EXISTS Route (
id TEXT,	
pkey TEXT,
active TEXT DEFAULT 'YES',
alternate TEXT,               -- alternate dial for desk to desk shortdial
auth TEXT DEFAULT 'NO',       -- 1/0 used for pin dial
cluster TEXT,
cname TEXT,
description TEXT,  
dialplan TEXT,                -- route dialplan
path1 TEXT DEFAULT 'None',
path2 TEXT DEFAULT 'None',
path3 TEXT DEFAULT 'None',
path4 TEXT DEFAULT 'None',
route TEXT DEFAULT 'None',       -- always the same as pkey.   Not used, not needed.
strategy TEXT DEFAULT 'hunt',   --hunt or balance
PRIMARY KEY (id),
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;


--
-- Table structure for table syslogs
--

DROP TABLE IF EXISTS syslogs;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE syslogs (
  id varchar(20) NOT NULL,
  instance-id varchar(20) DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='MOH media';
/*!40101 SET character_set_client = @saved_cs_client */;

/* messages table */
CREATE TABLE IF NOT EXISTS tt_help_core (
id TEXT PRIMARY KEY,
displayname TEXT,
htext TEXT,
-- name is deprecated and will be dropped in a near release use cname instead
name TEXT,
cname TEXT,                            -- common name
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci COMMENT='MOH media';

--
-- Table structure for table tenants
--



/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;

-- Dump completed on 2024-12-09  1:03:37
