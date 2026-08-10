# Tenant delete — data integrity

**Status:** Stance locked **2026-08-09** (investigation). **T1–T5 done** (2026-08-10). Remaining: T6–T8 when scheduled.  
**Related:** [`FLEET_TENANT_DELETE_REQUIREMENTS.md`](FLEET_TENANT_DELETE_REQUIREMENTS.md) · [`PRE_RELEASE_SAFETY_DEBT.md`](PRE_RELEASE_SAFETY_DEBT.md) · `pbx3api` `TenantMobilityService::destroyTenantData` · Rule **14**.

---

## 1. What exists today (not broken by omission of DB RI)

SQLite schema has **no `FOREIGN KEY`** constraints on `cluster` → child tables. Integrity is **application cascade**, not engine RI.

| Path | Behaviour |
|------|-----------|
| Solo Sanctum `DELETE /tenants/{tenant}` | `destroyTenantData` + portable users + park cleanup + FQDN inline |
| Fleet wipe `DELETE /fleet/tenants/{shortuid}` | Same wipe primitive (+ portable users); orchestrated by Fleet Delete job |
| Wipe primitive | `TenantMobilityService::TENANT_DATA_TABLES` — `DELETE … WHERE cluster IN (aliases)` then `DELETE FROM cluster WHERE id=?` |

`TENANT_DATA_TABLES` matches tenant-schema tables with a `cluster` column (extensions/`ipphone`, `inroutes`/DiDs, routes, queues, IVR, dialalias **owned by this tenant**, day-parts, COS links, recordings index rows, …). Unit test covers ipphone + inroutes + cluster.

**Aliases** (`cluster_identifier_aliases`): pkey + shortuid + KSUID id — so legacy `cluster` values keyed by any of those should wipe.

**Docs:** `pbx3api/docs/general.md` — “Deleting a tenant will delete ALL of its dependencies.”

---

## 2. Stance (locked)

| # | Lock |
|---|------|
| I1 | **Delete = wipe**, not “refuse if dependents exist.” Gating Delete on empty children would fight Fleet Delete / solo tear-down and leave operators stuck. |
| I2 | **End-state direction = hybrid RI.** In-DB tenant graph → prefer **SQLite FK + `ON DELETE CASCADE`** (engine truth) once normalize + `PRAGMA foreign_keys=ON` are safe. **Out-of-DB** planes (S3 catalog, Magrathea domain/DIDs, media trees, peer dialaliases on *other* tenants) **cannot** be FK-cascaded — those stay **Rule 14 jobs / wipe steps**. |
| I3 | **Near-term:** keep app wipe, but treat `TENANT_DATA_TABLES` drift as the known failure mode — harden with preflight, orphan audit, schema↔list CI, sibling dialalias + park parity (T1–T5). |
| I4 | Trunks remain **instance-owned** (not in tenant wipe) — intentional. |
| I5 | App wipe does **not** go away when FKs land — it shrinks to: resolve aliases → delete `cluster` (children cascade) → run **extra-plane** steps (S3/edge/media/peers). |
| I6 | **Data classes on wipe (locked 2026-08-09).** Not everything under a tenant is equal. See §2.2. |
| I7 | **Site Group dialalias projections on delete (locked 2026-08-10).** Sender-local prefix rows are required (Rule 1 / PrefixDial). **Fleet Delete must prune them** on reachable peer homes — same intent as Site Group **remove member**. Operators must **not** be expected to log into each peer tenant SPA to delete prefixes. **Unreachable peer:** **warn** on the delete job; home wipe may continue. Finishing that peer’s prune is **operator responsibility** via existing delete **retry** and/or Site Group **Sync now** when the node is back — product warns and provides the tools; it does not babysit every offline home to green. |

---

## 2.1 Why “just DB RI” is incomplete (and “just app RI” is leaky)

```text
                    ┌─ SQLite child tables (ipphone, inroutes, …)
   DELETE cluster ──┼─ FK CASCADE can own this plane (end-state)
                    │
                    ├─ Sibling dialalias on *other* tenants     ─┐
                    ├─ Catalog / S3 tenant meta + DID attach    ─┼─ jobs / wipe steps
                    ├─ Magrathea domain / edge projection       ─┤   (not SQLite FK)
                    └─ Greeting/recording files on disk         ─┘
```

App-only RI already proved the oversight class (**G6**: new table forgotten in the list). DB FK fixes that class **inside** the node DB. It does **not** replace Fleet Delete’s soft-decommission, SBC domain remove, or catalog DID policy — those stay orchestrated.

**Do not** enable FKs as the *only* delete path before extra-plane steps are explicit and tested.

---

## 2.2 Data classes — what “wipe” means

Tenant delete must **not** silently destroy audit / compliance material. Split:

| Class | Examples | On tenant Delete |
|-------|----------|------------------|
| **A — Operational config** | `ipphone`, `inroutes`, routes, queues, IVR, COS, day-parts, dialalias *owned by* tenant, greetings DB rows | **Wipe** with cluster (app list today; FK CASCADE later) |
| **B — Call evidence** | MixMonitor / recording **files**, `recordings` index rows, **CDR** (Asterisk MySQL / instance CDR plane) | **Retain by default.** Purge only via **explicit** confirm (typed shortuid + separate “also delete recordings/CDR” flags) or a later retention job — never as an unnoticed side effect of FK CASCADE |
| **C — Fleet / edge projection** | Catalog meta, attached DIDs, Magrathea domain | Soft-decommission / edge DELETE as today; DID auto-unassign = product pick (T6) |
| **D — Instance-shared** | Trunks, globals | **Never** tenant-cascaded |

**Today’s awkwardness:** wipe already deletes `recordings` **index** rows (`TENANT_DATA_TABLES`) but **leaves media trees** on disk (G3). That is half-destructive and confusing for ops/compliance. Near-term fix direction:

1. **Stop** treating Class B as automatic wipe — remove `recordings` from default cascade (or gate behind `purge_recordings: true`).  
2. **Never** add CDR tables to FK CASCADE without the same explicit purge gate.  
3. Media/CDR purge = separate step with its own confirm copy (“deletes all call recordings / CDR for {shortuid}”).

When SQLite FKs land (T8): Class A tables get `ON DELETE CASCADE`; Class B tables stay **no FK** or `ON DELETE RESTRICT` / nullable detach — so deleting `cluster` cannot vacuum evidence by accident.

---

## 3. Real gaps (why suspicion is partly right)

| Gap | Risk | Notes |
|-----|------|--------|
| **G1** Cross-tenant `dialalias` rows **targeting** this tenant | Peers still dial a dead FQDN; **N-tenant manual cleanup is unacceptable** | Site Group remove already prunes mesh; **Fleet Delete must do the same** (I7 / T2) — Gatekeeper fan-out, not Sanctum hand edits |
| **G2** Catalog DIDs still attached | Fleet preflight **warns only**; no auto-unassign v1 | Locked in Fleet Delete “Not in v1” — still an integrity smell for go/no-go honesty |
| **G3** Greeting/recording **media trees** | Files left on disk; index rows wiped | Class B — see §2.2; default should **retain** evidence, not half-wipe |
| **G3b** `recordings` in default `TENANT_DATA_TABLES` | Index gone, files remain / compliance surprise | Align with I6 — opt-in purge only |
| **G3c** CDR plane | Not in tenant sqlite wipe today (good) | Keep out of CASCADE; explicit purge only if ever offered |
| **G4** Fleet wipe vs Sanctum wipe parity | Sanctum calls `pbx3_delete_park_asterisk_instances`; fleet did not | **T3 done** — Fleet `destroyTenant` calls the same helper |
| **G5** Orphans if `cluster` column holds a value **outside** aliases | Rare after normalize; possible on hand-edited DBs | **T4 done** — `pbx3:tenant-orphan-audit` |
| **G6** New tenant table added without `TENANT_DATA_TABLES` | Silent orphans on next delete | **T5 done** — `pbx3:tenant-wipe-list-check` + unit test |
| **G7** No DB RI | Manual SQL / buggy path can delete `cluster` alone | Defense in depth later |

DiDs **on the node** (`inroutes` with matching `cluster`) **are** in the wipe list — suspicion that DiDs are skipped is wrong for the happy path; catalog/SBC DiDs are the separate gap (G2).

---

## 4. Recommended slices (when scheduled)

| Slice | Deliverable |
|-------|-------------|
| **T1** | **Done** — Preflight counts API: `GET /fleet/tenants/{t}/wipe-preflight` (+ Sanctum solo twin); Gatekeeper stores `wipe_counts`; SPA confirm lists non-zero tables. Still allow wipe with confirm. |
| **T2** | **Done** — Fleet-orchestrated mesh prune (I7): `pruning_mesh` phase detaches Site Group + prunes peer dialaliases on reachable homes (warn if unreachable; retry / Sync now). Same-home inbound prune inside `destroyTenantData`. |
| **T3** | **Done** — Fleet wipe calls `pbx3_delete_park_asterisk_instances` (parity with Sanctum) |
| **T4** | **Done** — `php artisan pbx3:tenant-orphan-audit` (+ unit tests); reports child rows whose `cluster` ∉ live `cluster.id\|shortuid\|pkey` |
| **T5** | **Done** — `php artisan pbx3:tenant-wipe-list-check` (+ unit test); `TENANT_DATA_TABLES` ⊇ tenant-schema tables with a `cluster` column |
| **T6** | Catalog DID policy: block Fleet Delete confirm while DIDs attached **or** auto-unassign (product pick — today warn-only) |
| **T7** | Class B policy: default **retain** recordings index + media + CDR; optional `purge_recordings` / `purge_cdr` on Delete job with typed confirm; remove `recordings` from automatic wipe |
| **T8** | SQLite FK + `ON DELETE CASCADE` on **Class A** only — after T4/T5 + shortuid normalize; Class B **no** cascade FK; shrink app wipe to “delete cluster + Class A extras + optional Class B purge.” ETL/`-L`/dumper need FK-safe windows. |

**Order:** T1–T5 (stop list drift) → T2/T3/T6 + **T7 Class B** → **T8** (DB RI for Class A only).

---

## 5. Acceptance (T1–T5)

- Wipe still removes cluster + all listed child rows for aliases.  
- Sibling dialaliases targeting deleted tenant FQDN/shortuid gone after wipe **on all reachable peer homes** (Fleet fan-out; retry covers the rest).  
- Fleet wipe removes park instances like Sanctum.  
- Orphan audit returns 0 on golden after delete lab.  
- Adding a new `cluster`-keyed table without list update fails CI.

---

## 6. Explicit non-goals

- Blocking Delete solely because extensions/DiDs exist.  
- Cascading **instance** trunks with the tenant.  
- Believing SQLite FK will cascade **S3 / Magrathea / sibling peers** — it will not.  
- **Silent** wipe of call recordings or CDR as part of ordinary tenant Delete (Class B = opt-in only).  
- Full S3 catalog hard-purge (Fleet Delete catalog soft-decommission stays until a later product pick).  
- **Leaving Site Group prefix projections stale** after Fleet Delete for operators to clean by hand (I7 — prune is Fleet’s job).
