# Number dialect requirements (PSTN)

**Status:** Requirements locked for UK-first implementation (Magrathea + Gamma).  
**Related:** [`DID_ASSIGNMENT_DESIGN.md`](DID_ASSIGNMENT_DESIGN.md) · [`FLEET_TRUNK_PEERING_DECISION.md`](FLEET_TRUNK_PEERING_DECISION.md) §3 · [`DESIGN_RULES.md`](DESIGN_RULES.md) Rule 13 · [`pbx3sbc/workingdocs/PEERING-PLAN.md`](../../../pbx3sbc/workingdocs/PEERING-PLAN.md)

## 1. Problem

Carriers disagree on **wire formats** for dialled numbers and CLI:

| Form | Example (UK) | Typical use |
|------|----------------|-------------|
| National | `01924918076` | Magrathea / Gamma accept on R-URI |
| IDD | `00441924918076` | Magrathea accept |
| E.164 digits | `441924918076` | Some trunks / older peers |
| **+E.164** | `+441924918076` | Fleet wire; Teams / modern SIP |

Cross-carrier trunking (DID on carrier A, egress on carrier B) requires **normalize → canonical → render** on each leg. Inventory alone (E.164 ownership) is not enough.

## 2. Glossary

| Term | Meaning |
|------|---------|
| **Inventory key / HoR** | E.164 **digits only** (no `+`), e.g. `441924918076` — matches catalog `e164_key` |
| **Canonical wire (+E.164)** | Digit string with leading `+`, e.g. `+441924918076` — **fleet internal** form between node ↔ SBC and toward Asterisk after inbound normalize |
| **Carrier dialect** | What a Peer accepts inbound and requires outbound (dialled + CLI headers) |
| **Network number** | Trusted CLI (often PAID) — Magrathea LI |
| **Presentation number** | Display CLI (RPID / From when ≠ network) |

### 2.1 Why +E.164 on the wire

ITU-T E.164 defines the globally unique digit structure (max 15 digits). For **interoperable SIP / VoIP routing**, the userpart should be written as **+E.164** (leading `+` = international prefix indicator). Example US: `+15556667777`. This matches Microsoft Teams Direct Routing practice and modern carrier/SIP trunks; digit-only E.164 remains the **storage / drouting prefix** key.

See also: [Twilio E.164](https://www.twilio.com/docs/glossary/what-e164).

## 3. Layer ownership (locked)

| Concern | Owner | Notes |
|---------|--------|--------|
| Which CLI number to present | **Node** (routes / extension / cluster CLID) | Existing |
| How to format dialled + CLI for a carrier | **SBC Peer** (dialect profile) | Rule 13 — edge-authored |
| DID ownership | Fleet catalog | Digits HoR; no call-path directory |
| Trivial digit strip/prefix | `dr_gateways.strip` / `pri_prefix` | Fallback only |

```text
Phone --(tenant dial habit)--> Node --(+E.164 dialled+CLI)--> SBC
Carrier A --(A dialect)--> SBC --(+E.164)--> Node
Node --(+E.164)--> SBC --(B dialect)--> Carrier B
```

## 4. Four transform slots

1. **Inbound R-URI** (DID as delivered) → digit key for `do_routing(1)` / alias → **+E.164** toward Asterisk  
2. **Inbound From / PAID / RPID** → normalize network + presentation to +E.164 (keep distinction)  
3. **Outbound R-URI** after carrier select → render dialled for Peer dialect  
4. **Outbound CLI** → render network (+ presentation) into required headers  

## 5. Profile schema

Stored on Peer as `dialect=<preset>` in `dr_gateways.attrs` (with `carrier=` / `role=`). Preset expands to:

| Field | Type | Meaning |
|-------|------|---------|
| `inbound_accept` | ordered list | Parsers tried until one matches |
| `outbound_dial` | one renderer | R-URI / To userpart |
| `outbound_cli_network` | renderer + header | `paid` or `from` |
| `outbound_cli_presentation` | renderer + header or `same` | `rpid` / `from` |
| `default_cc` | string | Country code for national/IDD (e.g. `44`) |
| `privacy` | enum | `privacy_id` — `Privacy: id` (+ keep valid CLI) |

### 5.1 Parsers / renderers

| Id | Parse | Render |
|----|-------|--------|
| `plus_e164` | `^\+[1-9]\d{1,14}$` | ensure leading `+` |
| `e164_digits` | `^[1-9]\d{1,14}$` | digits only (no `+`) |
| `uk_national` | `^0\d{9,10}$` → `44` + NSN | `0` + NSN (strip CC `44`) |
| `uk_idd` | `^0044\d+$` → `44…` | `00` + CC + NSN |

### 5.2 Built-in presets

| Preset | inbound_accept | outbound_dial | CLI network | CLI presentation | privacy |
|--------|----------------|---------------|-------------|------------------|---------|
| `uk-magrathea` | plus_e164, e164_digits, uk_national, uk_idd | plus_e164 | plus_e164 → **paid** | plus_e164 → **rpid** (if ≠ network) | privacy_id |
| `uk-gamma` | plus_e164, e164_digits, uk_national, uk_idd | plus_e164 | plus_e164 → **paid** | same as network (From aligned) | privacy_id |
| `strict-plus-e164` | plus_e164 only | plus_e164 | plus_e164 → paid | same | privacy_id |
| `none` / unset | best-effort UK multi-accept | leave / strip+ for routing only | unchanged | unchanged | — |

Custom: set `dialect=custom` later; v1 ships presets only.

## 6. Carrier matrices (published anchors)

### 6.1 Magrathea

Sources:

- [Line Identity (LI) Agreement](https://www.magrathea-telecom.co.uk/wp-content/uploads/2018/09/LI-Agreement-1.pdf)  
- [Guidance on network and presentation numbers](https://www.magrathea-telecom.co.uk/wp-content/uploads/2018/11/Guidance-on-Network-and-Presentation-numbers.pdf)  
- [Client Handbook](https://www.magrathea-telecom.co.uk/wp-content/uploads/CLIENT-HANDBOOK-13.pdf)  
- Lab: national / +E.164 / IDD delivery observed on DID inbound  

| Direction | Field | Accept / send |
|-----------|--------|----------------|
| Inbound | R-URI user | national `0…`, `+E.164`, IDD `00…`, digits |
| Outbound | R-URI | Prefer `+E.164`; national/IDD also accepted by Magrathea |
| Outbound | CLI | Digits and `+` only in userpart; **PAID** = network; **RPID** (or From ≠ PAID) = presentation; always send a valid dialable CLI (withhold via Privacy, do not omit) |

### 6.2 Gamma

Sources: Gamma SIP trunk CPE notes (R-URI/To/From/PAID format) as used by integrators; treat knobs as profile fields.

| Direction | Field | Accept / send |
|-----------|--------|----------------|
| Inbound / Outbound | R-URI / To | UK national **or** `+E.164` (some notes also IDD) |
| Outbound | From / PAID | National-significant or `+E.164` |
| Practice | CLI | Many stacks require **`+` CLI** for reliable presentation → preset uses plus_e164 |

## 7. Cross-carrier scenario

DID owned by Magrathea, egress via Gamma:

1. Inbound Magrathea Peer (`dialect=uk-magrathea`) normalizes DID + caller to digit key / +E.164 toward node.  
2. Node applies tenant policy (which CLI); dials Egress with **+E.164** dialled + CLI.  
3. SBC `do_routing(0)` selects Gamma outbound Peer (`dialect=uk-gamma`); render dialled + CLI for Gamma.  

Inventory `carrier` hint on DID is ops-only; **transforms follow the Peer that is signaling**, not the inventory carrier field.

## 8. Node expectations

- Fleet wire and stored CLIDs use **`+CC…`** where **CC = country code of the country that node serves** (not hard-coded `+44`).
- After SBC inbound normalize, Asterisk sees **+E.164** R-URI (and CLI where rewritten).
- `inroutes.pkey` may still match national or E.164 regex today; prefer patterns that match `+CC…` / digit E.164 going forward.
- **DNID:** Egress trunk **transformation mask** converts subscriber habit → `+CC…` (UK seed `0:+44 00:+`; US needs `011:+` etc. — do not apply UK national rules on a US node).
- **CLID:** Node sends CLIP **as stored** (no transform mask today). Prefer `+CC…` in extension/cluster/trunk CLI fields; carrier PAID/RURI shape is **SBC outbound dialect**.
- Overseas examples: UK→US `0015139266349` → `+15139266349`; US→UK `011441924918076` → `+441924918076` (after the right node transform).
- Do **not** duplicate Magrathea/Gamma header rules on the node.

## 9. Lab acceptance

| # | Case | Pass |
|---|------|------|
| M1 | Magrathea inbound DID as national / +E.164 / IDD | Routes to same tenant; Asterisk sees +E.164 |
| M2 | Magrathea outbound dial + CLI (+ PAID/RPID) | Call completes; CLI valid |
| M3 | Privacy withhold | Privacy set; CLI still present |
| G1 | Gamma outbound +E.164 dial + CLI | Call completes |
| G2 | Gamma inbound national or + | Same as M1 shape |
| X1 | DID Magrathea + egress Gamma | Dialled + CLI rendered for Gamma |

Unit tests in **pbx3sbc-admin** cover preset parse/render matrices offline.

## 10. Non-goals (v1)

- Moving Peers into S3 directory HoR  
- Full Ofcom LI compliance / number-portability validation  
- CNAM  
- Per-tenant dialect overrides  
- NANP / non-UK presets until UK presets proven (schema must stay country-pluggable via `default_cc` + parsers)

## 11. Implementation map

| Piece | Repo |
|-------|------|
| This spec | `pbx3-directory/docs` |
| `NumberDialect` service + presets + PHPUnit | `pbx3sbc-admin` |
| Peer Filament dialect picker | `pbx3sbc-admin` |
| OpenSIPS normalize/render routes | `pbx3sbc` |
| Egress seed transform + ops page | `pbx3-directory/tools`, `pbx3-docs` |
