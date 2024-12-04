#Keypad Operations
 
##Transfers
| Key Sequence |  data    |  function     |  Availability  |  Comment     |
|--------------|----------|---------------|----------------|--------------|
|\#|NULL|BLIND XFER||In-line xfer|
|\*2#|*{extension}*}|ATT XFER||inline Attended xfer|
|XFER-\>\*5|NULL|Park||Park a call into the parking lot|
|\*8|NULL|Pickup||Pickup call|
|\*8|*call group*}|Pickup||Pickup call from a specific call group|
|Hold|none|Hold|Endpoints with hold feature|Place call on hold call and play MOH|
|XFER|none|XFER|Endpoints with XFER feature|Place call on hold call and play MOH|
|Message Light/Mail Icon|none|Pick up voicemail|All VoIP endpoints with MWI feature|Connect to Voicemail|
|_70X|none|Parked call pickup|internal||
|\* |*{extension}*|dial or transfer to an extension's Voicemail|internal|Useful to transfer a call directly to an extension's voicemail box|
|\*\*|*{extension}*|dial or transfer to an extension's mini-queue|internal|*Camp-on miniqueue* feature; needs to be turned on for the tenant|

##DND and Diverts
| Key Sequence |  data    |  function     |  Availability  |  Comment     |
|--------------|----------|---------------|----------------|--------------|
|\*18\*| none | DND Activation | internal | Deflect all direct calls to voicemail | 
|\*19\*| none | DND Deactivation | internal | | 
|\*20\*| none | DND Toggle | internal | Flip from OFF to ON or ON to OFF |
|\*21\*|none or *extension*|Call Forward Immediate (CFIM)|internal|Use with no extension to turn off|
|\*22\*|none or *extension*|Call Forward Busy (CFBS)|internal|Use with no extension to turn off|
|\*23\*|none|Clear ALL callforwards|internal||
|\*27\*|*extension*|Follow Me|internal|Direct a remote extension's calls to the local station - requests your vmail passwd|

##Timers
| Key Sequence |  data    |  function     |  Availability  |  Comment     |
|--------------|----------|---------------|----------------|--------------|
|\*30\*| none | Set Timers to Automatic (default) | internal | | 
|\*31\*| none | Set Timers to CLOSED  | internal | | 
|\*31\*| none | Set Timers to OPEN  | internal | |


##Voicemail
| Key Sequence |  data    |  function     |  Availability  |  Comment     |
|--------------|----------|---------------|----------------|--------------|
|\*50\*| none | Retrieve Voicemail for the current extension | internal | The attedant will ask for the vmail password| 
|\*51\*| none | Retrieve Voicemail for the another extension  | internal | The attedant will ask for the extension number and its vmail password | 

##Miscellaneous
| Key Sequence |  data    |  function     |  Availability  |  Comment     |
|--------------|----------|---------------|----------------|--------------|
|\*26\*| 99 | Set ringtime before failing to vmail | internal | if no ring delay is specified the ring will never timeout | 
|\*52\*| none | echo test | internal | Used to test audio quality | 
|\*55\*| none | Time and Date | internal | | 
|\*56\*| none | Speak the extension number | internal | |


##System Greetings
| Key Sequence |  data    |  function     |  Availability  |  Comment     |
|--------------|----------|---------------|----------------|--------------|
|\*60\*| 9999 | Record a new system greeting | internal | greetings MUST be 4 digits long | 
|\*61\*| 9999 | Listen to a greeting | internal | |


##ACD - Agents, Queues and supervision
| Key Sequence |  data    |  function     |  Availability  |  Comment     |
|--------------|----------|---------------|----------------|--------------|
|\*63\*| *Agent ID* | Pause Agent | internal | Agent will be given no new calls while paused|
|\*64\*| *Agent ID* | Resume Agent | internal | Agent will resume receiving calls|
|\*65\*| *Agent ID* | Agent Login | internal | Agent will begin receiving calls after login|
|\*66\*| *Agent ID* | Agent Logout | internal | Agent will cease receiving calls after logout|
|\*67\*| *extension* | ChanSpy(Whisper) | internal | Supervisor coaching |
|\*68\*| *extension* | ChanSpy | internal | Supervisor coaching |

##NANP Vertical Service Code Compatibility 
| Key Sequence |  data    |  function     |  Availability  |  Comment     |
|--------------|----------|---------------|----------------|--------------|
|\*60| none | Time and Date | internal | |
|\*65| none | Speak the extension number | internal | |
|\*72|*extension*|Call Forward Immediate|internal||
|\*73|none|Cancel Call Forward Immediate|internal|
|\*77|*nnnn*|4-digit greeting number|Record a system greeting|internal|
|\*78|none|Do Not Disturb|internal|
|\*79|none|Cancel Do Not Disturb|internal|
|\*90|(*extension*)|Call Forward Busy|internal||
|\*91|none|Cancel Call Forward Busy|internal|
|\*97|Local Voicemail|internal|connect to voicemail from own station|
|\*98|*extension*|Remote Voicemail|internal/external|Connect to voicemail from another station|
