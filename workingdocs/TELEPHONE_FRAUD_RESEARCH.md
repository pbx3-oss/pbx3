# Telephone fraud — research notes (living)

**Status:** Research capture **2026-07-28** (ownership + competitor scan + ClearIP/Sansay bolt-on). Append jurisdiction notes and feature rows over time; do not treat this as a build plan.  
**Related:** **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`** (instance IRSF / velocity act); **`SBC_PRODUCT_TRACKS.md`** Track B (STIR posture — Twilio near-term; §6 bolt-on cross-link); **`NUMBER_DIALECT_REQUIREMENTS.md`** (CLI shape at Peer / Egress); **`DESIGN_RULES.md`** Rule 1 (directory out of call path), Rule 5 (notify ≠ call-path SLA).

**How to extend:** Add a dated row under **Changelog**; append jurisdiction bullets under **§3**; add or revise rows in **§2** when ownership clarity improves. Prefer facts + sources over product commitments.

---

## 1. Two problem classes (do not blur)

| Class | Victim / bill | Typical shape | Who usually owns mitigation |
|-------|---------------|---------------|-----------------------------|
| **A — Scam / spoof / robocall** | Called party (consumer or business) | Fake CLI (bank, gov, local number); illegal telemarketing; vishing | **Carriers + regulators** (national CLI rules, STIR, DNO, traceback) |
| **B — Toll fraud (IRSF / PBX compromise)** | Tenant / MSP (outbound spend) | Compromised phone / SIP creds → premium or high-cost intl; CFIM to bad dest | **PBX operator** (CoS, velocity, lockout) + **carrier fraud desk** as backstop |

Fleet pbx3 already owns **class B** detection/act (velocity V1–V2+V5). Class A is mostly **carrier / national-network** territory; fleet participates only where we originate, present CLI, or sit on the interconnect edge.

```text
Class A (inbound trust to the called party)
  National rules → carrier CLI auth / block / DNO / traceback
    → optional Peer-shaped STIR (Twilio…) when we egress into that market
    → fleet: honest CLI + dialect; do not invent a national STI-CA

Class B (outbound spend from a compromised endpoint)
  CoS / dial policy (prevention)
    → CDR velocity + notify + active=NO (detection/act)
      ↔ ITSP geo-block / fraud desk (backstop, not HoR)
```

---

## 2. Feature ownership — fleet PBX vs carriers

**Legend**

| Owner | Meaning |
|-------|---------|
| **Fleet PBX** | Instance HoR: Asterisk / CAGI / GenAst / CoS / CDR / velocity / SPA admin |
| **Fleet SBC** | Magrathea / pbx3sbc: Peer interconnect, Fail2ban/pike, dialect render, optional STIR *if* we ever host AS |
| **Carrier / ITSP** | Magrathea, Twilio, Brindley, Bandwidth, national operators — regulatory CLI programmes, fraud desks, DNO feeds |
| **Regulator / industry** | FCC, Ofcom, CRTC, Anatel, DoT, GSMA/ITU — mandates and shared lists; not our code |
| **Shared** | We implement a thin slice; carrier holds the durable programme |

### 2.1 Class A — spoofing, robocalls, CLI trust

| Feature | Typical country use | Fleet PBX | Fleet SBC | Carrier / regulator | Notes for us |
|---------|---------------------|-----------|-----------|---------------------|--------------|
| **STIR/SHAKEN signing & verification** | US, CA, FR, BR (mandates); UK declined | — | Optional later (Track B shape C) | **Primary** | Posture: **Twilio (shape A)**; Bandwidth Hosted / OpenSIPS AS only if required — **`SBC_PRODUCT_TRACKS.md`** |
| **Rich Call Data / branded calling** | BR Origem Verificada; US brand overlays | — | — | **Primary** | Display name/logo after carrier auth; not instance HoR |
| **Block national CLI arriving from abroad** | UK, DE, CH, IN (landline/mobile variants) | — | Possible **mark/withhold** if we terminate national traffic | **Primary** at national gateways | Swiss `P-CH-Origin`-style mark; we are not a national ILDO |
| **Do Not Originate (DNO) lists** | UK, DE, US-style lists | Optional: refuse originate of known DNO CLIs we host | Optional Peer filter | **Primary** list ownership | Useful if we ever present bank/gov DIDs we don’t own — usually N/A |
| **Spare / unused numbering-level block** | IN strong; ITU asks for global DB | — | Optional drop malformed/spare if Peer asks | **Primary** | Carrier/ILD hygiene |
| **Malformed / short CLI drop** | IN; many ITSPs | Soft: don’t invent bad PAI | Soft: dialect + E.164 hygiene | **Primary** | Align with **`NUMBER_DIALECT_REQUIREMENTS.md`** |
| **Robocall Mitigation Database / KYC / KYUP** | US FCC RMD | — | — | **Primary** | Our duty is honest Peer KYC upstream when *we* are the ITSP story; fleet today peers *to* ITSPs |
| **Call traceback** | US, CA (mandatory participation growing) | Soft: preserve CDR / call-id for ops | Soft: retain edge CDR | **Primary** | Cooperate if asked; Gatekeeper not call-path |
| **Citizen scam reporting / CNAP** | IN Chakshu; IN CNAP work | — | — | **Primary** | Out of scope |
| **Presentation CLI we send outbound** | Everywhere | **Yes** — tenant/trunk CLI policy | Dialect / PAI shape at Peer | Carrier may overwrite / strip | Fleet must send **rightful** CLI; spoofing *as* a bank is fraud we must not enable |
| **PAID / attested identity headers** | STIR markets; some Peers | Soft: pass-through if present | Soft: pass or strip per Peer | **Primary** attest | Today: Peer-shaped (Twilio); don’t mint national attestations |

### 2.2 Class B — toll fraud / compromised PBX

| Feature | Industry practice | Fleet PBX | Fleet SBC | Carrier / ITSP | Notes for us |
|---------|-------------------|-----------|-----------|----------------|--------------|
| **Class of Service / dial policy** | Everywhere (enterprise) | **Primary** | — | Soft geo-block | Prevention first — velocity is not a substitute |
| **Credential / REGISTER hardening** | Everywhere | **Primary** (phones, passwords, no DISA) | Fail2ban / pike **inbound SIP** | Soft | Edge = outside→in; velocity = inside→out |
| **VM outdial lockout** | Best practice | **Primary** (product must not allow) | — | — | Prevention audit, not velocity |
| **IRSF / premium velocity detect** | Enterprise + some ITSPs | **Primary** (CDR batch — shipped V1–V2) | — | Fraud desk analytics | Spec: **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`** |
| **Auto-block compromised endpoint** | Fail2ban analogy | **Primary** (`ipphone.active=NO` + clear CF + hangup) | — | Soft: kill trunk | V5 act on instance |
| **Ops notify on velocity hit** | Ops practice | Detect on node → Gatekeeper mail | — | Carrier may mail separately | Rule 5: notify ≠ call-path SLA |
| **CFIM / Follow-me abuse detect** | Enterprise | **Planned** (velocity follow-on) | — | Soft | Same act as IRSF |
| **Wangiri correlation** | Carrier-heavy | Later / noisy | Soft | **Often primary** | Prefer carrier; don’t overclaim |
| **Traffic pumping (toll-free)** | Carrier / toll-free owner | — | — | **Primary** | Not instance HoR |
| **Interconnect cut of bad upstream** | Carrier / SBC peer ops | — | **Shared** — disable Peer / gwid | **Primary** | Filament Peer ops + ITSP contracts |
| **International rate / destination blocks** | ITSP fraud products | CoS prefixes | Optional Peer LCR exclude | **Shared** | CoS is HoR for tenant policy; carrier geo is backstop |

### 2.3 One-page split (what we build vs what we buy)

```text
BUILD / OPERATE ON FLEET
  • CoS, no DISA, VM outdial locked
  • Honest outbound CLI + number dialect
  • Velocity IRSF (+ later CFIM / off-hours) → notify → active=NO
  • SBC: inbound SIP abuse (Fail2ban/pike); Peer hygiene; dialect
  • STIR: consume Peer capability (Twilio…) — do not run national STI-CA

REMAIN WITH CARRIERS / REGULATORS
  • National STIR/SHAKEN governance & verification ecosystems
  • Abroad→domestic CLI block / anonymize at country gateways
  • DNO / spare-level national databases
  • Traceback programmes & Robocall Mitigation Database
  • Branded / Rich Call Data display to handsets
  • Toll-free traffic pumping; most wangiri at PSTN scale
  • Fraud-desk geo-blocks and interconnect KYC of *their* customers
```

---

## 3. Jurisdiction scratchpad (append over time)

Sources are indicative; verify before citing externally.

### United States
- **STIR/SHAKEN** mandated on IP voice; gateway + intermediate duties; robocall mitigation plans + **Robocall Mitigation Database**; traceback.
- FCC: [call authentication](https://www.fcc.gov/call-authentication).

### Canada
- **STIR/SHAKEN**; **traceback** participation expanding (CRTC 2026-52 era).
- Cross-border coordination with US.

### France
- Law-driven **STIR/SHAKEN** (MAN platform); operators expected to **block** unauthenticated / failed verification (stricter than US/CA terminate-anyway culture).

### Brazil
- Anatel **Origem Verificada**: STIR/SHAKEN + Rich Call Data; auth obligatory on a multi-year ramp (~2028).

### United Kingdom
- Ofcom **did not** proceed with STIR/SHAKEN (2024 assessment).
- **CLI guidance**: block invalid CLI; DNO; block abroad spoofing UK network/presentation numbers (landline then mobile); limited roaming/cloud exceptions. Stronger presentation rules from **2025-01-29**.

### Germany / Switzerland
- Prefer **international-origin mark + withhold/anonymize domestic CLI** from abroad over full national SHAKEN (roaming exceptions). DNO + E.164 checks common.

### India
- **CIOR** real-time spoof block at ILD; block Indian landline CLI from abroad; malformed/short CLI drop; unused/similar-CC blocks; citizen **Chakshu**; CNAP work for trusted name.

### Australia
- Industry code **C661** (scam calls/SMS): E.164 CLI checks; right-to-use for A-party before intl send; operator cooperation.

### ITU / GSMA (cross-border)
- Push for harmonised CLI authentication standards and a shared **used/spare numbering** database; GSMA notes roaming-status checks and interconnect CLI signing vs wangiri/IRSF between carriers.

---

## 4. Implications for pbx3 (non-binding)

1. **Do not** schedule a national STI-CA or “fleet STIR product” — Track B stays **Peer-shaped** (**`SBC_PRODUCT_TRACKS.md`**).
2. **Do** keep investing in **class B** (CoS + velocity + act) — that is our bill-saving lever.
3. **Do** keep **CLI honesty + dialect** correct at Peer/Egress — supports carrier programmes without owning them.
4. **SBC** stays the place for **inbound SIP abuse** and interconnect Peer controls; **not** for scoring tenant IRSF (instance CDR remains HoR).
5. When selling into **US/CA/FR/BR**, expect customers/Peers to ask about **attested CLI** — answer with trunk/Peer capability, not OpenSIPS-first.
6. When selling into **UK/DE/CH/IN-shaped** markets, expect **gateway CLI hygiene** questions more than SHAKEN — still mostly carrier; our job is not to present numbers we don’t have rights to.

---

## 5. Competitor / peer scan — Asterisk & FreeSWITCH value-add (2026-07-28)

**Scope:** What commercial or “value-add” PBX stacks (Asterisk- or FreeSWITCH-based, plus close peers) publicly say/do about **toll fraud** and **STIR/SHAKEN**. Marketing pages, vendor docs, and community how-tos — not a lab bake-off. Append vendors over time.

### 5.1 Headline

| Theme | What peers do |
|-------|----------------|
| **Toll fraud (class B)** | Almost everyone: **inbound SIP hardening** (firewall / Fail2ban / responsive firewall) + **outbound CoS / country / international restrictions**. Few ship a named **CDR velocity → disable endpoint** product like ours; more often “ask your ITSP fraud desk” or bolt-on **ClearIP / SBC scoring**. |
| **STIR/SHAKEN (class A)** | **Not a native FreePBX / VitalPBX / FusionPBX product feature** in the Sangoma/community sense. Industry consensus push: **sign at SBC or carrier / hosted STI-AS**, or dialplan API glue (Sansay NSS, Tiltx). Exceptions: **Yeastar** (built-in cert upload for cloud shared trunks), **SignalWire** (carrier-side attest on their numbers), **FS PBX** fork module (local cert, support-plan), experimental **Kazoo martini**. |
| **Asterisk engine** | Upstream **`res_stir_shaken`** exists (refactored ~2024) — **engine capability**, not “FreePBX position.” Verification path had **CVE-2025-49832** (DoS/possible RCE) — reason to be cautious about PBX-as-verifier on untrusted legs. |

Peers largely agree with our Track B instinct: **STIR is Peer/SBC/carrier-shaped; PBX owns CoS + edge SIP abuse.**

### 5.2 By product

| Product | Stack | Fraud / security they emphasize | STIR/SHAKEN position |
|---------|-------|----------------------------------|----------------------|
| **FreePBX / PBXact (Sangoma)** | Asterisk | **Firewall + Responsive Firewall** (throttle failed REGISTER, probe floods); Fail2ban; community guidance on passwords / provisioning. Toll fraud treated as ops + provider alerts. | **No native signing in GUI.** Official community docs: glue **Sansay NSS**, **Tiltx**, or **TransNexus ClearIP** (latter needs **in-line SIP proxy** — FreePBX can’t consume ClearIP’s 302 flow cleanly alone). |
| **VitalPBX** | Asterisk (+ multi-tenant) | Security as product theme; MT isolation stressed by SBC vendors. | Same as Asterisk: **not native**. Sansay documents trunk Identity injection; TelcoBridges pitches **STIR + toll-fraud scoring on SBC**, not in VitalPBX. |
| **FusionPBX** | FreeSWITCH | Edge/SBC for DoS + fraud scoring in partner content. | **No native PASSporT** in FS/Fusion (TelcoBridges). Optional **`fusionpbx-app-identity`** (local cert + curl sign). Forum: carriers rejecting missing Identity → use **BulkVS / Telonium** (carrier signs) or switch; FusionPBX team said STIR is **roadmap / high priority** (forum). **FS PBX** (fork) sells a **local cert module** (Attestation A, support-plan). |
| **SignalWire** | FreeSWITCH lineage / CPaaS | Fraud framed as **robocall / spoof** at platform. | **Yes — carrier-shaped:** numbers on SignalWire get default **attest C**; A/B after vetting. Sponsored open-source **`libstirshaken`**. Not “put SHAKEN in every customer PBX.” |
| **2600Hz Kazoo** | FreeSWITCH-based CPaaS | Strong **class B** story: multi-tenant **carrier limits**, high-rate blocks by default, per-account/device flags, “don’t delegate fraud solely to upstream.” | **Trunking.io** path: reseller uploads **own STI cert** (FCC reseller uniqueness messaging). Experimental open **`martini`** + SecSIPIdX for local Identity injection. |
| **Yeastar P-Series** | Proprietary PBX (not Ast/FS; close market peer) | Security Trust Center; advisory on **portal compromise → toll fraud**; IP/geo blocks, password policy, outbound restrict. | **Built-in** for **Central Management / shared trunks**: upload SHAKEN cert + key; sign outbound; verify inbound or trust ITSP verstat. Explicit “no extra signing box” marketing. Closest to **first-party STIR in the PBX product**. |
| **3CX** | Proprietary | Heavy on **anti-hack / IP SIP trunk** security alerts; global blacklist; outbound country rules. Toll fraud = compromised system / open trunk. | **No first-party STIR product** in the Yeastar sense; attestation expected from **SIP provider**. |
| **TelcoBridges ProSBC** (+ Ast/FS frontends) | SBC | Markets **toll-fraud scoring** (prefix, rate, time, pattern) + DoS + STIR at edge in front of FreePBX / Fusion / VitalPBX. | Explicit: **signing belongs at SBC**, not FreePBX/Fusion/Asterisk GUI. Integrates ClearIP / Neustar. |
| **TransNexus ClearIP** | Cloud STI-AS / analytics | **Toll fraud + robocall/TDoS + STIR + DNO + CNAM** in one dip; SIP 603 block. | **Hosted signing/verification** for Asterisk/FreePBX via **proxy or SBC** — Sangoma documents the FreePBX pattern. |
| **Asterisk (upstream)** | Engine | N/A as “product position.” | **`res_stir_shaken`** attest/verify with certs; interoperable refactor 2024. **Not** what FreePBX ships as a turnkey module. Treat verify-on-PBX carefully (CVE history). |

### 5.3 Patterns vs pbx3

| Pattern | Peers | pbx3 today |
|---------|-------|------------|
| Inbound SIP abuse (Fail2ban / responsive FW) | FreePBX strong; everyone recommends | **SBC Fail2ban/pike** — aligned |
| Outbound CoS / country / premium deny | Universal advice | **CoS** — aligned |
| CDR velocity → kill compromised phone | Rare as named product; ClearIP/SBC scoring or ITSP desk | **Velocity V1–V2+V5** — **differentiator** if we keep shipping it |
| STIR as first-party PBX feature | Yeastar yes; FS PBX module; Kazoo via trunking/cert; FreePBX/Vital/Fusion = glue or roadmap | **Peer-shaped (Twilio…)** — **mainstream peer stance**, not behind |
| STIR on own OpenSIPS/Asterisk with STI-CA | Possible; rare as default product | **Deferred** (Track B shapes B/C) — matches FreePBX/Vital “don’t own it first” |

### 5.4 Sources (indicative)

- Sangoma FreePBX community: Sansay NSS / Tiltx / ClearIP STIR how-tos; Firewall / Responsive Firewall docs.
- TelcoBridges: FreePBX / FusionPBX / VitalPBX + SBC pages (STIR + toll-fraud scoring at SBC).
- FusionPBX forums + `fusionpbx-app-identity` GitHub; SignalWire STIR docs + `libstirshaken`.
- 2600Hz Trunking.io STIR docs; Kazoo fraud/carrier-management blog; openkazoo/martini.
- Yeastar STIR overview / “built-in STIR” blog; security trust center + toll-fraud advisory.
- Asterisk docs `STIR-SHAKEN` / `res_stir_shaken`; CVE-2025-49832 advisory.
- TransNexus ClearIP product + Asterisk/FreePBX integration docs.

### 5.5 Yeastar STIR — what it actually does (2026-07-28)

**Not** toll-fraud velocity. **P-Series Cloud PBX** + **Yeastar Central Management (YCM)** for **shared trunks**:

1. Partner obtains own STI cert (STI-PA / STI-CA) — Yeastar does not issue it.
2. Upload SHAKEN cert + private key in YCM (shared across trunks).
3. Per trunk mode: outbound signing, signing+verification, etc.
4. **Outbound:** PBX signs INVITE `Identity`; docs say **attestation A**; skips emergency/anonymous; CDR logs status.
5. **Inbound:** either PBX verifies (fetch `x5u`, apply drop rules) or **inbound filtering** (trust ITSP verification result, then filter).

Marketing “built-in / no extra signing box” = cert held in YCM and crypto on the cloud PBX path — **compliance still on the partner**.

---

## 6. Bolt-on STI-AS — Sansay / ClearIP for pbx3 (2026-07-28)

**Status:** Research / decision aid — **do not schedule** while Track B stays Twilio shape **A**.  
**Related:** **`SBC_PRODUCT_TRACKS.md`** Track B shapes A / B / C; Bandwidth Hosted Signing checklist.

**Verdict:** Medium engineering, real recurring $, **high value only when we must attest as ourselves** (own US/FR VSP obligation) and Peers will not host-sign. For current shape **A**, value is **low**.

### 6.1 Options vs our stack

| Option | Attach point | Track B shape | Notes |
|--------|--------------|---------------|-------|
| **Sansay NSS** | HTTP per call → `Identity` → inject on INVITE (OpenSIPS preferred; Asterisk predial = multi-node tax) | **B**-ish hosted AS under **our** cert in NSS portal | FreePBX community path is dialplan+curl — we should not copy that onto every golden |
| **TransNexus ClearIP** | SIP **302** flow: INVITE → ClearIP → 302 with `Identity` (+ optional fraud/DNO/route) → carrier | **B** + optional class-A/B analytics | Better fit for an **SBC** than for FreePBX (which needs an inline proxy). Magrathea would implement 302/header handling in OpenSIPS **or** run a small proxy |
| **Sansay STIR/SHAKEN Express** | VSXi + cert + NSS + DNO package | Alternate edge SKU | **Not** a light Magrathea plugin — competes with / duplicates **pbx3sbc** |

### 6.2 Effort

| Slice | Size | Detail |
|-------|------|--------|
| Lab: one Magrathea→US Peer signed call (NSS or ClearIP) | **S–M** | Peer IP trust, dialect/`+E.164`, Identity preservation, fail-open vs fail-closed when vendor down |
| Production OpenSIPS + Peer attr (`stir=clearip` / `nss` / …) | **M** | HA companion, Filament/ops, logging, timeouts |
| Divert / CFIM / DIV PASSporT | **+M** | Same hard problem as Track B shape **C** — first INVITE is the easy case |
| Inbound verify + drop policy | **+M** | Prefer edge; avoid Asterisk verify-as-default (CVE history) |
| Compliance (OCN, 499-A, RMD, STI-PA, SPC, STI-CA / FR APNF) | **XL calendar** | Gates **own-cert** whether vendor is ClearIP, Sansay, Bandwidth, or OpenSIPS |

### 6.3 Cost (order-of-magnitude — not quotes)

| Line | Rough |
|------|--------|
| ClearIP | Usage monthly; industry comps often **~$5–15k/yr** TransNexus-class (volume + modules: STIR-only vs fraud+DNO+CNAM) |
| Sansay NSS / Express | Quote; Express bundles CA + sign/verify + DNO — VSP subscription tier |
| STI-PA + STI-CA | Annual + setup — required for own-cert US either way |
| Glue examples | e.g. third-party dSIPRouter ClearIP module marketed ~**$979/yr** *plus* ClearIP — glue ≪ service |
| Twilio shape **A** today | **~$0** incremental STIR product cost beyond trunking |

### 6.4 Value

| Need | Bolt-on value |
|------|----------------|
| Stay Peer-shaped **A** (Twilio signs) | **Low** |
| Own US TNs; Peer offers **hosted signing** (Bandwidth **B**) | Prefer **Bandwidth** over ClearIP/Sansay — same compliance, less Magrathea work |
| Own US TNs; Peer only relays / drops Identity | **High** — NSS, ClearIP, or OpenSIPS AS all become necessary |
| Extra outbound fraud scoring beyond velocity | **Medium** — ClearIP overlaps class B; velocity already covers compromised-phone IRSF; ClearIP adds interconnect/reputation-style blocks |
| France MAN | **Don’t assume** US ClearIP/Sansay Express = APNF — separate trust pack |
| Marketing parity with Yeastar | **Weak** — Yeastar still requires partner STI cert; bolt-on does not skip compliance |

### 6.5 Recommendation (locked with Track B)

1. **Do not bolt on now** for curiosity — continue Twilio **A**.
2. When own-cert US is forced: prefer **Bandwidth Hosted Signing (B)** before ClearIP / Sansay / OpenSIPS **C**.
3. Revisit **ClearIP** if we want **STIR + fraud/DNO in one SIP dip** at the edge *and* Peers will not host-sign — budget **M eng + compliance XL + ~low–mid five figures/yr**.
4. Treat **Sansay Express** as an alternate SBC SKU, not a Magrathea plugin.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-07-28 | Initial research capture; class A vs B; ownership matrix fleet PBX / SBC / carrier; jurisdiction scratchpad from public regulator/GSMA/ITU material. |
| 2026-07-28 | §5 competitor scan — FreePBX/Vital/Fusion/SignalWire/Kazoo/Yeastar/3CX + SBC/ClearIP; STIR mostly Peer/SBC/carrier; velocity as differentiator. |
| 2026-07-28 | §5.5 Yeastar STIR mechanics; **§6** Sansay/ClearIP bolt-on effort/cost/value + Track B recommendation. |
