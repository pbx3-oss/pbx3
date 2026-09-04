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
| Has **NAT = Auto** | **Auto** (Network STUN panel may stay Off) |
| No Auto (STUN / Manual / Disabled only) | **STUN** + a real STUN server (e.g. `stun.l.google.com` port **3478**) |
| **Disabled** | **Avoid on fleet** — even if audio sometimes works via RTP learning |

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

- [x] **D-series / office Snom** (lab **401** / `3cg94b`) — often OK with NAT left default/off; public-ish Contact / ephemeral ports; soak audio OK (**2026-09-03**). Still verify BYE on each new model.
- [ ] Other Snom models — ___

### Fanvil

- [ ] NAT setting + audio + BYE — ___

### Grandstream

- [ ] NAT setting + audio + BYE — ___

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
