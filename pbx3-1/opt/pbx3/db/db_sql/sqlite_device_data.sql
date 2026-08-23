-- Device seed (lean) — PJSIP create-time templates only.
-- No in-house HTTP provisioner templates (#INCLUDE / Fkey / common fat rows).
-- Keepers: General SIP, WebRTC, MAILBOX + vendor bases used by ExtensionController MAC path.
-- Existing DBs: run sqlite_device_lean_prune.sql (or equivalent) to delete surplus rows.
-- NOTE 2026-08-23: Device.sipiaxfriend is DEPRECATED (unused by GenAst; tmpl + pjsip_overlay).
-- Seed still inserts heritage blobs so INSERT OR IGNORE stays compatible; do not rely on them.
BEGIN TRANSACTION;
INSERT OR IGNORE INTO Device(pkey,desc,device,noproxy,owner,sipiaxfriend,technology) values ('General SIP','General SIP definition','General SIP','1','system','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
host=dynamic
qualify=yes
context=internal
call-limit=3
callerid="$desc" <$ext>
canreinvite=no
pickupgroup=1
callgroup=1
subscribecontext=extensions
disallow=all 
allow=alaw
allow=ulaw
nat=$nat
transport=$transport
encryption=$encryption','SIP');
INSERT OR IGNORE INTO Device(pkey,desc,device,owner,technology) values ('WebRTC','WebRTC definition','WebRTC','system','SIP');
INSERT OR IGNORE INTO Device(pkey,desc,device,owner,sipiaxfriend,technology) values ('MAILBOX','Unattached mailbox','MAILBOX','system','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
host=dynamic
qualify=yes
context=internal
call-limit=3
callerid="$desc" <$ext>
canreinvite=no
pickupgroup=1
callgroup=1
subscribecontext=extensions
disallow=all 
allow=alaw
allow=ulaw','SIP');
INSERT OR IGNORE INTO Device(pkey,desc,noproxy,owner,provision,sipiaxfriend,technology) values ('Yealink','yealink SIP phone','1','system','#INCLUDE yealink.Common
account.1.label = $ext
account.1.auth_name = $ext
account.1.password = $password  
account.1.user_name =  $ext
account.1.sip_server_host = $localip
account.1.sip_server_port = $bindport
account.1.outbound_host = $localip
account.1.outbound_port = $bindport
account.1.proxy_require = $localip
account.1.outbound_proxy_enable = 0

','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
host=dynamic
qualify=yes
context=internal
call-limit=3
callerid="$desc" <$ext>
canreinvite=no
pickupgroup=1
callgroup=1
subscribecontext=extensions
disallow=all 
allow=alaw
allow=ulaw
nat=$nat
transport=$transport
encryption=$encryption','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,desc,owner,provision,sipiaxfriend,technology) values ('Cisco','ciscoMP.Fkey','Cisco 7800 8800 Multiplatform Series ','system','#INCLUDE ciscoMP.Common
<!-- Subscriber Information -->
<Display_Name_1_>$desc</Display_Name_1_>
<Station_Display_Name>$desc($ext)</Station_Display_Name>
<User_ID_1_>$ext</User_ID_1_>
<Password_1_>$password</Password_1_>
<Auth_ID_1_>$ext</Auth_ID_1_>

$fkey','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
host=dynamic
qualify=yes
context=internal
call-limit=3
callerid="$desc" <$ext>
canreinvite=no
pickupgroup=1
callgroup=1
subscribecontext=extensions
disallow=all 
allow=alaw
allow=ulaw
nat=$nat
transport=$transport
encryption=$encryption','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,desc,owner,provision,sipiaxfriend,technology) values ('Polycom','polycom.Fkey','Polycom','system','<?xml version="1.0" standalone="yes"?>
<!-- $Revision: 1.14 $  $Date: 2005/07/27 18:43:30 $ -->
<APPLICATION APP_FILE_PATH="sip.ld" CONFIG_FILES="[MACADDRESS]-polycom-locals.cfg, [MACADDRESS]-polycom-phone1.cfg" />
','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
host=dynamic
qualify=yes
context=internal
call-limit=3
callerid="$desc" <$ext>
canreinvite=no
pickupgroup=1
callgroup=1
subscribecontext=extensions
disallow=all 
allow=alaw
allow=ulaw
nat=$nat
transport=$transport
encryption=$encryption','SIP');
INSERT OR IGNORE INTO Device(pkey,desc,owner,provision,sipiaxfriend,technology) values ('Fanvil','Fanvil SIP phone range','system','<<VOIP CONFIG FILE>>Version:2.0000000000                      

<SIP CONFIG MODULE>
--SIP Line List--  :
SIP1 Enable Reg         :1
SIP1 Phone Number       :$ext
SIP1 Display Name       :$ext($desc)
SIP1 Sip Name           :$ext
SIP1 Register Addr      :$localip
SIP1 Register Port      :$bindport
SIP1 Register User      :$ext
SIP1 Register Pswd      :$password
SIP1 Pickup Num         :*8
SIP1 MWI Num            :*50*
SIP1 VoiceCodecMap      :PCMU,PCMA,G726-32,G729,G723,iLBC,AMR,G722,AMR-WB

<CALL FEATURE MODULE>
--Alert Info Ring--:
Alert1 Text               :
Alert1 Line               :-1
Alert1 Ring Type          :Type 1
Alert2 Text               :
Alert2 Line               :-1
Alert2 Ring Type          :Type 1
Alert3 Text               :
Alert3 Line               :-1
Alert3 Ring Type          :Type 1
Alert4 Text               :
Alert4 Line               :-1
Alert4 Ring Type          :Type 1
Alert5 Text               :
Alert5 Line               :-1
Alert5 Ring Type          :Type 1
Alert6 Text               :
Alert6 Line               :-1
Alert6 Ring Type          :Type 1
Alert7 Text               :
Alert7 Line               :-1
Alert7 Ring Type          :Type 1
Alert8 Text               :
Alert8 Line               :-1
Alert8 Ring Type          :Type 1
Alert9 Text               :
Alert9 Line               :-1
Alert9 Ring Type          :Type 1
Alert10 Text               :
Alert10 Line               :-1
Alert10 Ring Type          :Type 1

<PHONE FEATURE MODULE>
Menu Password      :123
KeyLock Password   :123
Fast Keylock Code  :
Enable KeyLock     :0
KeyLock Timeout    :0
KeyLock Status     :0
Emergency Call     :110
Push XML IP        :
SIP Number Plan    :0
LDAP Search        :0
Search Path        :0
Caller Display T   :5
CallLog DisplayType:0
Enable Recv SMS    :1
Enable Call History:1
Line Display Format:$name@$protocol$instance
Enable MWI Tone    :0
All Pswd Encryption:0
SIP Notify XML     :1
Block XML When Call:1
XML Update Interval:30
Vqm Display Order  :
Enable Push XML Auth:0
Pickup Visual Alert:0
Pickup Audio Alert :0
Pickup Ring Type   :
--Display Input--  :
LCD Title          :VOIP PHONE
LCD Constrast      :5
Enable Energysaving:4
LCD Luminance Level:12
Backlight Off Time :45
Disable CHN IME    :0
Phone Model        :
Host Name          :bcm911188sv
Default Language   :en
Enable Greetings   :0
--Power LED--      :
Power              :0
MWI Or SMS         :3
In Using           :0
Ring               :2
Hold               :0
Mute               :0
Missed Call        :3
--Line LED--       :
Line Idle Color    :0
Line Idle Ctl      :1
--BLF LED--        :
BLF Idle Color     :0
BLF Idle Ctl       :1
BLF Idle Text      :terminated
BLF Ring Color     :1
BLF Ring Ctl       :2
BLF Ring Text      :early
BLF Dialing Color  :1
BLF Dialing Ctl    :0
BLF Dialing Text   :
BLF Talking Color  :1
BLF Talking Ctl    :1
BLF Talking Text   :confirmed
BLF Hold Color     :1
BLF Hold Ctl       :0
BLF Hold Text      :
BLF Failed Color   :2
BLF Failed Ctl     :0
BLF Failed Text    :failed
BLF Parked Color   :0
BLF Parked Ctl     :3
BLF Parked Text    :parked
--Voice Volume--   :
Handset Vol        :5
Handset Mic Vol    :3
Headset Vol        :5
Headset Mic Vol    :3
Headset Ring Vol   :5
HandFree Vol       :5
HandFree Mic Vol   :3
HandFree Ring Vol  :5
Ring Type          :1
--DateTime Config--:
Enable SNTP        :1
SNTP Server        :0.pool.ntp.org
Second SNTP Server :time.nist.gov
Time Zone          :0
Time Zone Name     :United Kingdom(London) 
SNTP Timeout       :60
DST Type           :0
DST Location       :0
DST Rule Mode      :0
DST Min Offset     :60
DST Start Mon      :3
DST Start Week     :5
DST Start Wday     :0
DST Start Hour     :2
DST End Mon        :10
DST End Week       :5
DST End Wday       :0
DST End Hour       :2
--DateTime Display--:
Enable TimeDisplay :0
Time Display Style :0
Date Display Style :0
Date Separator     :0
--Softkey Config-- :
Softkey Mode       :0
SoftKey Exit Style :2
Desktop Softkey    :history;contact;dnd;menu;
Talking Softkey    :hold;xfer;conf;end;
Ringing Softkey    :accept;none;forward;reject;
Alerting Softkey   :end;none;none;none;
XAlerting Softkey  :end;none;none;xfer;
Conference Softkey :hold;none;split;end;
Waiting Softkey    :xfer;accept;reject;end;
Ending Softkey     :redial;none;none;end;
DialerPre Softkey  :send;save;delete;exit;
DialerCall Softkey :send;2aB;delete;exit;
DialerXfer Softkey :delete;xfer;send;exit;
DialerCfwd Softkey :send;2aB;delete;exit;
Desktop Click      :history;status;none;none;none;
Dailer  Click      :pline;nline;none;none;none;
Ringing Click      :none;none;none;none;none;
Call    Click      :none;none;voldown;volup;none;
Desktop Long Press :status;none;none;none;reset;
DialerConf Softkey :contact;clogs;redial;video;cancel;
--LDAP Config--    :
LDAP1 Title              :LDAP
LDAP1 Server             :$localip
LDAP1 port               :389
LDAP1 Base               :
LDAP1 Use SSL            :0
LDAP1 Version            :3
LDAP1 Calling Line       :-1
LDAP1 Bind Line          :-1
LDAP1 In Call Search     :0
LDAP1 Out Call Search    :0
LDAP1 Authenticate       :3
LDAP1 Username           :
LDAP1 Password           :
LDAP1 Tel Attr           :telephoneNumber
LDAP1 Mobile Attr        :mobile
LDAP1 Other Attr         :other
LDAP1 Name Attr          :cn sn ou
LDAP1 Sort Attr          :cn
LDAP1 Displayname        :cn
LDAP1 Number Filter      :(|(telephoneNumber=%)(mobile=%)(other=%))
LDAP1 Name Filter        :(|(cn=%)(sn=%))
LDAP1 Max Hits           :50

<DSSKEY CONFIG MODULE>
Select DsskeyAction:0
Memory Key to BXfer:3
FuncKey Page Num   :5
SideKey Page Num   :1
DSS Home Page      :0
Display Parked Info:0
DSS DIAL Switch Mode :0
First Call Wait Time :16
First Num Start Time :360
First Num End Time   :1080
DSS Long Press Action:1
Extern1 Page Belong :0
Extern2 Page Belong :0
Extern3 Page Belong :0
Extern4 Page Belong :0
Extern5 Page Belong :0
DSS Extend1 MAC     :
DSS Extend1 IP      :
DSS Extend2 MAC     :
DSS Extend2 IP      :
DSS Extend3 MAC     :
DSS Extend3 IP      :
DSS Extend4 MAC     :
DSS Extend4 IP      :
DSS Extend5 MAC     :
DSS Extend5 IP      :
--Sidekey Config1--:
Fkey1 Type               :2
Fkey1 Value              :SIP1
Fkey1 Title              :
Fkey1 ICON               :Green
Fkey2 Type               :2
Fkey2 Value              :SIP2
Fkey2 Title              :
Fkey2 ICON               :Green
Fkey3 Type               :2
Fkey3 Value              :SIP3
Fkey3 Title              :
Fkey3 ICON               :Green
Fkey4 Type               :2
Fkey4 Value              :SIP4
Fkey4 Title              :
Fkey4 ICON               :Green
--Dsskey Config1--:
Fkey1 Type               :0
Fkey1 Value              :
Fkey1 Title              :
Fkey1 ICON               :Green
Fkey2 Type               :0
Fkey2 Value              :
Fkey2 Title              :
Fkey2 ICON               :Green
Fkey3 Type               :0
Fkey3 Value              :
Fkey3 Title              :
Fkey3 ICON               :Green
Fkey4 Type               :0
Fkey4 Value              :
Fkey4 Title              :
Fkey4 ICON               :Green
Fkey5 Type               :0
Fkey5 Value              :
Fkey5 Title              :
Fkey5 ICON               :Green
Fkey6 Type               :0
Fkey6 Value              :
Fkey6 Title              :
Fkey6 ICON               :Green
--Dsskey Config2--:
Fkey1 Type               :0
Fkey1 Value              :
Fkey1 Title              :
Fkey1 ICON               :Green
Fkey2 Type               :0
Fkey2 Value              :
Fkey2 Title              :
Fkey2 ICON               :Green
Fkey3 Type               :0
Fkey3 Value              :
Fkey3 Title              :
Fkey3 ICON               :Green
Fkey4 Type               :0
Fkey4 Value              :
Fkey4 Title              :
Fkey4 ICON               :Green
Fkey5 Type               :0
Fkey5 Value              :
Fkey5 Title              :
Fkey5 ICON               :Green
Fkey6 Type               :0
Fkey6 Value              :
Fkey6 Title              :
Fkey6 ICON               :Green
--Dsskey Config3--:
Fkey1 Type               :0
Fkey1 Value              :
Fkey1 Title              :
Fkey1 ICON               :Green
Fkey2 Type               :0
Fkey2 Value              :
Fkey2 Title              :
Fkey2 ICON               :Green
Fkey3 Type               :0
Fkey3 Value              :
Fkey3 Title              :
Fkey3 ICON               :Green
Fkey4 Type               :0
Fkey4 Value              :
Fkey4 Title              :
Fkey4 ICON               :Green
Fkey5 Type               :0
Fkey5 Value              :
Fkey5 Title              :
Fkey5 ICON               :Green
Fkey6 Type               :0
Fkey6 Value              :
Fkey6 Title              :
Fkey6 ICON               :Green
--Dsskey Config4--:
Fkey1 Type               :0
Fkey1 Value              :
Fkey1 Title              :
Fkey1 ICON               :Green
Fkey2 Type               :0
Fkey2 Value              :
Fkey2 Title              :
Fkey2 ICON               :Green
Fkey3 Type               :0
Fkey3 Value              :
Fkey3 Title              :
Fkey3 ICON               :Green
Fkey4 Type               :0
Fkey4 Value              :
Fkey4 Title              :
Fkey4 ICON               :Green
Fkey5 Type               :0
Fkey5 Value              :
Fkey5 Title              :
Fkey5 ICON               :Green
Fkey6 Type               :0
Fkey6 Value              :
Fkey6 Title              :
Fkey6 ICON               :Green
--Dsskey Config5--:
Fkey1 Type               :0
Fkey1 Value              :
Fkey1 Title              :
Fkey1 ICON               :Green
Fkey2 Type               :0
Fkey2 Value              :
Fkey2 Title              :
Fkey2 ICON               :Green
Fkey3 Type               :0
Fkey3 Value              :
Fkey3 Title              :
Fkey3 ICON               :Green
Fkey4 Type               :0
Fkey4 Value              :
Fkey4 Title              :
Fkey4 ICON               :Green
Fkey5 Type               :0
Fkey5 Value              :
Fkey5 Title              :
Fkey5 ICON               :Green
Fkey6 Type               :0
Fkey6 Value              :
Fkey6 Title              :
Fkey6 ICON               :Green
--SoftDss Config-- :
Fkey1 Type               :0
Fkey1 Value              :
Fkey1 Title              :
Fkey1 ICON               :Green
Fkey2 Type               :0
Fkey2 Value              :
Fkey2 Title              :
Fkey2 ICON               :Green
Fkey3 Type               :0
Fkey3 Value              :
Fkey3 Title              :
Fkey3 ICON               :Green
Fkey4 Type               :0
Fkey4 Value              :
Fkey4 Title              :
Fkey4 ICON               :Green
Fkey5 Type               :0
Fkey5 Value              :
Fkey5 Title              :
Fkey5 ICON               :Green
Fkey6 Type               :0
Fkey6 Value              :
Fkey6 Title              :
Fkey6 ICON               :Green
Fkey7 Type               :0
Fkey7 Value              :
Fkey7 Title              :
Fkey7 ICON               :Green
Fkey8 Type               :0
Fkey8 Value              :
Fkey8 Title              :
Fkey8 ICON               :Green
Fkey9 Type               :0
Fkey9 Value              :
Fkey9 Title              :
Fkey9 ICON               :Green
Fkey10 Type               :0
Fkey10 Value              :
Fkey10 Title              :
Fkey10 ICON               :Green

<MMI CONFIG MODULE>
--MMI Account--    :
Account1 Name               :admin
Account1 Password           :$padminpass
Account1 Level              :10
Account2 Name               :user
Account2 Password           :$userpass
Account2 Level              :5

<AUTOUPDATE CONFIG MODULE>

Flash Server IP    :http://$localip/provisioning
<<END OF FILE>>','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
host=dynamic
qualify=yes
context=internal
call-limit=3
callerid="$desc" <$ext>
canreinvite=no
pickupgroup=1
callgroup=1
subscribecontext=extensions
disallow=all 
allow=alaw
allow=ulaw
nat=$nat
transport=$transport
encryption=$encryption','SIP');
INSERT OR IGNORE INTO Device(pkey,desc,legacy,owner,provision,sipiaxfriend,technology) values ('Gigaset','Gigaset SIP XML ','1','system','<?xml version="1.0" encoding="ISO-8859-1"?>
<ProviderFrame xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="actc_provider.xsd">
<Provider>

<MAC_ADDRESS value="7C:2F:80:57:EE:64" />
<PROFILE_NAME class="string" value="PBX3"/>
<S_SIP_SERVER class="string" value="$localip" />
<SYMB_ITEM ID="BS_AE_Subscriber.stMtDat[0].aucTlnName" class="symb_item" value=$quotedDesc />
<S_SIP_USER_ID class="string" value="$ext" />
<S_SIP_PASSWORD class="string" value="$password" />
<S_SIP_DISPLAYNAME class="string" value="$desc" />
<S_SIP_DOMAIN class="string" value="$localip" />
<S_SIP_LOGIN_ID class="string" value="$ext" />
<B_SIP_ACCOUNT_IS_ACTIVE_1 class="boolean" value="true" />
<SYMB_ITEM ID="BS_AE_SwConfig.ucCountryCodeTone" class="symb_item" value="8" />
<S_SIP_REGISTRAR class="string" value="$localip" />
<I_CHECK_FOR_UPDATES_TIMER_INIT class="integer" value="1400" />


<I_ONESHOT_PROVISIONING_MODE_1 class="integer" value="1"/>
<B_SIP_SHC_ACCOUNT_IS_ACTIVE class="boolean" value="false"/>
<I_DTMF_TX_MODE_BITS class="integer" value="2"/>
<B_AUTO_UPDATE_PROFILE class="boolean" value="true" />

</Provider>
</ProviderFrame>','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,desc,device,owner,provision,sipiaxfriend,technology) values ('Aastra','None','Aastra SIP phone','Aastra','system','sip registrar ip: $localip
sip screen name: $desc
sip user name: $ext
sip display name: $ext
sip auth name: $ext
sip password: $password
sip proxy ip: $localip','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
host=dynamic
qualify=yes
context=internal
call-limit=3
callerid="$desc" <$ext>
canreinvite=no
pickupgroup=1
callgroup=1
subscribecontext=extensions
disallow=all 
allow=alaw
allow=ulaw
nat=$nat
transport=$transport
encryption=$encryption','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,desc,owner,provision,sipiaxfriend,technology) values ('Vtech','vtech.Fkey','Vtech SIP Phone','system','#INCLUDE vtech.Common

sip_account.1.sip_account_enable = 1
sip_account.1.label = $ext
sip_account.1.display_name = $desc
sip_account.1.user_id = $ext
sip_account.1.authentication_name = $ext 
sip_account.1.authentication_access_password = $password 
','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
host=dynamic
qualify=yes
context=internal
call-limit=3
callerid="$desc" <$ext>
canreinvite=no
pickupgroup=1
callgroup=1
subscribecontext=extensions
disallow=all 
allow=alaw
allow=ulaw
nat=$nat
transport=$transport
encryption=$encryption','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,desc,owner,provision,sipiaxfriend,technology) values ('Panasonic','panasonicHDV.Fkey','Panasonic KX-HDV range','system','# Panasonic SIP Phone Standard Format File #
# This is a simplified sample configuration file.
############################################################
# Configuration Setting #
############################################################
# URL of this configuration file
OPTION66_ENABLE="Y"
OPTION66_REBOOT="Y"
PROVISION_ENABLE="Y"
CFG_RESYNC_FROM_SIP="check-sync"
CFG_STANDARD_FILE_PATH="http://$localip/provisioning?mac={mac}"
SIP_DETECT_SSAF_1="Y"
############################################################
# SIP Settings #
# Suffix "_1" indicates this parameter is for "line 1". #
############################################################
# IP Address or FQDN of SIP registrar server, proxy server
SIP_RGSTR_ADDR_1="$localip"
SIP_PRXY_ADDR_1="$localip"
# IP Address or FQDN of SIP presence server
SIP_PRSNC_ADDR_1="$localip"
# Enables DNS SRV lookup
SIP_DNSSRV_ENA_1="Y"

# Set TLS initially OFF
SIP_RGSTR_PORT_1="$bindport"
SIP_PRXY_PORT_1="$bindport"
SIP_PRSNC_PORT_1="$bindport"
SIP_SRC_PORT_1=“5060"
SIP_TRANSPORT_1=“0"
SIP_TLS_MODE_1=“0"
SRTP_CONNECT_MODE_1=“1"

NUM_PLAN_PICKUP_DIRECT="*8"
NTP_ADDR="pool.ntp.org"
# 
# Timezone needs to be set for your zone if not UK
#
LOCAL_TIME_ZONE_POSIX="GMT0BST,M3.5.0/1,M10.5.0"
HTTPD_PORTOPEN_AUTO="Y"
VM_SUBSCRIBE_ENABLE="Y"
VM_NUMBER_1="*50*"
HTTPD_PORTOPEN_AUTO="Y"

# UK call progress tones

DIAL_TONE1_FRQ="350,440"
DIAL_TONE1_TIMING="60,0"
BUSY_TONE_FRQ="400,400"
BUSY_TONE_TIMING="60,375,315"
REORDER_TONE_FRQ="400,400"
REORDER_TONE_TIMING="60,0"
RINGBACK_TONE_FRQ="400,450"
RINGBACK_TONE_TIMING="60,400,200,400,1940"

# this is the stutter dial tone
DIAL_TONE4_FRQ="350,440"
DIAL_TONE4_TIMING="560,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,0"

# not sure what this is used for but was the same as dial tone 1
DIAL_TONE2_FRQ="350,440"
DIAL_TONE2_TIMING="60,0"

# cause un-reg/re-reg on sync 
USE_DEL_REG_OPEN_1="Y"
USE_DEL_REG_CLOSE_1="Y"

# # Browser access - CHANGE THIS FOR YOUR SITE!
## N.B. passwords must be 6 characters or more
ADMIN_ID="admin"
ADMIN_PASS="$padminpass"
USER_ID="user"
USER_PASS="$puserpass"

## LDAP Settings
LDAP_ENABLE="Y"
LDAP_DNSSRV_ENABLE="N"
LDAP_SERVER="ldap://$localip"
LDAP_SERVER_PORT="389"
LDAP_MAXRECORD="20"
LDAP_NUMB_SEARCH_TIMER="30"
LDAP_NAME_SEARCH_TIMER="5"
# 
# UID and PWD need to be set for your installation!
LDAP_USERID="root"
LDAP_PASSWORD="spibble"
#
LDAP_NAME_FILTER="(|(cn=%)(sn=%))"
LDAP_NUMB_FILTER="(|(telephoneNumber=%)(mobile=%)(homePhone=%))"
LDAP_NAME_ATTRIBUTE="cn,sn"
LDAP_NUMB_ATTRIBUTE="telephoneNumber,mobile,homePhone"
LDAP_BASEDN="$ldapbase"
LDAP_SSL_VERIFY="0"
LDAP_ROOT_CERT_PATH=""
LDAP_CLIENT_CERT_PATH=""
LDAP_PKEY_PATH=""

# ID, password for SIP authentication
PHONE_NUMBER_1="$ext"
SIP_AUTHID_1="$ext"
SIP_PASS_1="$password"','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
host=dynamic
qualify=yes
context=internal
call-limit=3
callerid="$desc" <$ext>
canreinvite=no
pickupgroup=1
callgroup=1
subscribecontext=extensions
disallow=all 
allow=alaw
allow=ulaw
nat=$nat
transport=$transport
encryption=$encryption','SIP');
COMMIT;
