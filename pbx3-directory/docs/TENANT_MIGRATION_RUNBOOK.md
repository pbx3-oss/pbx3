# Tenant migration between fleet instances

**Status:** Phase **S8.5–S8.6** (see **`IMPLEMENTATION_PLAN.md`** § Phase S8).  
**Goal:** Move a tenant from instance **A** (source) to **B** (destination) with minimal downtime and consistent catalog, DNS, TLS, and Asterisk config.

**Tooling:** `php artisan tenant:export` / `tenant:import` on each node (pbx3api **main**). Catalog: **`move-tenant.sh`**.

**Worked example below:** **08jzwn** → **bzy54n** (golden → second fleet node). Replace tenant shortuid / KSUID with your tenant.

---

## Fleet reference (this exercise)

| | Source **08jzwn** | Destination **bzy54n** |
|--|-------------------|------------------------|
| FQDN | `08jzwn.pbx3.com` | `bzy54n.pbx3.com` |
| KSUID (`globals.id`) | `3DmAsxePTWQZgynBYXE8obIRqEE` | `3E3gAOVGBhvc6vEPTBIYCBPycIk` |
| EC2 (May 2026) | `i-02ec2b05b5baacb5d` | `i-0bb601e7b1253c3f5` |
| Target package | `pbx3 0.0.3-21` on **main** | Upgrade from **0.0.3-10** → **0.0.3-21** first |

**Mac ops:** **`OPERATOR_MAC_SETUP.md`** · **`PBX3_ORG_BUCKET=08jzwn-pbx3`**

---

## Concepts

| Item | Moves? | Notes |
|------|--------|-------|
| Tenant **`cluster.id`** (KSUID) | **Keep** | Export/import preserves object KSUIDs |
| **`cluster.shortuid`** / **`pkey`** | Usually keep | S3 paths use **shortuid** |
| **`cluster.fqdn`** | Often unchanged | DNS **A** must point to **B** after cutover |
| **Trunks** | **No** (instance-owned) | Destination must have usable trunks; outbound routes may reference trunk **pkey** — map or create matching trunks on **B** before Commit |
| Recordings on S3 | **Stay** under `tenants/{shortuid}/recordings/` | `move-tenant.sh` does not copy prefix |
| Recordings on node | Optional | `tenant:export --include-recordings` |
| Instance backups | Per `instances/{ksuid}/backups/` | Historical backups stay on source |

---

## Phase 0 — Bring destination to current release

**bzy54n** is on **0.0.3-10**; source/golden tooling expects **0.0.3-21** (restore scripts, fleet preflight, tenant export/import).

On **bzy54n** (SSH as `ubuntu`):

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ssmtp
sudo chmod +x /etc/ssmtp 2>/dev/null || true

# Copy pbx3_0.0.3-21_all.deb from build machine or golden, then:
sudo apt install ./pbx3_0.0.3-21_all.deb
```

Deploy **pbx3api** from **main** (git pull in `/opt/pbx3api`, `composer install`, re-run installer if nginx/php changed):

```bash
cd /opt/pbx3api
sudo git pull origin main
sudo composer install --no-dev --optimize-autoloader
sudo /opt/pbx3api/scripts/installer.sh
```

Merge help seeds (safe after large version jump):

```bash
sudo sqlite3 /opt/pbx3/db/sqlite.db < /opt/pbx3/db/db_sql/sqlite_message.sql
```

Fleet health:

```bash
cd /opt/pbx3api && sudo -u www-data php artisan pbx3:fleet-preflight
```

Re-onboard if IAM/`.env` drifted while the node was down — **`onboard-fleet-instance.sh`** (see **`INSTANCE_ONBOARDING.md`**).

**Do not** run `reloader.sh` on a configured node.

---

## Phase 1 — Preparation

On **source (08jzwn)** record for the tenant you are moving:

```bash
sudo sqlite3 /opt/pbx3/db/sqlite.db \
  "SELECT id, shortuid, pkey, fqdn FROM cluster WHERE pkey != 'default';"
```

Checklist:

- [ ] Destination **Phase 0** complete; `pbx3:fleet-preflight` green on **bzy54n**
- [ ] Same **`globals.domain`** on both nodes (e.g. `pbx3.com`)
- [ ] Destination has (or will have) trunks for outbound routes after import
- [ ] Maintenance window agreed (brief quiesce before DNS cutover optional)

---

## Phase 2 — Export on source (A)

On **08jzwn**:

```bash
cd /opt/pbx3api

# Replace {tenant} with shortuid, pkey, or cluster KSUID — e.g. affcot, duns, sandycroft, willand
sudo -u www-data php artisan tenant:export {tenant}

# Optional: include on-node recording wav files
sudo -u www-data php artisan tenant:export {tenant} --include-recordings
```

Output: `/opt/pbx3/bkup/pbx3tenant.{shortuid}.{epoch}.zip` (manifest + `tenant.sqlite.db` + greeting media).

Copy zip to Mac or straight to destination:

```bash
# From Mac (adjust key path and tenant shortuid):
scp -i ~/path/to/pbx3test.pem \
  ubuntu@08jzwn.pbx3.com:/opt/pbx3/bkup/pbx3tenant.{shortuid}.*.zip \
  /tmp/

scp -i ~/path/to/pbx3test.pem \
  /tmp/pbx3tenant.{shortuid}.*.zip \
  ubuntu@bzy54n.pbx3.com:/tmp/
```

On **bzy54n**:

```bash
sudo mkdir -p /opt/pbx3/bkup
sudo mv /tmp/pbx3tenant.*.zip /opt/pbx3/bkup/
sudo chown www-data:www-data /opt/pbx3/bkup/pbx3tenant.*.zip
```

---

## Phase 3 — Import on destination (B)

On **bzy54n**:

```bash
cd /opt/pbx3api
ZIP=/opt/pbx3/bkup/pbx3tenant.{shortuid}.*.zip

sudo -u www-data php artisan tenant:import "$ZIP"
```

If the tenant already exists on **bzy54n** (e.g. old test row), use **`--replace`**:

```bash
sudo -u www-data php artisan tenant:import "$ZIP" --replace
```

Verify in SPA (proxy to bzy54n): tenant list, extensions, inbound routes, queues.

**Trunks:** Create or map trunks on **bzy54n** so outbound route `path1`…`path4` resolve. Trunks are **not** in the export zip.

---

## Phase 4 — Asterisk config (both nodes)

On **bzy54n** (and later on **08jzwn** after source cleanup):

1. SPA → **Commit** (runs `genAst.sh` + reload)
2. Place a test call on **bzy54n** before DNS cutover (use node API URL or hosts override)

---

## Phase 5 — DNS cutover

Point tenant FQDN **A** record to **bzy54n** public IP (unchanged hostname, new IP).

```bash
# From Mac — after DNS propagates:
dig +short {tenant}.pbx3.com
```

---

## Phase 6 — TLS (both nodes)

Per **`LETSENCRYPT_PER_TENANT_FQDN.md`** §4.2 / **`TLS_IMPLEMENTATION_STEPS.md`** §4.2:

1. **bzy54n:** Certificates → **Sync with tenant list** (tenant FQDN must be in SANs)
2. **08jzwn:** After tenant removed on source → **Sync** to drop moved tenant FQDN from cert
3. **Commit** on both if firewall inline FQDN list changed

---

## Phase 7 — Catalog (Mac)

```bash
cd pbx3/pbx3-directory/tools
export PBX3_ORG_BUCKET=08jzwn-pbx3

./move-tenant.sh \
  --tenant-shortuid {shortuid} \
  --instance-id 3E3gAOVGBhvc6vEPTBIYCBPycIk \
  --fqdn {tenant.fqdn}
```

Does **not** copy `tenants/{shortuid}/recordings/` on S3 (prefix unchanged; `instance_id` in meta updates).

---

## Phase 8 — Remove tenant on source (A)

On **08jzwn** after **bzy54n** is validated:

1. SPA → delete tenant (not **`default`**)
2. Certificates → **Sync**
3. **Commit**
4. Mac: `move-tenant.sh` already points catalog at **bzy54n**

---

## Validation

- [ ] `tenants/{shortuid}/meta.json` → `"instance_id": "3E3gAOVGBhvc6vEPTBIYCBPycIk"`
- [ ] Login to **bzy54n** API; tenant data complete
- [ ] Inbound/outbound test call after DNS + LE
- [ ] LE on **bzy54n** includes tenant FQDN; **08jzwn** cert no longer includes it
- [ ] `pbx3:fleet-preflight` green on both nodes

---

## Rollback

If cutover fails before source tenant delete:

1. Revert DNS **A** to **08jzwn**
2. LE **Sync** on **08jzwn**
3. Catalog: `move-tenant.sh` back to `3DmAsxePTWQZgynBYXE8obIRqEE`
4. Do **not** delete tenant on source until **bzy54n** is proven

---

## References

- **`LETSENCRYPT_PER_TENANT_FQDN.md`** §4.2 / §8 — cert sync on move
- **`TLS_IMPLEMENTATION_STEPS.md`** §4.2
- **`TRUNK_ROUTE_MULTITENANCY.md`** — trunks not in tenant miniDB
- **`NEW_INSTANCE_CHECKLIST.md`** · **`INSTANCE_ONBOARDING.md`**
- **`tools/move-tenant.sh`**, **`tools/README.md`**
- Legacy: **`backupClusters.php`** (per-tenant sqlite only; use **`tenant:export`** for fleet moves)
