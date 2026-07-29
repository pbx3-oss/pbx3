# Fleet-first tenant create — requirements (locked 2026-07-29)

**Status:** Requirements locked; implementation not started.  
**Cursor plan:** `fleet-first_tenant_create` (agent plans).  
**Related:** Rule 6 / 10 / 11 / 13 · mobility gotcha #3 · [`S3Registrar::registerTenant`](../pbx3-directory/gatekeeper/src/S3Registrar.php) · Fleet Tenants “Register on SBC”.

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

### Cheap solo vs fleet split

One **instance** flag (existing fleet mode / `PBX3_FLEET_MODE` or equivalent) — **not** per-tenant types or dual schemas. Solo = absence of fleet mode.

## Human process (happy path)

1. Fleet → Tenants → **Create** (home instance, `pkey`, description, optional CLID / local area as digit **strings**).
2. One action: row on node + catalog meta + SBC domain.
3. Instance admin configures and Builds the PBX as today.
4. Optional: Fleet DIDs assign / project.

**Not** routine: Mac `register-tenant.sh`, hidden SBC Domains URL, Call Routes “new domain” (new setid footgun).

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

| Slice | Repo |
|-------|------|
| `POST /fleet/tenants` create (share `TenantController::save`) | pbx3api |
| `POST /api/v1/tenants/provision` | pbx3-directory gatekeeper |
| Fleet Create UI | pbx3spa |
| Fleet mode: hide Create/Delete; FQDN/shortuid read-only + API reject | pbx3spa + pbx3api |
| Fleet Delete + FQDN rename orchestrators | **Follow-on** (policy locked; UI after create) |

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
