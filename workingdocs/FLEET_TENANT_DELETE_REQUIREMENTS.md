# Fleet tenant delete — requirements (locked 2026-08-06)

**Status:** Spec locked; implementation slices **D1–D5** **done**. **D6 FQDN rename — cancelled** (2026-08-06).  
**Policy:** Rule **6 / 10 / 14** · [`FLEET_TENANT_CREATE_REQUIREMENTS.md`](FLEET_TENANT_CREATE_REQUIREMENTS.md) · [`DESIGN_RULES.md`](../pbx3-directory/docs/DESIGN_RULES.md) Rule 14 · naming [`FLEET_NAMING_LOCK.md`](FLEET_NAMING_LOCK.md).  
**Mirror:** Tenant-move durable jobs — **not** Fleet Create sync provision.

## Product decision

| Decision | Lock |
|----------|------|
| Who deletes a fleet tenant | **Fleet admin only** |
| Instance Sanctum Delete on fleet node | Still **403** (create already locked) |
| Solo / kick-tyres | On-node Delete **unchanged** |
| Catalog on delete | **Soft-decommission** (`status=decommissioned`); keep `meta.json` for audit. Hard S3 prefix purge = later |
| Ability | Same as Create: **`fleet_instances`** |
| FQDN rename (D6) | **Cancelled** — FQDN always `{shortuid}.{apex}`; see **`FLEET_NAMING_LOCK.md`** |

## Job stages (v1)

```text
pending → preflight
       → awaiting_confirm   (HUMAN: type shortuid; irreversible)
       → pruning_mesh       (Site Group detach + peer dialalias prune)
       → removing_edge      (SBC DELETE domain)
       → wiping_node        (DELETE /fleet/tenants/{shortuid} + cert sync + commit best-effort)
       → catalog            (soft-decommission tenant meta)
       → completed
```

| State | Notes |
|-------|--------|
| `preflight` | Resolve home instance, FQDN, node reachable; warn if catalog DIDs still attached (no auto-unassign v1); **T1** wipe row counts |
| `awaiting_confirm` | Typed shortuid + `confirm: true` |
| `pruning_mesh` | **T2 / I7** — detach Site Group; prune peer dialaliases on reachable homes; unreachable → warn (retry / Sync now) |
| `removing_edge` | Idempotent if domain already absent |
| `wiping_node` | Node wipe (+ same-home inbound dialalias prune); **media trees not deleted** (known Class B gap) |
| `catalog` | `status=decommissioned`; hidden from Fleet Tenants list |
| `failed` / `aborted` | Terminal; notify like move jobs |

**Abort boundary:** Safe **before** `wiping_node`. If SBC domain already deleted, repair with **Register on SBC**. After wipe, recovery = re-provision (out of scope).

## Confirm UX

- SPA: Fleet → Tenants → **Delete** creates job → opens job detail (Jobs list also).
- Gate: type tenant **shortuid**; danger button; irreversible copy (node data wipe + SIP domain gone).
- Reopen anytime via Fleet → **Jobs** (do not require staying on the page).

## Not in v1

- Drain / AMI wait-for-zero channels  
- Auto DID unassign / S3 backup purge / media tree wipe  
- Sync one-shot POST (violates Rule 14)  
- FQDN rename (D6 — **cancelled**; not a Delete non-goal forever, just not a product)

**Follow-on integrity (2026-08-09):** App cascade already wipes tenant tables — see **`TENANT_DELETE_DATA_INTEGRITY.md`** (sibling dialaliases, park parity, orphan audit, optional FK later). Do **not** gate Delete on “no dependents.”

## Implementation map

| Slice | Repo | Status |
|-------|------|--------|
| D0 Spec | pbx3 workingdocs | **Done** |
| D1 SBC `DELETE /fleet/domains/{domain}` + Gatekeeper client | pbx3sbc-admin + gatekeeper | **Done** |
| D2 Catalog `decommissionTenant` | gatekeeper | **Done** |
| D3 Delete job store/runner/routes | gatekeeper | **Done** |
| D4 SPA Delete + Jobs confirm | pbx3spa | **Done** |
| D5 Lab + MkDocs | pbx3-docs | **Done** (operator page; lab operator verifies) |
| D6 FQDN rename job | — | **Cancelled** 2026-08-06 — see § D6 |

## D6 — FQDN rename (**cancelled** 2026-08-06)

**No longer planned.** Tenant (and instance) FQDN is always **`{shortuid}.{apex}`**; shortuid is immutable; human rebrand = edit **Name** (`pkey` / sitename). Vanity hostnames (lab `kildare.pbx3.com`) are policy debt — **`FLEET_NAMING_LOCK.md`**. Fleet-wide apex change = separate ops problem if ever needed.

## Lab acceptance

1. Fleet Create lab tenant → Delete job → confirm shortuid.  
2. SBC domain gone (REGISTER to FQDN fails / unknown domain).  
3. Node: cluster row and tenant tables gone.  
4. Catalog: tenant `decommissioned`, hidden from Fleet Tenants.  
5. Job `completed`; reopen from Jobs works mid-flight.  
6. Solo: instance Delete still works.
