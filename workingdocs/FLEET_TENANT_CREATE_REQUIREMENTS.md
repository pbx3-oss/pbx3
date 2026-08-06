# Fleet-first tenant create — requirements (locked 2026-07-29)

**Status:** Create **shipped on `main`** (2026-07-30 merge). Delete = **[`FLEET_TENANT_DELETE_REQUIREMENTS.md`](FLEET_TENANT_DELETE_REQUIREMENTS.md)** (Rule 14 durable job; slices D1–D5). FQDN rename = D6 after Delete.  
**Cursor plan:** `fleet-first_tenant_create` (agent plans).  
**Related:** Rule 6 / 10 / 11 / **14** · mobility gotcha #3 · [`S3Registrar::registerTenant`](../pbx3-directory/gatekeeper/src/S3Registrar.php) · Fleet Tenants “Register on SBC”.
**Gatekeeper:** [`TenantProvisioner`](../pbx3-directory/gatekeeper/src/TenantProvisioner.php) · `POST /api/v1/tenants/provision`  
**Node:** `POST /api/fleet/tenants` · docs [`pbx3api/docs/FLEET_TENANT_CREATE.md`](../../pbx3api/docs/FLEET_TENANT_CREATE.md)

## Product decision

| Decision | Lock |
|----------|------|
| Who creates a new tenant | **Fleet admin only** (MSP / NOC) |
| End-customer (`tenant` role) | Never mints a new company; operates assigned cluster(s) |
| Instance `admin` on fleet node | No routine Create / Delete; FQDN + shortuid immutable |
| Solo / kick-tyres | On-node Create / Delete / FQDN edit **unchanged** (Rule 6) |
| DID attach | **Separate** Fleet DIDs step (not part of create v1) |

### Lifecycle ownership (fleet-joined instance)

| Operation | Owner |
|-----------|--------|
| Create + home + SBC `domain → setid` | Fleet |
| Delete / decommission | Fleet |
| Rename FQDN / change shortuid | Fleet |
| Edit PBX tenant settings (description, CLID, local area, timers, …) | Instance |
| Extensions / queues / IVRs / inbound / CoS / Commit | Instance |
| Default outbound dialplan template (locale) | **Instance** `globals.default_outbound_dialplan` — see [`SEED_OUTBOUND_ON_TENANT_CREATE.md`](SEED_OUTBOUND_ON_TENANT_CREATE.md) (**shipped**) |
| OutRoute rows after tenant create | Tenant (auto-seeded `MainOut` from globals when set) |

### Cheap solo vs fleet split

One **instance** flag (existing fleet mode / `PBX3_FLEET_MODE` or equivalent) — **not** per-tenant types or dual schemas. Solo = absence of fleet mode.

## Human process (happy path)

1. Fleet → Tenants → **Create** (home instance, `pkey`, description, optional CLID / local area as digit **strings**).
2. One action: row on node + catalog meta + SBC domain.
3. Instance admin configures and Builds the PBX as today.
4. Optional: Fleet DIDs assign / project.

**Not** routine: Mac `register-tenant.sh`, hidden SBC Domains URL, Call Routes “new domain” (new setid footgun).  
**Lab:** never invent node-only tenants on a fleet box — **`pbx3-directory/docs/LAB_FLEET_TENANTS.md`** + **`tools/reconcile-node-tenants.sh`**.

## Technical flow (push)

```text
Fleet SPA → Gatekeeper POST …/tenants/provision
         → Node POST /fleet/tenants   (create cluster; return shortuid/fqdn)
         → S3 registerTenant meta
         → SBC POST /fleet/domains (setid = instance sbc_dispatcher_setid)
```

Node consumes create via **push** (same family as move `/fleet/*`). Tenant appears on the instance automatically because create runs **on** the node first. Catalog and SBC follow from the create response.

### Partial failure (v1)

| Failed after | Behaviour |
|--------------|-----------|
| Node OK, catalog fail | Error + node shortuid; retry catalog+SBC (idempotent) |
| Catalog OK, SBC fail | Tenant in Fleet list; **Register on SBC** repairs |
| Node fail | Nothing in catalog/SBC |

Synchronous v1 (no durable job). Rule 11: other tenants’ calls unaffected.

## Implementation map (when scheduled)

| Slice | Repo | Status |
|-------|------|--------|
| `POST /fleet/tenants` create (share `TenantController::save`) | pbx3api | **Done** (`main`) |
| Sanctum Create/Delete 403 on fleet nodes | pbx3api | **Done** (`main`) |
| `POST /api/v1/tenants/provision` | pbx3-directory gatekeeper | **Done** (`main`) |
| Fleet Create UI | pbx3spa | **Done** (`main`) |
| Fleet mode: hide Create/Delete; FQDN/shortuid read-only | pbx3spa | **Done** (`main`; FQDN already readonly) |
| Fleet Delete + FQDN rename | **Delete: see FLEET_TENANT_DELETE_REQUIREMENTS.md** | Spec locked 2026-08-06. Node wipe exists. Implement D1–D5; FQDN rename D6 later. **Blocks first product release**. |

## Non-goals (v1)

- Customer self-serve “add company”
- Auto DID on create
- Exposing Domains in SBC nav / Call Routes shared-setid redesign
- Billing / quotas
- `ipphone.desc` vs `description` rename (separate parked TODO)

## Lab acceptance (when built)

1. Fleet Create → golden has cluster row; catalog meta; SBC domain setid **2**.
2. REGISTER to new FQDN via SBC without manual Domains URL.
3. Solo: Create Tenant still works.
4. Fleet node: Create/Delete hidden; FQDN/shortuid not editable.
5. SBC down mid-provision: Register on SBC repairs.
