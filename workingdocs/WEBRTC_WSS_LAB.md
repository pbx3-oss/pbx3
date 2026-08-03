# WebRTC lab notes — golden `:8089` baseline (2026-07-28)

**Status:** Golden `:8089` **REGISTER + bidirectional audio OK** (2026-07-28). Recovery **`pre-webrtc-wss-20260728`**. Magrathea VIP **not** touched.  
**2026-08-03:** After Mode 4 rebuild, TLS again failed to bind (unreadable keys / snakeoil) → only **:8088**. Fixed ops + **source:** **`apply-active-cert.sh`** now sets **ssl-cert** ACLs on LE material and **restarts Asterisk** so WSS survives renew/rebuild.

## Done

1. **Docs priority** — WebRTC/WSS #1 in **`SBC_PRODUCT_TRACKS.md`**, **`TODO.md`**, §6.1 active note in **`FLEET_TRUNK_PEERING_DECISION.md`**.
2. **Golden HTTPS/WSS listen** — LE privkey mode `700`/`600` root → Asterisk cannot open key → TLS bind fails. **Product fix:** **`apply-active-cert.sh`** (ssl-cert group ACLs + Asterisk restart). Lab also used `ssl-cert` + LE paths in **`http.conf`**.
3. **Renewal** — certbot deploy hook already invokes **`apply-active-cert.sh`** (`le-renew-with-80.sh`); no separate golden-only hook required once the package script is deployed.
4. **WebRTC extension** — dialable **`1500`** / SIP user + endpoint **`8af9ee`** (shortuid) / tenant **`dhbm8x`**. Admin SPA shows extension **1500** (label/desc), not the SIP shortuid. **`pjsip_webrtc.tmpl`** uses **`$id`/shortuid**. Creds: golden **`~/webrtc-1500.env`**.
5. **Shorewall** — `ACCEPT net $FW tcp 8089` (WebRTC WSS). **`ACCEPT net $FW udp 10000:20000`** (RTP — must be **net**, not **`$LAN` only**; fleet/cloud phones + browsers hit public EIP; LAN-only caused silent Snom/Yealink/WebRTC).
6. **REGISTER smoke (2026-07-28):** JsSIP → **`SMOKE_OK`**. On-box use **loopback** `wss://127.0.0.1:8089/ws`; external clients `wss://08jzwn.pbx3.com:8089/ws`.
7. **Webphone audio smoke (2026-07-28):** Browser JsSIP → Echo; ICE + RTP bypass OK — **no rtpengine**.
8. **Third-party SPA REGISTER (2026-07-28):** REGISTER as **`8af9ee`** OK; outbound dial issues on that SPA were client-side.
9. **Browser-Phone (InnovateAsterisk, local)** — good lab client (SIP.js); SIP user = shortuid, domain = tenant FQDN.

## Operator smoke (browser / product webphone)

```text
WSS:     wss://08jzwn.pbx3.com:8089/ws
SIP user: 8af9ee          (shortuid — NOT extension 1500)
Domain:   dhbm8x.pbx3.com
Pass:     see ~/webrtc-1500.env on golden (or scp)
```

Webphone server field: hostname only `08jzwn.pbx3.com` (no `wss://` prefix if the UI adds it), port `8089`, path `/ws`.

If “Connecting…” forever: on node check `sudo asterisk -rx "http show status"` must show **HTTPS … 8089**. If only 8088: run **`sudo /opt/pbx3/scripts/apply-active-cert.sh`** (after LE and `le-domain` exist).

If auth works but register fails with **403 / max contacts**: stale WSS Contact under AOR **`max_contacts=1`**. New browser ports look like a second contact. Product AOR uses **`remove_existing=yes`** (`pjsip_webrtc.tmpl`). Lab clear: `sudo asterisk -rx "database deltree registrar/contact"` then re-register (or reload after template fix).

## Inbound to webphone (Snom → 1500)

**Fixed 2026-08-03 (lab + source):** WSS server→client INVITE was ignored until Contact/SDP hosts were public:

| Broken | Working |
|--------|---------|
| `Contact: <sip:asterisk@08jzwn:5060;transport=ws>` | `Contact: <sip:asterisk@08jzwn.pbx3.com;transport=ws>` |
| SDP `c=` private `172.31…` | `media_address` = public EIP (`$externip`) |
| `from_domain` missing / short host | `from_domain` = LE FQDN (`$fqdn` from `identity/le-domain`) |

With those + `direct_media=no` / `100rel=no` / `timers=no` / `remove_existing=yes`, golden log: **100 Trying → 180 Ringing → 200 OK** on WSS, ACK, full client SDP (ICE to public srflx).

**Still fails if:** two WSS tabs share one AOR (`max_contacts=1`) — Contact port ≠ dialing socket → INVITE black-hole. Close extras; `database deltree registrar/contact`; one re-REGISTER; one `ss` line on `:8089`.

Confirm Shorewall **tcp 8089** + **udp 10000–20000** on **net** (not LAN-only) and AWS SG same.

**Post-answer audio delay (2026-08-03):** ICE advertised VPC **host** `172.31…` ahead of public **srflx** → browser spun dead candidates. Fix: **`[ice_host_candidates]`** private⇒EIP in **`rtp.conf`**, no multi-`stunaddr` (Asterisk sample). Maintained by **`refresh-pjsip-externip.sh`**. After change: re-REGISTER, answer a call; SDP host candidate should be the EIP only.

## Next (non-disruptive) — **stay on golden**

1. Product/controlled webphone dial; far-end SPA sanitize follow-ups.  
2. Clamp SG **8089/tcp** world-open when host tests done.  
3. **Cross-AZ fleet lab (required before “real” multi-AZ):** same-AZ hides ICE/NAT/host-identity and inter-node path assumptions. Stand instances (or at least phone↔node / node↔SBC legs) in **two AZs** and re-smoke REGISTER, desk phone RTP, singleton-direct WSS, and SBC path when ready.  
4. **Later:** OpenSIPS W1 on scratch or Magrathea.

## Notes

- `http show status` → `/ws` enabled; curl `/httpstatus` may 403 — fine if TLS handshake works.
- RTP bypass proven on golden; rtpengine not needed for this path.
- WebRTC PJSIP object id = shortuid; dialable pkey only in dialplan/callerid (PBX3 phone pattern).
