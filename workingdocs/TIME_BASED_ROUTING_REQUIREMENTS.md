# Time-based routing requirements (day-parts + route profiles)

**Status:** Requirements draft — design direction locked 2026-07-26; open questions in §8. **No implementation yet.**  
**Scope:** Instance / tenant inbound schedule → destination selection (`dateseg`, `holiday`, `pbx3timer.php`, `CheckState` / `CheckTime`, `inroutes`, SPA Day/Holiday timers + Inbound).  
**Not:** Fleet control plane, SBC, or FreePBX-style time-condition chains (deferred — §6).  
**Related:** `pbx3cagi/workingdocs/REFACTOR_PLAN.md` (Phase 4 parked — this track changes CheckState contract first) · canvas study [time-based routing review](file:///Users/jeffstokoe/.cursor/projects/Users-jeffstokoe-GiT-pbx3-master/canvases/time-based-routing-review.canvas.tsx) · SARK convert: `db_legacy_sql/`, TODO SARK V6 normalize gap.

---

## 1. Problem

Today the product exposes **OPEN / CLOSED / AUTO**, but the call path only ever resolves **two** outcomes:

| Operator sees | Call path does |
|---------------|----------------|
| AUTO | Follow schedule |
| OPEN / CLOSED (manual or schedule) | Branch to `inroutes.openroute` or `inroutes.closeroute` |

`dateseg` (Day timers) + `holiday` + `pbx3timer.php` (~1/min) write tenant state (`cluster.oclo`, `routeoverride`). CAGI `CheckState` / `CheckTime` read that state (plus AstDB `OCSTAT` overrides) and pick one of two DID destinations.

**Weakness:** Competitors support multiple day-parts (lunch, evening shift, …). pbx3 customers need **custom apps** for that — flexible but not self-serve. The open/close pair on every DID is also a poor UX for anything beyond binary hours.

---

## 2. Current behaviour (baseline — do not regress without migrate)

### 2.1 Schedule evaluation (cron)

1. **Holidays** with `stime ≤ now ≤ etime` → set `cluster.routeoverride` to holiday `route` (clear when inactive).  
2. **dateseg** rows: match month / day-of-week / date-of-month / `timespan`.  
3. Default each tenant to **OPEN**; any matching dateseg → **CLOSED** (windows are *closed* periods, not open hours).  
4. Write `cluster.oclo` and `dateseg.state` (`IDLE` / `*INUSE*`); refresh readonly SQLite when changed.

### 2.2 Call-time decision (CAGI)

1. Load DID `openroute` / `closeroute` (and cluster).  
2. Master AstDB `STAT/OCSTAT == CLOSED` → **closeroute** (does **not** apply holiday `routeoverride` today).  
3. Else `CheckTime`: non-empty `routeoverride` → treat as CLOSED and rewrite closeroute; else tenant/master AstDB `OCSTAT`; else `cluster.oclo`.  
4. Goto open or close destination in tenant context.

### 2.3 Manual / BLF

GenAst emits MASTER / per-tenant BLF and `*30*`–`*34*` style throws that toggle AstDB between **CLOSED** and **AUTO** (resume schedule).

### 2.4 What we keep as a strength

**Precompute in cron; O(1) at call time.** Do **not** move to dialplan `GotoIfTime` forests (classic FreePBX cost: every call re-qualifies calendar / holidays). Minute lag is acceptable for business hours.

---

## 3. Goals

1. Support **N named schedule modes** (day-parts), not only OPEN/CLOSED.  
2. Remove the special **open/close dropdown pair** as the primary DID routing UI.  
3. Keep **tenant-wide current mode** (BLF / “are we open?” / master force still make sense).  
4. Keep **cron precompute** + thin CAGI lookup.  
5. **Forward-convert** SARK / existing pbx3 DBs without silent behaviour change.  
6. Leave **custom apps** as the escape hatch for exotic logic.  
7. Defer FreePBX **time-condition chains** (optional later).

---

## 4. Locked direction

### 4.1 Product model: day-parts + route profiles

| Concept | Role |
|---------|------|
| **Schedule mode** | Tenant-wide label for “what period are we in now?” (e.g. `open`, `closed`, `lunch`, `evening`). Written by timer (and optional manual force). |
| **Day timer (`dateseg`)** | Calendar window that, when matched, sets the tenant to a **mode** (not only CLOSED). |
| **Route profile** | Named map **mode → destination** (IVR, queue, extension, app, …). Reusable across DIDs. |
| **DID / inbound** | Thin: **which profile** (or single entry dest). Not a binary open/close state machine. |
| **Holiday** | Force a **mode** and/or a **destination override** (today’s `routeoverride` cleaned up). |
| **Custom app** | Unchanged escape hatch. |

**Not v1 default:** FreePBX time-condition objects (match → A, fail → B chains) or per-call `GotoIfTime`. Those remain a possible **later** advanced layer sharing the same calendar tables.

### 4.2 Why not FreePBX-first

- FreePBX is familiar in Asterisk reseller land, not best-in-class UX.  
- TC chains fight the existing tenant-wide timer + BLF mental model.  
- Day-parts + profiles **evolve** `oclo` / open-close instead of replacing the authority model.  
- Cloud / 3CX-style “open / lunch / after hours” matches competitor expectations without dialplan calendar tax.

### 4.3 Evaluation locus (locked)

| Layer | Responsibility |
|-------|----------------|
| `pbx3timer.php` (or successor) | Evaluate holidays + day timers; write **current mode** (+ holiday override fields). |
| CAGI `CheckState` | Read mode (+ manual AstDB force); resolve destination via **profile** (fallback: legacy columns). |
| GenAst | BLF / feature codes force **mode** (or CLOSED/AUTO as special cases of mode). |
| Dialplan | No `GotoIfTime` schedule forest. |

---

## 5. Target shape (logical — schema names TBD at implement)

### 5.1 Day timer

Existing `dateseg` calendar fields retained. Add:

- **`mode`** — schedule mode this window asserts when matched.  
- **Priority / order** — when multiple windows match (policy in §8).  
- Migrate existing rows: **`mode = closed`** (preserves today’s match ⇒ CLOSED).

### 5.2 Tenant state

- **`sched_mode`** (new) or widened **`oclo`** — current resolved mode string.  
- Holiday: keep ability to force destination; prefer explicit **force mode** and/or **force dest** over overloading “always CLOSED path.”

### 5.3 Route profile

- Profile header: id, tenant (`cluster`), name, optional default mode when lookup misses.  
- Profile lines: `(mode, destination)` — destination uses the same dialplan target vocabulary as today’s open/close routes.  
- Stock convert: one profile (or per distinct pair) with `open` → former `openroute`, `closed` → former `closeroute`.

### 5.4 Inbound (`inroutes`)

- **`route_profile`** (or equivalent FK / shortuid).  
- Optionally a single **entry** destination if “always the same” (no schedule).  
- Keep **`openroute` / `closeroute`** populated through dual-read period; SPA stops presenting them as primary UI once profiles ship.

### 5.5 CAGI dual-read (required for convert)

```text
mode = resolve(master AstDB, holiday, tenant AstDB, sched_mode)
if DID has profile:
    dest = profile[mode] or profile.default or safe fallback
else:
    dest = (mode in closed-like) ? closeroute : openroute   # legacy
Goto dest
```

Exact “closed-like” set and fallbacks locked at implement with tests.

---

## 6. Non-goals (v1)

- FreePBX time-condition chain UI / objects.  
- Evaluating Christmas / hours in `extensions.conf` via `GotoIfTime`.  
- Dropping custom apps.  
- Immediate drop of `openroute`/`closeroute` columns (only after convert + lab proven).  
- CAGI Phase 4 domain file splits (parked until this contract is stable).

---

## 7. SARK / existing DB conversion (first-class)

SARK already has `dateseg`, `Holiday`, `openroute`/`closeroute`, `oclo`, `routeoverride`. Conversion is **transform-in-place**.

**Idempotent migrate** (postinst / `migrateLegacyDb` follow-on / one-shot SQL+PHP), after cluster shortuid normalize where needed:

1. `dateseg.mode = 'closed'` where null/empty.  
2. Build route profiles from distinct `(openroute, closeroute)` per tenant (or per DID — choose at implement; prefer fewer shared profiles).  
3. Point each DID at the matching profile; **leave** open/close columns filled.  
4. Map `oclo` OPEN/CLOSED → `sched_mode`.  
5. Holidays: preserve `route` as force-dest (and/or `mode=closed`) so behaviour matches today’s CheckTime override.  
6. Document operator steps next to SARK V6 / fixRi / `sqlite_normalize_cluster_to_shortuid.sql` (dateseg/holiday already called out as normalize gap on TODO).

**Acceptance:** A golden/SARK DB after convert: same destinations for open and closed periods as before, without SPA profile edits.

---

## 8. Open questions (lock before code)

| Id | Question | Notes |
|----|----------|--------|
| **Q1** | Default when **no** day-timer matches: `open` (today) or `closed` (typical “office hours”)? | Affects UX and convert; can keep today for v1. |
| **Q2** | Mode catalog: fixed set (`open`/`closed`/`lunch`/`evening`/…) vs tenant-defined free labels? | Fixed is easier for SPA + BLF; free is more flexible. |
| **Q3** | Overlap policy: priority order, most-specific wins, or forbid overlaps in UI? | Timer must be deterministic. |
| **Q4** | Holiday: force destination (today), force mode, or both? | Recommend both; clarify master-force interaction. |
| **Q5** | Master / BLF hard-close: should it still **ignore** holiday destination (today’s quirk)? | Prefer: force mode `closed` still honour holiday dest override, or document intentional ignore. |
| **Q6** | Profile ownership: per-tenant only? Instance-shared profiles? | Start tenant-scoped. |
| **Q7** | Invert calendar UX later (“open hours” windows) vs keep closed-window semantics? | Optional; independent of profile work. |

---

## 9. Delivery slices (when scheduled)

Do **not** interleave with other dial-locus / GenAst contract changes. Design lock (§8) first; then:

| Slice | Repos | Operator-visible |
|-------|--------|------------------|
| **A** — schema + idempotent convert + CAGI dual-read | pbx3, pbx3api, pbx3cagi | None (legacy path) |
| **B** — timer writes `sched_mode` / multi-mode | pbx3 | Timer status may show mode |
| **C** — Profiles SPA + inbound “use profile” | pbx3api, pbx3spa | New UI; hide open/close primary |
| **D** — BLF / feature codes force mode; holiday cleanup | pbx3, GenAst, SPA | Manual day-part force |
| **E** — Deprecate columns / help text (later) | all | Clean model |

Offline `make test` + golden inbound cases (open, closed, holiday, master force) after each slice that touches CAGI.

---

## 10. Repo / component checklist

| Component | Change |
|-----------|--------|
| `sqlite_create_tenant.sql` (+ Laravel migrates) | mode, profile tables, inbound FK, sched_mode |
| `pbx3timer.php` | Multi-mode resolve; priority; holiday fields |
| `pbx3cagi` CheckState/CheckTime | Profile lookup + dual-read |
| `GenClass` BLF / *codes | Mode force |
| pbx3api | DayTimer, HolidayTimer, Profile, InboundRoute |
| pbx3spa | Day timers mode; Profiles panel; Inbound UI |
| Legacy convert script | §7 |
| `tt_help_core` | Retire open/close-as-primary help when UI moves |

---

## 11. Sequencing vs other work

- **After** current GenAst A–H + cagi through 3.2 lab confidence.  
- **Own track** — not “cagi Phase 4” and not a drive-by on inbound SPA.  
- **Before** FreePBX TC chains, CAGI Phase 4 domain splits, or a full SARK V6 rewrite (this convert is the schedule piece those should assume).  
- Park until §8 answers are explicit (“do it anyway” only with accepted exceptions).

---

## 12. Success criteria

1. Tenant can define ≥3 modes and route different DIDs via profiles without custom apps.  
2. Converted SARK/pbx3 DB: binary open/close behaviour unchanged until operator edits profiles.  
3. Call path remains precompute + lookup (no GotoIfTime schedule forest).  
4. Manual / master override still usable (mode force).  
5. Custom apps still reachable as destinations.

---

## 13. Revision

| Date | Note |
|------|------|
| 2026-07-26 | Initial draft from design session: day-parts + profiles; cron kept; FreePBX deferred; SARK convert first-class; Phase 4 cagi parked pending this contract. |
