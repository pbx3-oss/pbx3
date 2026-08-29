# Fleet DID hop-1 authorship — lock (2026-08-11)

**Status:** Locked. Extends **Rule 13** dual contract.  
**Related:** [`DESIGN_RULES.md`](DESIGN_RULES.md) Rule 13 · [`DID_ASSIGNMENT_DESIGN.md`](DID_ASSIGNMENT_DESIGN.md) · [`FLEET_TRUNK_PEERING_DECISION.md`](FLEET_TRUNK_PEERING_DECISION.md) §5 · `FleetDidProjector` (`fleet=did` attrs)

---

## Two hops (do not conflate)

| Hop | Question | Where | Author (fleet-joined) |
|-----|----------|--------|------------------------|
| **1 — Delivery** | Which **tenant / home** gets this INVITE? | SBC `dr_rules` group **1** — singleton **or block** prefix | **Fleet only** (catalog → project) |
| **2 — Behaviour** | Which **endpoint**? | Tenant `inroutes` | Instance / tenant admin |

Example: SBC may match block `4419249264…` (digit E.164 after dialect) → tenant home; tenant then routes hop-2 `+441924918076` / national face → `40001`.

### Accepted imbalance — Allocate does **not** seed hop-2 (2026-08-29)

Fleet Allocate → catalog + SBC project only. It does **not** auto-create tenant `inroutes`. That looks like two gestures for one DID, but open-seeding per Allocate would fight **Class** / consecutive-number masks (many DIDs → one hop-2 row). Hop-2 stays instance-authored (DiD singleton, Class, CLiD, regex). Keep instance **Inbound Routes → Create**; do not hide it for fleet.

---

## Product path to retarget hop 1

**Switch tenant A → B (singleton or block):** Fleet **Allocate / reassign** (with `reassign` when changing owner) → catalog write → `projectDids`. Or **move** the owning tenant (homing + re-project).

**Magrathea MUST NOT offer** edit/delete of fleet-owned hop-1 rows (`attrs` contain `fleet=did`). Hide actions; reject mutate if attempted. Message: use Fleet DIDs.

**Standalone SBC** (no `fleet=did` tags / empty `PBX3_FLEET_SERVICE_TOKEN`): Filament Number routes remain first-class hop-1 authoring (inbound + outbound).

**Fleet-joined Magrathea (2026-08-29):** Filament **hides inbound** Number route list/create (outbound only). Signal = non-empty `PBX3_FLEET_SERVICE_TOKEN`. Projector + `/api/fleet/project-dids` still write groupid **1**. Reopen later if general-SBC non-fleet backends need Filament inbound again.

**Forbidden:** Magrathea → catalog sync as product path; treating Filament retarget as sticky under fleet.

---

## Catalog UI vs live edge

Fleet DIDs panel shows **catalog intent** (ownership / status), not a live scrape of Magrathea. Soft **released** rows stay visible (grey) until hard-remove exists. **Project all → SBC** compiles active/porting delivery; released removes fleet-owned projection rows only.

---

## Enforcement

- **Shipped:** `DrRulePolicy` + Filament `canEdit`/`canDelete` (2026-08-09); Fleet lock badge + Edit-page redirect message (2026-08-11).
- Fleet SPA: DIDs = catalog intent; tenant action **Repair SBC domain** (not a routine post-create step).
- **Shipped (2026-08-11 #33):** Fleet Allocate `delivery=singleton|block` + `sip_prefix`; `GET /api/v1/dids/reconcile` (catalog ↔ `fleet=did`); Apply = `POST /api/v1/dids/project`. Schema: optional `delivery` on `did-record.v0.json`.
- **Shipped (2026-08-11):** Magrathea inbound Number-route **create/update** hard-rejects prefixes that **nest under or above** a `fleet=did` rule (longest-prefix subdivision / shadow). Same “use Fleet DIDs” message. Outbound unaffected.
- **Shipped (2026-08-12):** Hop-1 match digits must be **post-dialect** (digit E.164). OpenSIPS `DIALECT_INBOUND_NORMALIZE` turns UK national `0…` → `44…` **before** `do_routing(1)`. **Singleton:** omit `sip_prefix` (project `e164_key`); re-assign **clears** a stale `sip_prefix`. **Block:** `sip_prefix` required and must **not** be UK national leading-`0` — use digit form (e.g. `4419249264`). Assign **422** if violated.
