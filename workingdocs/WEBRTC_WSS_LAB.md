# WebRTC lab notes — golden `:8089` baseline (2026-07-28)

**Status:** Golden `:8089` **REGISTER + bidirectional audio OK** (2026-07-28). Recovery tag **`pre-webrtc-wss-20260728`**. Magrathea VIP **not** touched.

## Done

1. **Docs priority** — WebRTC/WSS #1 in **`SBC_PRODUCT_TRACKS.md`**, **`TODO.md`**, §6.1 active note in **`FLEET_TRUNK_PEERING_DECISION.md`**.
2. **Golden HTTPS/WSS listen** — Asterisk had `tlsenable` + LE paths in `http.conf` but **could not read** LE privkey (`live/`/`archive/` mode `700`, key `600` root). Fixed: `ssl-cert` group + `750`/`640`. **HTTPS now bound on `0.0.0.0:8089`**.
3. **Certbot deploy hook** on golden: `/etc/letsencrypt/renewal-hooks/deploy/asterisk-ssl-cert-perms.sh` so renewals keep Asterisk-readable perms.
4. **WebRTC extension** — dialable **`1500`** / SIP user + endpoint **`8af9ee`** (shortuid) / tenant **`dhbm8x`**. **2026-07-28:** fixed `pjsip_webrtc.tmpl` to use `$id` (same pattern as phones); was wrongly `$ext` so endpoint was `1500` and admin hint `PJSIP/8af9ee` never lit. Also `/etc/asterisk/pjsip_ready_webrtc.conf` was a stale file — now symlink to GenAst output like phones/trunks. Creds: golden **`~/webrtc-1500.env`** (`sip_user=8af9ee`).
5. **Shorewall** — `pbx3_rules` lacked **tcp 8089**; added `ACCEPT net $FW tcp 8089` (WebRTC WSS) and `shorewall restart`. Live `net-fw` multiport now `80,44300,8089,22`. RTP `10000:20000` was already open. Product template updated.
6. **REGISTER smoke (2026-07-28):** JsSIP on-box → **`SMOKE_OK registered sip:1500@dhbm8x.pbx3.com`**. Note: on-box must use **loopback** `wss://127.0.0.1:8089/ws` (public EIP hairpin from the instance itself fails). External clients use `wss://08jzwn.pbx3.com:8089/ws`.
7. **Webphone audio smoke (2026-07-28):** Browser JsSIP (Chromium) via `wss://08jzwn.pbx3.com:8089/ws` → dial lab Echo **1599@dhbm8x** (runtime dialplan; removed after). **ICE connected**; browser `getStats` ~60KB in/out; Asterisk `pjsip show channelstats` **279/279** ulaw packets, 0 loss. RTP bypass OK — **no rtpengine**. Magrathea UDP untouched.
8. **Third-party SPA REGISTER (2026-07-28):** Test-mule webphone **REGISTER OK** as SIP user **`8af9ee`** (hostname-only WSS field). Admin hint **Idle**. **Outbound keypad dial still sends no INVITE** (operator comparing to SARK 6.5). Not a golden audio gate.

## Operator smoke (browser / product webphone)

```text
WSS:     wss://08jzwn.pbx3.com:8089/ws
SIP user: 8af9ee          (shortuid — NOT extension 1500)
Domain:   dhbm8x.pbx3.com
Pass:     see ~/webrtc-1500.env on golden (or scp)
```

Webphone server field: hostname only `08jzwn.pbx3.com` (no `wss://` prefix if the UI adds it), port `8089`, path `/ws`.

`scp -i ~/Documents/pemfiles/pbx3test.pem ubuntu@08jzwn.pbx3.com:~/webrtc-1500.env /tmp/`

Confirm Shorewall allows **tcp 8089** (`pbx3_rules`) and AWS SG allows **8089/tcp** (+ RTP **udp 10000–20000**) from your client IP. Desk UDP path unchanged.

## Next (non-disruptive) — **stay on golden**

**Locked:** Demo / near-term work continues on **golden `:8089`**. That does **not** disrupt Magrathea UDP desk/Peer SIP. Scratch SBC / Magrathea WSS cutover are **later** (fleet VIP story).

1. Third-party SPA outbound INVITE (operator digging vs SARK 6.5) — or product/controlled webphone dial.  
2. Clamp SG **8089/tcp** world-open when SPA host test done.  
3. **Later:** OpenSIPS W1 on scratch or Magrathea dedicated port (`webrtc-wss` branch scaffold) when booking VIP edge for webphones.

## Notes

- `http show status` → `/ws` enabled; curl `/httpstatus` may 403 — fine if TLS handshake works.
- RTP bypass proven on golden; rtpengine not needed for this path.
- WebRTC PJSIP object id = shortuid; dialable pkey only in dialplan/callerid (PBX3 phone pattern).
