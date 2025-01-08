
BEGIN TRANSACTION;


/* Laravel tables - these live with the instance and are universal to the instance */

CREATE TABLE IF NOT EXISTS "migrations"(
  "id" integer primary key autoincrement not null,
  "migration" varchar not null,
  "batch" integer not null
);
CREATE TABLE IF NOT EXISTS "users"(
  "id" integer primary key,
  /* cluster added to handle cluster migration */
  "cluster" varchar DEFAULT "default",
  "name" varchar not null,
  "email" varchar not null,
  "email_verified_at" datetime,
  "password" varchar not null,
  "remember_token" varchar,
  "created_at" datetime,
  "updated_at" datetime
);
CREATE UNIQUE INDEX "users_email_unique" on "users"("email");
CREATE TABLE IF NOT EXISTS "password_reset_tokens"(
  "email" varchar not null,
  "token" varchar not null,
  "created_at" datetime,
  primary key("email")
);
CREATE TABLE IF NOT EXISTS "sessions"(
  "id" varchar not null,
  "user_id" integer,
  "ip_address" varchar,
  "user_agent" text,
  "payload" text not null,
  "last_activity" integer not null,
  primary key("id")
);
CREATE INDEX "sessions_user_id_index" on "sessions"("user_id");
CREATE INDEX "sessions_last_activity_index" on "sessions"("last_activity");
CREATE TABLE IF NOT EXISTS "cache"(
  "key" varchar not null,
  "value" text not null,
  "expiration" integer not null,
  primary key("key")
);
CREATE TABLE IF NOT EXISTS "cache_locks"(
  "key" varchar not null,
  "owner" varchar not null,
  "expiration" integer not null,
  primary key("key")
);
CREATE TABLE IF NOT EXISTS "jobs"(
  "id" integer primary key autoincrement not null,
  "queue" varchar not null,
  "payload" text not null,
  "attempts" integer not null,
  "reserved_at" integer,
  "available_at" integer not null,
  "created_at" integer not null
);
CREATE INDEX "jobs_queue_index" on "jobs"("queue");
CREATE TABLE IF NOT EXISTS "job_batches"(
  "id" varchar not null,
  "name" varchar not null,
  "total_jobs" integer not null,
  "pending_jobs" integer not null,
  "failed_jobs" integer not null,
  "failed_job_ids" text not null,
  "options" text,
  "cancelled_at" integer,
  "created_at" integer not null,
  "finished_at" integer,
  primary key("id")
);
CREATE TABLE IF NOT EXISTS "failed_jobs"(
  "id" integer primary key autoincrement not null,
  "uuid" varchar not null,
  "connection" text not null,
  "queue" text not null,
  "payload" text not null,
  "exception" text not null,
  "failed_at" datetime not null default CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX "failed_jobs_uuid_unique" on "failed_jobs"("uuid");
CREATE TABLE IF NOT EXISTS "personal_access_tokens"(
  "id" integer primary key autoincrement not null,
  "tokenable_type" varchar not null,
  "tokenable_id" integer not null,
  "name" varchar not null,
  "token" varchar not null,
  "abilities" text,
  "last_used_at" datetime,
  "expires_at" datetime,
  "created_at" datetime,
  "updated_at" datetime
);
CREATE INDEX "personal_access_tokens_tokenable_type_tokenable_id_index" on "personal_access_tokens"(
  "tokenable_type",
  "tokenable_id"
);
CREATE UNIQUE INDEX "personal_access_tokens_token_unique" on "personal_access_tokens"(
  "token"
);


/* SYSTEM TABLES - these are not backed up as part of a cluster backup */

/* system settings */
CREATE TABLE IF NOT EXISTS globals (
pkey TEXT PRIMARY KEY,
ABSTIMEOUT INTEGER DEFAULT 14400,   -- default abstimeout 4 hours **MOVED**
BINDADDR TEXT,                      -- Asterisk SIP bindaddr
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
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* trunks/gateways */
CREATE TABLE IF NOT EXISTS gateways (
id TEXT,
pkey TEXT PRIMARY KEY,
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
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

/* messages table */
CREATE TABLE IF NOT EXISTS tt_help_core (
pkey TEXT PRIMARY KEY,
displayname TEXT,
htext TEXT,
-- name is deprecated and will be dropped in a near release use cname instead
name TEXT,
cname TEXT,                            -- common name
z_created datetime,
z_updated datetime,
z_updater TEXT DEFAULT 'system'
);

COMMIT;

