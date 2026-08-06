# Number wire standard (DRAFT — D1 locked)

**Status:** **D1 locked 2026-08-06** (Model **C** — see §4 / §9). D2–D4 still open. **Do not strip node Mangle** until SBC habit-normalize is real and gated. Canonical surfaces (§3) and Peer-dialect ownership stand.  
**Operator policy (who does what):** [`NUMBER_WIRE_POLICY.md`](NUMBER_WIRE_POLICY.md) — start there.  
**Date:** 2026-08-02 (D1 locked 2026-08-06)  
**Prompted by:** Kildare greenfield + Brindley DID lab — works only after hop-by-hop patches.  
**Related (existing / partly locked):**  
- [`NUMBER_WIRE_POLICY.md`](NUMBER_WIRE_POLICY.md) — **who does what** (operator / implementer)  
- [`NUMBER_DIALECT_REQUIREMENTS.md`](NUMBER_DIALECT_REQUIREMENTS.md) — Peer dialects (locked UK-first presets)  
- [`EGRESS_PLUS_E164_WIRE.md`](../../workingdocs/EGRESS_PLUS_E164_WIRE.md) — current “node Mangle → +E.164” practice  
- [`CARRIER_NUMBERING_EXPECTATIONS_RESEARCH.md`](../../workingdocs/CARRIER_NUMBERING_EXPECTATIONS_RESEARCH.md) — PTT vs SIP face; UK/US matrices; research gaps  
- [`DESIGN_RULES.md`](DESIGN_RULES.md) Rule 13 — edge-authored carrier behaviour  
- Lab lesson: Brindley path needed `_0…` / `_00…` after ad hoc edge strip/prefix; Magrathea/Twilio want other shapes.

**Naming (operator 2026-08-06):** Say **the SBC** for our edge (OpenSIPS). **Magrathea** is a **UK tier-2 carrier / ITSP** (like Gamma) — a **Peer** the SBC talks *to*, not the SBC itself. Lab habit of calling the edge host “Magrathea” is confusing; prefer host/VIP/`pbx3sbc` in ops notes. Same for docs and agent language going forward.

**Brindley posture (operator 2026-08-06):** Brindley is a **lab Asterisk trunker**, not a PTT / wholesale ITSP with numbering-plan ownership. AFAIK it mostly **accepts what the PTT sends and ships it on**, and **accepts what the PBX sends and ships it on**; transform masks exist but are **ad hoc**. Do **not** treat Brindley as the Peer archetype for this decision or for product dialect law. Real layer-B examples: Magrathea / Gamma / Twilio-class. A named `uk-brindley` / `uk-national` preset (if any) is optional **lab CPE adapter**, not the driver of D1. Lab strip2/prefix0 was fitting our edge to Brindley’s dialplan, not discovering a carrier contract.

**Product posture (operator 2026-08-06 — D1):** Do **what we can on the SBC** without **compromising the PBX**. Third-party SBCs span **passthrough → locality-aware translators**; **the SBC** is a **reliable translation device** (Peer dialect always; habit when it has serving-country context). PBX stays an uncompromised appliance (no peer dialects; CLI value / dial plan / CoS stay on-node).

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

1. **Carrier face (Magrathea / Gamma / Twilio-class Peer dialect; Brindley only as lab adapter if needed)** → **SBC Peer only**.  
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
| **Carrier R-URI / headers** | **Peer dialect** | e.g. Magrathea `+…` / Gamma multi-accept; lab Brindley adapter if used |

**Hard rule:** never store “national DID” as the SBC `dr_rules.prefix` if inbound normalize always produces digit-E.164. Lab bug was exactly that.

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

### Model C — Phased (D1 locked) — SBC translator; PBX uncompromised

**Locked direction (2026-08-06):** Grow **SBC translation** to the maximum that does not compromise the PBX. Commercial SBCs are flexible from **pure passthrough** to **trunk / locality-aware translators**; that is the product identity of the edge.

| Phase | Habit → unambiguous | Carrier face | PBX |
|-------|---------------------|--------------|-----|
| **1 (now)** | Node Egress Mangle (Model A) — keep until gate | Peer dialect | Uncompromised; may emit habit or already-`+E.164` |
| **2 (when ready)** | SBC habit-normalize using instance `serving_cc` / access plan **before** Peer dialect; pass through if already canonical | Peer dialect | Mangle optional / empty only when SBC advertises habit-accept |

**Hard rules under C:**

1. **Never both** node habit-Mangle and SBC habit-normalize on the same call.  
2. **Never neither** (empty Egress while SBC habit is off).  
3. **Never** put Peer / carrier dialect on the PBX.  
4. After edge normalize, fleet routing / Asterisk inbound wire stays **`+E.164`**.  
5. Node Mangle **off** only when fleet mode + SBC **advertises** habit-accept + instance has durable `serving_cc`.

**Does not compromise the PBX:** CLI *value*, dial plan, CoS, inroute match stay on-node; no peer-aware transforms; no flag-day empty seed that breaks outbound.

**End-state intent:** SBC as reliable translator (passthrough when already `+E.164`; locality + Peer dialect when not). Node Mangle is a **Phase-1 producer**, not the long-term identity of numbering policy.

---

## 5. SBC responsibilities (locked-ish under C)

Always true if we standardise:

1. **Peer dialect** = sole carrier-facing transform (inbound parsers + outbound renderers).  
2. **No** permanent lab crock of `strip`/`pri_prefix` *instead of* dialect (allowed as **emergency** only; prefer named preset e.g. `uk-brindley` / `uk-national`: national `0`, IDD `00`).  
3. **DID rules** always matched on **post-normalize digit E.164**.  
4. **Wire to Asterisk** always **+E.164** after DID match (`DIALECT_APPLY_PLUS_WIRE`).  
5. Failover gwlist ordered by **working** peers (Twilio not on UK default path).  
6. **Phase 2:** habit / access-plan normalize on Asterisk→edge when `serving_cc` is known — then Peer dialect (translator, not passthrough-only).

**Lab CPE adapter example (Brindley — not product Peer law):** if retained as a named preset, treat as SARK-style national face for that box only:

| Direction | Accept / render |
|-----------|-----------------|
| Out dial | `0`+NSN, `00`+CC+NSN |
| In DID | national `0…` and/or IDD `00…` → digit E.164 key |

Not a D1 driver — Magrathea/Gamma/Twilio matrices are.

---

## 6. Node responsibilities (under C)

| Concern | Node |
|---------|------|
| Which CLI to send | Yes (routes / phone / cluster) — **value** not **carrier format** |
| Inroute match | **+E.164** pkey only on fleet nodes |
| Out dial plan / CoS | Yes |
| Carrier R-URI / PAID shape | **No** |
| Serving-country habit→+E.164 | **Phase 1:** Mangle mask. **Phase 2 (gated):** none or strip non-digits only; SBC owns habit |

---

## 7. Forbidden mixes (acceptance tests)

1. Magrathea DID prefix = national while inbound dialect produces `44…`.  
2. Node inroute national while SBC delivers `+44…`.  
3. Egress transform empty while SBC habit-normalize is off (or not advertised for that instance).  
4. Peer dialect `null` + random strip/prefix as long-term design.  
5. Same Brindley FQDN used as fleet instance EIP (hairpin).  
6. Double habit rewrite (node Mangle + SBC habit-normalize) on one call.

---

## 8. Migration sketch (Model C → Phase 2)

1. Catalog / instance: **`serving_cc`** (e.g. `44`) — declare on onboard even in Phase 1 (data for humans + future gate).  
2. SBC: Peer dialects + DID/inroute hygiene (independent of habit flip).  
3. SBC: habit normalize on Asterisk-from path, before `do_routing(0)`, using that node’s `serving_cc` → digit E.164 / +E.164; **passthrough** if already `+E.164` / unambiguous.  
4. Advertise habit-accept per instance (or fleet capability).  
5. Only then: seed Egress `transform` empty (or strip non-digits) on opted-in instances.  
6. Panel: DID create always writes digit key + node +E.164 inroute.  
7. Brindley named dialect only if still needed as lab adapter; remove strip2/prefix0 when replaced.  
8. Docs: amend `EGRESS_PLUS_E164_WIRE.md` (wire stays +E.164; Phase-1 producer = node; Phase-2 producer may be SBC).

**Rollback:** re-enable node transform; disable habit-accept advertise for that instance.

---

## 9. Decision log

| # | Question | Options | Decision | Date |
|---|----------|---------|----------|------|
| D1 | Who produces fleet wire +E.164 from habit? | A node Mangle · B SBC · C phased | **C** — SBC-max translation; PBX uncompromised; Phase 1 = A until SBC habit gated | **2026-08-06** |
| D2 | Brindley lab adapter (optional) | named preset `uk-national` / `uk-brindley` / keep strip / drop when unused | *open* — **not** D1 driver | |
| D3 | CLI always stored +E.164 on node? | yes / allow national with SBC fill | *open* | |
| D4 | Display national in SPA only? | yes / show both | *open* | |

**Operator bias recorded (2026-08-02):**  
Prefer **carrier handling at SBC only**; question node Mangle as long-term home for habit→international form.

**Operator lock (2026-08-06) — D1:**  
Do **what we can on the SBC** without **compromising the PBX**. SBC = flexible **passthrough → locality-aware translator** (Peer dialect always; habit when `serving_cc` exists). Keep node Mangle in Phase 1; do not empty it until Phase-2 gate. Brindley is lab pass-through, not Peer archetype. UK Magrathea/Gamma multi-accept + national delivery; US DIDWW/Twilio lean CC/`+1`; E.164/Teams awareness rising.

---

## 10. What we will *not* debate here

- Directory in call path (Rule 1).  
- Inventory E.164 ownership (catalog).  
- Gatekeeper DID projection format once D3 lands (must emit digit keys + +E.164 inroutes).

---

## 11. Next

1. ~~Mark D1~~ **done (C).**  
2. Sketch `serving_cc` HoR (catalog vs onboard globals vs dispatcher attrs) — data even before Phase 2 code.  
3. Continue Peer dialect / DID hygiene (Phase 1 safe).  
4. **Do not** implement SBC habit-normalize or empty Egress until Phase-2 gate design is explicit.  
5. D2–D4 when convenient.
