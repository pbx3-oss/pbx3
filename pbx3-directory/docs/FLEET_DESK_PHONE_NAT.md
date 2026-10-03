# Fleet desk phones — NAT / STUN (provisioning)

**Status:** Locked direction **2026-09-03** (lab: golden `hf3zzv` + SBC).  
**Audience:** Operators + anyone maintaining **customer RPS / handset templates**.  
**Related:** **`FLEET_TRUNK_PEERING_DECISION.md`** §6.1 (RTP bypass / media on home) · soak list in **`~/GiT/pbx3-ops/TODO_OPS.md`**.

---

## 1. Why this exists

Fleet homes sit in **AWS**; desks register via the **SBC**; media is **anchored on the home** (`direct_media=no`, `rtp_symmetric=yes`).

That differs from **direct-to-cloud Asterisk** (no SBC): the home used to see REGISTER from the **office public NAT** and rewrite Contact to a reachable mapping. With an SBC in front, the home often sees SIP from the **SBC VIP**, so **phone-advertised Contact / SDP** matter more.

| Symptom | Typical cause |
|---------|----------------|
| No / one-way audio | Phone SDP `c=` is LAN-only; Asterisk RTP never reaches the set (until STUN/Auto or the set “sends RTP first”) |
| Audio OK, **BYE / hangup broken** | Contact still LAN-ish; in-dialog SIP (BYE) does not tear down cleanly |
| Same vendor, one set OK one not | Different NAT UI defaults / firmware (e.g. Yealink **402** vs **403**) |

**Do not** rely on “it worked on LAN Asterisk” or “audio seemed fine with NAT=Disabled.”

---

## 2. Provisioning rule (product)

Customer **provisioning scripts / RPS templates** for fleet must set desk NAT explicitly:

| Handset capability | Set |
|--------------------|-----|
| Has **NAT = Auto** (some Yealink UI) | Prefer **Auto** in UI when soaking by hand; **CFG has no Auto** — Yealink `account.X.nat.nat_traversal` is **0=Disabled / 1=STUN / 2=Manual** (Admin Guide V86). Product streams use the **STUN** path below. |
| No Auto (STUN / Manual / Disabled only) | **STUN** + a real STUN server (e.g. `stun.l.google.com` port **3478**) |
| **Disabled** | **Avoid on fleet** — even if audio sometimes works via RTP learning |

### Yealink stream keys (vendor grain)

Shipped in `yealink.Common`:

```text
static.sip.nat_stun.enable = 1
static.sip.nat_stun.server = stun.l.google.com
static.sip.nat_stun.port = 3478
account.1.nat.nat_traversal = 1
account.1.nat.rport = 1
account.1.nat.udp_update_enable = 1
account.1.nat.udp_update_time = 30
```

Softphones: treat each app’s “NAT / STUN / ICE” as the same class of setting; check off below when soaked.

---

## 3. Manufacturer soak checklist

Check off when **lab or customer fleet** proven: **register · two-way audio · local hangup (BYE) · far hangup**, via SBC + cloud home. Note model + NAT setting used.

### Yealink

- [x] **T-series with Auto** (lab **403** / `0c9m50`) — Account **NAT = Auto**; Network STUN Off; audio + path OK after Auto (**2026-09-03**).
- [x] **T-series Auto not required if already well-behaved** (lab **402** / `2qcrrq`) — worked with LAN-ish Contact via RTP learning; still prefer **Auto** in templates for consistency (**2026-09-03**).
- [x] **T31P** (no Auto) — **NAT = STUN** + STUN server; Disabled → audio often OK but **BYE broken**; STUN fixes hangup (**2026-09-03**).
- [ ] **BLF / subscribe** on Yealink — still open (separate from NAT; see pickup/BLF notes in TODO).
- [ ] Other Yealink models (T4x/T5x/CP…) — ___

### Snom

- [x] **D-series / office Snom** (lab **401** / `3cg94b`) — audio often OK with outbound+rport only; **BYE from far end** failed when Contact was LAN (`x-ast-orig-host=192.168.x.x`). Same class as Yealink T31P. Product stream sets **`stun_server1`** + binding interval; far hangup proven (**2026-10-01**).
- [ ] Other Snom models — ___

### Snom stream keys (vendor grain)

Shipped in `snom.Common`:

```text
stun_server1$: stun.l.google.com:3478
stun_binding_interval1$: 30
enable_rport_rfc3581$: on
rtp_keepalive$: on
```

Plus per-line **`user_outbound1$`** = SBC (`snom.udp` / Extension).

### Fanvil

- [x] **Desk mule** (lab Sirius **412** / `27b2mr`) — **STUN Off** (UI default); calls OK via SBC (**2026-10-03**). Forgiving like Yealink **402**; stock `fanvil.Common` still ships STUN for fleet consistency.

### Grandstream

- [x] **GRP / desk mule** (lab Sirius **408** / `74y2h3`) — **NAT Traversal = Auto** (UI default); two-way audio + BYE OK via SBC (**2026-10-03**). Prefer Auto in manual setup / future streams unless a model proves otherwise.

### Poly

- [ ] **VVX / UCS mule** — OOTB: calls OK but **far-end hangup fails** on outbound (same class as Snom / Yealink T31P). **STUN is provisioning-only** (browser NAT page has no STUN; chatbot Web-GUI STUN is wrong). Ship `feature.nat.stun.*` in `poly.Common`; re-soak BYE. Details: **`POLY_PROVISION_SUBPROJECT.md` §0.2**.

### Gigaset

- [ ] NAT setting + audio + BYE — ___

### Softphones / apps

- [x] **Bria Mobile iOS** — registered / mapped (UA harvest); NAT/ICE defaults TBD if issues.
- [ ] **Zoiper** — ___
- [ ] **Groundwire** — registered lab; NAT/ICE TBD.
- [ ] **Linphone desktop** — parked (no REGISTER in soak).
- [ ] Others — ___

---

## 4. Ops verify (quick)

On the home after REGISTER:

```text
pjsip show aor <shortuid>
```

Prefer `x-ast-orig-host` showing a **public** face (or a mapping that survives BYE). LAN-only `:5060` + NAT=Disabled is the smell that failed **403** / T31P hangup.

Line test report: **Bytes in/out** both &gt; 0 after answer; hangup clears both ends.

---

## 5. History

| Date | Note |
|------|------|
| 2026-09-03 | Line test play() race fixed (SPA). Yealink **403** zero inbound RTP until NAT Auto/STUN; **T31P** BYE until STUN; **Snom 401** / **Yealink 402** comparatively forgiving. Doc created. |
| 2026-10-01 | Snom **401** post-fleet-provision: Contact LAN (`192.168.1.138`) vs Yealink public; far-end hangup leaves Snom up. Added STUN to `snom.Common`; Contact → public; far BYE clears (**lab soak**). |
| 2026-10-03 | Grandstream Sirius **408**: NAT Traversal **Auto** (default) — audio + BYE OK. |
| 2026-10-03 | Fanvil Sirius **412**: STUN **Off** (default) — calls OK; streams keep STUN for fleet. |
| 2026-10-03 | Poly: far-end BYE fails OOTB; STUN **provisioning-only** (no Web UI); BYE re-soak open. |
