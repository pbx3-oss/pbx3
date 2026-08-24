-- PJSIP overlay help (extension / trunk admin). Safe on live + new.
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
UPDATE tt_help_core SET displayname='PJSIP overlay', htext='Admin-only thin fragment merged into the stock phone/WebRTC (or trunk) PJSIP template on **Commit**. Each block targets a PJSIP object by **`type=`** — **endpoint**, **auth**, or **aor** (not just the endpoint). GenAst **replaces or adds** keys on that object. Leave empty for the stock template. Prefer first-class SPA fields (e.g. Named call/pickup groups) when they exist.

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

Takes effect on **Commit**. Stock defaults live in the package templates; generated output is in `pjsip_ready_phones.conf` / `pjsip_ready_webrtc.conf` on the node.' WHERE pkey='pjsip_overlay';
