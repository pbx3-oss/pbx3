-- tt_help_core seed data. htext: Markdown (GFM). Export: pbx3spa/scripts/export-help-core-to-sql.mjs
-- Pruned: SPA-referenced rows only (audit-unreferenced-help.mjs --prune).
BEGIN TRANSACTION;
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('abstimeout','Call Timeout (seconds)','Use this value to set an absolute time limit for outbound calls.  The default is 14400 seconds (4 hours) and the maximum permitted value is 99999 seconds (about 28 hours). After the timer expires, the call will be put on-hook by the system.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('action','Action','Firewall Action - for PBX3 this is always ACCEPT');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('active','Active?','Activate or de-activate this object');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('adminpin','Admin PIN','Administrator PIN (0000->9999 or blank)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('agent','Agent','Agent number (allocated by PBX3)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('alertinfo','Alert-info string','Use this field to specify distinctive ring data for the sip header.  This is phone specific so you will need to read up on your phone type.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('allday','Whole Day Close','If this rule applies to a whole day, e.g. perhaps you are closed every Saturday, then turn this switch on');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('allow_hash_transfer','Allow hash transfer','Allow in-band transfer using the hash key (default is enabled)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('bindport','SIP Listen Port','This determines the local port at which the PBX will listen for SIP.   By default this is the well known UDP port 5060 but you can set this to some high port to help avoid SIP hack attacks.  N.B. your phones will need to be aware of this value and you will need to provision them accordingly.  You will also need to add port=5060 to your upstream trunk peer definitions.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('blkstart','Extension','This is the number which an end-user will dial to contact this endpoint (e.g 123, 1234, 12345).  It is NOT the same as the *sip-user* (which is an auto generated unique 6 character string used to identify the sip endpoint).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callbackto','Callback destination','Which device you want us to call when you click2dial; your deskphone or your cellphone.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callerid','Outbound Caller ID','Usually you can leave this field blank and the endpoint will automatically send its extension CLID.  However if, for example, you want to send a DDI then you can set it here.  Internal calls will always use the phone''s extension CLID');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callmax','Call Max','The maximum number of concurrent calls allowed for this extension.  Once the extension has Call Max calls running, no further calls will be started until the number falls below Call Max.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callprogress','Call Progress?','Force an early ringback tone.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callrecord_1','Call Recording Default','Set the global recording preferences you want. This can be overridden at the individual call group or extension.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cellphone','Cellphone Twin','Here you can enter a cellphone number to be the twin of this extension.  You can then turn twinning on and off.  When twinning is active, calls to the extension will also ring the cell.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('celltwin','Enable Cell Twinning','Turn cell twinning on/off');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cfbs','Call Forward Busy','When this is set calls to this extension will be forwarded on busy.  However, most multi-line SIP phones will almost never actually give back a busy signal unless you disable call-waiting in the phone. Calls to this extension from a ring group will usually still ring the extension.  You can change this behaviour by changing the parameters in the individual ring groups. You can also set/unset this feature from the phone with *22*{number}.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cfim','Call Forward Immediate','When this is set all direct calls to this extension will be immediately forwarded to the number you enter.  Calls to this extension from a ring group will usually still ring the extension.  You can change this behaviour by changing the parameters in the individual ring groups. You can also set/unset this feature from the phone with *21*{number}.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cfwd_answer','CFWD ANSWER','Cause external call forwards (hairpin calls) to be answered by Asterisk before the external call leg is started. This can sometimes be necessary to force RTP packets to flow across NATs when forwarding SIP calls.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cfwd_progress','CFWD PROGRESS','Cause external call forwards (hairpin calls) to be dialed with early media. This can sometimes be necessary to force RTP packets to flow across NATs when forwarding SIP calls.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('chanmax','ChanMax','The maximum number of outbound channels allowed for this tenant.  Once the tenant has ChanMax calls running, no further calls will be started until the number falls below ChanMax.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('chooser','Trunk Type','Choose the type of trunk you want from the dropdown; -
{SIP|IAX2}.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('closeroute','Closed','The CLOSED inbound route.  The route which will be used by the inbound route manager to process calls from this DDI outside of business hours.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cluster','Tenant','This is the name of the Tenant which this object belongs to.  If you specified no Tenant then PBX3 will use the default Tenant.  Tenants are used to provide multi-tenant support within PBX3.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('clusterclid','CLID','This is the default CLID that will be sent from this Tenant.  Usually you should set this to the main inbound number for the Tenant.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('clustersysop','Operator','The extension to be used as the operator for this Tenant.  This is used by PBX3 as the endpoint of last resort so it is important that you select a real endpoint.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cname','Common Name','Common name for this object');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('confpkey','Room','Room Number (100->99999).  Room numbers must be unique.  It is a good idea to choose a block of numbers for this purpose so you don''t accidentally try to allocate an extension with the same number as a conference room.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('conftype','Conference Type','Choose from assisted or unassisted conferences.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('context','Context Name','The name of the context you want your custom app to run in.  This must be system-wide unique.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cosclosed','Default Closed','Defines whether this COS will be ON by default for closed hours when new extensions are created.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cosdialplan','Dialplan','The dialplan pattern for this class-of-service.  COS dialplans follow standard Asterisk dialplan conventions.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cosname','Key','Dialplan context key for this Class of Service rule. SPA-created rules use the system UID automatically; product seeds may use a stable name (e.g. HR_UK070). Not editable after create.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cosopen','Default Open','Defines whether this COS will be ON by default for open hours when new extensions are created.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cosstart','Class Of Service','Whether we will run COS or not.  PBX3 Class of Service is very powerful but if you dont intend to use it then you can save a little cpu by turning it off.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('countrycode','Country Code','Set to the correct code for your country.  This will control the tones which Asterisk generates for busy, ringback, congestion etc.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('customappname','Custom app name','Unique name for this custom Asterisk application (maps to the app context).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dayofweek','Week Day','Choose the day of the week you want this rule to apply to. If it applies every day (for example, your night time close hours) then choose Every Day.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('default_outbound_dialplan','Default outbound dialplan','Instance default route dialplan string (space-separated Asterisk patterns). Copied once onto each new tenant OutRoute (MainOut → Egress on fleet). Edit per tenant afterward. UK seed: _0XXX. _00XX. (national + IDD; each pattern min match must exceed tenant extension length). US nodes should use a NANP/011 pattern string instead.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('desc','User','This is usually the name of the endpoint user.  In the case of a sip extension it is used to set the *caller-id(name)* on outbound calls.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('description','Description','Freeform description string');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('device','Device','Extension type label: General SIP, WebRTC, MAILBOX, or a vendor name when a MAC OUI is recognised. Not a provisioning template (in-house provisioner is won''t-do; use manufacturer RPS).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('devicerec','RecOpts','Recording options for this object. Recording options can be one of the following:-
default - use the value set in Globals
None - Do not record for this endpoint
Inbound - Record inbound calls
Outbound - Record outbound calls
Both - Record both inbound and Outbound

The list of available options will vary depending upon the object you are working with.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('devtech','Template Type','This is the Template type.  Type can be ''SIP'' (for a regular phone stream), ''Descriptor'' (for a reuseable component like a common provisioning block) or ''BLF Template'' (for a recursive BLF block)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dialplan','Dialplan','Route dialplan.  The dialplan consists of the set of numbers and number patterns that this route will be sensitive to. (e.g. _0XXX. 100 _XXXXX)   Arguments are separated by whitespace.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dialprefix','Dial prefix','2–4 digit prefix local to this tenant. Dial prefix then the remote extension (digits only). Example: prefix 81 + extension 1000 → dial 811000. Feature codes (*…) stay local — not after a prefix.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dialprefix_target','Target tenant','Pick another tenant from the known list (this node plus fleet catalog when available). Stored as that tenant’s full FQDN — not the instance hostname. Prefix is only for the calling tenant; reverse needs its own prefix on the other side.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('didnumber','DiD Number/Pattern','DiD number.  You can specify this in several different ways according to your needs.
A single DiD number will route just that number e.g.:-
*0123456789*
You can specify a DiD range by using a slash to indicate how many DiDs there are in the range e.g.:-
*0123456780/10*
This example will actually allocate 10 DiD numbers for you.
Finally, you can specify a pattern.  For example if you wanted to route all of the numbers in a DiD range you can specify a pattern like this:-
*_012345678X*');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('directdial','Direct Dial','Dialable number for this object; it MUST be unique withing your Tenant!');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('disapass','DISA Password ','4 digit DISA password.  Set this ONLY if you intend this trunk to be dedicated to DISA.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('displayname','Legend ','String which will appear alongside the target object (or inside a widget) whenever it is displayed by PBX3.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('divert','Divert Target','When set, you can use this value as a target for a visual or manual divert of this ring group.  The extension for the divert (or BLF) will be **{ring group number}. So for example, ring group 800 will be diverted when **800 is dialed either manually or from a BLF key.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dns','DNS Server','Set this to the correct value for your network');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('domain','Local Domain','This is the local Domain name within your IPV4 LAN. In most cases you can leave it as it is');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dvrvmail','Voicemailbox','Number of the voice mailbox you wish to have voicemail delivered to. The default is the extension but you can have it delivered to a different extension if you wish');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('edomaindig','Public IP Address','This is the public IP address returned from DiG. The public IP address is usually needed if you are running behind a NATed firewall. It forces Asterisk to include the correct return IP address in outbound SIP/RTP packets. Without it, Asterisk will use the local server IP address and effectively spoof itself.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('emergency','COS Emergency passthru','Use this field to set your Emergency number (e.g. 911, 999, 112).  This is used by Class of Service and becomes part of the always-available set of dialable numbers.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('end','End time','Use **24-hour (military) time** in **HH:MM** — **not AM/PM**. Examples: `09:00` = 9:00 AM, `13:30` = 1:30 PM, `17:00` = 5:00 PM.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('entry_dest','Always route','Optional fixed destination: skip schedule and always send the call here.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('extalert','Alert-info string','Alert-info alters the SIP header sent to the device.  It is usually used to send a request to play a distinctive ring-tone.  The actual content of the header varies from device to device.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('extchooser','Extension Type','Choose the type of extension you want from the dropdown; -
Provisioned extensions are auto provisioned by PBX3 and you will need to enter the MAC address of the phone.
Unprovisioned extensions require no MAC and you manage their provisioning yourself.
You can also create blocks where you can specify multiple extensions and PBX3 will create them all in one go.  For provisioned extensions you must supply a block of MAC addresses.  For unprovisioned extensions you simply need to tell PBX3 how many you want.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('extcode','Extension Code','Asterisk **extensions.conf** dialplan fragment for this custom app. On commit it is written under a context named after the app **pkey**. Use standard Asterisk dialplan syntax (priorities, applications, and labels).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('filetype','Filetype','File type (MP3|wav)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fqdn','Public FQDN','The Fully Qualified Domain Name (if any) which resolves to this server, e.g. *somesip.someserver.com*');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fwdesc','Comment','Optional comment stored on the UFW allow-list rule (shown in ufw status).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fwdestports','Port','Destination port or range (e.g. 5060 or 10000:20000). Leave empty for icmp.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fwproto','Proto','Network protocol: tcp, udp, icmp, or all.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fwsource','Source','Literal source only: any, an IPv4 or IPv6 address, or CIDR (e.g. 192.168.1.85, 192.168.1.0/24, 2001:db8::1, 2001:db8::/32). No $LAN/$SBC shorthand. One table covers UFW IPv4 and IPv6.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('greeting','Greeting Number','Greeting number that this IVR uses.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('greetingnum','Number','The 4-digit greeting number');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('host','Host address','Enter the URL or the IP address of the target host (unless this host will register with you, in which case enter the string ''dynamic'')');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('help_message_key','Message key','Unique **`tt_help_core.pkey`** for this help row. Must match the column name SPA fields use in **`help-pkey`** (letters, digits, underscore, hyphen — no spaces). **Immutable after create.** Example keys: `password`, `callerid`, `tenantname`.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('hostname','Hostname','The local hostname of this server.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('icmp','Accept ping requests?','Set to NO if you want to ignore ping requests');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('idd','Dial','IVR direct dial access.  Supply a unique tenant-wide extension number here.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('inprefix','Add CLI Prefix','Allows you to add a CLI prefix.  This is because many carriers do not send the NDD character (usually zero).  This allows you to add it back.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ivr_digit_wait','IVR digit wait','How long to wait for another digit');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ivr_key_wait','IVR key wait','How long to wait after keypress');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('language','Language','Default language code for voice prompts and voicemail (e.g. en-gb).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldapanonbind','LDAP anonymous bind','LDAP anonymous bind YES/NO');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldapbase','LDAP Base','LDAP base, sometimes called domain; enter it in the form dc=somecompany,dc=com');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldaphost','LDAP host','LDAP host');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldapou','Organizational Unit','The name of the OU where the contacts directory is held (default contacts) ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldappass','LDAP Password','ldap password for PBX3 to use');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldaptls','LDAP TLS','LDAP TLS mode(off/on)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldapuser','LDAP User','ldap user for PBX3 to use - it must have update privileges to the directory OU');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('leasedhdtime','Hot desk lease','Seconds a hot-desk extension lease remains valid before automatic release.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('listenforext','Listen for extension dial?','If this switch is turned on, the ivr will listen for an extension dial(as well as the ivr key presses). You should be aware that this will slow down the IVR response because it will listen for extra digits after the first keypress.  If this is not what you want you can include an ’extension press’ option in your greeting; e.g. ’press the star key to enter an extension number’.  Then you can handle the listen option in a separate sub-IVR which is set to listen but has no active keys.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('localarea','Area Code','(Optional field) This is the area code for this Tenant.  If you specify it AND a local dialplan then the system will automatically prepend the area code when you dial a short local number.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('localdplan','Local Dialplan','(Optional field) This is an Asterisk dialplan for local numbers for this tenant. If you specify it AND your area code (above) then the system will automatically prepend the local area code when you dial a local number');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('localIP','Local IPV4','Local subnet IPV4 address');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('loglevel','SysLog Level','Sets the browser log level. Valid values 0-9.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('logsipdispsize','PCAP display size','Sets the initial number of lines to display from a PCAP segment in the log browser window. This keeps the response time down on large PCAP segments.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('logsipfilesize','Max Segment Size','Sets the maximum size of a SIP PCAP log segment (in Kbytes).  Thus the maximum space the logger will use is *{segment size X max segments}*');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('logsipnumfiles','Max Segments','Sets the maximum number of file segments in the log set before rotation will occur.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('log-local-cdr','Local days — CDR CSV','Number of days to keep before deleting or archiving');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('log-local-messages','Local days — Asterisk messages','Number of days to keep before deleting or archiving');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('log-local-syslog','Local days — syslog','Number of days to keep before deleting or archiving');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('log-s3-cdr','S3 maxage days — CDR','Number of days to keep before deleting');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('log-s3-messages','S3 maxage days — Asterisk messages','Number of days to keep before deleting');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('log-s3-syslog','S3 maxage days — syslog','Number of days to keep before deleting');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('lterm','Late Termination','If you set this on, PBX3 will attempt to terminate inbound calls as late as it can in the switching process (i.e. when the target extension goes off hook).   This is not always possible, or desireable and it can sometimes cause loss of ringback tone during complex switching operations such as internal/external call forking.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('macaddr','MAC','The MAC address of the end-point.  The MAC address is used by PBX3''s autoprovisioning routines. If you do not provide the MAC address you will not be able to use autoprovisioning.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('masterclose','Master force','Master hard-force (BLF/API). AUTO = follow day-parts schedule (timer sched_mode + route profiles). CLOSED forces closed routing and wins over holidays. Multi-mode force uses AstDB OCSTAT mode tokens; *30*/*31* still AUTO/CLOSED.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('match','Line Pre-select','Optional: 1 or 2 digit pre-select code which you can use to seize a specific trunk (must be systemwide unique)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('maxin','Max inbound calls','Maximum concurrent inbound calls allowed for this scope (instance globals or tenant).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('maxlen','Max queue length','Maximum number of callers waiting in the queue. When full, additional callers receive the busy treatment.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('maxout','Max outbound calls','Maximum concurrent outbound calls allowed at instance level.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('members','Queue members','Member endpoints for this queue (comma-separated hints or extensions). Dynamic members are often managed via the queue configuration.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('mode','Day timer mode','Mode asserted when this day-timer window matches (e.g. closed, lunch). Higher priority wins on overlap.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('priority','Priority','When two or more day timers match the same time on this tenant, the **higher priority number wins** and sets the schedule mode. Equal priority: first matching timer in database order is kept. Default is 0.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('moh','MOH on Ring?','Play Music-on-Hold rather than the more usual ringback tone to the caller.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('monitor_out','Monitor out path','Directory where completed call monitor files are stored.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('monitor_stage','Monitor stage path','Staging directory for in-progress monitor recordings.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('musicclass','Music class','Music-on-hold class played to callers while waiting. Must match an MOH class configured for this tenant or the system default.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('named_call_group','Named call groups','Asterisk **named_call_group**: the pickup pool(s) this extension **belongs to**. Ringing calls on this phone are eligible for pickup by others whose **Named pickup groups** include the same token(s). Default **ALL** = whole tenant (tenant shortuid on Commit — isolated across tenants on one instance). Comma-separated department names or digit tokens (e.g. `sales` or `1,2`). Can differ from Named pickup groups.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('named_pickup_group','Named pickup groups','Asterisk **named_pickup_group**: the pool(s) this extension **can pick up from** (*8 / directed pickup). Default **ALL** = whole tenant. Comma-separated department names or digit tokens (e.g. `sales` or `1,2`). Can differ from Named call groups (e.g. belong to `sales` but pick up `sales,support`). Takes effect on Commit.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('openroute','Open ','The OPEN inbound route. The route which will be used by the inbound route manager to process calls from this DDI during normal business hours.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('orideclosed','Override','Set this to YES if you want to force ALL extensions to have this closed restriction');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('orideopen','Override','Set this to YES if you want to force ALL extensions to have this open restriction');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('outcome','Outcome','Where the call will be delivered if the call group fails to terminate the call.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('password','Password','The password for this account, called the secret in Asterisk');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('path1','Path 1','You can specify up to 4 paths (1 primary and up to 3 failover) in descending order of priority.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('path2','Path 2','You can specify up to 4 paths (1 primary and up to 3 failover) in descending order of priority.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('path3','Path 3','You can specify up to 4 paths (1 primary and up to 3 failover) in descending order of priority.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('path4','Path 4','You can specify up to 4 paths (1 primary and up to 3 failover) in descending order of priority.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('peername','Peer name','This is the SIP or IAX peername.  If this is an upstream (vendor) trunk then it will have been given to you by your supplier. If it is a downstream (Asterisk) trunk then it should have a unique name.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('pin','PIN','PIN.  This can be a conference room PIN or an agent PIN.

*Conference room* PIN (when set) is required to enter the conference.
*Agent* PIN is required to login as an agent to service a Queue(s).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('pjsip_overlay','PJSIP overlay','Admin-only thin fragment merged into the stock phone/WebRTC (or trunk) PJSIP template on **Commit**. Each block targets a PJSIP object by **`type=`** — **endpoint**, **auth**, or **aor** (not just the endpoint). GenAst **replaces or adds** keys on that object. Leave empty for the stock template. Prefer first-class SPA fields (e.g. Named call/pickup groups) when they exist.

**Examples** (use the extension **shortuid** in `[...]`; you can combine several blocks in one overlay):

Endpoint — codecs:
[abc123]
type=endpoint
allow=!all,ulaw,alaw,g722

Endpoint — media:
[abc123]
type=endpoint
direct_media=yes

AOR — contacts / qualify:
[abc123]
type=aor
max_contacts=2
qualify_frequency=60

Takes effect on **Commit**. Stock defaults live in the package templates; generated output is in `pjsip_ready_phones.conf` / `pjsip_ready_webrtc.conf` on the node.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('park_overlay','Parking overlay','Admin-only thin fragment merged into the stock **parking lot** template (`parking_lot.tmpl`) on **Commit**. Targets the tenant section **`[park-$clstshortuid]`**. GenAst **replaces or adds** keys on that section. Leave empty for the stock template (default park dial *900, slots 901–903, 30s timeout).

**Examples** (section header is substituted on Commit; combine key lines in one overlay):

Longer timeout and more slots:
[park-$clstshortuid]
parkingtime=45
parkpos=901-909

Different park retrieve code:
[park-$clstshortuid]
parkext=*88

Takes effect on **Commit**. Generated overlay: `callparks/{shortuid}_parking.overlay.conf` on the node.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('queue_overlay','Queue overlay','Admin-only thin fragment merged into the stock **queue** template (`queue.tmpl`) on **Commit**. **Flat `key=value` lines** only — GenAst prepends **`[shortuid]`** for this queue. GenAst **replaces or adds** keys on that section. Leave empty for the stock template. Prefer first-class SPA fields (strategy, timeout outcome, members) when they exist.

**Examples** (combine key lines in one overlay; no section header needed):

Longer ring and retry:
timeout=45
retry=5

Announce hold time:
announce-holdtime=yes
announce-frequency=30

Takes effect on **Commit**. Generated overlay: `queues/{pkey}_queue.overlay.conf` on the node.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('pjsipreg','SIP registration','How this **SIP trunk** handles provider registration. **Instance → Outbound → Trunks** (not fleet tenant panels). Choose at **create**; edit shows the saved mode.

**Purpose** — Tells GenAst which stock PJSIP trunk template to use on **Commit**. For send-registration, Asterisk registers outbound to the ITSP via a PJSIP `type=registration` object built from **Host**, **Username**, and **Password**.

**Choices**
- **Send registration (SND)** — PBX registers to the provider. Host must be IP/FQDN (not `dynamic`).
- **Accept registration (RCV)** — Provider registers to the PBX. Use host **`dynamic`**.
- **Trusted peer** (empty) — No outbound registration; provider sends to a fixed host/IP.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('play_beep','Play tone on Failover','If set on, a beep tone will be played whenever the system fails over a trunk call to a secondary provider.  If set off, no tone will be played.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('play_busy','Play tone on Busy','If set to YES the PBX will come off-hook and play a busy tone, if set to NO the PBX will stay on-hook and play a busy message, if set to SIGNAL a BUSY signal will be sent to the ua.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('play_congested','Play tone on Congested','If set to YES the PBX will come off-hook and play a congestion tone, if set to NO the PBX will stay on-hook and play a congestion message, if set to SIGNAL a CONGESTION signal will be sent to the ua.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('play_transfer','Play message on transfer','If set on the PBX will play, "Please hold while we try to connect you." whenever it attempts to transfer a call to some remote endpoint (for example a cellphone).  if set off, no message will be played.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('privileged','Priv','Denotes whether this trunk is running in privileged mode or unprivileged mode.  For regular external trunks, you can generally leave this to default.  Set the switch ON if you are building inter-site trunks, for example between remote premises. It will set the correct trunk contexts and send the correct CLID during intersite exchanges.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('protocol','Internet Protocol','This can be IPV4 or IPV6 (if your network supports it).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('q1','Q1','Agent Queue ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('q2','Q2','Agent Queue ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('q3','Q3','Agent Queue ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('q4','Q4','Agent Queue ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('q5','Q5','Agent Queue ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('q6','Q6','Agent Queue ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('qdd','Direct Dial','Queue direct dial access');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('queueoptions','Options','Asterisk Queue options.  You can learn what queue options are and what they do by reading the Asterisk sample queues.conf');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('queuetimeout','Member timeout','Seconds to ring each queue member before trying the next member.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('rec_age','Delete old recordings','Set the maximum age of your call recordings here (in days).  This will keep the size of the recording directory relatively constant and prevent the disk from becoming full. The default size is 60 days but you can increase/decrease it depending upon the available storage. The recordings folder will be aged every morning at 02:00');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('rec_file_dlim','Recording file delimiter','Delimiter character(s) used between fields in recorded call filenames.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('rec_final_dest','Recording final destination','Path or target where completed recordings are moved after staging.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('rec_grace','Recording grace period','Grace seconds before a recording is considered complete.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('rec_limit','Recording limit','Maximum recording size or duration limit for this tenant (read-only when computed by the system).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recfiledlim','Recording file delimiter','Instance-wide delimiter used in call recording filenames.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('reclimit','Recording limit','Instance-wide recording size or count limit.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recmaxage','Max recording age','Set the maximum age of your Tenant call recordings here (in days). This will keep the size of the recording directory relatively constant and prevent the disk from becoming full. The default size is 60 days but you can increase/decrease it depending upon the available storage. The recordings folder will be aged every morning at 02:00');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recmaxsize','Max recording size','Set the maximum size of your Tenant call recordings here (in bytes). This will keep the size of the recording directory relatively constant and prevent the disk from becoming full. The default size is 0 bytes (unlimited) but you can increase/decrease it depending upon the available storage. The recordings folder will be aged every morning at 02:00');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recmount','Recording mount','External mount command for call recordings (see instance globals). Leave blank to store locally.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recqdither','Recording queue dither','Jitter applied when ageing the recording queue.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recqsearchlim','Recording search limit','Maximum age or scope when searching the recording index.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recs3','S3 offload','Opt this tenant into fleet S3 disaster recovery for call recordings (default No). Requires the home to have recordings S3 upload plumbing enabled at install. Local archive and max age/size always apply; Yes only adds upload of archived files to the fleet recordings bucket.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recused','Storage','How much recording space this tenant is currently using.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('retry','Queue retry','Seconds to wait before trying the next available member when a call is not answered.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ringdelay','Ring Time(sec)','The number of seconds that we will ring the end-point before taking an outcome. If you leave this blank the default delay is 20 seconds, or about 5 ring cycles.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('route','Route','Route name - must be system-wide unique.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('route_profile','Route profile','The **route profile** key used by this DID route — maps schedule mode to destination for the tenant. Pick from the dropdown.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sched_mode','Schedule mode','Current day-parts mode written by the timer (open, closed, lunch, …). Inbound routing uses this with route profiles. Operator CLOSED force overrides it.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sendedomain','Send domain','Domain name sent in SIP headers for outbound calls from this instance.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sessiontimout','Session timeout','Web session idle timeout in seconds before automatic SPA logout (default 600 = 10 minutes).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('shortuid','UID','System generated shortuid.   A 6-character unique value allocated to objects to uniquely identify them.  Among other things it is used to identify SIP endpoints (i.e. the *sip-user*) to Asterisk.   This is separate from any dialable number (e.g. an extension number or DDI).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sipflood','Throttle SIP floods?','Retired under UFW (no Shorewall limit template). Leave NO; SIP abuse controls live at the SBC for fleet.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sitename','Site name','Friendly name for this PBX instance (Home header, session chips, Network). Set at install or here; not the DNS hostname.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('start','Start time','Use **24-hour (military) time** in **HH:MM** — **not AM/PM**. Examples: `09:00` = 9:00 AM, `13:30` = 1:30 PM, `17:00` = 5:00 PM.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('start_datetime','Start','Holiday window **start**. Use the date/time picker (**local browser date and time**). **End** must be after start.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('end_datetime','End','Holiday window **end**. Use the date/time picker (**local browser date and time**). Must be **after** start.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('smtphost','SMTP Host','The IP address or URL of the mailserver you want the PBX to use. PBX3 does not have an onboard mailserver so it requires you to create an account for it on your own mailserver or a third party server such as Gmail etc.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('smtppwd','SMTP Password','A user account password which PBX3 will use to authorize itself with the mailserver');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('smtpuser','SMTP User ID','A user account ID which PBX3 will use to authorize itself with the mailserver');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('smtpusestrttls','SMTP STARTTLS','Set this on if your mailserver requires it');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('smtpusetls','SMTP TLS','Set this on if your mailserver uses SMTP over TLS');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('source','Source','Source of the tooltip help (either CORE (from the PBX3 tt DB) or USER (from the user tt DB).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('span','Span','The Span of your custom app... Your app can be included into the inbound call path, the outbound call path, both inbound and outbound or neither.  PBX3 will automatically generate the correct includes for you based upon the setting you choose here.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('spypass','4-digit Spy Password','Password used to validate spy requests.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('staticipv4','Static IPV4 Address','Here you provide a static IP address that your PBX will run VoIP operations from.  PBX3 will always keep a dynamic IP (if DHCP is available) and a second static IP for operations.  This makes network changes less fraught because as long as there is a DHCP server running then PBX3 will get at least one IP after a restart.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('strategy','Strategy','Whether to:
1. select trunks in priority, i.e only select trunk 2 if trunk 1 is unavailable (*hunt*) 
or 
2. to load-balance calls across all available trunks in the route (*balance*)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('striptags','Strip Tags?','By default, any tags will be automatically stripped from the input.  You can override this behaviour by setting this switch off');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('swoclip','SWOC?','Switch-On-CLIP. Turn this on if you want this DDI to route CLID patterns (defined in a CLIP DDI).  For example, you may have defined a CLIP DDI to route all inbound callers from a particular area code or country. If those callers will dial in on this DDI then you must turn on SWOC to route on the CLIDs');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sysop','Operator Real Extension','The operator endpoint.  This is used by PBX3 as the endpoint of last resort so it is important that you point this at a real endpoint.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('syspass','4-digit Sys Password','Password used for privileged key operations (such as recording a greeting or putting the system into night mode).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('tag','Alpha Tag','Alpha tagging allows you to send a short character string to the phone.  Most phones will display this tag when they receive it.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('technology','Technology','Can have any of the values {SIP|IAX2|DiD|CLiD|Class} depending upon the use case. It is used in the definition of Trunks and DiDs.

Trunks can be {SIP|IAX2}
DiDs can be {DiD|CLiD|Class}
1. DiD - A regular DiD routing
2. CLiD - Route on the inbound callerID
2. Class - Route according to a DiD *class*.  e.g. _5139266XXX will route any DiD *beginning* with 5139266.  You can use any Asterisk exten regex to identify the range you wish to route.  Class regex''s must always begin with  an underscore (_).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('tenantname','Tenant','The name of the Tenant.  It should be system-wide unique.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('timez','Timezone','Set this to the local Timezone for your installation.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('tlsport','SIP TLS Port Number','SIP TLS default port number is 5061 but you can choose a high port if you wish');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('transform','Transformation mask','Used to transform numbers using value comparisons and proceeding left to right... xx:xx xx:xx.  Nulls in the left operand result in addition.  Nulls in the right operand result in suppression.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('transport','Transport Protocol','Set the SIP transport protocol you wish to use for this endpoint. The default is UDP but PBX3 can also use TCP,TLS or WSS.  If you are unsure which to choose then you should leave it set to UDP.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('trunkname','Name','This is the unique name of the trunk.  It will usually be a userID given to you by your ITSP or a username you have given to a downstream client PBX.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('usemohcustom','Custom MOH Active?','This switch activates/deactivates your custom MOH. If you deactivate it then the default MOH will be used instead.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('username','Username','The username for this IP Carrier account');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('vmail_age','Delete old vmail','Number of days after which opened voicemail will be deleted (blank for never)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('vmailfwd','Email address','Set this to the email address of the user if you want Asterisk to send voicemails as encapsulated attachments in an e-mail.  This is often called unified messaging.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('voice_instr','Play Long Vmail Intro','Setting this value to YES will cause voicemail to play the long instruction message.  Setting it to NO plays the short version.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('voip_max','Max Outbound VOIP calls','Maximum number of concurrent VOIP outbound calls the system will allow before failing over to other pathways.  This number should be set well below the bandwidth threshold of your Internet circuit.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('wrapuptime','Wrap-up time','Seconds an agent remains unavailable after completing a call before receiving the next queue call.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ext_len','Extensions length','Number of digits for each extension in this tenant (2–5; default 3). Every extension must be exactly this length — no mixed lengths within one tenant. Outbound routes and short-dial prefixes must match dial strings strictly longer than this count.');

COMMIT;
