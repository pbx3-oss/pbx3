# Lab tenants on fleet nodes

**Status:** Locked practice (2026-08-01).  
**Why:** Creating a tenant only in node SQLite (soak scripts, surgical restore, “just for SIPp”) skips `tenants/{shortuid}/meta.json`. Then **`catalog/tenant-home.json`** never lists that shortuid → **Sign in to tenant** fails, DIDs/moves drift. Lab matters; the catalog model does not yield for it.

## Rule

On a **fleet-joined** instance, every tenant that will be dialed, logged into, or soaked is a **catalog tenant** first:

1. **Fleet → Tenants → Create** (or Gatekeeper `POST /api/v1/tenants/provision`), **or**
2. Exception recovery only: Mac **`register-tenant.sh`** then **`rebuild-tenant-home.sh`**

Solo / kick-tyres (no fleet mode) may still create on-node (Rule 6). That is not golden/lab fleet.

## After Mode 4 / restore

Before calling the lab green:

```bash
export PBX3_ORG_BUCKET=08jzwn-pbx3
./pbx3-directory/tools/reconcile-node-tenants.sh \
  --ssh ubuntu@EIP_OR_FQDN \
  --ssh-key ~/Documents/pemfiles/pbx3test.pem
```

| Result | Meaning | Action |
|--------|---------|--------|
| **node_only** | On node, no catalog meta for this instance | Fleet Create, or `--fix` (registers meta + rebuilds tenant-home) |
| **wrong_home** | Meta exists but `instance_id` ≠ this node | Move / fix meta — do not blind `--fix` |
| **catalog_only** | Meta claims this node; missing in SQLite | Import tenant or decommission meta (`--strict-catalog` fails the run) |
| **ok** | Match | Proceed |

`pkey=default` is skipped unless `--include-default`.

Also listed in **`REBUILD_INSTANCE_RUNBOOK.md`** Phase 5 and **`BUILD_PLAN_0.0.4.md`** lab knobs.

## SIPp / soak

Point recipes at a **catalog shortuid** (env / config), not a hardwired local-only cluster name. Provision soak phones under that tenant after Fleet Create.

## Related

| Doc / tool | Role |
|------------|------|
| **`FLEET_TENANT_CREATE_REQUIREMENTS.md`** | Fleet-first create locked |
| **`tools/register-tenant.sh`** | Write meta (recovery) |
| **`tools/rebuild-tenant-home.sh`** | B′ login rollup |
| **`tools/reconcile-node-tenants.sh`** | This guard |
