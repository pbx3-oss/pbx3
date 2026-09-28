# Number wire policy — who does what

**Status:** Policy locked **2026-08-06** (D1 = Model C). **Outbound handoff lock (2026-08-29):** tenant/home forms valid E.164 for the SBC.  
**Audience:** Operators and implementers configuring fleet PSTN.  
**Detail / decision log:** [`NUMBER_WIRE_STANDARD_DRAFT.md`](NUMBER_WIRE_STANDARD_DRAFT.md) · Peer dialects: [`NUMBER_DIALECT_REQUIREMENTS.md`](NUMBER_DIALECT_REQUIREMENTS.md) · Phase-1 node practice: [`EGRESS_PLUS_E164_WIRE.md`](../../workingdocs/EGRESS_PLUS_E164_WIRE.md) · Trunk face program: [`TRUNK_CARRIER_FACE_NORMALIZATION_REQUIREMENTS.md`](TRUNK_CARRIER_FACE_NORMALIZATION_REQUIREMENTS.md)

**Naming:** Say **the SBC** for our edge. **SBC** / **Gamma** are UK ITSP **Peers** the SBC talks *to* — not the SBC.

---

## One-sentence policy

**The tenant (via its home) is responsible for forming a valid E.164 number to hand off to the SBC.** The SBC translates **carrier face** only on that wire (Peer dialect). It does **not** guess the site’s national habit / CC — that knowledge lives on the home that serves the tenant (Egress Mangle today). Habit-normalize on the SBC remains a gated Phase-2 idea, not the product default.

Broader framing: **The PBX stays an uncompromised appliance** (what to dial, which CLI *value*, dial plan / CoS) — never peer-aware. **The SBC is the carrier-face translator.** Do not empty Phase-1 Mangle until a Phase-2 habit-accept gate exists.

---

## Who owns what

| Concern | Owner | Notes |
|---------|--------|-------|
| What the user dials (national / IDD / `+`) | **Phone / PBX dial plan** | Habit of the country that PBX serves |
| Which CLI *number* to send | **PBX** (extension / cluster / route) | Value only — not carrier header shape |
| Dial plan, CoS, routing on-node | **PBX** | Unchanged |
| Habit → **valid E.164 handoff to SBC** | **Tenant / home** (Egress `Mangle`) | **Product rule.** Seed per **primary** serving country (e.g. UK `00:+ 0:+44`). Cross-border other countries → IDD, not a second national seize — **`MULTI_LOCALE_INSTANCE_REQUIREMENTS.md`** |
| Habit → unambiguous form (Phase 2 **later**, gated) | **SBC** using instance `serving_cc` | Only if ever advertised; then node Mangle may empty. International seize/CC oddities make this hard — not assumed. |
| Fleet wire node ↔ SBC / Asterisk inbound | **`+E.164`** | Canonical after normalize |
| Inventory / DID / drouting key | **Digit E.164** (no `+`) | Catalog + SBC `dr_rules.prefix` |
| How dialled + CLI look to a **carrier** | **SBC Peer dialect** | Rule 13 — format **recipe** on the Peer (not one preset per ITSP/country; §5.3). Compose new recipes from primitives **without a tip** (§5.4). |
| Ad hoc strip/prefix on a gateway | **Emergency only** | Prefer a named dialect recipe |

```text
Product default (Phase 1):
  Phone habit → home Mangle → +E.164 → SBC → Peer dialect → Carrier
  Carrier → SBC dialect → +E.164 → PBX

Phase 2 (gated, optional):
  Phone habit → PBX (passthrough) → SBC habit(serving_cc) → +E.164 → Peer dialect → Carrier
```

---

## Hard rules

1. **Valid E.164 to the SBC** — the tenant/home forms it; SBC may **`400 E.164 required`** if not.  
2. **Carrier face never on the PBX** — no “this trunk is SBC so use `0`.”  
3. **Never both** node habit-Mangle and SBC habit-normalize on the same call.  
4. **Never neither** — do not empty Egress transform while SBC habit-accept is off.  
5. **DID prefixes** on the SBC = digit E.164; **inroutes** on the node = `+E.164`.  
6. **Panel display** may show national; storage / match keys follow the table above.

---

## Operator quick guide

| You are doing… | Do this |
|----------------|---------|
| Seeding a **UK** fleet node | Keep Egress transform for UK habit → `+44…` (see Egress wire doc). |
| Seeding a **US** fleet node | Use a US/NANP transform — not UK `0:+44`. |
| Adding a **carrier Peer** | Configure a **format recipe** (dialect) on the Peer — not a node mask and not a new id per ITSP logo. |
| Creating a **DID** | Catalog / drouting = digit E.164; node inroute = `+E.164`. |
| Wondering if the PBX should “speak Brindley” | **No.** Lab adapters (if any) are SBC Peer presets. |
| Stripping node Mangle because “the SBC should do it” | **Not the default.** Phase 2 only after `serving_cc` + habit-accept advertise — and that path is internationally hard. |
| Seeing **400 E.164 required** on outbound | Home sent habit (`0…` / `00…`), not fleet wire. Fix Egress transform. |

---

## Phases (Model C)

| Phase | Status | Habit → E.164 | Carrier translator |
|-------|--------|---------------|--------------------|
| **1** | **Product default** | Tenant/home (Egress Mangle) | SBC Peer dialect |
| **2** | Gated / optional | SBC (`serving_cc`) if ever | SBC Peer dialect |

Phase 2 is **not** scheduled by this policy alone — see draft §8 / §11. Phase 1 is correct product behaviour: **tenant forms E.164; SBC does carrier face.**
