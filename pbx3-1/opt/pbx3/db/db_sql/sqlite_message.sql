-- tt_help_core seed data. htext: Markdown (GFM). Export: pbx3spa/scripts/export-help-core-to-sql.mjs
BEGIN TRANSACTION;
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('Act','Act?','Denotes whether the object is active (i.e. part of the running config) ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('IPV6GUA','Global Unicast Address','The Global Unicast Address of this server (if any)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('IPV6LLA','Link Local Address','A Link Local address used by this server');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('IPV6ULA','Unique Local Address','The Unique Local Address of this server (if any)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('abstimeout','Call Timeout (seconds)','Use this value to set an absolute time limit for outbound calls.  The default is 14400 seconds (4 hours) and the maximum permitted value is 99999 seconds (about 28 hours). After the timer expires, the call will be put on-hook by the system.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('acl','Create Extension ACLs','Set this on if you want the system to create automatic ACL constraints for local extensions.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('action','Action','Firewall Action - for PBX3 this is always ACCEPT');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('active','Active?','Activate or de-activate this object');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('adminpin','Admin PIN','Administrator PIN (0000->9999 or blank)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('agent','Agent','Agent number (allocated by PBX3)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('agentname','Name','Agent Name');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('agentstart','Agent Start','Agent number from which PBX3 will begin allocating agents.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('alert','Diagnostic Alerts','Set to none,email,sms or both. Used to determine how you want to receive diagnostic alerts - SMS requires a PTT SMS gateway.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('alertinfo','Alert-info string','Use this field to specify distinctive ring data for the sip header.  This is phone specific so you will need to read up on your phone type.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('allday','Whole Day Close','If this rule applies to a whole day, e.g. perhaps you are closed every Saturday, then turn this switch on');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('allow_hash_transfer','Allow hash transfer','Allow in-band transfer using the hash key (default is enabled)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('alphatag','Tag','Value of the alpha tag (if any) ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('alternate','Alternate Route to remote Host','Specify an alternative if this route is unavailable.  This is for desktop-to-desktop links using short dials.  If the short dial link fails, you can specify a full-dial alternate. (e.g. IAX link to 5525 is down so dial 441924405525 over PSTN).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('astfiledate','create date','Date the file was created');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('astfilename','Filename','The filename');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ato','Abstime','absolute call timeout  ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('auth','Auth','Does this route require the user to enter a pin number in order to use it.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('authnum','Authorized Number','Telephone number you wish to authorize for callback.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('backchan','Back Channel','Channel to use for the Call back.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('beginclosed','Beginning of Closed Period','Select the start time of your closed segment.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('bindport','SIP Listen Port','This determines the local port at which the PBX will listen for SIP.   By default this is the well known UDP port 5060 but you can set this to some high port to help avoid SIP hack attacks.  N.B. your phones will need to be aware of this value and you will need to provision them accordingly.  You will also need to add port=5060 to your upstream trunk peer definitions.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('blfhead','BLF/DSS Keys','You can edit the BLF rows by clicking or touching the cells. On desktop devices click away from the cell to save it, on mobile devices touch Done, Return or Save, depending upon the mobile OS.  If this phone type is capable of in-flight sync then a Sync button will be shown in the right menu bar and you can use it to update the phone BLF keys without a reboot.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('blfkey','FKEY','Relative FKEY number');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('blfkeyname','Keyfile','Name of the associated BLF key template');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('blfkeys','BLF#','The number of BLF keys to generate when the extension is created');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('blflabel','Label','Some phones can display a soft label next to the key');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('blftype','Type','Key Type (None/BLF/Speed/Line)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('blfvalue','Target','Target number (specify extension for BLF, any diallable number for Speed dial');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('blindbusy','Bounce busy destination','Alternative destination if a bounce returns to a busy sender.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('blksize','Quantity','Enter the number of extensions you want to create.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('blkstart','Extension','This is the number which an end-user will dial to contact this endpoint (e.g 123, 1234, 12345).  It is NOT the same as the *sip-user* (which is an auto generated unique 6 character string used to identify the sip endpoint).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('bouncealert','Alert-Info for Xfer Bounce','Use this field to specify distinctive ring data for the sip header.  This is phone specific so you will need to read up on your phone type.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('bt','boot','reboot the endpoint');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callbackto','Callback destination','Which device you want us to call when you click2dial; your deskphone or your cellphone.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callduration','Secs','Seconds on call.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callerid','Outbound Caller ID','Usually you can leave this field blank and the endpoint will automatically send its extension CLID.  However if, for example, you want to send a DDI then you can set it here.  Internal calls will always use the phone''s extension CLID');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('calleridname','Extension Name','This is what the phone will send in the callerid (name) variable.  It is usually set to the user name or to some department function.  Do not put special characters in this field because some phones do not handle them well. ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callfromto','Number','Number');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callgroup','Number','Name (extension number) of this call group');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callmax','Call Max','The maximum number of concurrent calls allowed for this extension.  Once the extension has Call Max calls running, no further calls will be started until the number falls below Call Max.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callprogress','Call Progress?','Force an early ringback tone.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callrecord_1','Call Recording Default','Set the global recording preferences you want. This can be overridden at the individual call group or extension.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('callshelp','Calls help','The "calls in" and "calls out" tables show the last 40 calls received or made.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('calltime','Time','Time of call.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('camponqonoff','Campon Mini-queue','Turn the camp-on feature ON and OFF');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('camponqopt','Mini-queue options','Camp-on uses standard asterisk queues.  You can set the queue parameters as you wish using this field.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('carrier','Carrier','This is either the SIP or IAX carrier name or the technology type (e.g. mISDN or Dahdi).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('carriertype','Type','Denotes the class of trunk (e.g. VOIP, PSTN etc.) ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cdialstring','Custom Dial String','Use only for custom devices');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cdr','Log CDR to MySQL','Set to yes if you want PBX3 to log cdrs to MySQL (as well as the normal cdr-csv file). This will allow you to use the Areski Stats package to analyze your CDR records.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cellphone','Cellphone Twin','Here you can enter a cellphone number to be the twin of this extension.  You can then turn twinning on and off.  When twinning is active, calls to the extension will also ring the cell.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('celltwin','Enable Cell Twinning','Turn cell twinning on/off');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cfbs','Call Forward Busy','When this is set calls to this extension will be forwarded on busy.  However, most multi-line SIP phones will almost never actually give back a busy signal unless you disable call-waiting in the phone. Calls to this extension from a ring group will usually still ring the extension.  You can change this behaviour by changing the parameters in the individual ring groups. You can also set/unset this feature from the phone with *22*{number}.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cfim','Call Forward Immediate','When this is set all direct calls to this extension will be immediately forwarded to the number you enter.  Calls to this extension from a ring group will usually still ring the extension.  You can change this behaviour by changing the parameters in the individual ring groups. You can also set/unset this feature from the phone with *21*{number}.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cfwd_answer','CFWD ANSWER','Cause external call forwards (hairpin calls) to be answered by Asterisk before the external call leg is started. This can sometimes be necessary to force RTP packets to flow across NATs when forwarding SIP calls.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cfwd_progress','CFWD PROGRESS','Cause external call forwards (hairpin calls) to be dialed with early media. This can sometimes be necessary to force RTP packets to flow across NATs when forwarding SIP calls.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cfwdextrn_rule','CFWD Override CLID','Cause a call forward to an external number to be given the CLID stored in the forwarding extension definition (if any).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('chanmax','ChanMax','The maximum number of outbound channels allowed for this tenant.  Once the tenant has ChanMax calls running, no further calls will be started until the number falls below ChanMax.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('chooser','Trunk Type','Choose the type of trunk you want from the dropdown; -
{SIP|IAX2}.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('chooserDiD','Route Type','Choose the type of routing you want from the dropdown; -
DiD or CLID
Most of your inbound routing will probably be DiD based but you can also route on CLID if you wish. To do that you will also need to enable Switch-On-Clip (SWOC) for the DiD which is handling the call.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('clidstart','Caller ID','Caller ID of the calling telephone.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('clinumber','CLID Number/Pattern','CLID number.  You can specify this in several different ways according to your needs.
A single CLID number will route just that number e.g.:-
*0123456789*
You can specify a pattern.  For example if you wanted to route all of the numbers from a particular areacode you can specify a pattern like this:-
*_01234XXXXXX*
...or like this:-
*_01234X.*');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('closeroute','Closed','The CLOSED inbound route.  The route which will be used by the inbound route manager to process calls from this DDI outside of business hours.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cluster','Tenant','This is the name of the Tenant which this object belongs to.  If you specified no Tenant then PBX3 will use the default Tenant.  Tenants are used to provide multi-tenant support within PBX3.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('clusterclid','CLID','This is the default CLID that will be sent from this Tenant.  Usually you should set this to the main inbound number for the Tenant.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('clusterid','Prefix','Cluster identifier, used as a prefix for extension numbers');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('clusterstart','Tenant support','Enable this if you wish to run multi tenant support on your PBX');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('clustersysop','Operator','The extension to be used as the operator for this Tenant.  This is used by PBX3 as the endpoint of last resort so it is important that you select a real endpoint.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cn','Contact','Contact full name.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cname','Common Name','Common name for this object');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('compression','CODEC','[FIDELITY,THRUPUT,g729] PBX3 will attempt to minimise CODEC transcoding using this value. If you choose Fidelity it will enforce g711(law) coding where it can.  If you choose Thruput it will use g729 if it is available, otherwise it use gsm.  If you choose g729. it will blanket enforce g729.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('conf','queues.conf Stanza','This is the stanza which PBX3 will generate for this queue. You can freely add to it if, for example, you want to add static members or change some of the default behaviours.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('confpkey','Room','Room Number (100->99999).  Room numbers must be unique.  It is a good idea to choose a block of numbers for this purpose so you don''t accidentally try to allocate an extension with the same number as a conference room.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('conftype','Conference Type','Choose from assisted or unassisted conferences.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('connrate','Connrate','Connection Rate.  Format is *[-|[{s|d}:[[name]:]]]rate/{sec|min|hour|day}[:burst]*.
e.g. to limit a connection rate to 4 per minute bursting to 5 you could enter;
 *4/min:5*
See http://shorewall.net/manpages/shorewall-rules.html');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('context','Context Name','The name of the context you want your custom app to run in.  This must be system-wide unique.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('copy','Copy','You can leave this as ''New'' to start a new empty template or you can Copy an existing template as the basis for your new entry.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cosclosed','Default Closed','Defines whether this COS will be ON by default for closed hours when new extensions are created.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cosday','Standard Class of Service','Rules that apply in Standard hours: schedule mode is anything other than closed (open, lunch, evening, night day-parts, etc.), or when not forced closed. Outbound dial privileges for this extension.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cosdialplan','Dialplan','The dialplan pattern for this class-of-service.  COS dialplans follow standard Asterisk dialplan conventions.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cosname','Key','Dialplan context key for this Class of Service rule. SPA-created rules use the system UID automatically; product seeds may use a stable name (e.g. HR_UK070). Not editable after create.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cosnight','After-hours Class of Service','Rules that apply in After-hours: schedule mode closed, or tenant/master force CLOSED. Lunch and other non-closed day-parts still use Standard CoS.');
UPDATE tt_help_core SET displayname = 'Standard Class of Service', htext = 'Rules that apply in Standard hours: schedule mode is anything other than closed (open, lunch, evening, night day-parts, etc.), or when not forced closed. Outbound dial privileges for this extension.' WHERE pkey = 'cosday';
UPDATE tt_help_core SET displayname = 'After-hours Class of Service', htext = 'Rules that apply in After-hours: schedule mode closed, or tenant/master force CLOSED. Lunch and other non-closed day-parts still use Standard CoS.' WHERE pkey = 'cosnight';
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cosopen','Default Open','Defines whether this COS will be ON by default for open hours when new extensions are created.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('cosstart','Class Of Service','Whether we will run COS or not.  PBX3 Class of Service is very powerful but if you dont intend to use it then you can save a little cpu by turning it off.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('country','Your Country Identifier','Enter your country of operation.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('countrycode','Country Code','Set to the correct code for your country.  This will control the tones which Asterisk generates for busy, ringback, congestion etc.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ct','Connected','denotes whether the endpoint is connected or not and whether proxy operations are possible  ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('customappname','Custom app name','Unique name for this custom Asterisk application (maps to the app context).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('datemonth','Date','Day date when this segment is active (asterisk * means any date).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dayofweek','Week Day','Choose the day of the week you want this rule to apply to. If it applies every day (for example, your night time close hours) then choose Every Day.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ddial','<span>&nbsp;</span>','Click2dial.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('defaultclosed','Defaultclosed','Set this to YES if you want all new extensions to be created with this closed restriction');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('defaultopen','Defaultopen','Set this to YES if you want all new extensions to be created with this open restriction');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('del','Del','Delete this entry');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('desc','User','This is usually the name of the endpoint user.  In the case of a sip extension it is used to set the *caller-id(name)* on outbound calls.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('description','Description','Freeform description string');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dialprefix','Dial prefix','2–4 digit prefix local to this tenant. Dial prefix then the remote extension (digits only). Example: prefix 81 + extension 1000 → dial 811000. Feature codes (*…) stay local — not after a prefix.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dialprefix_target','Target tenant','Pick another tenant from the known list (this node plus fleet catalog when available). Stored as that tenant’s full FQDN — not the instance hostname. Prefix is only for the calling tenant; reverse needs its own prefix on the other side.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dialalias','Dial prefix','2–4 digit prefix local to this tenant. Dial prefix then the remote extension (digits only). Example: prefix 81 + extension 1000 → dial 811000. Feature codes (*…) stay local — not after a prefix.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dialalias_target','Target tenant','Pick another tenant from the known list (this node plus fleet catalog when available). Stored as that tenant’s full FQDN — not the instance hostname. Prefix is only for the calling tenant; reverse needs its own prefix on the other side.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('device','Device','Extension type label: General SIP, WebRTC, MAILBOX, or a vendor name when a MAC OUI is recognised. Not a provisioning template (in-house provisioner is won''t-do; use manufacturer RPS).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('devicename','Template Name','Legacy Device-template name field. Device templates were removed; this help key is unused.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('devicerec','RecOpts','Recording options for this object. Recording options can be one of the following:-
default - use the value set in Globals
None - Do not record for this endpoint
Inbound - Record inbound calls
Outbound - Record outbound calls
Both - Record both inbound and Outbound

The list of available options will vary depending upon the object you are working with.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('devtech','Template Type','This is the Template type.  Type can be ''SIP'' (for a regular phone stream), ''Descriptor'' (for a reuseable component like a common provisioning block) or ''BLF Template'' (for a recursive BLF block)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dhcp','DHCP','Default YES; set this to NO if you want to set your own IP address');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dhcpaddr','DHCP','Turn this on to obtain a local ip address from your site dhcp server.  By default, when the PBX is first installed in an on-premise scenario, this flag will be turned on.  Usually, after initial installation, you will want to allocate a fixed IP to the PBX and turn it off ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dhcpend','DHCP pool end','The last IP address of your dhcp range.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dhcpserver','DHCP server','Turn this on if you want the PBX to run as a DHCP server for the network segment it is in. In most cases you will already have a DHCP server running and you should leave this off.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dhcpstart','DHCP pool start','The local IP address from which you want to begin allocating DHCP addresses.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dialparams','Dial Params','Here we expose a subset of the Asterisk Dialplan parameters.  You should only change these if you REALLY know what you are doing.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dialplan','Dialplan','Route dialplan.  The dialplan consists of the set of numbers and number patterns that this route will be sensitive to. (e.g. _0XXX. 100 _XXXXX)   Arguments are separated by whitespace.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('default_outbound_dialplan','Default outbound dialplan','Instance default route dialplan string (space-separated Asterisk patterns). Copied once onto each new tenant OutRoute (MainOut → Egress on fleet). Edit per tenant afterward. UK seed: _0XXX. _00XX. (national + IDD; each pattern min match must exceed tenant extension length). US nodes should use a NANP/011 pattern string instead.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('didend','DiD End','End DiD (DDI) for this group (its perfectly fine to allocate only a single number).');
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
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dl','D/L','Download');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dns','DNS Server','Set this to the correct value for your network');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('domain','Local Domain','This is the local Domain name within your IPV4 LAN. In most cases you can leave it as it is');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dvrvmail','Voicemailbox','Number of the voice mailbox you wish to have voicemail delivered to. The default is the extension but you can have it delivered to a different extension if you wish');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('dynamicfeatures','Dynamic Features','This is the string which PBX3 will apply to Asterisk dynamic features.  The system default should be sufficient for most applications but you can change the feature list here if you wish');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('eclose','Reopen','Choose the time you want the closed period to end. ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ed','Edit','Edit this entry');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('edomaindig','Public IP Address','This is the public IP address returned from DiG. The public IP address is usually needed if you are running behind a NATed firewall. It forces Asterisk to include the correct return IP address in outbound SIP/RTP packets. Without it, Asterisk will use the local server IP address and effectively spoof itself.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('edomainsend','Use public IP?','Normally you should leave this set to YES but you can suppress sending it by setting NO.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('emergency','COS Emergency passthru','Use this field to set your Emergency number (e.g. 911, 999, 112).  This is used by Class of Service and becomes part of the always-available set of dialable numbers.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('endclosed','End of Closed Period','Select the end time of your closed segment.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('eurl','External URL','Well formed URL for external phone provisioning');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ext','Ext','Extension Number (if this is a local extension) or PSTN number if this is an organization or Direct Dial');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('extalert','Alert-info string','Alert-info alters the SIP header sent to the device.  It is usually used to send a request to play a distinctive ring-tone.  The actual content of the header varies from device to device.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('extblklst','Use external blacklists?','Block inbound traffic from known SIP offender IP addresses(needs line of site to port 80 outbound)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('extchooser','Extension Type','Choose the type of extension you want from the dropdown; -
Provisioned extensions are auto provisioned by PBX3 and you will need to enter the MAC address of the phone.
Unprovisioned extensions require no MAC and you manage their provisioning yourself.
You can also create blocks where you can specify multiple extensions and PBX3 will create them all in one go.  For provisioned extensions you must supply a block of MAC addresses.  For unprovisioned extensions you simply need to tell PBX3 how many you want.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('extcode','Extension Code','Asterisk **extensions.conf** dialplan fragment for this custom app. On commit it is written under a context named after the app **pkey**. Use standard Asterisk dialplan syntax (priorities, applications, and labels).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('extension','Extension','This is the "home" extension for this user.  You MUST enter an extension number for every user you create and it MUST be an existing extension. Your user will login with this extension number.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('externalip','Registration URI for remote phones','Only applies to remote phones that you wish to provision from the PBX3 http provisioning server. This will be the remote (i.e. PBX3) URI.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('extlen','Extension Length','PBX3 can have extension numbers of 3 or 4 digits.  However, you can only change the length when there are no extensions defined to the system (i.e. at system inception).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fax','Autosense FAX Extension','Endpoint to send Autosensed faxes to.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('faxdetect','FAX Detect Delay','How long to delay an inbound analogue call on a shared voice/fax line while we wait for Asterisk to decide if it has a fax or not.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('faxonoff','Fax detect','Anaologue lines only - whether to listen for FAX tones on the line');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('filesize','Filesize','File size (in bytes)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('filetype','Filetype','File type (MP3|wav)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('forename','Forename','Forename for a person or blank for an organization');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fqdn','Public FQDN','The Fully Qualified Domain Name (if any) which resolves to this server, e.g. *somesip.someserver.com*');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fqdnhttp','Filter my FQDN for HTTP?','Turning this on will cause header inspection to be done on all *remote* HTTP/HTTPS connections.  Packets referencing our FQDN in the URL will be allowed to pass.  Packets not referencing our FQDN will be rejected. This can help prevent robo-hack attempts to brute-force a login or provisioning request. This feature will have no effect on *local* (LAN) connections. Obviously, you must have a FQDN which resolves to your external IP address.  N.B. you must restart the HTTP server (e.g. nginx) for this feature to take effect.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fqdninspect','Filter my FQDN for SIP?','Retired under UFW. Fleet SIP is limited to SBC IP(s) on the allow-list; STRING packet inspection is no longer used. Leave this set to NO.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fqdnipaddress','IP Address','IP address this FQDN resolves to');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fqdnprov','Provision with FQDN?','When creating new extensions if an FQDN exists then set them to send the Fully Qualified Domain Name (instead of the public IP) when provisioning remote phones? (recommended) ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fqdntrust','Accept dynamic URLs?','A list of dynamic URLs will be used to periodically construas the registrar andct a set of trusted IP addresses.  This can be useful for dynamic IP addresses');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetbackups','Delete backups','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetboot','Reset Reboot','Choosing any or all of the Reset functions will cause a system reboot.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetcdrs','Delete CDRS','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetcontinue','Reset Continue','Choosing Delete functions will not cause a reboot.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetdb','Reset the PBX3 Database to factory','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetdhcp','Reset IP to DHCP','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetfirewall','Reset Firewall rules to factory','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresethost','Reset host to PBX3','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetldap','Delete ldap directory entries','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetlogs','Delete system logs','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetsnaps','Delete Snapshots','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetsshport','Reset SSH to port 22','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetusergreets','Delete user greetings','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetvmail','Delete Voicemail','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fresetvrec','Delete call recordings','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fwdesc','Comment','Optional comment stored on the UFW allow-list rule (shown in ufw status).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fwdest','Dest','Unused under UFW (legacy Shorewall field).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fwdestports','Port','Destination port or range (e.g. 5060 or 10000:20000). Leave empty for icmp.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fwproto','Proto','Network protocol: tcp, udp, icmp, or all.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fwsource','Source','Literal source only: any, an IPv4 or IPv6 address, or CIDR (e.g. 192.168.1.85, 192.168.1.0/24, 2001:db8::1, 2001:db8::/32). No $LAN/$SBC shorthand. One table covers UFW IPv4 and IPv6.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('fwsource6','Source','Unused — UFW dual-stack uses the same Source column (IPv4 or IPv6) as the main allow-list.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('gatewayip','Gateway','Gateway address of your subnet');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('greeting','Greeting Number','Greeting number that this IVR uses.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('greetingnum','Number','The 4-digit greeting number');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('groupname','Group id','The extension number of the group or alias.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('groupstring','Target','The extensions in this callgroup.  It can consist of extensions, call groups or external numbers separated by whitespace, e.g. 553 554 924018076');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('grouptype','Type','The group type; ring, hunt or page. Ring groups will ring all the phones in the group simultaneously. Hunt groups will ring the phones sequentially.  Page groups will broadcast, or page, the phones in the group.  Paging is actioned in a different way to the other two.  To invoke a page group you dial the feature key *40* followed by the page group number.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('header','Asterisk Filename','Name of the Asterisk control file for this header');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('headlocation','L/R','Local or remote.  Denotes whether the phone will run inside or outside the local firewall. If it is outside then PBX3 will use symmetrical RTP.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('hhmm','Time (hh:mm)','Time (hh:mm)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('home','Tel3','Alt Number (if applicable)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('host','Host address','Enter the URL or the IP address of the target host (unless this host will register with you, in which case enter the string ''dynamic'')');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('hostname','Hostname','The local hostname of this server.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('httppassword','Password','Enter the existing password ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('icmp','Accept ping requests?','Set to NO if you want to ignore ping requests');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('idd','Dial','IVR direct dial access.  Supply a unique tenant-wide extension number here.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('include','Include','A list of other tenants that you want to be able to extension dial from this tenant.  Ordinarily, tenants can only dial other tenants by using the asociated PSTN number but you can use this list to bypass it.  You can also use the keyword ALL to include all tenants.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('inprefix','Add CLI Prefix','Allows you to add a CLI prefix.  This is because many carriers do not send the NDD character (usually zero).  This allows you to add it back.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('int_ring_delay','Default Ring Time(seconds)','How long we will ring an internal phone before taking some outcome (usually voicemail).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ipaddr','IP','The IP Address of the end-point.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ivrActive','Active?','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ivrHelp','IVR Keys','Activate a key by clicking or touching the slider.  From the action dropdown, choose the action you want the IVR to take when the key is pressed. You can also send an alphatag to the phone to give the callee more information about the call type, e.g. sales, accounts, etc. You can set a distinctive ring by incuding an alertinfo tag. These tags are not standard and vary by phone manufacturer so you will need to refer to the relevant documentation from your phone supplier.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ivr_digit_wait','IVR digit wait','How long to wait for another digit');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ivr_key_wait','IVR key wait','How long to wait after keypress');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ivrname','IVR Name','IVR keyfield');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ivrnumber','IVR Number','IVR dialable number');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('keyboardDial','&nbsp;','Enter the number you wish to call and press the Dial button.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('language','Language','Default language code for voice prompts and voicemail (e.g. en-gb).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('lanipaddr','DHCP IPV4 Address','The dynamic IPV4 address of this server (from DHCP).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('latency','latency','The latency of the end-point (i.e. the time taken for Asterisk to receive a response to an IP request).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldapanonbind','LDAP anonymous bind','LDAP anonymous bind YES/NO');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldapbase','LDAP Base','LDAP base, sometimes called domain; enter it in the form dc=somecompany,dc=com');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldaphost','LDAP host','LDAP host');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldapou','Organizational Unit','The name of the OU where the contacts directory is held (default contacts) ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldappass','LDAP Password','ldap password for PBX3 to use');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldaptls','LDAP TLS','LDAP TLS mode(off/on)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ldapuser','LDAP User','ldap user for PBX3 to use - it must have update privileges to the directory OU');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('leasedhdtime','Hot desk lease','Seconds a hot-desk extension lease remains valid before automatic release.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('line','Line','Usually the Subscriber number the carrier has allocated to you.  However it may also be a DiD(or DDI) number and sometimes the account name or number (in the case of some VOIP trunks).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('listenforext','Listen for extension dial?','If this switch is turned on, the ivr will listen for an extension dial(as well as the ivr key presses). You should be aware that this will slow down the IVR response because it will listen for extra digits after the first keypress.  If this is not what you want you can include an ’extension press’ option in your greeting; e.g. ’press the star key to enter an extension number’.  Then you can handle the listen option in a separate sub-IVR which is set to listen but has no active keys.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('localIP','Local IPV4','Local subnet IPV4 address');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('localarea','Area Code','(Optional field) This is the area code for this Tenant.  If you specify it AND a local dialplan then the system will automatically prepend the area code when you dial a short local number.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('localdplan','Local Dialplan','(Optional field) This is an Asterisk dialplan for local numbers for this tenant. If you specify it AND your area code (above) then the system will automatically prepend the local area code when you dial a local number');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('localhost','Local Host Name','This is the local hostname');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('localnets','Asterisk IPV4 Localnets','These are the IPV4 localnet entries for subnets which Asterisk regards as being inside the NAT. Default settings on a new install will be the RFC 1918 reserved ranges. You can just leave them as they are in most cases.  **N.B.**You will need to create the relevant firewall entries if you run more than one of these ranges on your network or you add a new range.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('location','Local/Remote?','Set to local if the endpoint is in the same subnet as the PBX.  Set to remote if the endpoint is at some other location and probably behind a NAT firewall, perhaps another office or a co-worker''s home.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('loglevel','SysLog Level','Sets the browser log level. Valid values 0-9.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('logopts','Log options','Additional Asterisk logging options for this instance.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('logsip','Log Action','You can set up continuous SIP logging in this section.  PBX3 uses DUMPCAP to create a carousel of PCAP logs which you can use to analyse and debug SIP packets.  You can control how much space you want to give to your logs by specifying the size and number of files in the carousel. Once the space has been used, PBX3 will rotate the logs, deleting the oldest and beginning a new one. The actual logs can be found in /var/log/siplog so you can easily set up a remote rsync over SSH if you wish to back the logs up onto secondary storage. You must specify at least two dumpfiles in order to enaure continuity of capture.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('logsipdispsize','PCAP display size','Sets the initial number of lines to display from a PCAP segment in the log browser window. This keeps the response time down on large PCAP segments.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('logsipfilesize','Max Segment Size','Sets the maximum size of a SIP PCAP log segment (in Kbytes).  Thus the maximum space the logger will use is *{segment size X max segments}*');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('logsipfilter','Filter','You can supply a regular tshark/wireshark filter here and apply it to the PCAP file. For example, to see only REGISTER requests, you can use a filter of *^REGISTER*
To action the filter press the *Filter* button above.
For more information on filters refer to the wireshark documentation');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('logsipnumfiles','Max Segments','Sets the maximum number of file segments in the log set before rotation will occur.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('lterm','Late Termination','If you set this on, PBX3 will attempt to terminate inbound calls as late as it can in the switching process (i.e. when the target extension goes off hook).   This is not always possible, or desireable and it can sometimes cause loss of ringback tone during complex switching operations such as internal/external call forking.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('macaddr','MAC','The MAC address of the end-point.  The MAC address is used by PBX3''s autoprovisioning routines. If you do not provide the MAC address you will not be able to use autoprovisioning.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('macblock','MAC List','Enter a list of MAC addresses separated by white space or carriage returns. Usually, you can just copy and paste them from the dispatch note or invoice. You could also use a barcode scanner and zap them in directly from the phone packaging (set the scanner so that it doesn’t send enter each time it scans).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('masterclose','Master force','Master hard-force (BLF/API). AUTO = follow day-parts schedule (timer sched_mode + route profiles). CLOSED forces closed routing and wins over holidays. Multi-mode force uses AstDB OCSTAT mode tokens; *30*/*31* still AUTO/CLOSED.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('match','Line Pre-select','Optional: 1 or 2 digit pre-select code which you can use to seize a specific trunk (must be systemwide unique)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('maxin','Max inbound calls','Maximum concurrent inbound calls allowed for this scope (instance globals or tenant).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('maxlen','Max queue length','Maximum number of callers waiting in the queue. When full, additional callers receive the busy treatment.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('maxout','Max outbound calls','Maximum concurrent outbound calls allowed at instance level.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('mcastip','IP Address','This is the address you will multicast on.  The well known SIP multicast IPV4 address is 224.0.1.75 but there are others you may wish to use.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('mcastlport','Linksys Port','Linksys Multicast port.  Linksys/Sipura/Cisco-small-business phones use two ports for multicast, this is the second port. ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('mcastpkey','Group','Multicast group extension.  This is the number you will dial to trigger the multicast page.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('mcastport','Port','Multicast port.  This is the port you will multicast on. ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('members','Queue members','Member endpoints for this queue (comma-separated hints or extensions). Dynamic members are often managed via the queue configuration.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('mixmonitor','Mix monitor','Optional MixMonitor application string for call recording on this tenant.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('mobile','Tel2','Cell phone number');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('modified','Modified','Last time the file was modified.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('moh','MOH on Ring?','Play Music-on-Hold rather than the more usual ringback tone to the caller.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('mohhead','Music-on-Hold','MOH files associated with this tenant.  You can add further music files by uploading them.  Candidate files should be in 8Khz Mono wav format, if they are not then PBX3 will attempt to convert them but they may not play.  If you have multiple files loaded then one will be chosen at random whenever MOH is called for by a user of this tenant.  If you include no files, then the system default files will be played. ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('monitor','Monitor this resource','Set this to YES if you want the diagnostic routines to watch this resource.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('monitor_out','Monitor out path','Directory where completed call monitor files are stored.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('monitor_stage','Monitor stage path','Staging directory for in-progress monitor recordings.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('month','Month','Month Date when this segment is active (asterisk * means any month).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('musicclass','Music class','Music-on-hold class played to callers while waiting. Must match an MOH class configured for this tenant or the system default.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('named_call_group','Named call groups','Asterisk **named_call_group**: the pickup pool(s) this extension **belongs to**. Ringing calls on this phone are eligible for pickup by others whose **Named pickup groups** include the same token(s). Default **ALL** = whole tenant (tenant shortuid on Commit — isolated across tenants on one instance). Comma-separated department names or digit tokens (e.g. `sales` or `1,2`). Can differ from Named pickup groups.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('named_pickup_group','Named pickup groups','Asterisk **named_pickup_group**: the pool(s) this extension **can pick up from** (*8 / directed pickup). Default **ALL** = whole tenant. Comma-separated department names or digit tokens (e.g. `sales` or `1,2`). Can differ from Named call groups (e.g. belong to `sales` but pick up `sales,support`). Takes effect on Commit.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('natdefault','Default NAT setting','The NAT setting is important when creating extension entries, it helps to manage RTP (voice) traffic across NAT firewalls.  Set this to "local" if most of your phones will be on the same network segment as the PBX (i.e. on the same LAN), otherwise set it to remote. PBX3 will initially set the value to "local" for CPE based deployments and "remote" for cloud based deployments but you can change it to suit your needs and also change it at the individual extension level.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('natparams','Default NAT Parameter String','You can set the Asterisk nat parameter string for remote phones here.  Usually you should leave this as it is.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('netmask','Netmask','Set this to the correct value for your subnet.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('new','New','Button Text');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('newpassword','New Password','Enter the new password ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('newpassword2','Re-Enter','Re-enter the new password');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ntp-servers','NTP Server Pool','A pool of ntp servers which the PBX will use to synchronize its clock. Usually these will be internet servers but you can use a local NTP server if the PBX does not have line-of-site to the Internet.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('obeydnd','ObeyDND','When enabled, the ring group will not attempt to ring phones which it knows to be in DND');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('oclo','Timer State (legacy)','Legacy OPEN/CLOSED mirror of sched_mode for dual-read. Prefer Schedule mode for multi-mode day parts.');

INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sched_mode','Schedule mode','Current day-parts mode written by the timer (open, closed, lunch, …). Inbound routing uses this with route profiles. Operator CLOSED force overrides it.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('route_profile','Route profile','Tenant map of schedule mode to destination for this DID. Preferred over separate open/close columns when set.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('entry_dest','Always route','Optional fixed destination: skip schedule and always send the call here.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('mode','Day timer mode','Mode asserted when this day-timer window matches (e.g. closed, lunch). Higher priority wins on overlap.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('openroute','Open ','The OPEN inbound route. The route which will be used by the inbound route manager to process calls from this DDI during normal business hours.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('operator','System Operator(default 0)','The system operator.  The key press you wish to use to contact the operator (default is zero).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('orideclosed','Override','Set this to YES if you want to force ALL extensions to have this closed restriction');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('orideopen','Override','Set this to YES if you want to force ALL extensions to have this open restriction');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('outcome','Outcome','Where the call will be delivered if the call group fails to terminate the call.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('padminpass','Phone Admin Password','The global admin password to be set into the phones at the next provision');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('password','Password','The password for this account, called the secret in Asterisk');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('path1','Path 1','You can specify up to 4 paths (1 primary and up to 3 failover) in descending order of priority.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('path2','Path 2','You can specify up to 4 paths (1 primary and up to 3 failover) in descending order of priority.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('path3','Path 3','You can specify up to 4 paths (1 primary and up to 3 failover) in descending order of priority.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('path4','Path 4','You can specify up to 4 paths (1 primary and up to 3 failover) in descending order of priority.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('peername','Peer name','This is the SIP or IAX peername.  If this is an upstream (vendor) trunk then it will have been given to you by your supplier. If it is a downstream (Asterisk) trunk then it should have a unique name.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('phone','Tel1','Extension or PSTN number');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('pin','PIN','PIN.  This can be a conference room PIN or an agent PIN.

*Conference room* PIN (when set) is required to enter the conference.
*Agent* PIN is required to login as an agent to service a Queue(s).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('play','Play','Play the sound file');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('play_beep','Play tone on Failover','If set on, a beep tone will be played whenever the system fails over a trunk call to a secondary provider.  If set off, no tone will be played.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('play_busy','Play tone on Busy','If set to YES the PBX will come off-hook and play a busy tone, if set to NO the PBX will stay on-hook and play a busy message, if set to SIGNAL a BUSY signal will be sent to the ua.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('play_congested','Play tone on Congested','If set to YES the PBX will come off-hook and play a congestion tone, if set to NO the PBX will stay on-hook and play a congestion message, if set to SIGNAL a CONGESTION signal will be sent to the ua.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('play_transfer','Play message on transfer','If set on the PBX will play, "Please hold while we try to connect you." whenever it attempts to transfer a call to some remote endpoint (for example a cellphone).  if set off, no message will be played.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('port','Port','The port which this end-point is using to receive SIP packets.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('portrangeend','Port Range End','The end port for this rule. You can leave this blank if it is the same as port range start');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('portrangestart','Port Range Start','The start port for this rule.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('postdial','Dial String Lead-out','Used to construct the trailing part of the dial for this technology.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('preannounce','Preannounce','Play a greeting before joining the Queue. You create greetings in the greetings section.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('predial','Dial String Lead-in','Used to construct the beginning part of the dial for this technology. For example, to use misdn TE p2p group dial  you might specify mISDN/g:TEPP (see the mISDN setup guides at http://www.misdn.org).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('prefix','Dial Prefix','Use this if you need to have PBX3 dial a line-seize digit or some other pre-dial string during call back to an authorized number.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('privileged','Priv','Denotes whether this trunk is running in privileged mode or unprivileged mode.  For regular external trunks, you can generally leave this to default.  Set the switch ON if you are building inter-site trunks, for example between remote premises. It will set the correct trunk contexts and send the correct CLID during intersite exchanges.');
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
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('protocol','Internet Protocol','This can be IPV4 or IPV6 (if your network supports it).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('provisioning','Provisioning','Free form text box into which you may copy/load device specific provisioning rules.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('provisionwith','Provision With URL?','Tells PBX3 what kind of addresses to set in the provisioning stream.  This will be used by the endpoint to request provisioning data from PBX3. You can set this to either *FQDN* or *IP*, depending upon how you want the phone to contact PBX3.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('proxy','Dynamic Proxy Enable','Enables/disables PBX3s dynamic proxy feature (see extensions panel status field).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('puserpass','Phone User Password','The global user password to be set into the phones at the next provision');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('push','Push','Some phones (Snoms) can reload their config without rebooting');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('pwdlen','Ext password length','Length of the password (in characters) the randomizer will create for new extensions');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('q1','Q1','Agent Queue ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('q2','Q2','Agent Queue ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('q3','Q3','Agent Queue ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('q4','Q4','Agent Queue ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('q5','Q5','Agent Queue ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('q6','Q6','Agent Queue ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('qdd','Direct Dial','Queue direct dial access');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('queuename','Name','Tenant wide unique queue name. Name can be letters and numbers but you should not use special characters or spaces.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('queueoptions','Options','Asterisk Queue options.  You can learn what queue options are and what they do by reading the Asterisk sample queues.conf');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('queuetimeout','Member timeout','Seconds to ring each queue member before trying the next member.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('realname','User Name','The name of this user.  N.B. There may be GDPR implications if you are using full names in this field so you may consider using nicknames or abbreviated names instead.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('rec_age','Delete old recordings','Set the maximum age of your call recordings here (in days).  This will keep the size of the recording directory relatively constant and prevent the disk from becoming full. The default size is 60 days but you can increase/decrease it depending upon the available storage. The recordings folder will be aged every morning at 02:00');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('rec_file_dlim','Recording file delimiter','Delimiter character(s) used between fields in recorded call filenames.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('rec_final_dest','Recording final destination','Path or target where completed recordings are moved after staging.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('rec_grace','Recording grace period','Grace seconds before a recording is considered complete.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('rec_limit','Recording limit','Maximum recording size or duration limit for this tenant (read-only when computed by the system).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('rec_mount','Call recording mount command','This is the mount cmd target where you can direct PBX3 to use external storage for call recordings. Code it EXACTLY as you wouild at the linux CLI, but exclude the local mountpoint (PBX3 will provide that) e.g.
*mount -t efs -o tls fs-xxxxxx:/*
 You can specify any valid mountable url (NFS,EFS,CIFS etc).
If you leave this field blank then call recordings will be held locally on the instance.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recfiledlim','Recording file delimiter','Instance-wide delimiter used in call recording filenames.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('reclimit','Recording limit','Instance-wide recording size or count limit.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recmaxage','Max recording age','Set the maximum age of your Tenant call recordings here (in days). This will keep the size of the recording directory relatively constant and prevent the disk from becoming full. The default size is 60 days but you can increase/decrease it depending upon the available storage. The recordings folder will be aged every morning at 02:00');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recs3','S3 offload','Opt this tenant into fleet S3 disaster recovery for call recordings (default No). Requires the home to have recordings S3 upload plumbing enabled at install. Local archive and max age/size always apply; Yes only adds upload of archived files to the fleet recordings bucket.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recmaxsize','Max recording size','Set the maximum size of your Tenant call recordings here (in bytes). This will keep the size of the recording directory relatively constant and prevent the disk from becoming full. The default size is 0 bytes (unlimited) but you can increase/decrease it depending upon the available storage. The recordings folder will be aged every morning at 02:00');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recmount','Recording mount','External mount command for call recordings (see instance globals). Leave blank to store locally.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recqdither','Recording queue dither','Jitter applied when ageing the recording queue.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recqsearchlim','Recording search limit','Maximum age or scope when searching the recording index.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('recused','Storage','How much recording space this tenant is currently using.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('register','Registration String','Used to provide a registration string if your carrier requires it');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('regress','Reg','Regress the system to this image');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('regthistrunk','Generate a registration string','Set this on if you want PBX3 to register this trunk. Your carrier will have given you instructions as to whether registration is required or not');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('remotenum','DiD Number','The subscriber number which will be presented to us by this trunk (technically, the Dialled Number ID, or DNID).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('resetasterisk','Restore the Asterisk folder','The Asterisk folder contains all of the Asterisk runtime files');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('resetdb','Restore the PBX3 Database','The PBX3 database contains all of the objects which make up the PBX, extensions, trunks, callgroups etc.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('resetldap','Restore the LDAP directory','Restore all of the LDAP directory items');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('resetpwd','Reset pwd','Reset password to system default');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('resetusergreets','Restore usergreetings','Restore all of the usergreetings');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('resetvmail','Restore voicemail','Restore all of the voicemail boxes');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('retry','Queue retry','Seconds to wait before trying the next available member when a call is not answered.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('rev','Version','PBX3 Version number');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ringdelay','Ring Time(sec)','The number of seconds that we will ring the end-point before taking an outcome. If you leave this blank the default delay is 20 seconds, or about 5 ring cycles.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('route','Route','Route name - must be system-wide unique.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('routeable','Routeable?','Set this value to YES if this custom trunk will be used to route inbound traffic. ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('routedesc','Description','Free form description');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('routename','Route Name','The route name should be systemwide unique.  By convention (although it isnt mandatory) we use UPPERCASE for the route name.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('rule','Extension Number','Extension Number.  This is the system internal extension number.  It can be either 3 or 4 digits in length.  The length is set systemwide in the Globals panel before any extensions have been defined.  For new extensions, PBX3 will set this value to the first unused extension number it can find, however you can override this if you wish.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('runfop','Flash Operator Panel','Enables/disables the FOP server.  The FOP server is quite heavy on resource and it can cause big CPU spikes on a small system.  Disable it to save CPU.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('s-peername','Far-end Hostname','The linux hostname of the Sibling (given by uname -n).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('schedend','End','End of a schedule period ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('schedstart','Start','Beginning of a schedule period ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sclose','close','Choose the time you want the closed period to begin.  It''s OK to have a close period span midnight so your close time may be later than your reopen time.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('searchkey','goKey','Here you can enter all or part of the key for any object in the database, for example: an extension number, ring group number, queue name etc.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('secondary','Secondary Path','The second choice trunk for this route.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('selectall','Select All','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sendedomain','Send domain','Domain name sent in SIP headers for outbound calls from this instance.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sessiontimout','Session timeout','Web session idle timeout in minutes before automatic logout.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('shortuid','UID','System generated shortuid.   A 6-character unique value allocated to objects to uniquely identify them.  Among other things it is used to identify SIP endpoints (i.e. the *sip-user*) to Asterisk.   This is separate from any dialable number (e.g. an extension number or DDI).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sipdriver','SIP Channel Driver','You can use the older chan_sip (SIP) stack or the more modern PJSIP stack.  You MUST issue a commit after you change this and then you MUST restart Asterisk or bad things will happen.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sipflood','Throttle SIP floods?','Retired under UFW (no Shorewall limit template). Leave NO; SIP abuse controls live at the SBC for fleet.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sipiaxfriend','SIP Peer entry','Asterisk SIP settings');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sipiaxstart','Extension Start Number','Extension number from which PBX3 will begin allocating extensions.  Set extension length (EXTLEN in Globals) BEFORE you set this value.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sipiaxuser','SIP user entry','Asterisk user stanza name');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sipmulticast','PnP Provisioning','Enable this feature to provide multicast support for provisioning. PnP is used by phones from manufacturers such as Snom, Yealink and Gigaset');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sitename','Site name','Friendly name for this PBX instance (Home header, session chips, Network). Set at install or here; not the DNS hostname.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('smartlink','Smartlink','If set to yes, then PBX3 will attempt to match the last digits of the DiD with an extension number.  If it finds a match it will automatically create a routing for the DiD to the extension.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('smtphost','SMTP Host','The IP address or URL of the mailserver you want the PBX to use. PBX3 does not have an onboard mailserver so it requires you to create an account for it on your own mailserver or a third party server such as Gmail etc.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('smtppwd','SMTP Password','A user account password which PBX3 will use to authorize itself with the mailserver');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('smtpuser','SMTP User ID','A user account ID which PBX3 will use to authorize itself with the mailserver');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('smtpusestrttls','SMTP STARTTLS','Set this on if your mailserver requires it');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('smtpusetls','SMTP TLS','Set this on if your mailserver uses SMTP over TLS');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sndcreds','Auth','Controls when credentials will be sent to the phone with its provisioning stream; Once means send only on the next provisioning request, Always means send on every provisioning request. This is a security feature which allows you to control the transmission of sensitive data to the phone, however some phones require credentials on each provision.  Consult your phone manufacturer''s provisioning guide for more information.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('source','Source','Source of the tooltip help (either CORE (from the PBX3 tt DB) or USER (from the user tt DB).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('span','Span','The Span of your custom app... Your app can be included into the inbound call path, the outbound call path, both inbound and outbound or neither.  PBX3 will automatically generate the correct includes for you based upon the setting you choose here.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('spypass','4-digit Spy Password','Password used to validate spy requests.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sshport','SSH Port','Set this value to the required port number, save it and issue a reboot. ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('staticipv4','Static IPV4 Address','Here you provide a static IP address that your PBX will run VoIP operations from.  PBX3 will always keep a dynamic IP (if DHCP is available) and a second static IP for operations.  This makes network changes less fraught because as long as there is a DHCP server running then PBX3 will get at least one IP after a restart.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('strategy','Strategy','Whether to:
1. select trunks in priority, i.e only select trunk 2 if trunk 1 is unavailable (*hunt*) 
or 
2. to load-balance calls across all available trunks in the route (*balance*)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('striptags','Strip Tags?','By default, any tags will be automatically stripped from the input.  You can override this behaviour by setting this switch off');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('supemail','Supervisor Email','Supervisor email address');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('surname','Name','Surname or organization name');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('swoclip','SWOC?','Switch-On-CLIP. Turn this on if you want this DDI to route CLID patterns (defined in a CLIP DDI).  For example, you may have defined a CLIP DDI to route all inbound callers from a particular area code or country. If those callers will dial in on this DDI then you must turn on SWOC to route on the CLIDs');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('sysop','Operator Real Extension','The operator endpoint.  This is used by PBX3 as the endpoint of last resort so it is important that you point this at a real endpoint.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('syspass','4-digit Sys Password','Password used for privileged key operations (such as recording a greeting or putting the system into night mode).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('tactive','A','Active flag.  You can De-activate a trunk by clicking off the ACT checkbox in trunk edit.  PBX3 will keep the trunk definition but will not generate any entries in the Asterisk .conf files.  This makes it easy to bring trunks into and out of the complex.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('tag','Alpha Tag','Alpha tagging allows you to send a short character string to the phone.  Most phones will display this tag when they receive it.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('technology','Technology','Can have any of the values {SIP|IAX2|DiD|CLiD|Class} depending upon the use case. It is used in the definition of Trunks and DiDs.

Trunks can be {SIP|IAX2}
DiDs can be {DiD|CLiD|Class}
1. DiD - A regular DiD routing
2. CLiD - Route on the inbound callerID
2. Class - Route according to a DiD *class*.  e.g. _5139266XXX will route any DiD *beginning* with 5139266.  You can use any Asterisk exten regex to identify the range you wish to route.  Class regex''s must always begin with  an underscore (_).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('tenantname','Tenant','The name of the Tenant.  It should be system-wide unique.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('tenantoperator','Operator','The extension which will serve as the operator for this Tenant.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('timespan','Time Span','Time when this segment is active (asterisk * means any time).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('timez','Timezone','Set this to the local Timezone for your installation.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('tls','SIP TLS/SRTP','Enable/disable SIP TLS/SRTP for this phone');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('tlsport','SIP TLS Port Number','SIP TLS default port number is 5061 but you can choose a high port if you wish');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('toggleDhcpElement','Use DHCP to obtain an IP address?','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('toggleDhcpd','Run as DHCP Server?','');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('transform','Transformation mask','Used to transform numbers using value comparisons and proceeding left to right... xx:xx xx:xx.  Nulls in the left operand result in addition.  Nulls in the right operand result in suppression.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('transport','Transport Protocol','Set the SIP transport protocol you wish to use for this endpoint. The default is UDP but PBX3 can also use TCP,TLS or WSS.  If you are unsure which to choose then you should leave it set to UDP.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('trunkname','Name','This is the unique name of the trunk.  It will usually be a userID given to you by your ITSP or a username you have given to a downstream client PBX.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('tstate','State','State of the endpoint');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('twin','Enable Twinning','Set this on to enable cellphone call twinning.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('uname','User','Name of the endpoint or the endpoint user ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('usemohcustom','Custom MOH Active?','This switch activates/deactivates your custom MOH. If you deactivate it then the default MOH will be used instead.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('user','Userid','Userid for this sign in.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('usercreate','Autocreate User Logins','Enable this to have PBX3 automatically create a user login every time a new extension is created. ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('useremail','Email','User email address');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('username','Username','The username for this IP Carrier account');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('userotp','User One Time Password','This is the one-time password (OTP) that will be set for newly created users. It is randomly generated by PBX3 at system installation time but you can set it to something more memorable if you wish.  It will be used when a user logs into her account for the first time.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('userpass','Password','User password');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('userscope','Scope','User control scope');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('userspan','Span','User control span');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('vdelete','Empty the mailbox','Delete all the mail for this account (cannot be undone)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('version','Version','This is the PBX3 version number.  You may need this when dealing with Tech Support.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('vmail_age','Delete old vmail','Number of days after which opened voicemail will be deleted (blank for never)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('vmailfwd','Email address','Set this to the email address of the user if you want Asterisk to send voicemails as encapsulated attachments in an e-mail.  This is often called unified messaging.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('voice_instr','Play Long Vmail Intro','Setting this value to YES will cause voicemail to play the long instruction message.  Setting it to NO plays the short version.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('voip_max','Max Outbound VOIP calls','Maximum number of concurrent VOIP outbound calls the system will allow before failing over to other pathways.  This number should be set well below the bandwidth threshold of your Internet circuit.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('vp','Vp','Reset the vmailbox');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('vr','Vr','Empty the vmailbox');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('vreset','Reset Vmail password','Reset the voicemail password the the default (extension number) ');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('vringdelay','Induced VoIP Ring Delay','Allows you place an artificial ring-back tone delay onto a VOIP circuit.  Voip circuits do not naturally ring.  This feature will generate a ring-back tone for the number of seconds specified.  Usually, it is best to leave this value at zero since the target extensions will in any event generate their own ring-back tone.  However, it can be useful if you are using IVR to answer all of your calls.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('weekday','Day','Day of the week when this segment is active (asterisk * means any day).');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('wrapuptime','Wrap-up time','Seconds an agent remains unavailable after completing a call before receiving the next queue call.');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('xref','Cross Reference','Objects which reference this object');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('year','Year','Year(YYYY)');
INSERT OR IGNORE INTO tt_help_core(pkey,displayname,htext) values ('ztp','Zero Touch Provisioning','Enable this to provide Zero Touch Provisioning. You must also have PnP enabled with this option');

-- UFW Phase 4: refresh firewall help on existing DBs (INSERT OR IGNORE does not update).
UPDATE tt_help_core SET displayname='Comment', htext='Optional comment stored on the UFW allow-list rule (shown in ufw status).' WHERE pkey='fwdesc';
UPDATE tt_help_core SET displayname='Port', htext='Destination port or range (e.g. 5060 or 10000:20000). Leave empty for icmp.' WHERE pkey='fwdestports';
UPDATE tt_help_core SET displayname='Proto', htext='Network protocol: tcp, udp, icmp, or all.' WHERE pkey='fwproto';
UPDATE tt_help_core SET displayname='Source', htext='Literal source only: any, an IPv4 or IPv6 address, or CIDR (e.g. 192.168.1.85, 192.168.1.0/24, 2001:db8::1, 2001:db8::/32). No $LAN/$SBC shorthand. One table covers UFW IPv4 and IPv6.' WHERE pkey='fwsource';
UPDATE tt_help_core SET htext='Unused — UFW dual-stack uses the same Source column (IPv4 or IPv6) as the main allow-list.' WHERE pkey='fwsource6';
UPDATE tt_help_core SET htext='Retired under UFW. Fleet SIP is limited to SBC IP(s) on the allow-list; STRING packet inspection is no longer used. Leave this set to NO.' WHERE pkey='fqdninspect';
UPDATE tt_help_core SET htext='Retired under UFW (no Shorewall limit template). Leave NO; SIP abuse controls live at the SBC for fleet.' WHERE pkey='sipflood';

COMMIT;
