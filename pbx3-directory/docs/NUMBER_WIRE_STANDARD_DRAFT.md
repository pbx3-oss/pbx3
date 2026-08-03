# Number wire standard (DRAFT — open decision)

**Status:** Draft for operator review. **Not locked. Do not implement as product law until §9 is explicitly accepted.**  
**Date:** 2026-08-02  
**Prompted by:** Kildare greenfield + Brindley DID lab — works only after hop-by-hop patches.  
**Related (existing / partly locked):**  
- [`NUMBER_DIALECT_REQUIREMENTS.md`](NUMBER_DIALECT_REQUIREMENTS.md) — Peer dialects (locked UK-first presets)  
- [`EGRESS_PLUS_E164_WIRE.md`](../../workingdocs/EGRESS_PLUS_E164_WIRE.md) — current “node Mangle → +E.164” practice  
- [`CARRIER_NUMBERING_EXPECTATIONS_RESEARCH.md`](../../workingdocs/CARRIER_NUMBERING_EXPECTATIONS_RESEARCH.md) — PTT vs SIP face; UK/US matrices; research gaps  
- [`DESIGN_RULES.md`](DESIGN_RULES.md) Rule 13 — edge-authored carrier behaviour  
- Lab lesson: Brindley wants `_0…` / `_00…`; Magrathea/Twilio want other shapes.

---

## 1. The mess (what lab taught us)

One call path currently transforms the *same* user meaning several times:

| Hop | Who | What happens (UK mobile example) |
|-----|-----|----------------------------------|
| Phone | User | dials `07949943282` |
| Node Egress transform (`Mangle`) | PBX | → `+447949943282` |
| SBC strip `+` | SBC | → `447949943282` |
| Brindley peer strip/prefix (ad hoc) | SBC | → `07949943282` |
| Brindley | Carrier | answer national `_0…` |

Inbound again reshapes: Brindley `01924918076` → SBC normalize `441924918076` → wire `+441924918076` → node inroute must match **`+…`** while humans typed national in the panel once.

That is correct *if* every layer is disciplined. It was painful because **rules, dialects, and panel values mixed national / digit-E.164 / +E.164** without a single “HoR form per surface.”

**Agreement already in product docs:** **carrier-specific shape is an SBC concern** (Peer dialect).  
**Open disagreement / product tension:** should the **node** run a serving-country habit → +E.164 transform at all?

---

## 2. Design principle (your stated IMHO, as default draft stance)

> **Different carriers require different things. The SBC is the place that adapts to the carrier.**  
> The PBX should present a **single, boring form** toward the fleet edge — and should **not** invent carrier dialects.

That does **not** automatically mean “zero transform on the PBX.” It means:

1. **Carrier face (Brindley national, Magrathea +E.164 / IDD, Twilio +E.164, …)** → **SBC Peer only**.  
2. **PBX** → **never** peer-aware (no “this trunk is Brindley so use 0”).  
3. Optional / contentious: whether **habit → +E.164** is done on the **node** (today’s Mangle) or moved to the **SBC** once it knows the node’s **serving country**.

---

## 3. Canonical surfaces (proposed standard)

| Surface | Canonical form | Example (UK DID) |
|---------|----------------|------------------|
| **Storage / inventory / catalog DID key** | digit E.164, no `+` | `441924918076` |
| **Fleet wire R-URI (node ↔ SBC)** | **+E.164** | `+441924918076` |
| **SBC drouting / DID rule prefix** | digit E.164 | `441924918076` |
| **Node inroute pkey** | **+E.164** (same digits as rule, with `+`) | `+441924918076` |
| **Stored CLI (extension / cluster)** | **+E.164** (recommend) | `+441924918076` |
| **Panel display (optional)** | national / pretty print | `01924 918076` — display only, not HoR |
| **Carrier R-URI / headers** | **Peer dialect** | Brindley `0…` / `00…` |

**Hard rule:** never store “national DID” as the Magrathea `dr_rules.prefix` if inbound normalize always produces digit-E.164. Lab bug was exactly that.

---

## 4. Two models for “who owns habit → fleet wire”

### Model A — Node serves country (status quo after seed)

```text
Phone habit --Mangle(serving_cc)--> +E.164 --Egress--> SBC --dialect--> Carrier
Carrier --dialect--> +E.164 --Ingress--> Node
```

| | |
|--|--|
| **Pros** | SBC always sees unambiguous +E.164; multi-country fleet doesn’t need per-INVITE “where is this node?”; matches current Mangle seed + docs |
| **Cons** | PBX still “knows” UK (`0:+44 00:+`); looks like double work next to SBC dialects; mask bugs (`sizeof` / order) hit the call path |
| **Who does carrier?** | SBC only (correct) |

### Model B — PBX transparent; SBC owns habit (your instinct)

```text
Phone habit --as dialled--> +E.164 or raw? --Egress--> SBC
  SBC: normalize using instance.serving_cc (or catalog) to +E.164 / digit key
  then peer dialect → Carrier
```

| | |
|--|--|
| **Pros** | Single place that “understands numbers”; PBX is not a mini-SBC; all dial/CLI policy for trunks centralizes |
| **Cons** | Every outbound INVITE must map **source Asterisk → serving country**; habit strings are **ambiguous without that** (`011…` US vs `00…` UK); need durable `serving_cc` (or national plan profile) on instance in catalog / edge projection; Greenfield nodes without projection break outbound |
| **Who does carrier?** | SBC only (same) |

### Model C — Soft middle

- Node Mangle **disabled** only when `PBX3_FLEET_MODE` and SBC advertises habit-accept.  
- Until then keep Model A. Migration path.

**Draft recommendation for thinking (not locked):**  
Keep **Model A short-term** (already shipped, Kildare proven) while **hardening Model B** for vNext: catalog `serving_country_code` + SBC outbound habit-normalize *before* peer dialect; then drop Egress transform to empty on new seed. Your “IMHO” lands on **B as end state**.

---

## 5. SBC responsibilities (locked-ish under both models)

Always true if we standardise:

1. **Peer dialect** = sole carrier-facing transform (inbound parsers + outbound renderers).  
2. **No** permanent lab crock of `strip`/`pri_prefix` *instead of* dialect (allowed as **emergency** only; prefer named preset e.g. `uk-brindley` / `uk-national`: national `0`, IDD `00`).  
3. **DID rules** always matched on **post-normalize digit E.164**.  
4. **Wire to Asterisk** always **+E.164** after DID match (`DIALECT_APPLY_PLUS_WIRE`).  
5. Failover gwlist ordered by **working** peers (Twilio not on UK default path).

Brindley-class peer (SARK-style):

| Direction | Accept / render |
|-----------|-----------------|
| Out dial | `0`+NSN, `00`+CC+NSN |
| In DID | national `0…` and/or IDD `00…` → digit E.164 key |

---

## 6. Node responsibilities (under proposed standard)

| Concern | Node |
|---------|------|
| Which CLI to send | Yes (routes / phone / cluster) — **value** not **carrier format** |
| Inroute match | **+E.164** pkey only on fleet nodes |
| Out dial plan / CoS | Yes |
| Carrier R-URI / PAID shape | **No** |
| Serving-country habit→+E.164 | **Model A:** Mangle mask. **Model B:** none (or strip only nonsensical digits) |

---

## 7. Forbidden mixes (acceptance tests)

1. Magrathea DID prefix = national while inbound dialect produces `44…`.  
2. Node inroute national while SBC delivers `+44…`.  
3. Egress transform empty under Model A and no SBC habit-normalize.  
4. Peer dialect `null` + random strip/prefix as long-term design.  
5. Same Brindley FQDN used as fleet instance EIP (hairpin).  

---

## 8. Migration sketch (if Model B accepted)

1. Catalog / instance: **`serving_cc`** (e.g. `44`) required for UK nodes; set on onboard.  
2. SBC: on Asterisk-from path, before `do_routing(0)`: habit normalize using that node’s `serving_cc` → digit E.164 / +E.164.  
3. Seed Egress `transform` = empty (or only strip non-digits).  
4. Panel: DID create always writes digit key + node +E.164 inroute.  
5. Named dialect `uk-national` for Brindley; remove strip2/prefix0.  
6. Docs: amend `EGRESS_PLUS_E164_WIRE.md` (wire stays +E.164; producer moves).  

If Model A retained: only (4)(5)(6-light) + document Mangle as “serving province, not carrier.”

---

## 9. Decision log (fill when you decide)

| # | Question | Options | Decision | Date |
|---|----------|---------|----------|------|
| D1 | Who produces fleet wire +E.164 from habit? | A node Mangle · B SBC · C phased | *open* | |
| D2 | Brindley peer preset name | `uk-national` / `uk-brindley` / keep strip | *open* | |
| D3 | CLI always stored +E.164 on node? | yes / allow national with SBC fill | *open* | |
| D4 | Display national in SPA only? | yes / show both | *open* | |

**Operator bias recorded (2026-08-02):**  
Prefer **carrier handling at SBC only**; **question node Mangle** as the right long-term home for habit→international form. Draft defaults aim at **B as end state**, A as until proven.

---

## 10. What we will *not* debate here

- Directory in call path (Rule 1).  
- Inventory E.164 ownership (catalog).  
- Gatekeeper DID projection format once D1–D3 land (must emit digit keys + +E.164 inroutes).

---

## 11. Next when you return

1. Mark D1 preferred (A / B / C).  
2. If B: sketch `serving_cc` source of truth (catalog vs onboard globals vs dispatcher attrs).  
3. Implement order: dialect Brindley → seed/inroute/DID hygiene → only then strip node Mangle.
