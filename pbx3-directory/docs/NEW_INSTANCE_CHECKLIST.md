# New fleet instance — operator checklist

**Status:** Draft (Phase **S8** — see **`IMPLEMENTATION_PLAN.md`** § Phase S8).  
**Goal:** One linear path to a healthy fleet node (backups, catalog, LE) without tribal knowledge.

**Supersedes as “start here”** (detail remains in linked docs):

| Topic | Deep dive |
|-------|-----------|
| Ubuntu install | **`pbx3/workingdocs/INSTALL_SEQUENCE_UBUNTU.md`** |
| Fleet join (2nd+ node) | **`INSTANCE_ONBOARDING.md`** |
| S3 / IAM / golden pattern | **`OPS_S3_RUNBOOK.md`** Golden node playbook |
| Automation | **`tools/onboard-fleet-instance.sh`** |

---

## A — New EC2 instance (greenfield)

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
- [ ] **A.8** **Mac:** IAM policy scoped to `instances/{KSUID}/*`; role + instance profile; **attach to EC2** (required for S3 backups)
- [ ] **A.9** **Node `.env`** (`/opt/pbx3api/.env`):

  ```env
  AWS_DEFAULT_REGION=us-east-1
  PBX3_ORG_BUCKET={org}-pbx3
  PBX3_DIRECTORY_BACKUP_UPLOAD=true
  ```

  No empty `AWS_ACCESS_KEY_ID=` / `AWS_SECRET_ACCESS_KEY=` — use **instance role**.

- [ ] **A.10** `cd /opt/pbx3api && sudo composer install --no-dev && sudo php artisan config:clear`
- [ ] **A.11** S3 smoke — instance role can list backups prefix (see **`OPS_S3_RUNBOOK.md`** or S8 preflight script)
- [ ] **A.12** **Mac:** `register-instance.sh` — catalog `id` = node **`globals.id`**
- [ ] **A.13** Create backup → panel shows **local+S3** (or run `pbx3:upload-backup`)

**Fast path:** **`onboard-fleet-instance.sh`** after A.1–A.5 (must still verify A.8 IAM attach).

---

## B — Rebuild / replace instance (same KSUID)

Use when EC2 is replaced but fleet identity (**`globals.id`**) stays the same.

- [ ] **B.1** Complete **§ A** stack install (A.2–A.5)
- [ ] **B.2** Restore DB or run installer on fresh DB — then **patch identity** if DB came from another host:

  ```sql
  UPDATE globals SET id='…', shortuid='…', fqdn='…', domain='pbx3.com' WHERE pkey='global';
  UPDATE cluster SET fqdn='{node-fqdn}', domain='pbx3.com' WHERE pkey='default';
  ```

  `sudo /opt/pbx3/scripts/normalize-globals-identity.sh` — **do not** run **`reloader.sh`**.

- [ ] **B.3** Merge help seeds if needed:  
  `sudo sqlite3 /opt/pbx3/db/sqlite.db < /opt/pbx3/db/db_sql/sqlite_message.sql`
- [ ] **B.4** Re-attach **IAM instance profile** (rebuilds often lose this — backups panel empty)
- [ ] **B.5** Restore **`.env` fleet block** (not in `sqlite.db` — stock Laravel `.env` is not enough)
- [ ] **B.6** DNS + **Certificates → Sync** if tenant FQDNs changed
- [ ] **B.7** SPA **Commit**; verify backups panel lists S3 archives

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
| IAM | `curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/` returns role name |
| S3 backups | Backups panel or `BackupIndexService` lists `source=s3` or `both` |
| Catalog | SPA picker shows instance |

---

## Related (not instance create)

**Tenant move** between nodes → **`TENANT_MIGRATION_RUNBOOK.md`** (Phase S8 — export/import + catalog + LE on both nodes).
