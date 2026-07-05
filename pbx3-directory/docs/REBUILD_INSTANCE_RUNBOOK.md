# Rebuild a fleet node from S3

**Status:** Phase **S8** (see **`IMPLEMENTATION_PLAN.md`** § Phase S8).  
**Audience:** Operators replacing a failed EC2 instance for an **existing** fleet node (same KSUID, same FQDN).

**Principle:** S3 holds the data of record. Every active fleet node must have a recent backup under  
`s3://{org-bucket}/instances/{globals.id}/backups/{stamp}/backup.zip`.  
Rebuild = empty EC2 → install stack → restore **latest S3 backup** → rejoin fleet → DNS/LE → verify.

**Recovery point:** Time of the last successful S3 upload (not the moment the old instance failed).

---

## Before you start (preconditions)

Record these values **before** terminating the old EC2 (from catalog, SPA, or S3):

| Field | Example (golden) | Where |
|-------|------------------|--------|
| Instance KSUID | `3DmAsxePTWQZgynBYXE8obIRqEE` | `globals.id`, catalog row `id` |
| FQDN | `08jzwn.pbx3.com` | catalog / `globals.fqdn` |
| Fleet bucket | `08jzwn-pbx3` | fleet config |
| AWS region | `us-east-1` | EC2 / bucket |
| New EC2 instance id | `i-…` | AWS console (after launch) |

**Hard stop:** If S3 has no backups for that KSUID, create a backup from the donor while it still runs, then continue.

```bash
export PBX3_ORG_BUCKET=08jzwn-pbx3
aws s3 ls s3://08jzwn-pbx3/instances/3DmAsxePTWQZgynBYXE8obIRqEE/backups/
```

You must see at least one `{stamp}/` prefix with `backup.zip` inside.

**Mac prerequisites:** AWS CLI with **ops/admin** credentials (`aws sts get-caller-identity` — ARN must **not** be `assumed-role/pbx3-node-…`), `jq`, `ssh`, pbx3 `.deb` + pbx3api source for the new node.

---

## Phase 1 — Empty EC2: install PBX stack

On the **new** instance (SSH as `ubuntu`):

1. Ubuntu **24.04** LTS.
2. Security group: inbound **22**, **44300**, **80** (LE); outbound **443** (S3).
3. Install packages:

   ```bash
   sudo apt install ./pbx3_*.deb
   # deploy pbx3api to /opt/pbx3api — see pbx3/workingdocs/INSTALL_SEQUENCE_UBUNTU.md
   sudo /opt/pbx3/scripts/installer.sh
   sudo /opt/pbx3api/scripts/installer.sh
   ```

4. Confirm API health (throwaway DB is OK — it will be replaced):

   ```bash
   curl -k -sS -o /dev/null -w "%{http_code}\n" https://127.0.0.1:44300/up
   # expect 200
   ```

Do **not** set `PBX3_ORG_BUCKET` in `.env` yet. Do **not** attach an IAM instance profile yet.

---

## Phase 2 — Mac: fetch latest S3 backup

From your Mac (pbx3 git clone):

```bash
cd pbx3/pbx3-directory/tools
chmod +x fetch-latest-instance-backup.sh

export PBX3_ORG_BUCKET=08jzwn-pbx3

ZIP=$(./fetch-latest-instance-backup.sh \
  --instance-id 3DmAsxePTWQZgynBYXE8obIRqEE \
  --output-dir /tmp)

echo "Downloaded: $ZIP"
```

This always selects the **newest** archive under `instances/{KSUID}/backups/`.  
Output is named `pbx3bak.{epoch}.zip` (required by the restore script).

---

## Phase 3 — Mac: copy backup to new node and restore

Replace `NEW_EC2_IP` and key path:

```bash
scp -i ~/path/to/pbx3test.pem "$ZIP" ubuntu@NEW_EC2_IP:/tmp/

ssh -i ~/path/to/pbx3test.pem ubuntu@NEW_EC2_IP \
  'sudo mkdir -p /opt/pbx3/bkup && \
   sudo mv /tmp/pbx3bak.*.zip /opt/pbx3/bkup/ && \
   sudo chown www-data:www-data /opt/pbx3/bkup/pbx3bak.*.zip && \
   sudo /opt/pbx3/scripts/restore-backup-zip.sh --full /opt/pbx3/bkup/pbx3bak.*.zip'
```

**Important:**

- The restore script replaces **`sqlite.db`** and telephony files from the zip.
- **Never** run **`reloader.sh`** after restore.
- Because the backup came from **this instance’s S3 prefix**, `globals.id` (KSUID) is already correct — **no identity SQL patch** for a same-node rebuild.

Merge help seeds (safe, idempotent):

```bash
ssh -i ~/path/to/pbx3test.pem ubuntu@NEW_EC2_IP \
  'sudo sqlite3 /opt/pbx3/db/sqlite.db < /opt/pbx3/db/db_sql/sqlite_message.sql'
```

---

## Phase 4 — Mac: rejoin fleet (IAM + `.env`)

```bash
cd pbx3/pbx3-directory/tools
export PBX3_ORG_BUCKET=08jzwn-pbx3

./onboard-fleet-instance.sh \
  --instance-id i-NEWEC2INSTANCE \
  --ssh ubuntu@NEW_EC2_IP \
  --ssh-key ~/path/to/pbx3test.pem \
  --region us-east-1
```

This step: IAM policy + instance profile attach + `.env` fleet block + S3 smoke + catalog verify.

Optional backup upload smoke if a local zip exists:

```bash
./onboard-fleet-instance.sh ... --smoke-backup
```

---

## Phase 5 — DNS, certificates, sign-off

1. **DNS:** Point `globals.fqdn` and each tenant `{shortuid}.pbx3.com` **A** record to the **new** public IP.
2. **LE:** SPA **Certificates → Sync with tenant list** (not **Renew** alone). Package **≥ 0.0.3-17**.
3. **Commit:** SPA **Commit** if Asterisk configs need regeneration.
4. **Fleet preflight** (on node):

   ```bash
   cd /opt/pbx3api && sudo php artisan pbx3:fleet-preflight
   ```

5. **Backups panel:** Should list S3 archives (`source=s3` or `both`).

| Check | Pass |
|-------|------|
| `curl -k https://127.0.0.1:44300/up` → 200 | |
| `globals.id` = catalog `id` = S3 prefix KSUID | |
| IAM metadata returns role name | |
| `pbx3:fleet-preflight` all green | |
| SPA backups show S3 rows | |

---

## What is not in the backup zip

| Item | Restored how |
|------|----------------|
| EC2 IAM instance profile | Phase 4 — `onboard-fleet-instance.sh` |
| `pbx3api/.env` fleet block | Phase 4 |
| DNS | Phase 5 |
| LE cert files on disk | Phase 5 — Certificates Sync |
| Call recordings (until S7) | On-node media only if in backup; S3 recordings prefix separate |

Catalog row (`instance-index.json`) usually **persists** in S3 — onboard verifies it; you do not re-register unless the instance was unregistered.

---

## Related docs

| Topic | Doc |
|-------|-----|
| Greenfield (new fleet node, new KSUID) | **`NEW_INSTANCE_CHECKLIST.md`** § A |
| Install order | **`pbx3/workingdocs/INSTALL_SEQUENCE_UBUNTU.md`** |
| S3 / IAM detail | **`OPS_S3_RUNBOOK.md`** |
| Tenant move (different workflow) | **`TENANT_MIGRATION_RUNBOOK.md`** |

---

## Tool reference

| Script | Where | Role |
|--------|-------|------|
| `fetch-latest-instance-backup.sh` | Mac — `pbx3-directory/tools` | Download newest `backup.zip` → `pbx3bak.{epoch}.zip` |
| `restore-backup-zip.sh` | Node — `/opt/pbx3/scripts` | Full restore from local zip |
| `onboard-fleet-instance.sh` | Mac — `pbx3-directory/tools` | IAM + `.env` + catalog + S3 smoke |
| `pbx3:fleet-preflight` | Node — `php artisan` | Pass/fail fleet health checks |
