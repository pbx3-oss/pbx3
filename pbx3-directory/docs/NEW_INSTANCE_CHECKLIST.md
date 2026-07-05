# New fleet instance — operator checklist

**Status:** Phase **S8** — see **`IMPLEMENTATION_PLAN.md`** § Phase S8.

**Rebuild a failed EC2 (same KSUID):** use **`REBUILD_INSTANCE_RUNBOOK.md`** only — S3 latest backup → restore → onboard. Do not use § B below for rebuilds.

**Goal:** One linear path to a healthy fleet node (backups, catalog, LE) without tribal knowledge.

| Topic | Doc |
|-------|-----|
| **Rebuild from S3 (catastrophic EC2 loss)** | **`REBUILD_INSTANCE_RUNBOOK.md`** |
| Ubuntu install | **`pbx3/workingdocs/INSTALL_SEQUENCE_UBUNTU.md`** |
| Fleet join (2nd+ node) | **`INSTANCE_ONBOARDING.md`** |
| S3 / IAM / golden pattern | **`OPS_S3_RUNBOOK.md`** |
| Automation | **`tools/onboard-fleet-instance.sh`** |

---

## A — New EC2 instance (greenfield, new KSUID)

- [ ] **A.1** Ubuntu 24.04; SG: inbound **22**, **44300**, **80** (LE), SIP as needed; outbound **443** (S3)
- [ ] **A.2** `apt install` **pbx3** + **pbx3api** debs; deploy API under **`/opt/pbx3api`**
- [ ] **A.3** `sudo /opt/pbx3/scripts/installer.sh` (first run creates DB + instance identity)
- [ ] **A.4** Record **`globals.id`** (KSUID), `shortuid`, `fqdn`:

  ```bash
  sqlite3 /opt/pbx3/db/sqlite.db \
    "SELECT id, shortuid, fqdn FROM globals WHERE pkey='global';"
  ```

- [ ] **A.5** `curl -k -sS -o /dev/null -w "%{http_code}\n" https://127.0.0.1:44300/up` → **200**
- [ ] **A.6** DNS **A** for `globals.fqdn` → instance public IP
- [ ] **A.7** LE: **`le-instance-bootstrap.sh`** or SPA **Certificates → Get certificate**
- [ ] **A.8** **Mac:** IAM policy scoped to `instances/{KSUID}/*`; role + instance profile; **attach to EC2**
- [ ] **A.9** **Node `.env`** (`/opt/pbx3api/.env`):

  ```env
  AWS_DEFAULT_REGION=us-east-1
  PBX3_ORG_BUCKET={org}-pbx3
  PBX3_DIRECTORY_BACKUP_UPLOAD=true
  ```

  No empty `AWS_ACCESS_KEY_ID=` / `AWS_SECRET_ACCESS_KEY=` — use **instance role**.

- [ ] **A.10** `cd /opt/pbx3api && sudo composer install --no-dev && sudo php artisan config:clear`
- [ ] **A.11** `sudo php artisan pbx3:fleet-preflight` → all green
- [ ] **A.12** **Mac:** `register-instance.sh` — catalog `id` = node **`globals.id`**
- [ ] **A.13** Create backup → panel shows **local+S3** (or run `pbx3:upload-backup`)

**Fast path:** **`onboard-fleet-instance.sh`** after A.1–A.5 (must still verify IAM attach).

---

## B — Rebuild / replace instance (same KSUID)

**Use `REBUILD_INSTANCE_RUNBOOK.md`** — single path: S3 latest backup → `restore-backup-zip.sh` → `onboard-fleet-instance.sh` → DNS/LE → `pbx3:fleet-preflight`.

Do not run **`reloader.sh`** after restore.

---

## C — Tenant DNS (multi-tenant LE)

- [ ] **C.1** Each tenant: **A** record `{shortuid}.pbx3.com` → node IP (or target after move)
- [ ] **C.2** After add/remove/restore: **Certificates → Sync with tenant list** (not **Renew** alone)
- [ ] **C.3** Package **≥ 0.0.3-17** for SAN replace on sync (`le-sync-cert-sans.sh` without `--expand`)

---

## D — Verification (sign-off)

| Check | Command / UI |
|-------|----------------|
| API up | `curl -k https://127.0.0.1:44300/up` |
| KSUID stable | `globals.id` = catalog row `id` = S3 prefix |
| Fleet preflight | `sudo php artisan pbx3:fleet-preflight` |
| IAM | `curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/` returns role name |
| S3 backups | Backups panel or `BackupIndexService` lists `source=s3` or `both` |
| Catalog | SPA picker shows instance |

---

## Related (not instance create)

**Tenant move** between nodes → **`TENANT_MIGRATION_RUNBOOK.md`** (Phase S8 — export/import + catalog + LE on both nodes).
