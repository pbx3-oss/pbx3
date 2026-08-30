# Number wire policy — who does what

**Status:** Policy locked **2026-08-06** (D1 = Model C).  
**Audience:** Operators and implementers configuring fleet PSTN.  
**Detail / decision log:** [`NUMBER_WIRE_STANDARD_DRAFT.md`](NUMBER_WIRE_STANDARD_DRAFT.md) · Peer dialects: [`NUMBER_DIALECT_REQUIREMENTS.md`](NUMBER_DIALECT_REQUIREMENTS.md) · Phase-1 node practice: [`EGRESS_PLUS_E164_WIRE.md`](../../workingdocs/EGRESS_PLUS_E164_WIRE.md) · Trunk face program: [`TRUNK_CARRIER_FACE_NORMALIZATION_REQUIREMENTS.md`](TRUNK_CARRIER_FACE_NORMALIZATION_REQUIREMENTS.md)

**Naming:** Say **the SBC** for our edge. **Magrathea** / **Gamma** are UK ITSP **Peers** the SBC talks *to* — not the SBC.

---

## One-sentence policy

**The SBC is the translator** (carrier face always; dial habit when it has serving-country context). **The PBX stays an uncompromised appliance** (what to dial, which CLI *value*, dial plan / CoS) — never peer-aware. Do as much on the SBC as we can **without** breaking or emptying the PBX’s Phase-1 path before the edge is ready.

---

## Who owns what

| Concern | Owner | Notes |
|---------|--------|--------|
| What the user dials (national / IDD / `+`) | **Phone / PBX dial plan** | Habit of the country that PBX serves |
| Which CLI *number* to send | **PBX** (extension / cluster / route) | Value only — not carrier header shape |
| Dial plan, CoS, routing on-node | **PBX** | Unchanged |
| Habit → unambiguous form (Phase 1 **now**) | **PBX** Egress transform (`Mangle`) | Seed per **primary** serving country (e.g. UK `00:+ 0:+44`). Cross-border other countries → IDD, not a second national seize — **`MULTI_LOCALE_INSTANCE_REQUIREMENTS.md`** |
| Habit → unambiguous form (Phase 2 **later**) | **SBC** using instance `serving_cc` | Only when SBC advertises habit-accept; then node Mangle may empty |
| Fleet wire node ↔ SBC / Asterisk inbound | **`+E.164`** | Canonical after normalize |
| Inventory / DID / drouting key | **Digit E.164** (no `+`) | Catalog + SBC `dr_rules.prefix` |
| How dialled + CLI look to a **carrier** | **SBC Peer dialect** | Rule 13 — format **recipe** on the Peer (not one preset per ITSP/country; §5.3). Compose new recipes from primitives **without a tip** (§5.4). |
| Ad hoc strip/prefix on a gateway | **Emergency only** | Prefer a named dialect recipe |

```text
Phase 1 (now):
  Phone habit → PBX Mangle → +E.164 → SBC → Peer dialect → Carrier
  Carrier → SBC dialect → +E.164 → PBX

Phase 2 (gated):
  Phone habit → PBX (passthrough) → SBC habit(serving_cc) → +E.164 → Peer dialect → Carrier
```

---

## Hard rules

1. **Carrier face never on the PBX** — no “this trunk is Magrathea so use `0`.”  
2. **Never both** node habit-Mangle and SBC habit-normalize on the same call.  
3. **Never neither** — do not empty Egress transform while SBC habit-accept is off.  
4. **DID prefixes** on the SBC = digit E.164; **inroutes** on the node = `+E.164`.  
5. **Panel display** may show national; storage / match keys follow the table above.

---

## Operator quick guide

| You are doing… | Do this |
|----------------|---------|
| Seeding a **UK** fleet node | Keep Egress transform for UK habit → `+44…` (see Egress wire doc). |
| Seeding a **US** fleet node | Use a US/NANP transform — not UK `0:+44`. |
| Adding a **carrier Peer** | Configure a **format recipe** (dialect) on the Peer — not a node mask and not a new id per ITSP logo. |
| Creating a **DID** | Catalog / drouting = digit E.164; node inroute = `+E.164`. |
| Wondering if the PBX should “speak Brindley” | **No.** Lab adapters (if any) are SBC Peer presets. |
| Stripping node Mangle because “the SBC should do it” | **Not yet.** Phase 2 only after `serving_cc` + habit-accept advertise. |
| Seeing **400 E.164 required** on outbound | Home sent habit (`0…` / `00…`), not fleet wire. Fix Egress transform (Phase 1). |

---

## Phases (Model C)

| Phase | Status | Habit producer | Carrier translator |
|-------|--------|----------------|--------------------|
| **1** | **Current** | PBX Mangle | SBC Peer dialect |
| **2** | When gated | SBC (`serving_cc`) | SBC Peer dialect |

Phase 2 is **not** scheduled by this policy alone — see draft §8 / §11. Until then, Phase 1 is correct product behaviour, not a temporary hack to feel guilty about.
