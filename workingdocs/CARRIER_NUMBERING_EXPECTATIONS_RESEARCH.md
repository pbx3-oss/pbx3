# Carrier numbering expectations — research notes (living)

**Status:** Research capture **2026-08-02**. Not a build plan; supports the open discussion in **`NUMBER_WIRE_STANDARD_DRAFT.md`**.  
**Prompt:** “What do national carriers expect? UK + USA known; old PBXs just sent what was dialled up the line.”  
**Related:** **`NUMBER_DIALECT_REQUIREMENTS.md`** (Peer dialect matrices) · **`EGRESS_PLUS_E164_WIRE.md`** (current fleet wire practice) · **`NUMBER_WIRE_STANDARD_DRAFT.md`** (open Model A vs B).

**How to extend:** Add a dated §Changelog row; fill / correct country matrices with **primary sources** (carrier CPE handbooks, Ofcom/FCC/national regulator). Prefer quotes + links over folklore.

---

## 1. Two different “number formats”

These get conflated constantly; keep them separate.

| Layer | Question | Typical answer |
|-------|----------|----------------|
| **A — Access / subscriber habit** | What does a person (or old PBX) dial? | National trunk prefix (`0…` UK, area codes US), international access (`00…` ITU IDD in much of the world, `011…` NANP) |
| **B — Interconnect / SIP trunk face** | What does the **next hop network** require on R-URI and CLI for **public** interconnect? | Increasingly **E.164** (`+CC…` or digit `CC…`); sometimes still national for domestic-only trunks |

Classic PTT hierarchy:

```text
  Extension → private switch → [digit string as dialled]
       → CO / PABX trunk → long-distance / international → far CO
```

The **private switch did not “own” world numbering**. It received tones/digits and **presented them upstream**. **Analysis and translation** lived in **exchange / ITSP / national network** equipment — national open numbering plans, IDD digit analysis, CLI screening.

That is exactly the user stance: **PBX sends what was dialled; upstream fixes network shape.**

Modern twist: “upstream” for a hosted fleet is often **our SBC + Peer**, not BT or AT&T’s class-4 in the same building. **Carrier SIP handbooks** still sit in layer **B**; handset habit is still layer **A**.

---

## 2. Classical PTT lesson (why Model B feels right)

| Era / device | Behaviour |
|--------------|-----------|
| Analogue PBX / early ISDN / many TDM gateways | Collect digits on access; seize trunk; **send digit stream with little/no local rewrite** |
| National transit | Digit analysis: local vs national vs international; strip trunk prefixes; insert CC when leaving country |
| International gateway | E.164-ish address on interconnect; CLI as international identity |

So: **digit analysis is a network function.** Putting Magrathea/Gamma *and* Brindley-shaped “mini networks” behind one SBC is the modern form of that hierarchy — **if** the SBC has enough context (serving country / access plan of this PBX).

Threat if the PBX also rewrites aggressively (Model A Mangle): **two independent “network-ish” layers**. Useful as a temporary fleet canonical wire; not how PTTs historically split the job.

---

## 3. Global anchors (not carrier-specific)

| Concept | Role |
|---------|------|
| **ITU-T E.164** | International public numbering: CC + N(S)N; max 15 digits. Storage and inter-operator identity. |
| **National (trunk) prefix** | Access digit(s) *inside* one country (often `0`) — **not** part of E.164 storage. |
| **International prefix** | Access to IDD *from* a country (`00` ITU default in many nations; `011` NANP). **Not** part of E.164. |
| **CLI on international interconnect** | Full international number (CC+NSN); prefixes/symbols often restricted (ITU notes, national LI rules). |
| **SIP userparts** | Common practice: **`+E.164`** for unambiguous API/SIP (Twilio, Teams DR, many wholesale SIP); **or** digit E.164; **or** national for *some* domestic SIP trunks. |

**RFC 3261** does not mandate E.164 in R-URI; **carrier contracts and regulators** do.

---

## 4. United Kingdom (lab + published)

### 4.1 Access habit (layer A)

| Call type | Typical dial |
|-----------|----------------|
| Geographic / non-geo national | `0` + NDC + SN (e.g. `01924918076`, `07…` mobiles) |
| Overseas | `00` + CC + NSN |
| Operator specials | Short codes, `1xx` — national matter |

### 4.2 ITSP / SIP face (layer B) — what we already know

| Peer class | Dialled R-URI | CLI | Notes / sources |
|------------|---------------|-----|-----------------|
| **Magrathea** (wholesale ITSP) | Prefer `+E.164`; national / IDD also seen | PAID network / RPID presentation; digits/`+` | Client handbook + LI guides (see NUMBER_DIALECT §6.1); lab |
| **Gamma** | National **or** `+E.164` | Often `+` for reliable presentation | Integrator CPE notes |
| **Brindley** (lab SARK “network” peer) | **`_0…` / `_00…` only** (York) | National-ish | Registration trunk; **not** a regulator doc — CPE reality |
| **TTNC (example UK retail SIP)** | E.164 userparts cited for CLI headers | Ofcom-style allowed CLI ranges | Public CLI presentation PDF (header userpart E.164 with `+` allowed) |

**Lab fact 2026-08-02:** Brindley rejected digit-E.164 `4479…` in context `mainmenu`; national `0794…` works after edge strip/prefix. That is **access-plan shaped** CPE, closer to “CO expects UK dialling” than modern wholesale +E.164.

### 4.3 Ofcom / LI (CLI honesty)

UK interconnect CLI is heavily regulated (network vs presentation number, LI agreements). **Shape of dialled R-URI is distinct from whether CLI is lawful to present.** Dialects must not invent CLI; they only **render** what the node authorised.

---

## 5. United States / Canada (NANP)

### 5.1 Access habit (layer A)

| Call type | Typical dial |
|-----------|----------------|
| Local / domestic | 10-digit (NPA-NXX-XXXX); some 7-digit residual; **no leading trunk `0`** |
| International | **`011`** + CC + NSN (not `00`) |
| Domestic with carrier access | Various `1010xxx` etc. — enterprise/ITSP often hide |

### 5.2 Interconnect / SIP (layer B)

| Practice | Notes |
|----------|--------|
| **+E.164** (`+1…`) | Dominant for CLEC/ITSP SIP, Twilio, Teams, STIR/SHAKEN signed identity payloads use number identity |
| **10-digit** | Still appears on some domestic trunks if configured “NANP only” |
| **STIR/SHAKEN** | Trust of **CLI identity**, not replacement for dial string rules — still need correct destination format per peer |

**Implication for multi-region fleet:** a UK node’s `00…` and a US node’s `011…` are **different access plans**. An SBC that accepts “raw dialled” **must know which plan applies to that source Asterisk**, or it cannot tell “local habit” from garbage.

---

## 6. Other major markets (first-pass / needs primary sources)

Fill these with CPE handbooks when we touch a Peer for real. First-pass industry pattern only.

| Region | Access IDD (layer A) | Trunk prefix (layer A) | Common SIP interconnect (layer B) |
|--------|----------------------|------------------------|-------------------------------------|
| **Most of EU / much of world** | `00` | Often `0` national | Mix: `+E.164` rising; DE/FR/etc. still see national on SIP; some profiles accept IDD form |
| **Germany** | `00` | `0` | National or E.164 common on SIP trunks depending on carrier |
| **France** | `00` | `0` | Similar |
| **Australia** | `0011` | `0` | Many SIP expects `+61…` or `0…` domestic |
| **India** | `00` | `0` | National / +91 depending on operator |
| **UAE / KSA** | `00` | `0` | Strict CLI allowlists common on wholesale (even if dial is E.164) |
| **FL1 / LI / CH style business SIP** | varies | varies | Specs often allow **+E.164 or 00+E.164** on From/PPI; can still deliver **national** toward CPE |

Pattern: **layer A varies by country; layer B is converging on E.164 for wholesale, residual national for domestic SIP / legacy CPE.**

---

## 7. Matrix: who should transform what

| Transform | Classic PTT | Model A (node Mangle today) | Model B (PBX transparent) |
|-----------|-------------|-----------------------------|---------------------------|
| Habit → unambiguous internal | National CO | Node Egress mask | **SBC** using serving-country / plan |
| Internal → carrier face | ITSP trunk card | SBC Peer dialect | **SBC** Peer dialect (only) |
| Inbound DID → PBX | Deliver in access plan or E.164 | SBC dialect → **+E.164** to Asterisk | **SBC** dialect → **+E.164** (recommended for multi-tenant) |
| CLI network/presentation | Network screening | Node *value*; SBC *headers* | Same (Rule 13) |

**Research takeaway:** Industry docs for **modern wholesale SIP** push **E.164 on the *network-facing* SIP**. That does **not** force the **PBX** to produce E.164 — historically the opposite. The **edge** can be the first equipment that understands both **access plan** and **peer face**.

---

## 8. Open research gaps (next source pulls)

1. **Bandwidth.com / major US CLECs** — published SIP dialled + CLI format (primary PDF).  
2. **BT Wholesale / Gamma / Vodafone UK** — latest SIP trunk CPE for R-URI (not reseller folklore).  
3. **Australian SIP** (e.g. AAPT, Telstra) — 0011 vs +61 expectation.  
4. **German DTAG / Sipgate / Telefonica DE** — national vs +49.  
5. Confirm **Twilio Elastic SIP**: documented +E.164 only for To/From (known for CLI 403 lab).  
6. Magrathea **explicit** outbound R-URI preferred form from newest handbook page (revalidate).  

---

## 9. Implications for pbx3 (positioning only)

1. **Do not** treat “carrier expects X” as one global PBX setting.  
2. **Do** treat **Peer dialect** as the sole **layer B** adapter (already product intent).  
3. **Model B** (PBX passes dialled digits) is **aligned with classical telephony** and with “upstream fixes it” **if** each fleet instance has a declared **access numbering plan / serving CC** for the SBC.  
4. **Model A** (node Mangle to +E.164) is a **fleet internal simplification**, not how PTTs taught PBXs to behave; it remains useful until (3) is real.  
5. **Inbound to Asterisk as +E.164** is still a good multi-tenant internal choice even under Model B (PBX *receives* network-shaped DID, separate from *sending* habit digits out).

---

## Changelog

| Date | Note |
|------|------|
| 2026-08-02 | Initial: PTT model, UK/US matrices, residual EU/AUS, Research gaps; links to wire draft. Lab Brindley national-only face noted. |
