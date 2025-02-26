BEGIN TRANSACTION;
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,device,owner,provision,sipiaxfriend,technology) values ('Aastra','None','Aastra SIP phone','Aastra','system','sip registrar ip: $localip
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
INSERT OR IGNORE INTO Device(pkey,description,device,owner,provision,sipiaxfriend,technology) values ('Aastra VXT','Aastra Hot Desk Template','AastraVXT','system','download protocol: HTTP
sip outbound proxy: $localip
sip registrar ip: $localip
sip screen name: $desc
sip user name: $ext
sip display name: $ext
sip vmail: *50*
sip auth name: $ext
sip password: $password
sip mode: 0
sip proxy ip: $localip
sip proxy port: 5060
missed calls indicator disabled: 1
directory 1: seldir
#softkey1 type: blf
#softkey1 label: name
#softkey1 value: 5000
#softkey1 line: 1','type=peer
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
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,owner,provision,sipiaxfriend,technology) values ('Cisco','ciscoMP.Fkey','Cisco 7800 8800 Multiplatform Series ','system','#INCLUDE ciscoMP.Common
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
INSERT OR IGNORE INTO Device(pkey,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Cisco/Linksys(SPA)','Cisco/Linksys(SPA)','Cisco/linksys(SPA)','1','system','<flat-profile>
<Proxy_1_> $localip
</Proxy_1_>
<Outbound_Proxy_1_> $localip
</Outbound_Proxy_1_>
<User_ID_1_> $ext
</User_ID_1_>
<Password_1_> $password
</Password_1_>
<Display_Name_1_> $desc
</Display_Name_1_>
<Dial_Plan_1_> (*x.|*xx*x.|x.)
</Dial_Plan_1_>
<Time_Zone> GMT
</Time_Zone>
<Resync_Periodic> 3600
</Resync_Periodic>
</flat-profile>','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,owner,provision,sipiaxfriend,technology) values ('CiscoMP','ciscoMP.Fkey','Cisco 7800 8800 Multiplatform Series ','system','#INCLUDE ciscoMP.Common
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
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,device,owner,provision,sipiaxfriend,technology) values ('CiscoSPA','cisco.Fkey','Cisco/Linksys(SPA)','Cisco/linksys(SPA)','system','#INCLUDE cisco.Common
$fkey
<User_ID_1_>$ext</User_ID_1_>
<Password_1_>$password</Password_1_>
<Station_Display_Name ua="na">$desc($ext)</Station_Display_Name>
#INCLUDE cisco.Fkey','type=peer
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
INSERT OR IGNORE INTO Device(pkey,description,device,legacy,owner,technology) values ('General IAX','General IAX definition','General IAX','1','system','IAX2');
INSERT OR IGNORE INTO Device(pkey,description,device,owner,technology) values ('WebRTC','WebRTC definition','WebRTC','system','SIP');
INSERT OR IGNORE INTO Device(pkey,description,device,owner,sipiaxfriend,technology) values ('General SIP','General SIP definition','General SIP','system','type=peer
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
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,sipiaxfriend,technology) values ('Gigaset','Gigaset SIP XML ','1','system','<?xml version="1.0" encoding="ISO-8859-1"?>
<ProviderFrame xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="actc_provider.xsd">
<Provider>

<MAC_ADDRESS value="7C:2F:80:57:EE:64" />
<PROFILE_NAME class="string" value="SARK"/>
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
INSERT OR IGNORE INTO Device(pkey,description,device,owner,sipiaxfriend,technology) values ('MAILBOX','Unattached mailbox','MAILBOX','system','type=peer
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
disallow=all q
allow=alaw
allow=ulaw','SIP');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,technology) values ('PIKAFXS','PIKA fxs extension','1','system','Custom');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,owner,provision,sipiaxfriend,technology) values ('Panasonic','panasonicHDV.Fkey','Panasonic KX-HDV range','system','# Panasonic SIP Phone Standard Format File #
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
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,legacy,owner,provision,sipiaxfriend,technology) values ('Panasonic KX','panasonic.Fkey','Panasonic KX-UT range','1','system','# Panasonic SIP Phone Standard Format File #
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
# ID, password for SIP authentication
PHONE_NUMBER_1="$ext"
SIP_AUTHID_1="$ext"
SIP_PASS_1="$password"
NUM_PLAN_PICKUP_DIRECT="*8"
NTP_ADDR="pool.ntp.org"
LOCAL_TIME_ZONE_POSIX="GMT0BST,M3.5.0/1,M10.5.0"
HTTPD_PORTOPEN_AUTO="Y"
VM_SUBSCRIBE_ENABLE="Y"
VM_NUMBER_1="*50*"
','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,legacy,owner,provision,sipiaxfriend,technology) values ('Panasonic KX-HDV','1','panasonicHDV.Fkey','Panasonic KX-HDV range','system','# Panasonic SIP Phone Standard Format File #
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
SIP_RGSTR_PORT_1=“5060"
SIP_PRXY_PORT_1=“5060"
SIP_PRSNC_PORT_1="5060"
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

# # Browser access - CHANGE THIS FOR YOUR SITE!
## N.B. passwords must be 6 characters or more
ADMIN_ID="admin"
ADMIN_PASS="myadminpass"
USER_ID="user"
USER_PASS="myuserpass"

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
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,sipiaxfriend,technology) values ('Panasonic TGP5xx','Panasonic DECT base station','system','# PCC Standard Format File #
# This is a simplified sample configuration file.
############################################################
# Configuration Setting #
############################################################
# URL of this configuration file
#OPTION66_ENABLE="Y"
#OPTION66_REBOOT="Y"
PROVISION_ENABLE="Y"
#CFG_RESYNC_FROM_SIP="check-sync"
CFG_STANDARD_FILE_PATH="http://$localip/provisioning?mac={mac}"
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
#SIP_DNSSRV_ENA_1="Y"
# ID, password for SIP authentication
PHONE_NUMBER_1="$ext"
SIP_AUTHID_1="$ext"
SIP_PASS_1="$password"
NUM_PLAN_PICKUP_DIRECT="*8"
NTP_ADDR="pool.ntp.org"
LOCAL_TIME_ZONE_POSIX="GMT0BST,M3.5.0/1,M10.5.0"
HTTPD_PORTOPEN_AUTO="Y"
VM_SUBSCRIBE_ENABLE="Y"
VM_NUMBER_1="*50*"
#SHARED_CALL_ENABLE_1="Y"
#SHARED_USER_ID_1="$ext"
LINE_ID_1=""
DISPLAY_NAME_1="$desc"


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
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,sipiaxfriend,technology) values ('Panasonic VXT','Panasonic Hot Desk','system','#INCLUDE Panasonic
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
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,owner,provision,sipiaxfriend,technology) values ('Polycom','polycom.Fkey','Polycom','system','<?xml version="1.0" standalone="yes"?>
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
INSERT OR IGNORE INTO Device(pkey,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Polycom IP320/330','Polycom POE deskphones','Polycom IP320/330','1','system','["$mac.cfg"
<?xml version="1.0" standalone="yes"?>
<!-- $Revision: 1.14 $  $Date: 2005/07/27 18:43:30 $ -->
<APPLICATION APP_FILE_PATH="sip.ld" CONFIG_FILES="$mac-phone.cfg, polycom-locals.cfg, phone1.cfg, sip.cfg" MISC_FILES="" LOG_FILE_DIRECTORY="" OVERRIDES_DIRECTORY="" CONTACTS_DIRECTORY=""/>
]

["$mac-phone.cfg"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<!-- $Revision: 1.73.6.2 $  $Date: 2006/07/17 21:46:42 $ -->

<phone$ext>
  <reg
      reg.1.displayName="$desc"
      reg.1.address="$ext"
      reg.1.label="$ext"
      reg.1.auth.userId="$ext"
      reg.1.auth.password="$password"/>
</phone$ext>
]

["$mac-directory.xml"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<!-- $Revision: 1.2 $  $Date: 2004/12/21 18:28:05 $ -->
<directory>
        <item_list>
                <item>
                        <ln>Doe</ln>
                        <fn>John</fn>
                        <ct>1001</ct>
                        <sd>1</sd>
                        <rt>3</rt>
                        <dc/>
                        <ad>0</ad>
                        <ar>0</ar>
                        <bw>0</bw>
                        <bb>0</bb>
                </item>

        </item_list>
</directory>
]
','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,device,owner,provision,sipiaxfriend,technology) values ('Polycom VXT','Polycom Hot Desk Template','Polycom VXT','system','["$mac.cfg"
<?xml version="1.0" standalone="yes"?>
<!-- $Revision: 1.14 $  $Date: 2005/07/27 18:43:30 $ -->
<APPLICATION APP_FILE_PATH="sip.ld" CONFIG_FILES="$mac-phone.cfg, polycom-locals.cfg, phone1.cfg, sip.cfg" MISC_FILES="" LOG_FILE_DIRECTORY="" OVERRIDES_DIRECTORY="" CONTACTS_DIRECTORY=""/>
]

["$mac-phone.cfg"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<!-- $Revision: 1.73.6.2 $  $Date: 2006/07/17 21:46:42 $ -->

<phone$ext>
  <reg
      reg.1.displayName="$desc"
      reg.1.address="$ext"
      reg.1.label="$ext"
      reg.1.auth.userId="$ext"
      reg.1.auth.password="$password"/>
  <reg
</phone$ext>
]

["$mac-directory.xml"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<!-- $Revision: 1.2 $  $Date: 2004/12/21 18:28:05 $ -->
<directory>
        <item_list>
                <item>
                        <ln>Doe</ln>
                        <fn>John</fn>
                        <ct>1001</ct>
                        <sd>1</sd>
                        <rt>3</rt>
                        <dc/>
                        <ad>0</ad>
                        <ar>0</ar>
                        <bw>0</bw>
                        <bb>0</bb>
                </item>

        </item_list>
</directory>
]','type=peer
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
INSERT OR IGNORE INTO Device(pkey,description,device,legacy,owner,sipiaxfriend,technology) values ('SipStack','Local H/S Stack','SipStack','1','system','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Snom 300','snom.Fkey','5','Snom 300 series','Snom 300','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Snom 320','snom.Fkey','12','Snom 320 series','Snom 320','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Snom 360','snom.Fkey','12','Snom 360 series','Snom 360','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Snom 370','snom.Fkey','12','Snom 370 series','Snom 370','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,legacy,owner,provision,sipiaxfriend,technology) values ('Snom 710','snom.Fkey','5','Snom 710 series','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,legacy,owner,provision,sipiaxfriend,technology) values ('Snom 715','snom.Fkey','Snom 715 series','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,legacy,owner,provision,sipiaxfriend,technology) values ('Snom 720','snom.Fkey','18','Snom 720 series','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,legacy,owner,provision,sipiaxfriend,technology) values ('Snom 760','snom.Fkey','12','Snom 760 series','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,legacy,owner,provision,sipiaxfriend,technology) values ('Snom 820','snom.Fkey','12','Snom 820 series','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,legacy,owner,provision,sipiaxfriend,technology) values ('Snom 821','snom.Fkey','12','Snom 821 series','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,legacy,owner,provision,sipiaxfriend,technology) values ('Snom 870','snom.Fkey','Snom 870 series','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Snom D305','snom.Fkey','5','Snom D305 series','Snom D305','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Snom D315','snom.Fkey','5','Snom D315 series','Snom D315','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Snom D345','snom.Fkey','5','Snom D345 series','Snom D345','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,legacy,owner,provision,sipiaxfriend,technology) values ('Snom D375','snom.Fkey','Snom D375 series','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Snom D710','snom.Fkey','5','Snom D710 series','Snom D710','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Snom D715','snom.Fkey','5','Snom D715 series','Snom D715','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Snom D725','snom.Fkey','5','Snom D725 series','Snom D725','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Snom D745','snom.Fkey','5','Snom D745 series','Snom D745','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Snom D765','snom.Fkey','5','Snom D765 series','Snom D765','1','system','#INCLUDE snom.Common
#INCLUDE snom.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,device,owner,provision,sipiaxfriend,technology) values ('Snom VXT','snom.Fkey','Snom Hot Desk','Snom VXT','system','#INCLUDE snom.Common
user_name1$: $ext
user_pname1$: $ext
user_pass1$: $password
user_host1$: $localip','type=peer
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
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,owner,provision,sipiaxfriend,technology) values ('Vtech','vtech.Fkey','Vtech SIP Phone','system','#INCLUDE vtech.Common

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
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,sipiaxfriend,technology) values ('Yealink','yealink SIP phone','system','#INCLUDE yealink.Common
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
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink CP860','Yealink CP860 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T12','Yealink T12 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T18','Yealink T18 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T19','Yealink T19 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T20','Yealink T20 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T21','Yealink T21 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T21_E2','Yealink T21_E2 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T22','Yealink T22 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T23','Yealink T23 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T26','yealink.Fkey','10','Yealink T26 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T27','yealink.Fkey','Yealink T27 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T28','yealink.Fkey','10','Yealink T28 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T29','yealink.Fkey','10','Yealink T29 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,device,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T2x','Yealink office phone range','Yealink T2x','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T32','Yealink T32 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,blfkeys,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T38','yealink.Fkey','10','Yealink T38 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T40','yealink.Fkey','Yealink T40 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T41','yealink.Lkey','Yealink T41 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T42','yealink.Lkey','Yealink T42 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T46','yealink.Lkey','Yealink T46 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink T48','yealink.Lkey','Yealink T48 phone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink VP-T49','Yealink VP-T49 Vidphone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink VP530','Yealink VP530 Vidphone','1','system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,sipiaxfriend,technology) values ('Yealink VXT','Yealink HotDesk ','system','#INCLUDE yealink.Common
account.1.label = $ext
account.1.auth_name = $ext
account.1.password = $password  
account.1.user_name =  $ext
account.1.sip_server_host = $localip
account.1.outbound_host = $localip
account.1.proxy_require = $localip
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
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,legacy,owner,provision,sipiaxfriend,technology) values ('Yealink W52P','None','Yealink W52P DECT','1','system''system','#INCLUDE yealink.Extension','type=peer
defaultuser=$desc
secret=$password
mailbox=$ext@default
callerid="$desc"
call-limit=3
canreinvite=no
pickupgroup=1
callgroup=1','SIP');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('aastra.Fkey','Aastra BLF template','system','softkey$seq type: $type
softkey$seq label: $label
softkey$seq value: $value
softkey$seq line: 1','BLF Template');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('aastra.Pkey','Aastra Pkey template','system','prgkey$seq type: $type
prgkey$seq label: $label
prgkey$seq value: $value
prgkey$seq line: 1','BLF Template');
INSERT OR IGNORE INTO Device(pkey,description,device,owner,provision,technology) values ('aastra.cfg','Aastra descriptor','aastra.cfg','system','download protocol: HTTP
sip mode: 0
sip proxy port: 5060
sip vmail: *50*
sip proxy port: 5060
sip outbound proxy port: 5060
sip registrar port: 5060
sip registration period: 0
time zone name: GB-London
tone set: UK
time server1: pool.ntp.org
auto resync mode: 1
auto resync time: 00:15
directed call pickup: 1
directed call pickup prefix: *8
missed calls indicator disabled: 1
directory 1: aastra.directory','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('aastra.directory','Aastra directory','system','# 
# Directory items should be of the following format :-
#some name, 9999999999
# example :-
#David Jones, 07975433306
#','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('cisco.Common','Cisco SPA common config','system','<Resync_On_Reset>Yes</Resync_On_Reset>
<Resync_Periodic></Resync_Periodic>
<Resync_At__HHmm_ ua="na">0015</Resync_At__HHmm_>
<Dial_Plan_1_>(*x.|*xx*x.|x.)</Dial_Plan_1_>
<Time_Zone>GMT</Time_Zone>
<NTP_Enable ua="na">Yes</NTP_Enable>
<Daylight_Saving_Time_Rule ua="na">start=3/-1/7/2;end=10/-1/7/2;save=1</Daylight_Saving_Time_Rule>
<Daylight_Saving_Time_Enable ua="na">Yes</Daylight_Saving_Time_Enable>
<Primary_NTP_Server ua="na">pool.ntp.org</Primary_NTP_Server>
<Secondary_NTP_Server ua="na">$localip</Secondary_NTP_Server>
<Enable_IP_Dialing_1_ ua="na">Yes</Enable_IP_Dialing_1_>
<Attendant_Console_Call_Pickup_Code ua="na">*8#</Attendant_Console_Call_Pickup_Code>
<Server_Type ua="na">Asterisk</Server_Type>
<Back_Light_Timer ua="na">Always On</Back_Light_Timer>
<Voice_Mail_Number ua="na">*50*</Voice_Mail_Number>
<Proxy_1_>$localip</Proxy_1_>
<Outbound_Proxy_1_>$localip</Outbound_Proxy_1_>','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('cisco.Fkey','Cisco SPA BLF template','system','<!-- Line Key $seq -->
<Extension_$seq_ ua="na">Disabled</Extension_$seq_>
<Share_Call_Appearance_$seq_ >private</Share_Call_Appearance_$seq_>','BLF Template');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('ciscoMP.Common','Cisco Multiplatform Series common config','system','<?xml version="1.0" encoding="UTF-8"?>
<device xsi:type="axl:XIPPhone" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

<flat-profile>

<!-- Interdigit Short Timer -->
<Interdigit_Short_Timer>5</Interdigit_Short_Timer>

<Enable_Web_Server>Yes</Enable_Web_Server>
<Web_Server_Port>80</Web_Server_Port>
<Enable_Web_Admin_Access>Yes</Enable_Web_Admin_Access>
<Admin_Password>33575</Admin_Password>
<User_Password/>

<Server_Type_1_ >Asterisk</Server_Type_1_>

<Voice_Mail_Number>*50*</Voice_Mail_Number>
<Call_Pickup_Code>*8</Call_Pickup_Code>

<Dial_Plan_1_ >(*x.|*xx*x.|x.)</Dial_Plan_1_>

<!-- Time Server -->
<Primary_NTP_Server ua="na">0.uk.pool.ntp.org</Primary_NTP_Server>
<Secondary_NTP_Server ua="na">$localip</Secondary_NTP_Server>
<Time_Zone>GMT-00:00</Time_Zone>

<!-- Backlight Timer -->
<Back_Light_Timer>Always On</Back_Light_Timer>

<!-- LDAP Settings -->
<LDAP_Dir_Enable>Yes</LDAP_Dir_Enable>
<LDAP_Corp_Dir_Name>Corporate directory</LDAP_Corp_Dir_Name>
<LDAP_Server>$localip</LDAP_Server>
<LDAP_Client_DN>$ldapbase</LDAP_Client_DN>
<LDAP_Search_Base>$ldapbase</LDAP_Search_Base>
<LDAP_Last_Name_Filter>cn:(cn=*$VALUE*)</LDAP_Last_Name_Filter>
<LDAP_Display_Attrs>a=cn,n=Contact;a=telephoneNumber,n=Work,t=p</LDAP_Display_Attrs>

<!-- Proxy and Registration -->
<Proxy_1_>$localip</Proxy_1_>
<Register_1_>Yes</Register_1_>
<Make_Call_Without_Reg_1_>No</Make_Call_Without_Reg_1_>
<Register_Expires_1_>3600</Register_Expires_1_>
<Use_DNS_SRV_1_>Yes</Use_DNS_SRV_1_>
<Proxy_Fallback_Intvl_1_>3600</Proxy_Fallback_Intvl_1_>
<Dual_Registration_1_>No</Dual_Registration_1_>

<!-- Programmable Softkeys -->
<Programmable_Softkey_Enable>Yes</Programmable_Softkey_Enable>
<Connected_Key_List>hold|1;endcall|2;xfer|3;conf|4;bxfer|5;</Connected_Key_List>
','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('ciscoMP.Fkey','Cisco Multiplatform Series BLF template','system','<!-- Line Key $seq -->
<Extension_$seq_ >Disabled</Extension_$seq_>','BLF Template');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('directory.xml','polycom local directory','system','<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<!-- $Revision: 1.73.6.2 $  $Date: 2006/07/17 21:46:42 $ -->
<directory>
  <item_list>
    <item>
      <ln>Doe</ln>
      <fn>John</fn>
      <ct>503</ct>
    </item>
  </item_list>
</directory>','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('panasonic.Fkey','Panasonic KX-UT Fkey','system','FLEX_BUTTON_FACILITY_ACT$seq="X_PANASONIC_IPTEL_$type"
FLEX_BUTTON_FACILITY_ARG$seq="$value"
FLEX_BUTTON_LABEL$seq="$label"','BLF Template');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('panasonic.Ldap','panasonic LDAP fragment','system','## LDAP Settings
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
','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('panasonic.ipv4','panasonic ipv4 fragment','system','IP_ADDR_MODE="0"','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('panasonic.ipv6','panasonic ipv6 fragment','system','IP_ADDR_MODE="2"
CONNECTION_TYPE_IPV6="2"','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('panasonic.tcp','panasonic tcp fragment','system','SIP_RGSTR_PORT_1="5060"
SIP_PRXY_PORT_1="5060"
SIP_SRC_PORT_1="5060"
SIP_TRANSPORT_1="1"
SIP_TLS_MODE_1="0"
SRTP_CONNECT_MODE_1="1"','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('panasonic.tls','panasonic tls fragment','system','SIP_RGSTR_PORT_1="$tlsport"
SIP_PRXY_PORT_1="$tlsport"
SIP_PRSNC_PORT_1="$tlsport"
SIP_SRC_PORT_1="$tlsport"
SIP_TRANSPORT_1="2"
SIP_TLS_MODE_1="1"
SRTP_CONNECT_MODE_1="0"','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,technology) values ('panasonic.udp','panasonic udp fragment','system','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('panasonicHDV.Fkey','Panasonic KX-HDV Fkey','system','FLEX_BUTTON_FACILITY_ACT$seq="X_PANASONIC_IPTEL_$type"
FLEX_BUTTON_FACILITY_ARG$seq="$value"
FLEX_BUTTON_LABEL$seq="$label"','BLF Template');
INSERT OR IGNORE INTO Device(pkey,description,device,owner,provision,technology) values ('polycom-locals.cfg','polycom local settings','polycom-locals.cfg','system','<?xml version="1.0" encoding="UTF-8" standalone="yes"?>

<!-- Our local phone system common configuration in this file -->
<localcfg>
 <server voIpProt.server.1.address="$localip"/>
 <SIP>
   <outboundProxy voIpProt.SIP.outboundProxy.address="$localip"/>
 </SIP>
<TCP_IP>
   <SNTP tcpIpApp.sntp.resyncPeriod="86400" tcpIpApp.sntp.address="$localip" tcpIpApp.sntp.address.overrideDHCP="0" tcpIpApp.sntp.gmtOffset="0" tcpIpApp.sntp.gmtOffset.overrideDHCP="0" tcpIpApp.sntp.daylightSavings.enable="1" />
 </TCP_IP>
 <call>
         <call.directedCallPickupMethod="legacy" call.directedCallPickupString="*8" />
         <missedCallTracking call.missedCallTracking.1.enabled="1" 
          call.missedCallTracking.2.enabled="0" call.missedCallTracking.3.enabled="0" 
          call.missedCallTracking.4.enabled="0" call.missedCallTracking.5.enabled="0" 
          call.missedCallTracking.6.enabled="0"/>
 </call>
<!-- Registration info -->
<attendant
          attendant.uri=""
          attendant.reg="1"
          attendant.behaviors.display.spontaneousCallAppearances.normal="1"
          attendant.behaviors.display.spontaneousCallAppearances.automata="1"
          attendant.behaviors.display.remoteCallerID.normal="1"
          attendant.behaviors.display.remoteCallerID.automata="1"
#INCLUDE polycom.Fkey
$fkey
/>
</localcfg>','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('polycom-phone1.cfg','polycom phone1 template','system','<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<!-- Registration info -->
<userinfo>
  <reg reg.1.displayName="$desc" reg.1.address="$ext" reg.1.label="$desc" reg.1.auth.userId="$ext" reg.1.auth.password="$password" />
</userinfo>','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('polycom.Fkey','Polycom Fkey','system','attendant.resourceList.$seq.address="sip:$value@$localip" attendant.resourceList.$seq.label="$label"  attendant.resourceList.$seq.type="normal"','BLF Template');
INSERT OR IGNORE INTO Device(pkey,blfkeyname,description,owner,provision,sipiaxfriend,technology) values ('snom','snom.Fkey','snom SIP phone','system','#INCLUDE snom.Common
user_name1$: $ext
user_pname1$: $ext
user_pass1$: $password
user_host1$: $localip:$bindport
user_idle_text1$: $ext($desc)','type=peer
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
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('snom.Common','Snom common config','system','setting_server$: http://$localip/provisioning?mac={mac}
update_policy$: 

;set TLS initially off
user_outbound1$:
user_srtp1$: off
user_srtp2$: off
user_auth_tag1$: off
user_savp1$: off

edit_alpha_mode&: 123

ldap_server$: $ldaphost
ldap_port$: 
ldap_base$: ou=$ldaptenant,ou=$ldapou,$ldapbase
ldap_username$: $ldaprouser
ldap_password$: $ldapropwd
ldap_max_hits$: 50
ldap_sort_mode$: server
ldap_search_filter$: (|(sn=%)(cn=%)(o=%))
ldap_number_filter$: (|(telephoneNumber=%)(mobile=%)(homePhone=%))
ldap_name_attributes$: cn o
ldap_number_attributes$: mobile telephoneNumber homePhone
ldap_search_filter_during_call$: (|(cn=%))
ldap_number_filter_during_call$: (|(telephoneNumber=%)(mobile=%)(homePhone=%))
ldap_display_name$: %cn,%o
; Turn this on if your directory supports TLS. Snom only supports LDAPS (SSL/TLS over port 686)
ldap_over_tls$: off

dkey_directory!: keyevent F_DIRECTORY_SEARCH

ignore_asserted_in_gui$: on

; leave dnd codes blank
dnd_on_code!:
dnd_off_code!:

; ntp server - in case it doesnt come from dhcp
ntp_server$: 0.pool.ntp.org

; locale settings
timezone!: GBR-0
language!: English(UK)
tone_scheme!: GBR
date_us_format&: off
time_24_format&: on

; change ringers as no one likes the normal one!
alert_internal_ring_sound!: Ringer6
alert_external_ring_sound!: Ringer2
user_ringer1!: Ringer6
user_ringer2!: Ringer6

; load firmware automatically with no user input if we send it
update_policy&: auto_update


; turn off long contact sip headers
user_descr_contact1$: off
user_descr_contact2$: off

; "support broken registrar" not sure this is needed any more for *
user_sipusername_as_line1$: on
user_sipusername_as_line2$: on

; shows name & number on inbound call
display_method!: display_name_number

; resync settings daily, only on v7 firmware
;settings_refresh_timer$: 14400

; settings for easier transfers
; call_join needs to be off for receptionists though!!!
transfer_on_hangup!: on
call_join_xfer!: on

; turns off stupid flash plugin in web gui
with_flash$: off

; stops LED lighting for missed calls
message_led_other!: off
;flash on call waiting
call_waiting$: visual

; Voicemail
dkey_retrieve!: speed *50*

;Dont keep asking for a password
challenge_response$: off

;turn off the logon wizard
logon_wizard$: skip welcome

;set an http UID & password
http_user!: user
http_pass!: $puserpass

admin_mode_password!: $padminpass','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('snom.Fkey','Snom BLF template','system','fkey$seq$: $type $value
fkey_label$seq$: $label','BLF Template');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('snom.ipv4','snom ipv4 fragment','system','dhcp_v6$: off','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('snom.ipv6','snom ipv6 fragment','system','dhcp_v6$: autoconfiguration','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('snom.tcp','snom tcp fragment','system','user_outbound1$:$localip;transport=tcp
user_srtp1$: off
user_srtp2$: off
user_auth_tag1$: off
user_savp1$: off','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('snom.tls','snom tls fragment','system','user_outbound1$: $localip:$tlsport;transport=tls
user_srtp1$: on
user_auth_tag1$: off
user_savp1$: mandatory
','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('snom.v10_ldap','snom v10 ldap search filter','system','ldap_search_filter$: (|(cn=%*)(sn=%*)(o=%*)','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('snom.udp','snom udp fragment','system','user_outbound1$:
user_srtp1$: off
user_srtp2$: off
user_auth_tag1$: off
user_savp1$: off','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,device,legacy,owner,provision,technology) values ('y000000000000.cfg','Yealink T28 descriptor','y000000000000.cfg','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000004.cfg','Yealink T26 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000005.cfg','Yealink T22 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000007.cfg','Yealink T20 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000009.cfg','Yealink T18 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000023.cfg','Yealink VP530 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000025.cfg','Yealink W52P descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000028.cfg','Yealink T46 descriptor ','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000029.cfg','Yealink T42 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000031.cfg','Yealink T19 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000032.cfg','Yealink T32 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000034.cfg','Yealink T21 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000035.cfg','Yealink T48 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000036.cfg','Yealink T41 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000037.cfg','Yealink CP860 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000038.cfg','Yealink T38 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000044.cfg','Yealink T23 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000045.cfg','Yealink T27 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000046.cfg','Yealink T29 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000051.cfg','Yealink VP-T49 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000052.cfg','Yealink T21_E2 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000053.cfg','Yealink T19 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,legacy,owner,provision,technology) values ('y000000000054.cfg','Yealink T40 descriptor','1','system','#INCLUDE yealink.Common','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('yealink.Common','Yealink common Y file','system','#!version:1.0.0.1

##File header "#!version:1.0.0.1" can not be edited or deleted, and must be placed in the first line.##

# # phone browser access - change for your site
security.user_password = admin:$padminpass
security.user_password = user:$puserpass

features.direct_ip_call_enable = 0

# Auto provisioning
auto_provision.pnp_enable = 1
auto_provision.power_on = 1
auto_provision.repeat.enable = 1
auto_provision.repeat.minutes = 1440
auto_provision.server.url = http://$localip/provisioning

# set TLS initially off
account.1.outbound_port = 5060
account.1.transport = 0
account.1.srtp_encryption = 0
security.trust_certificates = 0

# Time Zone - set for your TZ
local_time.time_zone = 0
local_time.time_zone_name = United Kingdom(London) 
local_time.ntp_server1 = pool.ntp.org
local_time.ntp_server2 = $localip

features.pickup.direct_pickup_enable = 1
features.pickup.direct_pickup_code = *8

#######################################################################################
##         	              LDAP Settings                                              ##
#######################################################################################
#Configure the search criteria for name and number lookups.
ldap.name_filter = (|(cn=%)(sn=%)(o=%))
ldap.number_filter = (|(telephoneNumber=%)(mobile=%)(homePhone=%))

ldap.host = $ldaphost
ldap.port = 389

ldap.base = ou=$ldaptenant,ou=$ldapou,$ldapbase
ldap.user=$ldaprouser
ldap.password=$ldapropwd 

#Specify the maximum of the displayed search results. It ranges from 1 to 32000, the default value is 50.
ldap.max_hits = 50

ldap.name_attr = cn o
ldap.numb_attr =  mobile telephoneNumber homePhone
ldap.display_name = %cn,%o

#Configure the LDAP version. The valid value is 2 or 3 (default).
ldap.version = 

#Conifugre the search delay time. It ranges from 0 (default) to 2000.
ldap.search_delay = 

#Enable or disable the phone to query the contact name from the LDAP server when receiving an incoming call; 0-Disabled (default), 1-Enabled;
ldap.call_in_lookup = 1

#Enable or disable the phone to sort the search results in alphabetical order; 0-Disabled (default), 1-Enabled; 
ldap.ldap_sort =  1

#Enable or disable the phone to query the LDAP server when in the pre-dialing or the dialing state; 0-Disabled (default), 1-Enabled;
ldap.dial_lookup =  1

# TLS mode - 0 = LDAP;1 = LDAP TLS start (port 389);2 = LDAPs(port 686)
# LDAPS is likely the most secure due to startTLS being "TOFU"
ldap.tls_mode=0


#######################################################################################
##         	              Account Settings                                              ##
#######################################################################################
account.1.enable = 1
account.1.outbound_proxy_enable = 1
account.1.subscribe_register = 1
account.1.subscribe_mwi = 1
account.1.subscribe_mwi_to_vm = 1
account.1.sip_trust_ctrl = 1
voice_mail.number.1 = *50*

# Enable/Disable the codecs you want to use - default is law, G729, G722

account.1.codec.1.enable = 1
account.1.codec.1.payload_type = PCMU
account.1.codec.1.priority = 1
account.1.codec.1.rtpmap = 0

account.1.codec.2.enable = 1
account.1.codec.2.payload_type = PCMA
account.1.codec.2.priority = 2 
account.1.codec.2.rtpmap = 8

account.1.codec.3.enable = 0 
account.1.codec.3.payload_type = G723_53
account.1.codec.3.priority =0
account.1.codec.3.rtpmap = 4

account.1.codec.4.enable = 0
account.1.codec.4.payload_type = G723_63
account.1.codec.4.priority = 0
account.1.codec.4.rtpmap = 4

account.1.codec.5.enable = 1
account.1.codec.5.payload_type = G729
account.1.codec.5.priority = 3
account.1.codec.5.rtpmap = 18

account.1.codec.6.enable = 1
account.1.codec.6.payload_type = G722
account.1.codec.6.priority = 4
account.1.codec.6.rtpmap = 9

account.1.codec.7.enable = 0
account.1.codec.7.payload_type = iLBC
account.1.codec.7.priority =  0
account.1.codec.7.rtpmap = 102

account.1.codec.8.enable = 0
account.1.codec.8.payload_type = G726-16
account.1.codec.8.priority = 0
account.1.codec.8.rtpmap = 112

account.1.codec.9.enable = 0
account.1.codec.9.payload_type = G726-24
account.1.codec.9.priority = 0
account.1.codec.9.rtpmap = 102

account.1.codec.10.enable = 0
account.1.codec.10.payload_type = G726-32 
account.1.codec.10.priority = 0 
account.1.codec.10.rtpmap = 99

account.1.codec.11.enable = 0
account.1.codec.11.payload_type = G726-40
account.1.codec.11.priority = 0
account.1.codec.11.rtpmap = 104

account.1.codec.12.enable = 0
account.1.codec.12.payload_type = iLBC_13_3
account.1.codec.12.priority = 0 
account.1.codec.12.rtpmap = 97

account.1.codec.13.enable = 0
account.1.codec.13.payload_type = iLBC_15_2
account.1.codec.13.priority = 0 
account.1.codec.13.rtpmap = 97 ','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('yealink.Fkey','Yealink BLF Template','system','memorykey.$seq.line = 0 
memorykey.$seq.value = $value 
memorykey.$seq.pickup_value = *8
memorykey.$seq.type =  $type','BLF Template');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('yealink.Lkey','Yealink Line key template','system','linekey.$seq.line = 0 
linekey.$seq.value = $value 
linekey.$seq.pickup_value = *8
linekey.$seq.type =  $type
linekey.$seq.label =  $label','BLF Template');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('yealink.ipv4','yealink ipv4 fragment','system','static.network.ip_address_mode = 0
static.network.ipv6_internet_port.type = 0','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('yealink.ipv6','yealink ipv6 fragment','system','static.network.ip_address_mode = 2
static.network.ipv6_internet_port.type = 2','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('yealink.tcp','yealink tcp fragment','system','account.1.transport = 1
account.1.outbound_port = 5060
account.1.srtp_encryption = 0
security.trust_certificates = 0','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('yealink.tls','Yealink tls fragment','system','account.1.outbound_port = $tlsport
account.1.transport = 2
account.1.srtp_encryption = 2
security.trust_certificates = 0','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('yealink.udp','yealink udp fragment','system','account.1.transport = 0
account.1.outbound_port = 5060
account.1.srtp_encryption = 0
security.trust_certificates = 0','Descriptor');
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,sipiaxfriend,technology) values ('Fanvil','Fanvil SIP phone range','system','<<VOIP CONFIG FILE>>Version:2.0000000000                      

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
INSERT OR IGNORE INTO Device(pkey,description,owner,provision,technology) values ('fanvil.Common','Fanvil common file','cust','phone.date.SNTPEnabled = 1
phone.date.SNTPServer = pool.ntp.org
phone.date.SecondSNTPServer = 
phone.date.TimeZone = 0
phone.date.TimeZoneName = United Kingdom(London) 

call.port.1.AllowIPCall = 0

sip.line.1.PickupCode = *8
sip.line.1.MWICode = *50*

web.account.1.Name = admin
web.account.1.Password = $padminpass
web.account.1.Level = 10
web.account.2.Name = user
web.account.2.Password = $puserpass
web.account.2.Level = 5

','Descriptor');

COMMIT;
