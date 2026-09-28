# Trunk carrier-face normalization — requirements stub

**Status:** Open work (not scheduled). Seeded **2026-08-29**.  
**Audience:** Product / SBC / node implementers.  
**Related:** [`NUMBER_WIRE_POLICY.md`](NUMBER_WIRE_POLICY.md) · [`NUMBER_DIALECT_REQUIREMENTS.md`](NUMBER_DIALECT_REQUIREMENTS.md) · [`EGRESS_PLUS_E164_WIRE.md`](../../workingdocs/EGRESS_PLUS_E164_WIRE.md) · MkDocs [DIDs](https://aelintra.github.io/pbx3-docs/fleet/dids/) · [Number dialects](https://aelintra.github.io/pbx3-docs/fleet/number-dialect/)

**Naming:** **SBC** = edge. Carrier **Peers** (upstream carrier, Gamma, Twilio, …) are not the SBC.

---

## Problem

ITSPs disagree on **inbound** and **outbound** number shape (national `0…`, digit E.164, `+E.164`, IDD `00…` / `011…`, CLI/PAID headers, strip/prefix quirks). Today operators stitch that with Peer **dialect** recipes, optional strip/pri_prefix, and node Egress **Mangle**. The **home PBX** must stay peer-unaware (wire policy); the **edge** must absorb carrier locality so the same tenant/trunk story works when a Peer is swapped or a site moves country.

**Goal:** Describe and (over time) implement a **carrier-face contract** so inbound and outbound PSTN work **anywhere** relative to the fleet wire — irrespective of the carrier’s local face — by **normalize / render** at the trunk (Peer) boundary, not by baking carrier habits into Asterisk dialplan.

---

## Desired end state (product)

| Direction | Carrier may send / expect | Fleet / node sees |
|-----------|---------------------------|-------------------|
| **Inbound DID / R-URI** | Whatever that Peer’s dialect accepts | **Always `+E.164`** toward Asterisk (already lab-proven; document as law) |
| **Inbound CLI** | National / `+` / privacy | Best-effort → `+E.164` (or documented passthrough) toward Asterisk |
| **Outbound dialled** | Peer’s required face | Node sends `+E.164` (Phase 1 via Egress Mangle); SBC **renders** Peer face |
| **Outbound CLI / PAID** | Peer’s required headers + shape | Node chooses **value**; SBC **renders** format/header per dialect |

Swapping upstream carrier ↔ Gamma ↔ Twilio (or UK ↔ US Peer set) should be **Peer + dialect (+ serving_cc)** changes — not a rewrite of tenant inroutes / OutRoutes.

---

## Work to schedule (describe → transform → normalize)

1. **Describe (requirements / matrix)**  
   - Per Peer role: inbound accept set, outbound dial render, CLI network vs presentation, privacy.  
   - Explicit “always emit `+E.164` inbound to home” (MkDocs already; keep in this spec as non-negotiable).  
   - Gap list: NANP bare 10-digit seize, ops-authored profiles without tip ([`NUMBER_DIALECT_REQUIREMENTS.md`](NUMBER_DIALECT_REQUIREMENTS.md) §5.4), Phase-2 habit on SBC ([`NUMBER_WIRE_POLICY.md`](NUMBER_WIRE_POLICY.md)).

2. **Transform (operator / migrate surfaces)**  
   - previous PBX DiD → `+E.164` on migrate (lock #15 in `private offline migrate tool`) — done in tip when merged.  
   - Egress seed / tenant create: serving-country transform packs (UK / US) stay aligned with fleet wire.  
   - Document how Class / CLiD stay local while DiD face is canonical.

3. **Normalize (runtime)**  
   - Finish dialect engine so **new recipes compose from primitives** without an OpenSIPS tip (§5.4).  
   - Optional: Phase-2 move habit normalize fully to SBC when gated.  
   - Keep node free of per-carrier strip tables except emergency break-glass.

---

## Non-goals (this stub)

- Baking SBC/Twilio-specific dialplans into GenAst.  
- Auto Fleet DID Allocate from ETL.  
- Changing hop-1 digit-E.164 inventory keys (catalog / `dr_rules.prefix` stay digit form).

---

## Acceptance sketch (later)

- [ ] Spec lists inbound emit + outbound render contracts with examples for ≥2 Peer families (UK ITSP + Twilio-class).  
- [ ] Lab: same tenant inroutes (`+E.164`) answer when carrier face changes (national vs `+`) on one Peer dialect.  
- [ ] Lab: outbound to two Peers with different CLI face without changing node CLIP storage.  
- [ ] Ops can add a recipe from primitives without shipping a new OpenSIPS tip (§5.4).

---

## Pointers

| Doc | Use |
|-----|-----|
| `NUMBER_WIRE_POLICY.md` | Who owns habit vs carrier face |
| `NUMBER_DIALECT_REQUIREMENTS.md` | Recipe grammar + §5.4 compose-without-tip |
| `ORIGIN_OUTBOUND_ROUTING_DESIGN.md` | Per-home outbound groups (related, parked) |
| MkDocs `fleet/dids.md` | SBC always emits `+E.164` inbound |
| `private offline migrate tool` REQUIREMENTS #15 | Migrate DiD pkeys to `+E.164` |
