# Fleet domain → setid authorship — lock (2026-08-11)

**Status:** Locked. Extends **Rule 13** dual contract.  
**Related:** [`DESIGN_RULES.md`](DESIGN_RULES.md) Rule 13 · [`FLEET_DID_HOP1_LOCK.md`](FLEET_DID_HOP1_LOCK.md) · `FleetDomainOwnership` (`fleet=domain` attrs)

---

## Fact

| Fact | Where | Author (fleet-joined) |
|------|--------|------------------------|
| Tenant SIP **FQDN → dispatcher setid** (homing) | SBC `domain` row | **Fleet only** (catalog → register / repoint / reconcile project) |

Same authorship class as hop-1 DID delivery: sticky Magrathea edit without catalog update = **dual HoR**.

---

## Product path

**Retarget home:** Fleet **tenant move** (or catalog instance setid + project) → SBC `repoint` / `registerDomain`.  
**Missing row:** Fleet **Repair SBC domain** / provision path → `registerDomain`.  
**Tag backfill:** Reconcile drift `missing_fleet_tag` → project (`registerDomain` stamps `fleet=domain`).

**Magrathea MUST NOT offer** rename / setid change / delete of fleet-owned Domain Routes (`attrs` contain `fleet=domain`). Hide actions; reject mutate if attempted. Message: use Fleet.

**Magrathea MUST NOT offer** Manage destinations / create / edit / delete of dispatcher rows for a setid that is fleet-locked (any `fleet=domain` tenant on that set, or any `fleet=node` destination). Change instance backends via Fleet Instances / node provision.

**Standalone SBC** (no `fleet=domain` / `fleet=node` tags): Filament Domain Routes + Destinations remain first-class.

**Still allowed on Magrathea for fleet rows:** read / View (including read-only destination list if deep-linked). Domain Routes list shows projected catalog **label** (attrs `label=…`) under the FQDN and destination **description** (instance Name) beside the SIP URI when present.

**Emergency (control plane down):** Filament stays locked. Break-glass = **SSH/SQL/MI** on the SBC, then after recovery **catalog wins** (Fleet reconcile / project). Not a sticky product path.

**Forbidden:** Magrathea → catalog sync as product path; treating Filament setid flip or destination edit as sticky under fleet.

---

## Enforcement

- **Shipped (2026-08-11):** `Domain` save merges attrs (no longer wipes to `setid=` only); `FleetDomainOwnership::stamp` on `registerDomain` / `repoint` / `rollback-repoint`; `DomainPolicy` + Domain Routes Filament lock badge / no-offer / Edit redirect; `GET /fleet/domains` returns `fleet_owned`; Gatekeeper reconcile `missing_fleet_tag` (warning) projectable via registerDomain.
- **Shipped (2026-08-11):** Hide Manage destinations for `fleet=domain`; `DispatcherPolicy` + create/edit redirect when `setidIsFleetLocked` / `fleet=node`; bulk-select hidden for fleet-owned Domain Routes.
- **Shipped (2026-09-24):** `registerDomain` / `repoint` accept optional `label` (+ `tenant_shortuid`); stamp `label=` in attrs; Domain Routes UI shows label under FQDN and dispatcher `description` (instance Name) in Destinations. Gatekeeper passes label on provision / reconcile / Repair.
