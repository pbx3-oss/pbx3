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

**Asterisk config symlinks:** `installer.sh` runs `runLinker.php` on first provision. **`apt install` / upgrade** also runs it from package **postinst** (from **0.0.3-22**). If a node was upgraded **before** that fix and extensions do not register after Commit, run once:

```bash
sudo php /opt/pbx3/php/utilities/runLinker.php
```

Then **Commit** again (or `core reload`). Verify e.g. `ls -l /etc/asterisk/pjsip.conf` → `/opt/pbx3/etc/asterisk/configs/pjsip.conf`. This is **not** run on every Commit — only install/upgrade (or manual repair).

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

**Firewall (automatic):** `tenant:import` runs **`update-fqdn-inline.sh`** after the DB merge (same hook as tenant create/update/delete in the API). That rebuilds `/etc/shorewall/pbx3_inline_fqdn` from **`cluster.fqdn`** and restarts Shorewall. No manual firewall step is required after import.

**Prerequisite:** Destination **`globals.fqdninspect`** should be **`YES`** if the fleet uses SIP URI string matching on UDP/TCP 5060 (golden **08jzwn** has this on). When **`fqdninspect`** is **`NO`**, the script clears inline FQDN rules and public SIP is limited to the VPC CIDR — phones on the internet will not register. Set via SPA → System Globals → “Filter my FQDN for SIP?” or:

```bash
sudo sqlite3 /opt/pbx3/db/sqlite.db "UPDATE globals SET fqdninspect='YES';"
sudo /opt/pbx3/scripts/update-fqdn-inline.sh
```

Confirm rules after import:

```bash
sudo cat /etc/shorewall/pbx3_inline_fqdn
sudo iptables -L net-fw -n | grep -i string
```

**Trunks:** Create or map trunks on **bzy54n** so outbound route `path1`…`path4` resolve. Trunks are **not** in the export zip.

---

## Phase 4 — Asterisk config (both nodes)

On **bzy54n** (and later on **08jzwn** after source cleanup):

1. SPA → **Commit** (runs `genAst.sh` + reload)
2. Place a test call on **bzy54n** before DNS cutover (use node API URL or hosts override)

### Troubleshooting: extensions not registering after Commit

**Symptom:** DB and SPA show extensions; Asterisk does not (UDP REGISTER fails or ext-to-ext does nothing).

**Cause:** Generated configs live under `/opt/pbx3/etc/asterisk/configs/`, but Asterisk reads `/etc/asterisk/`. Those paths are connected by **symlinks** from `runLinker.php` (from `installer.sh` on first provision, and from package **postinst** on `apt upgrade` from **0.0.3-22** onward). Nodes upgraded earlier may still have stock `/etc/asterisk` files — a one-time gap, not something Commit should fix on every run.

**Fix (once per node if symlinks were never created):**

```bash
sudo php /opt/pbx3/php/utilities/runLinker.php
```

Then **Commit** again (SPA) or `sudo asterisk -rx 'core reload'`. Verify e.g. `ls -l /etc/asterisk/pjsip.conf` points at `/opt/pbx3/etc/asterisk/configs/pjsip.conf`.

### Troubleshooting: phones blocked after import (stale or missing firewall STRING rules)

**Symptom:** Extensions in DB; REGISTER fails from the internet; `iptables -L net-fw` shows golden/source FQDNs, or no STRING rules at all.

**Cause:** Stale **`pbx3_inline_fqdn`** from a clone/restore (rules from another node), or **`fqdninspect=NO`** so inline rules are empty. Import now regenerates rules automatically; older pbx3api builds did not.

**Fix:**

1. Ensure **`globals.fqdninspect=YES`** on the destination (see Phase 3).
2. Re-run import (or once manually): `sudo /opt/pbx3/scripts/update-fqdn-inline.sh`
3. Verify **`cluster.fqdn`** for imported tenants appears in `pbx3_inline_fqdn` (two lines per FQDN: TCP + UDP 5060).
4. Phones must send the tenant hostname in SIP (not IP-only) for STRING match to pass.

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
3. **Commit** on both after cert sync (import/delete already refresh firewall inline FQDN rules)

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

## Phase 8 — Remove tenant on source (A) — **required, not optional**

**Preferred path (orchestrated):** after verifying, the move job reaches `awaiting_cleanup`. Operator confirms **Wipe tenant on source** — Gatekeeper calls source `DELETE /fleet/tenants/{shortuid}` (full cascade: all cluster-scoped rows + portable users), then source certificates sync + Commit. Do not mark the move complete without this gate.

**Manual / break-glass** (same outcome, if not using the job UI) on the **source** node after destination is validated:

1. SPA → delete tenant (not **`default`**) — must remove **all** cluster-scoped rows **and** portable users for that shortuid (API wipe path; Eloquent-only cluster delete is insufficient)
2. Certificates → **Sync**
3. **Commit**
4. Catalog already points at dest when the job ran `moveTenant` (or Mac: `move-tenant.sh`)

**Lesson (2026-07-22):** Incomplete source cleanup after willand/affcot moves left **orphan** `ipphone` / `inroutes` / … rows whose `cluster` shortuid no longer exists in `cluster`. SPA Tenant column then shows the raw shortuid (e.g. `0ggybk`, `9wvvnb`) instead of a pkey. **Sandycroft** move wiped source properly — no orphans.  

**Product rule for the move job:** after successful import + validation, **always** destroy source tenant rows (and detach/remove portable users) in the same job path — do not rely on a forgotten manual Phase 8.

---

## Validation

- [ ] `tenants/{shortuid}/meta.json` → `"instance_id": "3E3gAOVGBhvc6vEPTBIYCBPycIk"`
- [ ] Login to **bzy54n** API; tenant data complete; **source** has **zero** rows for that shortuid (no orphan extensions showing shortuid as Tenant)
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
