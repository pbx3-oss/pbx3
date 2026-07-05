# Tenant migration between fleet instances

**Status:** Draft outline (Phase **S8** — see **`IMPLEMENTATION_PLAN.md`** § Phase S8).  
**Goal:** Move a tenant from instance **A** to **B** with minimal downtime and consistent catalog, DNS, TLS, and config.

**Today (May 2026):** Only **`move-tenant.sh`** updates S3 **`tenants/{shortuid}/meta.json`** (`instance_id`, `moved_at`). **No** integrated export/import API or SPA wizard. Operator steps below are manual + documented gaps.

---

## Concepts

| Item | Moves? | Notes |
|------|--------|-------|
| Tenant **`cluster.id`** (KSUID) | **Keep** | Object rows reference tenant KSUID — preserve on import |
| Tenant **`cluster.shortuid`** / **`pkey`** | Usually keep | Catalog paths use **shortuid** |
| **`cluster.fqdn`** | Often unchanged | DNS A record must point to **new** node IP after cutover |
| Recordings on S3 | **Stay** under `tenants/{shortuid}/recordings/` | **`move-tenant.sh`** does not copy prefix; implement **Phase S7** upload before move if recordings must survive local ageing |
| Recordings on node only | Move with tenant DB | **Phase R1** operator access; export/import (**S8.6**) must include recording paths or re-point `rec_final_dest` |
| Instance backups | Per **`instances/{ksuid}/backups/`** | Historical backups stay on source instance prefix |

---

## Target workflow (S8 exit)

```text
Source (A)                    Destination (B)
─────────                     ───────────────
1. Export tenant data    →    2. Import tenant (same cluster.id)
3. (optional) quiesce           4. DNS cutover → B
5. Remove tenant on A           6. Certificates Sync (B, then A)
7. Commit A + B                 8. move-tenant.sh (catalog)
```

---

## Manual workflow (until S8.6 tooling)

### Preparation

- [ ] Destination instance **healthy** — follow **`NEW_INSTANCE_CHECKLIST.md`**
- [ ] Record tenant **shortuid**, **KSUID** (`cluster.id`), **fqdn** on source
- [ ] Destination has capacity; same **`globals.domain`** (e.g. `pbx3.com`)

### Data move (gap — operator-heavy)

- [ ] **Option 1:** Full instance backup/restore onto B, then delete other tenants (heavy)
- [ ] **Option 2:** Per-tenant mini DB from **`backupClusters.php`** (investigate / script — **S8.6**)
- [ ] **Option 3:** Future **`tenant:export` / `tenant:import`** (**S8.6**)

After import on **B**: verify tenant in SPA, extensions/routes present.

### Network & TLS

- [ ] DNS: **A** record for **`cluster.fqdn`** → destination public IP
- [ ] **B:** Certificates → **Sync with tenant list** (include tenant FQDN)
- [ ] **A:** Remove tenant (or disable); **Sync** to drop tenant FQDN from cert
- [ ] **Commit** on both nodes

### Catalog (Mac / ops IAM)

```bash
export PBX3_ORG_BUCKET=08jzwn-pbx3
./pbx3-directory/tools/move-tenant.sh \
  --tenant-shortuid {shortuid} \
  --instance-id {DEST_globals.id} \
  --fqdn {tenant.fqdn}
```

### Validation

- [ ] Login to destination API; select tenant; place test call
- [ ] `tenants/{shortuid}/meta.json` shows new **`instance_id`**
- [ ] LE cert on B includes tenant FQDN; A cert no longer includes it (if removed)

---

## References

- **`LETSENCRYPT_PER_TENANT_FQDN.md`** §4.2 / §8 — cert sync on move
- **`TLS_IMPLEMENTATION_STEPS.md`** §4.2
- **`S3_LAYOUT_PROPOSAL.md`** — tenant meta + recordings layout
- **`tools/move-tenant.sh`**, **`tools/README.md`**
