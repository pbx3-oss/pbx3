# Fleet built-tenant ingest — requirements (locked 2026-09-27)

**Status:** Requirements **locked** (2026-09-27). **I1–I3 shipped tip** (`BuiltTenantIngestService` + `tenant:ingest-built`); **I4** enroll = ops checklist below (Gatekeeper/SPA later as I5).  
**Cursor plan:** `built-tenant_ingest`.  
**Naming:** [`FLEET_NAMING_LOCK.md`](FLEET_NAMING_LOCK.md).  
**Create (empty tenant):** [`FLEET_TENANT_CREATE_REQUIREMENTS.md`](FLEET_TENANT_CREATE_REQUIREMENTS.md).  
**Move (already-fleet tenant):** [`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`](../pbx3-directory/docs/TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md) · `tenant:export` / `tenant:import`.  
**Lab:** never leave node-only tenants — [`LAB_FLEET_TENANTS.md`](../pbx3-directory/docs/LAB_FLEET_TENANTS.md).  
**ETL artifact:** private **`aelintra/sark-to-pbx3`** REQUIREMENTS **#17** (`bin/split-tenants.py`) · MkDocs `operator/migrate-and-split`.  
**Related rules:** 6 / 10 / 11 / 14.

## Problem

SARK → pbx3 offline ETL can emit a **per-tenant** sqlite (`<pkey>.db`) after migrate + split. Product today can only **create** an empty fleet tenant (node + catalog + SBC). There is **no** path to home a **built** tenant DB on a fleet instance and enroll it.

## Product decision

| Decision | Lock |
|----------|------|
| Who ingests | **Fleet / ops** (MSP / NOC) — not end-customer self-serve |
| v1 surface | **Ops/CLI first** (home artisan + catalog/SBC enroll). Gatekeeper API + Fleet SPA = **later**, same stages |
| Input artifact | **Direct** sark-to-pbx3 **split** `.db` (one `cluster`). Not “must wrap as mobility zip” |
| ETL #17 | **Unchanged** — split keeps full `globals` + inactive `trunks` for offline inspect; product **strips** on ingest |
| Create vs ingest | Create = empty cluster + seeds. Ingest = merge **built** payload; **do not** re-seed `MainOut` / CoS when those tables already have rows |
| Mobility vs ingest | Mobility = move **already-fleet** tenant (zip; preserve identity). Ingest = **first** fleet home from ETL artifact |
| DID attach | **Separate** Fleet DIDs step (same as create v1) |
| Solo | Out of scope for this lock; Rule 6 solo create/import paths unchanged |

### Lifecycle ownership (after ingest)

Same as create: fleet owns home + catalog + SBC domain; instance owns day-2 PBX config / Commit; Name = `pkey`; FQDN = `{shortuid}.{apex}` immutable after mint (remint only when ingest must resolve opaque collision — see Identity).

## Identity

| Key | Policy |
|-----|--------|
| **`pkey` (Name)** | Keep from ETL. **Collision = fail** — operator renames in source or on node before retry. Do not remint Name |
| **`shortuid` / `cluster.id`** | **Preserve** when free on the home (and catalog, when enroll runs). On **opaque** collision → **remint** the clashing key(s), rewrite all cluster-scoped refs, set FQDN. UIDs have **no** intrinsic semantics — uniqueness only |
| **FQDN** | Always rewrite to `{shortuid}.{apex}` using home `globals.domain` (after any remint) |
| Ops visibility | Log / CLI output **old→new** `shortuid` (and `id` if reminted) |

## Human process (happy path v1)

1. Offline: `migrate-offline.py` → optional `split-tenants.py` → `<pkey>.db` (e.g. smoke `flixton.db`).
2. Ops: copy `.db` to target **fleet home**; run ingest CLI (dry-run then apply).
3. Node merges tenant rows; remints opaque keys only if needed; FQDN + fleet route normalize.
4. Ops enrolls catalog meta + SBC domain (reuse create enroll / `register-tenant` + Register-on-SBC repair) — **same shortuid/FQDN** the merge returned.
5. Instance admin: remap any remaining site policy, **Commit**, desk/SIPp smoke.
6. Optional later: Fleet DIDs assign.

**Lab:** do not stop after step 3 with a node-only tenant.

## Technical flow (v1 CLI)

```text
split <pkey>.db
  → Home: preflight + merge (strip globals/trunks/threat/Laravel)
  → Identity preserve-or-remint + FQDN rewrite
  → Fleet: normalize route.path* → Egress (drop ETL trunks)
  → Catalog registerTenant (meta; label = pkey)
  → SBC domain → instance sbc_dispatcher_setid
```

Later (I5): Gatekeeper orchestrates the same stages (upload/stage → node merge API → catalog → SBC), then SPA.

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

3. **Commit** on the home; desk / SIPp smoke. DID attach remains a separate Fleet DIDs step.

### Lab mule (Flixton)

Smoke artifact (gitignored ETL work tree):

`~/GiT/sark-to-pbx3/work/fixture-smoke-backups-20260927/pdh3s02-tenants/flixton.db`

```bash
# On the fleet home (after rsync tip pbx3api):
sudo -u www-data php /opt/pbx3api/artisan tenant:ingest-built /tmp/flixton.db --dry-run
sudo -u www-data php /opt/pbx3api/artisan tenant:ingest-built /tmp/flixton.db
# Then enroll checklist above with printed shortuid/FQDN.
```

Unit coverage: `pbx3api` `tests/Unit/BuiltTenantIngestTest.php` (preserve, remint, pkey fail, Egress normalize).

## Non-goals (v1)

- Changing sark-to-pbx3 #17 split contract (drop globals/trunks or zip-only output)
- Requiring mobility zip as the only ingest input
- Auto DID inventory / SBC DID project
- Importing SARK greetings/recordings media or Laravel portable users
- SPA wizard / Gatekeeper upload UI (I5)
- Billing / quotas
- Always reminting shortuid when free (rejected — preserve-first)

## Lab acceptance (when built)

1. Dry-run on smoke split DB reports cluster Name, shortuid, row counts, collision plan (none or remint).
2. Apply on lab fleet home → one new `cluster`; **no** extra trunks from ETL; outbound paths → `Egress`.
3. Catalog `tenants/{shortuid}/meta.json` + SBC domain for home setid; Fleet list shows tenant (**pkey** as Name).
4. FQDN is `{shortuid}.{apex}`; REGISTER via SBC works after Commit (desk or SIPp).
5. Forced shortuid collision (lab) → remint logged; ingest succeeds; Name/`pkey` unchanged.
6. Forced `pkey` collision → fail cleanly; no partial catalog row.
7. No node-only leftover if enroll skipped — ops checklist / reconcile still applies.

## Open questions (non-blocking)

None for v1 lock. Schema pin drift vs ETL `PIN.txt` handled as preflight warn/fail when columns cannot intersect safely.
