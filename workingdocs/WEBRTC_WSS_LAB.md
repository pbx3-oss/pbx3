# WebRTC lab notes — golden `:8089` baseline (2026-07-28)

**Status:** In progress. Recovery tag **`pre-webrtc-wss-20260728`**. Magrathea VIP **not** touched.

## Done

1. **Docs priority** — WebRTC/WSS #1 in **`SBC_PRODUCT_TRACKS.md`**, **`TODO.md`**, §6.1 active note in **`FLEET_TRUNK_PEERING_DECISION.md`**.
2. **Golden HTTPS/WSS listen** — Asterisk had `tlsenable` + LE paths in `http.conf` but **could not read** LE privkey (`live/`/`archive/` mode `700`, key `600` root). Fixed: `ssl-cert` group + `750`/`640`. **HTTPS now bound on `0.0.0.0:8089`**.
3. **Certbot deploy hook** on golden: `/etc/letsencrypt/renewal-hooks/deploy/asterisk-ssl-cert-perms.sh` so renewals keep Asterisk-readable perms.
4. **WebRTC extension** — `1500` / tenant **`dhbm8x`** (`dhbm8x.pbx3.com`), device WebRTC, transport wss. genAst OK; `pjsip show endpoint 1500` → transport-wss. Creds file on golden: **`/home/ubuntu/webrtc-1500.env`** (mode 600; not committed).
5. **Shorewall** — `pbx3_rules` lacked **tcp 8089**; added `ACCEPT net $FW tcp 8089` (WebRTC WSS) and `shorewall restart`. Live `net-fw` multiport now `80,44300,8089,22`. RTP `10000:20000` was already open. Product template updated.
6. **REGISTER smoke (2026-07-28):** JsSIP on-box → **`SMOKE_OK registered sip:1500@dhbm8x.pbx3.com`**. Note: on-box must use **loopback** `wss://127.0.0.1:8089/ws` (public EIP hairpin from the instance itself fails). External clients use `wss://08jzwn.pbx3.com:8089/ws`.

## Operator smoke (browser / SIPp WebRTC client)

```text
WSS:   wss://08jzwn.pbx3.com:8089/ws
User:  1500
Auth:  see ~/webrtc-1500.env on golden (or scp)
Realm / domain: dhbm8x.pbx3.com (or as webphone expects)
```

`scp -i ~/Documents/pemfiles/pbx3test.pem ubuntu@08jzwn.pbx3.com:~/webrtc-1500.env /tmp/`

Confirm Shorewall allows **tcp 8089** (`pbx3_rules`) and AWS SG allows **8089/tcp** from your client IP. Desk UDP path unchanged. RTP `10000:20000` already open on golden `net-fw`.

## Next (non-disruptive) — **stay on golden**

**Locked:** Demo / near-term work continues on **golden `:8089`**. That does **not** disrupt Magrathea UDP desk/Peer SIP. Scratch SBC / Magrathea WSS cutover are **later** (fleet VIP story), not a gate for webphone audio.

1. **Webphone audio smoke** against `wss://08jzwn.pbx3.com:8089/ws` (ext **1500** / `~/webrtc-1500.env` on golden). REGISTER already proven via JsSIP.  
2. Optional polish: SPA create path for WebRTC ext; Shorewall 8089 in product template (done).  
3. **Later:** OpenSIPS W1 on scratch or Magrathea dedicated port (`webrtc-wss` branch scaffold) when booking VIP edge for webphones.

## Notes

- `http show status` → `/ws` enabled; curl `/httpstatus` may 403 — fine if TLS handshake works.
- tmpl callerid still has a curly-quote quirk in ready conf — cosmetic until next GenAst tmpl tidy.
- RTP bypass remains the plan; rtpengine only if audio fails.
