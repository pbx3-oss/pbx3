# Time-based routing requirements (day-parts + route profiles)

**Status:** **TRACK COMPLETE 2026-08-04** on **`time-based-routing`**. Slices **A–E** delivered (dual-read retained). Golden: lunch profile + force modes lab green; packages **pbx3 0.0.4-7** + **pbx3cagi 1.0.0-13**; day-parts help applied. SPA profiles primary; open/close demoted. BLF *30/*31 AUTO/CLOSED; multi-mode force via AstDB. **Not** pushed/merged. **Kildare** untouched.  
**Scope:** Instance / tenant inbound schedule → destination selection (`dateseg`, `holiday`, `pbx3timer.php`, `CheckState` / `CheckTime`, `inroutes`, SPA Day/Holiday timers + Inbound + route profiles).  
**Not:** Fleet control plane, **SBC / Magrathea product code** (unchanged path edge), FreePBX-style time-condition chains (deferred — §6), trunk legacy open/close fields.  
**Related:** `pbx3cagi/workingdocs/REFACTOR_PLAN.md` (Phase 4 parked — this track changes CheckState contract first) · `CALL_TEST_STRATEGY.md` / CAGI **`TEST_RECIPE.md`** · canvas study [time-based routing review](file:///Users/jeffstokoe/.cursor/projects/Users-jeffstokoe-GiT-pbx3-master/canvases/time-based-routing-review.canvas.tsx) · SARK convert: `db_legacy_sql/`.

**Lab hosts (2026-08-04):**

| Host | Use |
|------|-----|
| **Golden** (`08jzwn`, EIP `44.196.98.191`) | **Only** instance for package install / call-path / L0–L1 lab for this track. **Slice A lab-gated 2026-08-04:** packages **pbx3 0.0.4-7** + **pbx3cagi 1.0.0-12**; convert + dual-read; offline Ingress `+441924910444` → **1000**. |
| **Kildare** | **No day-parts packages or experiment installs** — operator production phones; may **originate** lab calls only |
| **bzy54n / others** | Not required for this track unless operator says otherwise |
| **SBC (Magrathea)** | **No pbx3sbc product branch / edge feature work** — existing Magrathea path carries the test DID; leave edge config alone unless op says fix |
| **Inbound DID (spare)** | **`01924910444`** / dial/wire forms as lab uses (digit E.164 **`441924910444`**, node Ingress often **`+441924910444`**) — **points at golden** (Magrathea `dr_rules` → gwid golden). Operator-allocated for day-parts L1/smoke. Originate from **Kildare desk** or **SIPp UAC** (`98.93.32.43` / Peer pack host as documented) — do not repoint office DIDs. |

**Convert note:** v1 line shortuids must be unique per profile+mode (profile ‖ `_open`/`_closed`); truncated hex collided — fixed + backfill missing lines.

**Git:** feature branch **`time-based-routing`** from `main` on the four product repos above. **No `pbx3sbc` branch.** Regress = stay off branch / redeploy `main` packages to golden.

**Testing rule (non-negotiable):** Every delivery slice ships with **unit / offline tests written as we go**. Lab (L1 SIPp / golden smoke) where the change hits a real call path — **golden only**. A slice is not done when “it works on golden once” only.

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
5. **Forward-convert** SARK / existing pbx3 DBs without silent behaviour change **for open/close destinations** (holidays = redesigned; convert is best-effort — §8 Q4).  
6. Leave **custom apps** as the escape hatch for exotic logic.  
7. Defer FreePBX **time-condition chains** (optional later).  
8. **Test with the code** — offline unit/L0 every slice; lab L1 where call path changes (§14).

---

## 4. Locked direction

### 4.1 Product model: day-parts + route profiles

| Concept | Role |
|---------|------|
| **Schedule mode** | Tenant-wide label for “what period are we in now?” (e.g. `open`, `closed`, `lunch`, `evening`). Written by timer (and optional manual force). |
| **Day timer (`dateseg`)** | Calendar window that, when matched, sets the tenant to a **mode** (not only CLOSED). |
| **Route profile** | Named map **mode → destination** (IVR, queue, extension, app, …). **Tenant-scoped only** (Q6). Reusable across that tenant’s DIDs. |
| **DID / inbound** | Thin: **which profile** (or single entry dest). Not a binary open/close state machine. |
| **Holiday** | **Redesigned** calendar override: primarily **force mode**; optional **force dest**. Not SARK’s early absolute-time route subversion. |
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
| `pbx3timer.php` (or successor) | Evaluate holidays + day timers; write **current mode** (+ holiday override fields). TZ-aware calendar for holidays. |
| CAGI `CheckState` | Read mode (+ manual AstDB force); resolve destination via **profile** (fallback: legacy columns). |
| GenAst | BLF / feature codes force **mode** (or CLOSED/AUTO as special cases of mode). |
| Dialplan | No `GotoIfTime` schedule forest. |

### 4.4 Call-time mode resolution order (locked)

1. **Operator hard-force** (master / tenant AstDB) if not AUTO — **wins over holiday** (Q5).  
2. Else **active holiday** (force dest if set, else force mode) — above ordinary day timers (Q4).  
3. Else **tenant AstDB** force if not already applied.  
4. Else **`cluster.sched_mode`** from timer (day timers + priority — Q3).  
5. Else default **`open`** (Q1).

Then: profile line for mode, or legacy openroute/closeroute dual-read.

---

## 5. Target shape (logical — schema names TBD at implement)

### 5.1 Day timer

Existing `dateseg` calendar fields retained. Add:

- **`mode`** — schedule mode this window asserts when matched.  
- **`priority`** — higher wins when multiple windows match (Q3); stable tie-break when equal.  
- Migrate existing rows: **`mode = closed`**, priority default (e.g. 0).

### 5.2 Tenant state

- **`sched_mode`** (new) or widened **`oclo`** — current resolved mode string; dual-write/read during transition.  
- Holiday fields: **force_mode**, **force_dest** (product names TBD); not “always CLOSED + rewrite closeroute” only.

### 5.3 Route profile

- Profile header: id, tenant (`cluster`), name, optional default when mode lookup misses.  
- Profile lines: `(mode, destination)` — same dest vocabulary as today’s open/close routes.  
- Stock convert: profiles from distinct `(openroute, closeroute)` per **tenant**; share when pairs match.  
- **No instance-shared live profiles** (Q6) — copy/duplicate is fine.

### 5.4 Inbound (`inroutes`)

- **`route_profile`** (or equivalent FK / shortuid).  
- Optionally a single **entry** destination if always the same (no schedule).  
- Keep **`openroute` / `closeroute`** populated through dual-read period; SPA stops presenting them as primary UI once profiles ship.

### 5.5 CAGI dual-read (required for convert)

```text
mode = resolve(operator force, holiday, tenant force, sched_mode, default open)
if DID has profile:
    dest = profile[mode] or profile.default or safe fallback
else:
    dest = (mode in closed-like) ? closeroute : openroute   # legacy
if holiday force_dest and operator not hard-forcing:
    dest = force_dest   # may short-circuit after mode resolve — exact order in L0 tests
Goto dest
```

Exact “closed-like” set and fallbacks locked at implement **with tests**.

### 5.6 Mode catalog (Q2)

- Always available: **`open`**, **`closed`**.  
- SPA **presets** for common extras (e.g. `lunch`, `evening`, `night`) — not hard special cases in the dialplane.  
- Modes stored as **plain strings** so free tenant labels can ship later without schema change.  
- **No** single catchall mode named `custom` (collapses distinct day-parts).  
- **AUTO** is not a mode — it means clear operator force and follow timer/holiday.

### 5.7 Holiday redesign (Q4)

SARK holiday was a brutal early subversion via absolute epochs + `routeoverride`; OK for UK national days, weak product foundation.

**v1 model:**

- Calendar-first UX evaluated in a **local timezone story** (tenant or instance TZ — pick at implement; document). Not absolute-epoch-only as the product interface.  
- Primary action: set / force a **mode**.  
- Optional **force dest** when a day must leave profile lookup entirely.  
- Precedence: under operator hard-force (Q5), above day timers.  
- Convert of old rows: best-effort (preserve dest where possible); **do not** promise every SARK evaluation quirk. Import notes: “review holiday windows after upgrade.”  
- Recurring national holiday packs / FreePBX-style libraries: not v1 unless scheduled separately.

### 5.8 Calendar UX (Q7)

Keep **closed-window** evaluation: default **open** when nothing matches; day timers assert modes (usually closed periods). Invert to “open hours” UX / default closed is **parked** after profiles ship (optional sugar generator later without changing engine first).

---

## 6. Non-goals (v1)

- FreePBX time-condition chain UI / objects.  
- Evaluating Christmas / hours in `extensions.conf` via `GotoIfTime`.  
- Dropping custom apps.  
- Immediate drop of `openroute`/`closeroute` columns (only after convert + lab proven).  
- CAGI Phase 4 domain file splits (parked until this contract is stable).  
- Instance-shared profile library (Q6).  
- Open-hours calendar invert as default product (Q7).  
- Faithful preservation of SARK holiday absolute-time subversion (Q4).

---

## 7. SARK / existing DB conversion (first-class for **open/close + timers**)

SARK already has `dateseg`, `Holiday`, `openroute`/`closeroute`, `oclo`, `routeoverride`. Conversion is **transform-in-place** where possible.

**Idempotent migrate** (postinst / `migrateLegacyDb` follow-on / one-shot SQL+PHP), after cluster shortuid normalize where needed:

1. `dateseg.mode = 'closed'` where null/empty; priority default.  
2. Build route profiles from distinct `(openroute, closeroute)` **per tenant** (share when pairs match).  
3. Point each DID at the matching profile; **leave** open/close columns filled.  
4. Map `oclo` OPEN/CLOSED → `sched_mode`.  
5. Holidays: best-effort map to redesigned shape (force dest / mode / local windows); document “review after upgrade.” **Not** a guarantee of identical holiday call paths if the old model was ambiguous.  
6. Operator notes next to SARK V6 / fixRi / `sqlite_normalize_cluster_to_shortuid.sql`.

**Acceptance (open/close):** A golden/SARK-like fixture DB after convert: same destinations for open and closed **schedule** periods as before, without SPA profile edits. Covered by **unit convert fixtures** (§14).

---

## 8. Design locks (Q1–Q7) — locked 2026-08-04

| Id | Decision |
|----|----------|
| **Q1** | Default when **no** day-timer matches: **`open`** (today). Convert stays honest. |
| **Q2** | **Hybrid:** always `open`/`closed`; SPA presets (`lunch`, `evening`, `night`, …); modes as plain strings for free labels later. No catchall `custom`. |
| **Q3** | Overlaps: **integer priority**, higher wins; stable tie-break; SPA may soft-warn; no hard-forbid in v1. |
| **Q4** | **Holiday redesign** — mode-first, optional force dest; TZ-aware calendar; not SARK early absolute-time subversion. Convert best-effort. |
| **Q5** | Operator **hard-force wins over holiday** (force was intentional). |
| **Q6** | Profiles **tenant-scoped only**. No live instance-shared “standard day” (sites differ enough). Copy/duplicate OK. |
| **Q7** | Keep **closed-window** semantics and default open for v1. Open-hours invert / sugar later. |

---

## 9. Delivery slices (when scheduled)

Do **not** interleave with other dial-locus / GenAst contract changes. **§8 locked.** Ship in order:

| Slice | Repos | Operator-visible | Done only when |
|-------|--------|------------------|----------------|
| **A** — schema + idempotent convert + CAGI dual-read | pbx3, pbx3api (schema reg if needed), pbx3cagi | None if dual-read preserves paths | Convert unit fixtures green + CAGI L0 dual-read matrix green |
| **B** — timer multi-mode + priority + holiday write path | pbx3 | Timer may show mode | Timer unit suite green; optional golden cron smoke |
| **C** — Profiles SPA + inbound “use profile” + holiday API/UI | pbx3api, pbx3spa | New UI | API feature tests + SPA critical validation; golden smoke open/closed/lunch |
| **D** — BLF / feature codes / force mode; Q5 behaviour explicit | pbx3 GenAst, CAGI AstDB, SPA | Manual day-part force | GenAst/L0 force matrix + lab master-closed |
| **E** — Deprecate columns / help (later) | all | Clean model | Regression suite still green; lab pack open/close |

**Gate habit:** unit/L0 first; lab before package roll that changes live call behaviour on golden/kildare.

---

## 10. Repo / component checklist

| Component | Change |
|-----------|--------|
| `sqlite_create_tenant.sql` (+ Laravel migrates) | mode, priority, profile tables, inbound FK, sched_mode, holiday redesign fields |
| Convert / migrate script | §7 + unit fixtures |
| `pbx3timer.php` | Multi-mode; priority; holiday TZ-aware writes |
| `pbx3cagi` `CheckState` / `CheckTime` | Profile lookup + dual-read + resolution order |
| `GenClass` BLF / *codes | Mode force |
| pbx3api | DayTimer, HolidayTimer, Profile, InboundRoute; Tenant force/status; mobility table list |
| pbx3spa | Day timers; Holidays; Profiles panel; Inbound; tenant timer display |
| Tenant mobility / backup table lists | Include profile tables |
| `tt_help_core` | Retire open/close-as-primary help when UI moves |
| **Tests** | §14 per slice / repo |

---

## 11. Sequencing vs other work

- **Own track** — not CAGI Phase 4 and not a drive-by on inbound SPA.  
- **Before** FreePBX TC chains, CAGI Phase 4 domain splits, or a full SARK V6 rewrite (this convert is the schedule piece those should assume).  
- Independent of short-dial residual D; do not mix dial-locus contracts.  
- §8 locked — implement when operator schedules.

---

## 12. Success criteria

1. Tenant can define ≥3 modes and route different DIDs via profiles without custom apps.  
2. Converted fixture DB: binary open/close **schedule** destinations unchanged without profile edits (§7; holidays: reviewed separately).  
3. Call path remains precompute + lookup (no GotoIfTime schedule forest).  
4. Manual / master override still usable (mode force; Q5).  
5. Custom apps still reachable as destinations.  
6. **Every shipped slice has green unit/L0 for its contract; lab cases exist for call-path slices before package roll.**

---

## 13. Affected modules (summary)

| Repo | Main modules |
|------|----------------|
| **pbx3** | tenant schema, convert, `pbx3timer.php`, GenAst open/close BLF, help, mobility/backup lists |
| **pbx3cagi** | `CheckState` / `CheckTime`, cluster cfg fields, L0 fixtures |
| **pbx3api** | DayTimer, HolidayTimer, InboundRoute, new Profile CRUD, Tenant timer fields, SchemaService, TenantMobilityService |
| **pbx3spa** | Day/Holiday/Inbound views, new Profiles views, tenant timer display, router/nav |
| **sipplab** | L1 day-part scenarios when scheduled (after A–C) |
| **Out of scope** | pbx3sbc (no branch), fleet Gatekeeper, directory, trunk open/close residue; **Kildare** (do not package/experiment) |

---

## 14. Testing plan (mandatory — build with the code)

### 14.1 Layers

| Layer | Where | When to use |
|-------|--------|-------------|
| **Unit / offline** | pbx3 convert; timer pure functions or PHPUnit/script harness; pbx3api feature/PHPUnit; pbx3spa unit (validation) where logic exists | **Every slice, as code lands** |
| **L0 CAGI** | `pbx3cagi` `make test` / `TEST_RECIPE.md` — fixture SQLite + AstDB mock | Every change to CheckState/CheckTime or profile lookup |
| **L1 lab SIPp** | sipplab — golden/Magrathea | After call path behaviour changes and before package roll that enables new modes in lab |
| **L3 manual** | Desk BLF, SPA admin flows | Force codes, SPA profile editing smoke — document short recipe |
| **L2 load** | Not required for this track | Do not block day-parts on soak |

**Rule:** Prefer **L0 + unit** for matrix combinations (modes × force × holiday × dual-read). Use **L1** for a few golden paths that prove wire + dialplan still connect (open, closed, one multi-mode, master force, holiday when ready).

Align scenario IDs with **`CALL_TEST_STRATEGY.md`** §5.4 when SIP cases land (`in-mode-lunch`, `feat-master-closed`, `feat-holiday-override`, …).

### 14.2 What each layer must cover

| Contract | Unit / L0 | Lab L1 (appropriate) |
|----------|-----------|----------------------|
| Convert open/closed dests | Fixture DBs: before/after dest matrix | Optional golden convert once |
| Convert holiday best-effort | Fixture: old row → new shape; flags “review” | Manual holiday review on golden |
| Mode default (Q1) | No dateseg match → open | — |
| Priority (Q3) | Overlapping windows → winner mode | Optional |
| Dual-read no profile | closed-like → closeroute else openroute | Existing pack open/closed still green |
| Profile lookup | mode → dest; miss → default/fallback | One lunch dest differs from open |
| Holiday vs force (Q4/Q5) | Operator force beats holiday dest; holiday beats day timer | Master-closed DID; holiday day without force |
| timer multi-mode write | Fixtures with frozen “now” | Optional: wait ≤1m for state flip on golden |
| API validation | Profile tenant scope; priority/mode fields | SPA smoke L3 |
| GenAst force | If emitted keys testable offline / L0 AstDB | Desk BLF closed/AUTO |

### 14.3 Per-slice test gates

| Slice | Unit / offline (block merge of slice without) | Lab (before package / “lab green” claim) |
|-------|-----------------------------------------------|------------------------------------------|
| **A** | Convert fixtures (idempotent, open/close dest parity); CAGI L0: dual-read open/closed + master force + baseline holiday fields; no profile and with profile open/closed only | Golden: inbound open + closed still match current pack behaviour (or pack open/close IDs) |
| **B** | Timer unit suite: no-match→open; single match→mode; priority win; tie stable; holiday active write | Optional: force a dateseg window and confirm `sched_mode` within cron period |
| **C** | API tests: profile CRUD tenant-scoped; inbound FK; validation rejects cross-tenant profile; SPA validation unit if any | Lab smoke: configure lunch mode → destination; place/test one inbound path (SIPp or known DID) |
| **D** | L0: force closed vs holiday (Q5); AUTO resumes schedule; multi-mode force if shipped | Lab: master or `*30*` style force closed → closeroute; AUTO recovers |
| **E** | Full L0 suite still green after help/column demotion | Pack open/close + at least one multi-mode L1 id if already added |

### 14.4 CAGI L0 scenario expansion (minimum matrix)

Add scenarios incrementally in slice A; expand in B–D. Do not drop existing open/closed coverage.

Suggested cases (names illustrative):

- `sched-open-default` — no match, dual-read  
- `sched-closed-oclo` / profile equivalent  
- `sched-mode-lunch-profile`  
- `sched-profile-miss-default`  
- `force-master-closed-over-holiday` (Q5)  
- `holiday-force-mode` / `holiday-force-dest` when not forced  
- `legacy-no-profile-closed-like`  

Gate: **`make test` PASS** on every CAGI PR in this track.

### 14.5 pbx3api / SPA

- **API:** feature tests for Profile, DayTimer (mode/priority), HolidayTimer (new fields), InboundRoute (profile attach), mobility list includes new tables.  
- **SPA:** unit tests for validation helpers; manual/L3 checklist for Profiles + Inbound (screenshot-free: short `workingdocs` recipe or SPA handoff note). Prefer Playwright only if the repo already uses it for similar panels.

### 14.6 Timer test approach

`pbx3timer.php` is historically a script. At implement: extract pure match/resolve functions (or run with injectable “now” + fixture DB) so unit tests **do not depend** on live cron or wall clock. Golden “watch oclo flip” is optional confirmation only.

### 14.7 When lab is *not* required

- Pure schema/docs-only substeps inside a slice if paired with convert unit fixtures.  
- SPA copy/help text with no API change.  
- Anything that cannot alter destination selection.

### 14.8 Cadence hooks

- Document new L0 / L1 IDs in **`CALL_TEST_STRATEGY.md`** and sipplab when added.  
- Package roll only after applicable slice gates in §14.3.  
- Do not wait for full multi-mode L1 matrix before finishing unit coverage — **unit leads**.

---

## 15. Revision

| Date | Note |
|------|------|
| 2026-07-26 | Initial draft: day-parts + profiles; cron kept; FreePBX deferred; SARK convert first-class; Phase 4 cagi parked. |
| 2026-08-04 | Slice **A** lab-gated on golden (packages 0.0.4-7 / cagi 1.0.0-12; convert fix; PSTN DID green). Slice **B** timer multi-mode + unit tests (`pbx3-schedule.php`). |
