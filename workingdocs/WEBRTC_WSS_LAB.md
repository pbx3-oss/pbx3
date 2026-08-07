# WebRTC lab notes — golden `:8089` baseline (2026-07-28)

**Status:** Golden `:8089` singleton-direct path (historical baseline).  
**2026-08-03 W1:** Magrathea edge path **lab green** — desk↔webphone both ways; **home instance TCP 8089 may be closed** (proven on golden). WSS terminates only on SBC; edge→home is ordinary SIP. Checklist **`pbx3sbc/workingdocs/WEBRTC_W1_MAGRATHEA.md`**.  
**2026-08-03 (earlier):** After Mode 4 rebuild, TLS bind fix via **`apply-active-cert.sh`** (ssl-cert ACLs + Asterisk restart).

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

## Fleet edge W1 (preferred multi-tenant) — architecture

**Lab green 2026-08-03** including **home instance TCP 8089 closed** (AWS SG): Magrathea-path calls still work.

### The cool part: WSS only at the edge

OpenSIPS is a **proxy-registrar**, not a WSS tunnel to Asterisk:

```text
Browser  ── SIP over WSS (TLS :8089/ws) ──►  Magrathea (sbc.pbx3.com)
                                                    │
                                                    │ ordinary SIP UDP :5060
                                                    ▼
                                           Home instance (PJSIP)
Browser  ◄══ media ICE/DTLS-SRTP ══════════════════╝   (RTP bypass — not via SBC)
Desk UA  ◄══ RTP ══════════════════════════════════╝
```

| Hop | Protocol | Who opens **8089**? |
|-----|----------|---------------------|
| Client → edge | SIP over **WSS** | **SBC only** (`wss://sbc.pbx3.com:8089/ws`) |
| Edge → home | Classic **SIP UDP** (same family as desk phones) | **Not needed** on the instance for this path |
| Media | ICE / DTLS-SRTP or RTP | Home public RTP range (and existing rules) |

So fleet homes are **not** “WSS extensions” for edge browsers. Home PJSIP WebRTC endpoints use:

- **`transport-udp`** + fleet **`outbound_proxy=sip:sbc.pbx3.com;lr`** (desk-like signaling)
- **`webrtc=yes`** still — browser **media** (ICE/DTLS), not “listen for WSS on :8089”
- PrepDial fleet: `PJSIP/shortuid/sip:shortuid@tenant.fqdn` so dial hits SBC **usrloc** (not SIP.js dummy `192.0.2.x` Contact)

**Side benefit (product):** one WSS edge / cert / port for all tenants; instances speak boring SIP; Track‑A / last-gen homes that already do SIP can share the same edge story without opening instance WSS to the world. **Close instance TCP 8089** for fleet Magrathea path — open it only for intentional **singleton-direct** lab (`wss://instance-fqdn:8089`).

### Client settings

```text
WSS:     wss://sbc.pbx3.com:8089/ws
SIP user: 8af9ee
Domain:   dhbm8x.pbx3.com
Pass:     ~/webrtc-1500.env on golden
```

## Next (non-disruptive)

1. **SPA WSS line test** (planned) — prefer WSS host = edge + SIP domain = tenant; see **FEATURE_PLANS_INDEX** + **TODO**.  
2. **Cross-AZ fleet lab** before treating multi-AZ media as proven.  
3. Package rolls: ensure **pbx3** webrtc tmpl + **pbx3cagi 1.0.0-10** land on nodes beyond golden hot-fix (branches already **merged to main**).

## SIP domain vs next hop (DNS) — product stance (2026-08-03; fleet lock 2026-08-06)

Do **not** assume every tenant FQDN is in public DNS. **SBC fleet lock:** **`TLS_AND_CERTIFICATES.md` §0** — no tenant A records; node LE = instance only; WSS host ≠ tenant FQDN.

Fleet desk path already works without tenant DNS:

| Concept | Role |
|---------|------|
| **SIP domain / registrar name** (e.g. `dhbm8x.pbx3.com` or tenant shortuid host form) | Identity on the wire. SBC **`domain`** table → setid → dispatcher. **No public A record required** for translate. |
| **Next hop** (SBC VIP FQDN or IP) | Where the phone **sends** REGISTER / INVITE. Only this must resolve/route for UDP softpath. |

Desk phones normally take both notions (or proxy + domain). Many **webphones have no outbound-proxy field** and collapse “server / WSS host / domain” into one box.

**Implications for W1 (WSS on SBC):**

1. **Preferred multi-tenant edge:** WSS connects to a **shared edge name** (SBC VIP/cert you already serve); SIP **domain / From-URI host** remains the **tenant** string the SBC looks up. That needs a client (or own SPA **line test**) that keeps **WSS host ≠ SIP domain**. Product SPA should plan for two values.
2. **Collapsed-host clients only:** if one field must be both transport host and SIP domain, operators may put **tenant FQDN → edge** in public DNS + LE for that name. Acceptable product trade when needed — **not** “already public because fleet works.” Tenant DNS is optional today by design.
3. **Lab / line test** may stay **singleton-direct** `wss://instance-fqdn:8089` (current golden). That proves PBX WebRTC, not multi-tenant proxy-registrar.
4. **Do not** invent public tenant DNS solely to “match” desk phones — desks never required that.

See also **`FLEET_TRUNK_PEERING_DECISION.md`** §6.1 (WSS path) and desk proxy-registrar notes in **`SBC_PRODUCT_TRACKS.md`**. **Magrathea enable checklist:** **`pbx3sbc/workingdocs/WEBRTC_W1_MAGRATHEA.md`**.

## Notes

- `http show status` → `/ws` enabled; curl `/httpstatus` may 403 — fine if TLS handshake works.
- RTP bypass proven on golden; rtpengine not needed for this path.
- WebRTC PJSIP object id = shortuid; dialable pkey only in dialplan/callerid (PBX3 phone pattern).
