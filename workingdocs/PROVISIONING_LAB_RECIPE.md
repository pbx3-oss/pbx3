# Phone provision — lab recipe (A6 + C edge)

**Law:** `PROVISIONING_SERVER_REQUIREMENTS.md` · plan `PROVISIONING_IMPLEMENTATION_PLAN.md`.  
**Edge ops:** `pbx3sbc/workingdocs/PROVISION_EDGE_PROXY.md`.

Automated coverage: `php /opt/pbx3/scripts/tests/provision-kernel-test.php` (and package-tree equivalent). This recipe is **handset / curl soak**.

---

## 0. Pre-flight (home)

1. Packages/tip include provision kernel + streams + `install-provision-listener.sh`.
2. Schema: `sudo /opt/pbx3/scripts/apply-sqlite-add-provision-columns.sh`
3. Listener + firewall:
   - After nginx/php-fpm: `sudo /opt/pbx3/scripts/install-provision-listener.sh solo` **or** `fleet`
   - UFW: new installs get `:41363` in baseline. Fleet: **SBC IP(s) only**. Mirror in AWS SG if used.
4. Solo HTTPS needs `apply-active-cert.sh` (snippet `pbx3-ssl-active.conf`).

**Solo URL:** `https://{instance-fqdn}:41363/provisioning/{mac}.cfg`  
**Fleet phone-facing:** `https://provision.{apex}:41363/provisioning/{mac}.cfg` (edge) → HTTP home.

### Manual URL (non-Snom/Yealink lab)

For brands without near-term mTLS/RPS (e.g. Grandstream, Gigaset, Fanvil soak): enter the fleet or solo provision URL **on the phone UI** (same paths as above). Enough to exercise stream/REGISTER; does **not** prove RPS or vendor client-cert. **Fanvil:** **`FANVIL_PROVISION_SUBPROJECT.md`**. **Grandstream:** **`GRANDSTREAM_PROVISION_SUBPROJECT.md`**.

### C5 mTLS tip (Snom + Yealink)

On SBC (after ops builds Snom+Yealink PEM — see `pbx3sbc` **`PROVISION_EDGE_PROXY.md`** § C5):

```bash
sudo VENDOR_CLIENT_CA_BUNDLE=/path/to/vendor-client-cas-snom-yealink.pem \
     PROVISION_MTLS=optional \
     PROVISION_FQDN=provision.pbx3.com \
     ./scripts/install-provision-edge.sh
```

`optional` keeps curl + manual-URL brands working. Prove Snom/Yealink phone GET still **200** with vendor client cert presented.

### Operator allow (lab eyeball — keep temporary)

Fleet baseline is **SBC-only** on home `:41363`. Temporary laptop allow: UFW/SG from your IP; **remove when done**.

---

## 1. Extension row

| Field | Value |
|-------|--------|
| `macaddr` | Phone MAC |
| `provision` | Prefer `#INCLUDE yealink.Extension` / `snom.Extension` (+ transport). **SIP host = tenant FQDN** (`$sipdomain`); **outbound proxy = SBC** (`$outbound`) when fleet. |
| `sndcreds` | `Once` (preferred) |
| `passwd` | Known SIP secret |

Commit/PJSIP as usual — provision GET does **not** require Commit.

---

## 2. Curl prove — home (Phase A)

```bash
MAC=aabbccddeeff
FQDN=xxxxxxxx.pbx3.com
curl -sk "https://${FQDN}:41363/provisioning/${MAC}.cfg" | head   # solo
curl -s "http://${FQDN}:41363/provisioning/${MAC}.cfg" | head    # fleet home (SBC or temp allow)
```

Expect: substituted body; Once → No after first send; audit obfuscated.

---

## 3. Fleet edge (Phase C) — lab 2026-09-30 green

**DNS:** `provision.pbx3.com` A → edge VIP (`3.93.26.82`). **LE** on SBC for that name.  
**Gatekeeper:** claim MAC → tenant + instance; conflict **409**; map at `catalog/provision-mac.map` (S3).  
**SBC:** `install-provision-edge.sh` + **`pbx3-provision-mac-map-sync.timer`** (every **1 min** pulls S3 → nginx). Manual force: `sync-provision-mac-map.sh`. Tip-hot push on claim = later polish (not required when the timer runs).

```bash
# known MAC → 200; unknown / y000000 → 404
# After SPA Save, allow up to ~1 min for the edge map timer before expecting 200
curl -sS -o /dev/null -w '%{http_code}\n' \
  "https://provision.pbx3.com:41363/provisioning/${MAC}.cfg"
```

Body must show **`sip_server_host` = tenant FQDN** (e.g. `{shortuid}.pbx3.com`) and **`outbound_host` = `sbc.pbx3.com`** with **outbound proxy enabled** — not SBC in the SIP-server field, not `127.0.0.1` / proxy off.

**Handset:** RPS or manual URL → `https://provision.pbx3.com:41363/provisioning/{mac}.cfg` (Yealink) or `…/provisioning?mac={mac}` (Snom). Both forms route on the edge when the MAC is in the map.

**Normal path:** SPA Save (claim) → wait ≤1 min → curl/phone GET. No Instance→SBC logout hop.

---

## 4. Exit checks

### A6
- [x] Known MAC → 200; unknown → 404  
- [x] Once flip + audit  
- [x] A7 suite  
- [x] Reset Once (SPA)  

### C lab
- [x] Edge LE URL → home via MAC map  
- [x] #11 no-MAC / y000000 → 404  
- [x] Yealink handset provision + SIP via SBC — lab: **T46U** fw **108.86.0.90** (Yealink 1); **T31P** fw **124.86.0.40** (Yealink 2)  
- [x] Snom handset provision + SIP via SBC — lab: **D717** fw **snomD717-SIP 10.1.198.19** (401)  
- [ ] C7/C8 automated exit  
- [ ] Tenant move → next provision without RPS edit  

**Next:** merge C2/C3 PRs · **B2** MkDocs RPS · api MAC claim tip on homes.

---

## 5. Fanvil mule soak (D3 start)

**Sub-project:** **`FANVIL_PROVISION_SUBPROJECT.md`**. **Lab mule:** **X3U Pro** · software **2.12.20** (Sirius 412). **Goal:** prove module-XML stream → edge GET → REGISTER/calls via SBC (same bar as Yealink/Snom). **Not** FDPS/RPS enrollment yet.

### Prep (before phone arrives)

1. Tip `fanvil.*` streams onto the home that will host the mule (likely **bzy** / tenant hosting Aelintra or a spare).
2. Create or pick a spare extension on that tenant.
3. Set `provision` to:

```text
#INCLUDE fanvil.Extension
#INCLUDE fanvil.udp
```

4. Leave `macaddr` blank until you have the MAC; `sndcreds` = **Once**; known SIP `passwd`.
5. Curl-prove with a **fake** MAC after writing the MAC on the row (or temp-claim):

```bash
MAC=001565aabbcc   # replace with real Fanvil MAC (12 hex, no colons)
curl -sS "https://provision.pbx3.com:41363/provisioning/${MAC}.cfg" | head -40
```

Expect XML with `<Register_Addr>` = tenant FQDN and `<Proxy_Addr>` = SBC (`sbc.pbx3.com`), not home IP.

### When the mule lands

1. Note MAC (strip colons) → SPA extension **MAC** + **device** label `Fanvil` if you use harvest.
2. Gatekeeper claim / map sync if fleet (same as Yealink).
3. Phone UI → **System / Auto Provision → Static Provisioning Server**:
   - Server: `https://provision.pbx3.com:41363/provisioning`  
     (or full `…/provisioning/{mac}.cfg` if the UI wants a file name)
   - Protocol: **HTTPS**
   - Update mode: **After reboot** (or equivalent)
4. Reboot. Edge log: GET **200**; home audit Once→No.
5. **Manual SIP account (if not provisioned yet):** UI labels **SIP User** + **Authentication User** both = shortuid (`$sipuser`); **Display Name** = dialable ext (`412`); **Server Address** = tenant FQDN; **Proxy Server Address** = SBC; leave **Proxy User** / Realm / Server Name empty. Field map: **`FANVIL_PROVISION_SUBPROJECT.md` §0.1**.
6. **Timezone:** OOTB is **Beijing** even with SNTP ON — set site zone (Sirius lab: **UTC-5**). Streams ship UK. Details: sub-project **§0.2**.
7. SPA/Asterisk: REGISTER; dial in-tenant + hangup (NAT/BYE — fill **`FLEET_DESK_PHONE_NAT.md`** Fanvil row).

### Exit checks

- [x] Curl/handset body is **`sysConf`** (X3U Pro 2.12 — not legacy `VOIP_CONFIG_FILE`)
- [x] Handset provision GET **200** → REGISTER (**2026-10-03**, Sirius 412 / `0c383e7151ef`; edge mTLS temporarily **off** pending Fanvil Root CA tip)
- [x] Manual SIP REGISTER + calls OK with **STUN Off** (default) — NAT row filled
- [x] Timezone: OOTB Beijing → set site zone (lab UTC-5); streams have UK
- [x] `FlashProtocol` **5** = HTTPS (sysConf)
- [ ] Restore Magrathea `ssl_verify_client optional` + tip Fanvil CA from ops `3pcerts.pem`
- [ ] (Later) FDPS / FDMCS enroll — out of scope for first mule

**Tune on failure:** empty body / phone ignores XML → compare against that model’s Autoprovision guide; STUN/`NAT_Type` (manual soak OK with STUN Off); timezone (Beijing OOTB ≠ SNTP); HTTPS protocol enum.

---

## 6. Grandstream mule soak (D3)

**Sub-project:** **`GRANDSTREAM_PROVISION_SUBPROJECT.md`**. **Lab mule:** **GRP2602P** · firmware **1.0.7.3** (Sirius 408). **GDMS is free** — sites may provision entirely in GDMS and never hit our listener (§0.2 vendor-cloud-only OK). Our `grandstream.*` streams are optional (when home-rendered CFG wanted).

**Manual SIP REGISTER green (2026-10-03, Sirius 408 / `74y2h3`):** Account Name=`408`, SIP Server=`$sipdomain`, Outbound Proxy=`$outbound`, SIP User ID=`$sipuser`, password=`$password`. No Fanvil dual-user quirk. Field table: sub-project **§0.2**.

**Dial plan (feature codes):** stock patterns reject `*56*` / `*21*`-shaped codes — add one line `*xx*`. Details: sub-project **§0.3**. Fanvil needs no change.

Stock streams still optional — author when firmware template known **and** posture (2) is chosen.

**OEM:** [SIP Device Provisioning Guide](https://www.grandstream.com/hubfs/Product_Documentation/gs_provisioning_guide.pdf) · P-value templates at [support/tools](https://www.grandstream.com/support/tools).

**Shape:** `<gs_provision>` / `<Pnnn>` XML; phone often requests **`cfg{mac}.xml`** (path may differ from Yealink `{mac}.cfg` — settle on first soak). Lab = Config Server Path → our provision HTTPS. **GDMS/GAPS** later.

### Resume (streams / NAT)

1. ~~Streams + tip~~ — `grandstream.*` on Sirius; **408** `#INCLUDE` + MAC claimed; **`P237`** Config path (not **P192** firmware).
2. ~~Factory / Config Server Path~~ → GET **200**; **`P52=4` Auto** → far BYE green (**2026-10-03**).
3. Edge needs GS client CAs in `vendor-client-cas.pem` (mTLS).

### Exit checks

- [x] Manual SIP REGISTER via SBC (Sirius)
- [x] Call / BYE + NAT Traversal **Auto** (default) — NAT row filled
- [x] Feature codes: dial-plan line `*xx*` added (stock alone fails `*56*` / `*21*`)
- [x] Streams authored from template (P2/P47/P48/P290+`*xx*`/…)
- [x] Claim MAC + provision GET **200** on `cfg{mac}.xml`; far BYE with **`P52=4` Auto** (2026-10-03)
- [ ] (Later) GDMS enroll — out of scope for first mule

---

## 7. Poly mule soak (D2/D3)

**Sub-project:** **`POLY_PROVISION_SUBPROJECT.md`**. **Lab mule:** **VVX 250** · firmware **6.4.3.5059** · Sirius **410** / `g0ntwm` · MAC **482567B0A593**. **Lab green 2026-10-03** — **streams** are the product. Discovery: **DHCP 66** / manual URL; Lens capable but no build-out unless asked. Assist-not-core.

**Streams v0:** `poly.Master` / `poly.Common` / `poly.Extension` / `poly.udp` — UCS master (`{mac}.cfg`) + settings (`{mac}-reg.cfg`). Edge must MAC-extract `-reg.cfg`.

**Manual SIP UI (2026-10-03):** OOTB timezone = **GMT**; **SIP server port** and **proxy port** both empty (must set); **Transport(s)** defaults to **DNSnaptr** → **UDPOnly**. Field lock: sub-project **§0.1**.

**NAT / far BYE:** OOTB far-end hangup fails; STUN **provisioning-only**. **Lab green 2026-10-03** (§0.2).

### Tip / soak

1. Tip `poly.*` onto Sirius home; edge `mac-from-request.map` must match `{mac}-reg.cfg`.
2. Extension **410** provision:

```text
#INCLUDE poly.Extension
#INCLUDE poly.udp
```

3. `sndcreds` = **Always** (Poly); MAC already on row (`482567B0A593`).
4. Curl-prove:

```bash
MAC=482567b0a593
curl -sk "https://provision.pbx3.com:41363/provisioning/${MAC}.cfg" | head -20   # APPLICATION master
curl -sk "https://provision.pbx3.com:41363/provisioning/${MAC}-reg.cfg" | head -40  # polycomConfig
```

5. Phone factory/OOTB: enter **admin password**, then Provisioning Server → `https://provision.pbx3.com:41363/provisioning`. Reboot/apply; GET **200** on master then `-reg.cfg`.
6. REGISTER + audio + **far BYE**; NAT keepalive **30**.

### Exit checks

- [x] Manual SIP UI knobs: TZ, both ports, Transport **UDPOnly** (not DNSnaptr) — fallback
- [x] Far BYE fail OOTB noted; STUN **provisioning-only** (§0.2)
- [x] Streams v0 + master/`-reg.cfg` path
- [x] Curl / handset GET **200**; REGISTER via SBC
- [x] Far BYE green with stream STUN (**2026-10-03**)
- [x] Factory-reset: admin password + provision URL only (**2026-10-03**)
- [x] Discovery: DHCP **66** / manual URL (Lens exists — no build-out unless asked)
