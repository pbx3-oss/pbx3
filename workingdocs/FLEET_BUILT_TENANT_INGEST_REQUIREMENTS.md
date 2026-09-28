# Fleet built-tenant ingest — requirements (locked 2026-09-27)

**Status:** Requirements **locked** (2026-09-27). **I1–I3 shipped tip** (`BuiltTenantIngestService` + `tenant:ingest-built`); **I4** enroll = ops checklist below (Gatekeeper/SPA later as I5).  
**Cursor plan:** `built-tenant_ingest`.  
**Naming:** [`FLEET_NAMING_LOCK.md`](FLEET_NAMING_LOCK.md).  
**Create (empty tenant):** [`FLEET_TENANT_CREATE_REQUIREMENTS.md`](FLEET_TENANT_CREATE_REQUIREMENTS.md).  
**Move (already-fleet tenant):** [`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`](../pbx3-directory/docs/TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md) · `tenant:export` / `tenant:import`.  
**Lab:** never leave node-only tenants — [`LAB_FLEET_TENANTS.md`](../pbx3-directory/docs/LAB_FLEET_TENANTS.md).  
**External DB sources:** any one-`cluster` compatible pbx3 sqlite (offline migrate/split, another fleet, or elsewhere) — **provenance does not change the enroll runbook**. Operator MkDocs: **`pbx3-docs`** [`fleet/ingest-compatible-db`](../../pbx3-docs/docs/fleet/ingest-compatible-db.md).  
**DID hop-1:** [`FLEET_DID_HOP1_LOCK.md`](../pbx3-directory/docs/FLEET_DID_HOP1_LOCK.md).  
**Related rules:** 6 / 10 / 11 / 13 / 14.

## Problem

Operators need to home a **built** tenant sqlite on a fleet instance (not only mint an empty tenant via Create). Sources include SARK offline ETL split DBs, a DB taken from **another fleet**, or other external one-tenant artifacts. Merge + catalog + SBC **domain** alone do **not** deliver PSTN — **Fleet DID attach (hop-1)** remains a required follow-on unless the tenant is extension/intersite-only.

## Product decision

| Decision | Lock |
|----------|------|
| Who ingests | **Fleet / ops** (MSP / NOC) — not end-customer self-serve |
| v1 surface | **Ops/CLI first** (home artisan + catalog/SBC enroll). Gatekeeper API + Fleet SPA = **later**, same stages |
| Input artifact | **Direct** one-`cluster` pbx3 sqlite (lab primary: sark-to-pbx3 **split** `.db`). Not “must wrap as mobility zip” |
| Source-agnostic | Same merge + enroll + **DID attach** runbook whether the DB came from ETL, another fleet, or elsewhere |
| ETL #17 | **Unchanged** when source is sark-to-pbx3 — split keeps full `globals` + inactive `trunks` for offline inspect; product **strips** on ingest |
| Create vs ingest | Create = empty cluster + seeds. Ingest = merge **built** payload; **do not** re-seed `MainOut` / CoS when those tables already have rows |
| Mobility vs ingest | Mobility = move **already-fleet** tenant (zip; preserve identity). Ingest = **first** home of an **external** built DB on this fleet (may remint opaque keys on collision) |
| DID attach | **Required runbook stage** after catalog + SBC domain when the tenant needs PSTN delivery — **not** auto inside `tenant:ingest-built`. Use Fleet DIDs Allocate → project (hop-1). Hop-2 `inroutes` stay instance-authored ([`FLEET_DID_HOP1_LOCK.md`](../pbx3-directory/docs/FLEET_DID_HOP1_LOCK.md)) |
| Solo | Out of scope for this lock; Rule 6 solo create/import paths unchanged |

### Lifecycle ownership (after ingest)

Same as create: fleet owns home + catalog + SBC domain; instance owns day-2 PBX config / Commit; Name = `pkey`; FQDN = `{shortuid}.{apex}` immutable after mint (remint only when ingest must resolve opaque collision — see Identity).

## Identity

| Key | Policy |
|-----|--------|
| **`pkey` (Name)** | Keep from source DB. **`default` / empty = fail** (common on solo/single-tenant DBs). **Collision = fail**. Operator renames in the candidate `.db` before ingest — no CLI override; do not remint Name. MkDocs: `fleet/ingest-compatible-db` §0 |
| **`shortuid` / `cluster.id`** | **Preserve** when free on the home (and catalog, when enroll runs). On **opaque** collision → **remint** the clashing key(s), rewrite all cluster-scoped refs, set FQDN. UIDs have **no** intrinsic semantics — uniqueness only |
| **FQDN** | Always rewrite to `{shortuid}.{apex}` using home `globals.domain` (after any remint) |
| Ops visibility | Log / CLI output **old→new** `shortuid` (and `id` if reminted) |

## Human process (happy path v1)

1. Obtain **external** one-tenant `.db` (e.g. sark-to-pbx3 `migrate-offline` → `split-tenants`, or export from another fleet).
2. If `cluster.pkey` is `default` / empty / colliding: rename in a copy of the candidate DB (MkDocs §0).
3. Ops: copy `.db` to target **fleet home**; run ingest CLI (dry-run then apply).
4. Node merges tenant rows; remints opaque keys only if needed; FQDN + fleet route normalize.
5. Ops enrolls catalog meta + SBC **domain** (`register-tenant` + Register-on-SBC) — **same shortuid/FQDN** the merge returned; set catalog `label` = `pkey` if the shell script omitted it.
6. **Fleet DID attach (hop-1)** — if the tenant must receive PSTN: Fleet → DIDs → **Allocate** (singleton or block) to this tenant → project to SBC (`fleet=did`). Ingest/create do **not** do this. Source DIDs in `inroutes` are hop-2 only until hop-1 points at the new home.
7. Instance admin: hop-2 / site policy as needed, **Commit**, desk/SIPp smoke (incl. DID if allocated).

**Lab:** do not stop after merge with a node-only tenant. Do not treat “domain registered” as “DIDs work.”

## Technical flow (v1 CLI)

```text
external <pkey>.db
  → Home: preflight + merge (strip globals/trunks/threat/Laravel)
  → Identity preserve-or-remint + FQDN rewrite
  → Fleet: normalize route.path* → Egress (drop source trunks)
  → Catalog registerTenant (meta; label = pkey)
  → SBC domain → instance sbc_dispatcher_setid
  → Fleet DID Allocate + project (hop-1)   ← runbook; not inside artisan ingest
```

Later (I5): Gatekeeper orchestrates merge → catalog → SBC domain (same as create family); **DID attach stays the Fleet DIDs path** unless a future lock folds hop-1 into the ingest job.

### What the split `.db` contains vs what the home keeps

| In split `.db` | On ingest |
|----------------|-----------|
| One `cluster` + cluster-scoped tenant tables | **Merge** into home sqlite (intersecting columns) |
| Full `globals`, all `trunks`, `threat` | **Strip / ignore** (instance-owned) |
| Laravel / help / device seed tables | **Ignore** |
| Outbound `route` rows pointing at ETL trunk pkeys | **Keep rows**; set `path1`→`Egress`, clear `path2`–`path4` on fleet home |

Reuse the mobility tenant table list where practical (`TenantMobilityService::TENANT_DATA_TABLES`) — ingest is a **sibling** merge path, not a zip wrapper.

### Partial failure (v1)

| Failed after | Behaviour |
|--------------|-----------|
| Preflight / merge fail | Nothing durable; fix artifact or conflicts and retry |
| Merge OK, catalog fail | Error + shortuid/FQDN; **retry enroll** (idempotent). Do not auto-wipe merge |
| Catalog OK, SBC fail | Tenant in catalog; **Register on SBC** repairs (same as create) |
| `pkey` collision | Hard fail before merge |

Synchronous v1 (no durable Rule-14 job). Rule 11: other tenants’ calls unaffected.

## Implementation map

| Slice | Repo | Status |
|-------|------|--------|
| **I1** Preflight: exactly one `cluster`; reject `pkey=default`; conflict scan (`shortuid` / `id` / `pkey`); schema/column intersect | pbx3api | **Done** (`BuiltTenantIngestService::preflight`) |
| **I2** Node merge service: strip instance tables; copy tenant payload; remint-if-needed; FQDN; fleet route normalize; no create seeds when data present | pbx3api | **Done** (`BuiltTenantIngestService::ingest`) |
| **I3** Artisan CLI e.g. `tenant:ingest-built {path.db}` (+ `--dry-run`); lab recipe (e.g. `flixton.db`) | pbx3api + ops notes | **Done** — `php artisan tenant:ingest-built /path/to/flixton.db --dry-run` |
| **I4** Catalog + SBC enroll using create-family tools / Gatekeeper register + domain; document resume | ops + existing Gatekeeper | **Ops checklist** (below) — no new Gatekeeper API yet |
| **I5** Gatekeeper `…/tenants/ingest` + Fleet SPA | gatekeeper + pbx3spa | Later |
| **I6** Optional ETL dual-emit mobility zip | sark-to-pbx3 | Optional later — **not** required by this lock |

## Ops enroll checklist (I4 — after successful merge)

CLI prints an `enroll_hint` with the final `shortuid` / FQDN. Do **not** leave a node-only tenant ([`LAB_FLEET_TENANTS.md`](../pbx3-directory/docs/LAB_FLEET_TENANTS.md)).

1. **Catalog meta** (Mac ops IAM):

```bash
cd ~/GiT/pbx3-master/pbx3/pbx3-directory/tools
export PBX3_ORG_BUCKET=…   # e.g. 08jzwn-pbx3
./register-tenant.sh \
  --tenant-shortuid <shortuid> \
  --instance-id <home globals.id> \
  --cname <shortuid>.<apex> \
  --fqdn <shortuid>.<apex>
```

Ensure catalog Name/`label` = tenant **`pkey`** (create path sets `label=pkey`; patch meta if the shell script omits it).

2. **SBC domain** — Fleet → Tenants → **Register on SBC** (or Gatekeeper domain enroll) using the home’s `sbc_dispatcher_setid`.

3. **Fleet DID attach (hop-1)** — required for PSTN delivery after any external-DB ingest (ETL, other fleet, etc.):

   - Fleet → **DIDs** → **Allocate** / re-allocate the number or block to this tenant’s **shortuid**.
   - Confirm project / Apply so SBC `dr_rules` (`fleet=did`) target this home’s setid.
   - **Hop-2** (`inroutes` already in the merged DB, or new Class/DiD rows) stays instance-authored — Allocate does **not** seed hop-2 ([`FLEET_DID_HOP1_LOCK.md`](../pbx3-directory/docs/FLEET_DID_HOP1_LOCK.md)).
   - Skip only if the tenant is intentionally non-PSTN (extensions / site-dial only).

4. **Commit** on the home; desk / SIPp smoke (REGISTER + optional DID).

### Lab mule (Flixton)

Smoke artifact (gitignored ETL work tree):

`~/GiT/sark-to-pbx3/work/fixture-smoke-backups-20260927/pdh3s02-tenants/flixton.db`

```bash
# On the fleet home (after rsync tip pbx3api):
sudo -u www-data php /opt/pbx3api/artisan tenant:ingest-built /tmp/flixton.db --dry-run
sudo -u www-data php /opt/pbx3api/artisan tenant:ingest-built /tmp/flixton.db
# Then enroll checklist: catalog + SBC domain + Fleet DID Allocate (if PSTN) + Commit.
```

Unit coverage: `pbx3api` `tests/Unit/BuiltTenantIngestTest.php` (preserve, remint, pkey fail, Egress normalize).

## Non-goals (v1)

- Changing sark-to-pbx3 #17 split contract (drop globals/trunks or zip-only output)
- Requiring mobility zip as the only ingest input
- **Auto** DID inventory / hop-1 project **inside** `tenant:ingest-built` (operator uses Fleet DIDs; documented as stage 3)
- Auto-seeding hop-2 `inroutes` from Allocate
- Importing greetings/recordings media or Laravel portable users
- SPA wizard / Gatekeeper upload UI (I5)
- Billing / quotas
- Always reminting shortuid when free (rejected — preserve-first)

## Lab acceptance (when built)

1. Dry-run on smoke split DB reports cluster Name, shortuid, row counts, collision plan (none or remint).
2. Apply on lab fleet home → one new `cluster`; **no** extra trunks from source; outbound paths → `Egress`.
3. Catalog `tenants/{shortuid}/meta.json` + SBC domain for home setid; Fleet list shows tenant (**pkey** as Name).
4. FQDN is `{shortuid}.{apex}`; REGISTER via SBC works after Commit (desk or SIPp).
5. After Fleet DID Allocate + project, inbound PSTN reaches the home (hop-1); hop-2 uses existing or new `inroutes`.
6. Forced shortuid collision (lab) → remint logged; ingest succeeds; Name/`pkey` unchanged.
7. Forced `pkey` collision → fail cleanly; no partial catalog row.
8. No node-only leftover if enroll skipped — ops checklist / reconcile still applies.

## Open questions (non-blocking)

None for v1 lock. Schema pin drift vs ETL `PIN.txt` handled as preflight warn/fail when columns cannot intersect safely.
