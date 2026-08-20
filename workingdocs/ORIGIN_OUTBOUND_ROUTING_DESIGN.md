# Origin outbound routing — design (#5d + smarter mangle)

**Status:** Design **accepted 2026-08-19** — **parked past first candidate out.** Most customers do not need multi-country trunks for v1; nationally homed instances + one Peer class per home remain the first-out story. Build on a **later out** when scheduled.  
**TODO:** product **#5d** (Phase A). Phase B is §3.E companion (not blocking §3.A / first out).  
**Locks this rests on:** [`MULTI_LOCALE_INSTANCE_REQUIREMENTS.md`](MULTI_LOCALE_INSTANCE_REQUIREMENTS.md) **§3.A / §3.D / §3.E / §9** · [`NUMBER_WIRE_POLICY.md`](../pbx3-directory/docs/NUMBER_WIRE_POLICY.md) · [`FLEET_TRUNK_PEERING_DECISION.md`](../pbx3-directory/docs/FLEET_TRUNK_PEERING_DECISION.md) · [`EGRESS_PLUS_E164_WIRE.md`](EGRESS_PLUS_E164_WIRE.md)

---

## 1. One-sentence goal

Every outbound PSTN call carries an **invisible origin policy** (tenant / home `serving_cc`): habit → `+E.164` and Peer selection both follow that origin — the caller never dials a CPS code or picks a carrier.

---

## 2. Problem (today)

OpenSIPS `FROM_ASTERISK` hardcodes:

```text
do_routing(0, …)
```

Group **0** is a **global** dest-prefix table. Longest-prefix therefore lets Peers **steal cross-border dests** from the wrong home class:

| Origin | Dialled (after mangle) | Wrong winner in shared group 0 | Correct Peer set |
|--------|------------------------|--------------------------------|------------------|
| UK-homed | NANP `1…` | Twilio | UK ITSPs (intl from UK) |
| US-homed | UK `44…` | Magrathea | US / Twilio (intl from US) |

Lab symptom: UK CLIP → Twilio **403**. Parking a rule is a band-aid, not product.

**Wanted inside one origin group (§3.D):** Magrathea vs Gamma priority / dest-class (`0800` → Gamma else Magrathea). That stays dest-based **within** the group.

---

## 3. Product principles (locked for this design)

1. **Hidden CPS** — default “carrier preselect” is a **call characteristic**, not a dialled access code. Derived from tenant / home origin. Optional digit preselect (`StripPreselect`) stays a power-user/ops escape hatch, not desk UX.
2. **All E.164 from an origin** use that origin’s Peer set — domestic **and** international.
3. **Smarter mangle ≠ bilingual mask** — never stuff `0:+44` and `1:+1` into one instance-wide transform. Per-tenant (or SBC Phase-2) habit tables instead.
4. **PBX stays Peer-unaware** — one Egress; carriers live on the SBC.
5. **§3.A usual ops** — one nationality per instance is fine with Phase A alone. **§3.E** (mixed-nationality tenants on one box) needs Phase B as well.

---

## 4. Architecture overview

```text
Phone (national habit)
    │
    ▼
Asterisk  ── Phase B: tenant-scoped Mangle ──► +E.164 on Egress
    │         (Phase A: keep instance Egress transform)
    ▼
SBC FROM_ASTERISK
    │  resolve origin → outbound drouting groupid
    │  do_routing($var(out_group))
    │  dest-prefix + priority / failover inside group
    ▼
Peer dialect → carrier
```

| Layer | Phase A (#5d — later out) | Phase B (§3.E — later still) |
|-------|-------------------------------------------|-------------------------|
| **Who picks carriers** | Origin → `groupid`; dest rules inside group | Same; prefer **tenant** origin when mixed |
| **Who mangling** | Instance Egress transform (today) | Tenant transform **or** SBC habit(`serving_cc`) per NUMBER_WIRE Phase 2 |
| **Caller sees** | Nothing new | Nothing new |

---

## 5. Phase A — outbound drouting group per origin (#5d)

### 5.1 Group model

Reserve numeric outbound `groupid`s by **serving country / policy**, not by dest CC.

| `groupid` | Role | Example contents |
|-----------|------|------------------|
| **0** | **Legacy / default** — keep for solo / transitional; prefer empty of mixed-national Peers once A ships | Until cutover: today’s table **or** deprecate to “unscoped fallback only” |
| **1** | **Inbound DID** (unchanged) | DID prefix → Asterisk gwid |
| **10+** | **Origin outbound policies** | One per `serving_cc` (or named policy) |

**Lab seed (illustrative):**

| Policy | `groupid` | Rules (sketch) |
|--------|-----------|----------------|
| `cc=44` (UK) | **10** | `44…` → Magrathea (prio); `0800…` → Gamma; `1…` → Magrathea intl; default → Magrathea |
| `cc=1` (US) | **20** | `1…` → Twilio; `44…` → Twilio intl; failover as configured |

Exact IDs are an ops convention; catalog stores the integer (or a named key that projects to it).

**Rule:** Twilio’s `prefix=1` lives **only** in the US group. Magrathea’s `prefix=44` lives in the UK group. Cross-border dests are **intl rules on the origin group**, not foreign Peer prefixes in a shared table.

### 5.2 How OpenSIPS selects the group

Today `CHECK_IS_FROM_ASTERISK` only sets `$var(is_from_asterisk)` via dispatcher SQL on `$si`. Extend that path (or a sibling route) to also resolve **outbound group**.

**Preferred resolution order (first hit wins):**

1. **Tenant domain (From / PAI host)** → catalog or SBC `domain` / `dr_groups` row → `outbound_dr_group`  
   - Fleet already sends per-tenant From (`sip:…@tenant.fqdn`) on PrefixDial faces; Egress path should expose tenant domain the same way where possible.
2. **Home / dispatcher attrs** for `$si` → `outbound_dr_group` or `serving_cc` → mapped group  
   - Fleet dispatcher attrs already carry `fleet=node;instance=…` (`FleetNodeProvisioner`). Extend with `serving_cc=` and/or `out_group=`.
3. **Fallback** → `groupid` **0** (or a configured default) + `xlog` warning so mixed fleets don’t silently steal.

Then:

```text
# conceptual — not implementation
route(RESOLVE_OUTBOUND_GROUP);   # sets $var(out_group)
do_routing($var(out_group), , , , $var(out_gw_attrs));
```

**Do not** key group solely on dialled CC. That recreates steal.

### 5.3 Catalog / Gatekeeper projection

| Field | Where | Notes |
|-------|-------|--------|
| `serving_cc` | Instance (v1) and/or tenant (Phase B) | ITU CC string (`44`, `1`) |
| `outbound_dr_group` | Optional override | Explicit int if policy ≠ 1:1 with CC |
| Projection | Dispatcher attrs + optional `dr_groups` | On Provision edge / instance PATCH / tenant home change |

Gatekeeper remains source of catalog truth; SBC admin rows stay fleet-tagged (Rule 13). No browser IAM.

**Instance v1 (matches §3.A):** one `serving_cc` per home is enough — all tenants on that box share the outbound group.  
**Tenant later (§3.E):** tenant `serving_cc` overrides when mixed nationals share a box; instance field becomes default only.

### 5.4 Admin / ops surface

- Filament (or Fleet): list outbound **policies** (groupid ↔ serving_cc ↔ Peer set).
- Seed scripts: split today’s group-0 carrier rules into origin groups; leave inbound group **1** alone.
- `dr_reload` after projection (existing MI path).

### 5.5 Non-goals for Phase A

- Caller-facing CPS digits or “pick Magrathea” UI.
- Changing CLIP ownership (PBX still owns value; SBC dialect formats).
- Emptying node Egress mangle (NUMBER_WIRE Phase 2 is separate / gated).
- Multi-Egress trunks on one instance to fake Peer pick.
- Building tenant-scoped mangle (that is Phase B).

### 5.6 Acceptance (lab)

| # | Case | Pass |
|---|------|------|
| A1 | US-homed → NANP | Twilio (or US Peer) |
| A2 | US-homed → UK `44…` / IDD | **Same US Peer set** (not Magrathea steal) |
| A3 | UK-homed → UK national | Magrathea/Gamma per in-group rules |
| A4 | UK-homed → NANP | **UK Peer set** intl (not Twilio steal / no CLIP 403) |
| A5 | UK group: Magrathea fail → Gamma | `use_next_gw` / gwlist order works |
| A6 | Unknown origin | Fallback group + logged; no silent cross-Peer |

---

## 6. Phase B — smarter mangle (companion, not #5d)

### 6.1 Why

Hidden CPS alone does **not** fix: UK tenant dials `07…` on a box whose only Egress mask is `011:+ 1:+1`. Habit collision is a **mangle** problem.

### 6.2 Options (pick at build time; preference order)

| Option | Mechanism | Pros | Cons |
|--------|-----------|------|------|
| **B1 Tenant transform on node** | `cluster` (or tenant row) holds transform; `Mangle` uses caller’s tenant table before Dial | Fits Phase-1 NUMBER_WIRE; move takes habit | GenAst / CAGI changes; two nationals on one dialplan still need careful OutRoutes |
| **B2 SBC habit from tenant `serving_cc`** | Node passthrough; SBC normalizes habit → `+E.164` then `do_routing` | Habit + origin group co-located; move = setid + catalog | NUMBER_WIRE Phase 2 gate; never both node+SBC habit |
| **B3 Route profiles** | OutRoute pattern → locale profile (transform + CLIP pool) | Flexible | Dialplan complexity; support burden |

**Design lean:** prefer **B1** for near-term §3.E capability while Phase 1 wire policy holds; migrate toward **B2** when Phase 2 is gated. Do **not** productize bilingual instance masks.

### 6.3 Shared key with Phase A

Both phases should use the same origin key: **`serving_cc`** (tenant when present, else instance).

```text
serving_cc
  → habit table (mangle)
  → outbound_dr_group (Peers)
```

Caller still only dials national / IDD habit for **their** tenant.

### 6.4 Non-goals for Phase B

- Teaching one mask both UK `0` and US `1` as equal first-class seizes.
- Dest-CC auto CLIP as a substitute for origin policy.
- Requiring users to dial digit-E.164 only (unhomed §8 remains optional exploration).

---

## 7. Mapping to existing code (build pointers — not a task list)

| Area | Today | Change when building |
|------|-------|----------------------|
| `pbx3sbc` `opensips.cfg.template` | `do_routing(0, …)` after `CHECK_IS_FROM_ASTERISK` | Resolve `$var(out_group)`; pass to `do_routing` |
| `CHECK_IS_FROM_ASTERISK` | COUNT on dispatcher by `$si` | Also SELECT attrs / setid / out_group |
| `FleetNodeProvisioner` | `fleet=node;instance=;setid=` | Add `serving_cc` / `out_group` |
| Gatekeeper catalog | Instance label / setid | Persist `serving_cc` (+ optional `outbound_dr_group`); project on provision |
| `dr_rules` lab seed | Shared group 0 + Twilio `1` | Split into origin groups; inbound **1** untouched |
| Egress / `Mangle` | Instance trunk transform | Phase A: unchanged. Phase B: tenant transform or SBC habit |
| pbx3cagi `StripPreselect` | Legacy access-prefix strip | Leave as optional override; not default UX |

---

## 8. Effort sketch (when scheduled)

| Slice | Rough | Notes |
|-------|-------|-------|
| **A — design → lab green** | ~2–4 eng days | Cfg + attrs + seed split + A1–A6; Gatekeeper field + provision |
| **A — Fleet UX polish** | ~1 day | serving_cc on instance edit; docs |
| **B1 tenant mangle** | ~3–5 eng days | Schema + GenAst/CAGI + seeds + mixed-tenant lab |
| **B2 SBC habit** | Larger; gated | Depends on NUMBER_WIRE Phase 2 advertise |

Testing: matrix A1–A6 on two homes (Toliman US + UK-homed) is the minimum bar for A. B needs two tenants with different `serving_cc` on **one** instance.

---

## 9. Decision log

| Date | Decision |
|------|----------|
| 2026-08-19 | Design only; no build this pass. |
| 2026-08-19 | CPS = hidden origin policy, not dialled feature. |
| 2026-08-19 | Phase A = per-origin `do_routing` group (#5d). Phase B = smarter (tenant/SBC) mangle for §3.E. |
| 2026-08-19 | Dest-based Peer pick remains **inside** an origin group (§3.D). |
| 2026-08-19 | Do not fix steal by parking Twilio rules or bilingual Egress masks. |
| 2026-08-19 | Design accepted; **not first candidate** — later out. Usual ops = one nationality / one carrier class per home. |

---

## 10. Open questions (resolve at build kickoff)

1. **Group id scheme** — fixed map `serving_cc → groupid` vs free `outbound_dr_group` per home?  
2. **Tenant From on all Egress INVITEs** — confirm every PSTN seize carries tenant domain today; if not, home-level attrs cover Phase A.  
3. **Deprecate group 0** — empty it after cutover, or keep as explicit fallback only?  
4. **Phase B first option** — lock B1 vs wait for B2 before any mixed-tenant production?
