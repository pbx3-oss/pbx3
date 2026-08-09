# Rebuild a fleet node from S3

**Status:** Phase **S8** (see **`IMPLEMENTATION_PLAN.md`** § Phase S8).  
**Audience:** Operators replacing a failed EC2 instance for an **existing** fleet node (same KSUID, same FQDN).

**Principle:** S3 holds the data of record. Every active fleet node must have a recent backup under  
`s3://{org-bucket}/instances/{globals.id}/backups/{stamp}/backup.zip`.  
Rebuild = empty EC2 → install stack → restore **latest S3 backup** → rejoin fleet → DNS/LE → verify.

**Recovery point:** Time of the last successful S3 upload (not the moment the old instance failed).

**Mac SSH + AWS CLI (read first):** **`OPERATOR_MAC_SETUP.md`** — golden host, key path, `aws sts`, common agent failures.

**Agent-assisted rebuild (Tier B):** An AI agent can execute this runbook end-to-end using in-repo docs and tools — see **`SELF_SERVICE_REBUILD_DESIGN.md`** § Mode 4. Kickoff for a new agent session:

```text
Rebuild fleet node from S3 — follow REBUILD_INSTANCE_RUNBOOK.md on main.
Instance KSUID: {ksuid}. Org bucket: {bucket}. Region: {region}.
Use latest S3 backup unless I specify a stamp.
Ask before: terminating EC2, DNS cutover, IAM-impacting changes on production.
After restore: pbx3:fleet-preflight must be all green before we call it done.
```

Read first: **`~/GiT/pbx3-ops/AGENT_HANDOFF.md`** § Next agent session notes → this file → **`OPERATOR_MAC_SETUP.md`**.

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

**Mac prerequisites:** See **`OPERATOR_MAC_SETUP.md`** (SSH to golden, AWS CLI session, `PBX3_ORG_BUCKET`, ops vs node role). Quick check:

```bash
export PBX3_ORG_BUCKET=08jzwn-pbx3
export AWS_DEFAULT_REGION=us-east-1
aws sts get-caller-identity   # ARN must NOT contain assumed-role/pbx3-node-
```

---

## Phase 1 — Empty EC2: install PBX stack

On the **new** instance (SSH as `ubuntu`):

1. Ubuntu **24.04** LTS (ARM **`t4g.*`** is the usual golden-lab shape).
2. Security group: inbound **22**, **44300**, **80** (LE); outbound **443** (S3). Prefer allocating an **Elastic IP** now and associating it to this instance — one DNS update this rebuild, then future rebuilds are **EIP reassociate only** (no DNS churn). Auto-assigned public IPs are not convertible to EIPs later.
3. **Patch the AMI first** (especially on AWS ARM images — currency issues otherwise):

   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

4. **Mail relay** — install **before** `pbx3` so `installer.sh` can set `ssmtp.conf` permissions:

   ```bash
   sudo apt install -y ssmtp
   sudo chmod +x /etc/ssmtp
   ```

5. Install PBX stack:

   ```bash
   sudo apt install ./pbx3_*.deb
   # deploy pbx3api to /opt/pbx3api — see pbx3/workingdocs/INSTALL_SEQUENCE_UBUNTU.md
   sudo DOMAIN_TLD=pbx3.com /opt/pbx3/scripts/installer.sh
   sudo /opt/pbx3api/scripts/installer.sh
   ```

6. Confirm API health (throwaway DB is OK — it will be replaced):

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

`restore-backup-zip.sh` also runs **`sync-hostname-from-globals.sh`**, then **`genAst`** (sqlite is HoR for phones/trunks — fills ASTLOCALCONF under `/opt/pbx3/.../configs`), **`runLinker`**, and **`refresh-pjsip-externip.sh`**.  

**Why genAst after restore / apt:** GenAst output lives in the package tree (`ASTLOCALCONF`). Restore writes a snapshot under `/etc/asterisk`. Apt **`runLinker`** renames those files to `*_installed` and symlinks `/etc/asterisk` → ASTLOCALCONF. Without regenerating ASTLOCALCONF from the DB, that leaves empty/stale PJSIP endpoints (seen on 0.0.4-2 upgrade). Package **≥ 0.0.4-3** postinst runs genAst + externip refresh when `sqlite.db` exists.

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

## Phase 5 — DNS / EIP, edge dispatcher, certificates, sign-off

1. **Address cutover (pick one):**
   - **Preferred:** Instance already has an **EIP** → point **instance** FQDN A record at that EIP **once**. Later rebuilds: reassociate the same EIP; DNS unchanged. **SBC fleet:** do **not** create tenant public A records (**`TLS_AND_CERTIFICATES.md` §0**).
   - **Without EIP:** Point the **instance** A record at the new public IP (must repeat every rebuild).
2. **Fleet SBC (Magrathea / OpenSIPS):** Update the dispatcher destination for this node's setid to `sip:{EIP_or_public_ip}:5060` (IP only — not a DNS name), then `ds_reload`. If the node already uses a stable EIP in dispatcher, **skip** when only the EIP moved onto the new EC2.
3. **LE (fleet):** SPA **Certificates → Sync certificate** (or first-issue) for the **instance FQDN only** — not tenant SANs. CLI: `le-sync-cert-sans.sh <email> <instance-fqdn>`. (**Solo/direct:** Option A multi-SAN — **`LETSENCRYPT_PER_TENANT_FQDN.md`**.)
4. **Commit:** SPA **Commit** if Asterisk configs need regeneration (transport externip already refreshed at restore).
5. **Fleet preflight** (on node):

   ```bash
   cd /opt/pbx3api && sudo php artisan pbx3:fleet-preflight
   ```

6. **Catalog ↔ node tenants** (lab / B′ login guard — **do not skip**):

   ```bash
   # Mac/ops
   export PBX3_ORG_BUCKET=08jzwn-pbx3   # or your org bucket
   ./pbx3-directory/tools/reconcile-node-tenants.sh \
     --ssh ubuntu@NEW_EC2_IP \
     --ssh-key ~/Documents/pemfiles/pbx3test.pem
   # node_only → Fleet Create or --fix; see LAB_FLEET_TENANTS.md
   ```

7. **Backups panel:** Should list S3 archives (`source=s3` or `both`).

| Check | Pass |
|-------|------|
| `curl -k https://127.0.0.1:44300/up` → 200 | |
| `globals.id` = catalog `id` = S3 prefix KSUID | |
| IAM metadata returns role name | |
| `pbx3:fleet-preflight` all green (incl. Egress Avail) | |
| **`reconcile-node-tenants.sh` OK** (no node_only / wrong_home) | |
| SPA backups show S3 rows | |
| Phones REGISTER via SBC land on new node | |

---

## What is not in the backup zip

| Item | Restored how |
|------|----------------|
| EC2 IAM instance profile | Phase 4 — `onboard-fleet-instance.sh` |
| `pbx3api/.env` fleet block | Phase 4 |
| DNS / EIP association | Phase 5 |
| OpenSIPS dispatcher destination | Phase 5 (fleet SBC) — use EIP when possible |
| LE cert files on disk | Phase 5 — Certificates Sync / first issue |
| PJSIP `external_*` public IP | Phase 3 — `refresh-pjsip-externip.sh` (after Asterisk restore) |
| Call recordings (until S7) | On-node media only if in backup; S3 recordings prefix separate |

Catalog row (`instance-index.json`) usually **persists** in S3 — onboard verifies it; you do not re-register unless the instance was unregistered.

---

## Related docs

| Topic | Doc |
|-------|-----|
| **Mac SSH + AWS CLI** | **`OPERATOR_MAC_SETUP.md`** |
| **Self-service rebuild (design)** | **`SELF_SERVICE_REBUILD_DESIGN.md`** (S8.9) |
| Greenfield (new fleet node, new KSUID) | **`NEW_INSTANCE_CHECKLIST.md`** § A |
| Install order | **`pbx3/workingdocs/INSTALL_SEQUENCE_UBUNTU.md`** |
| S3 / IAM detail | **`OPS_S3_RUNBOOK.md`** |
| Tenant move (different workflow) | **`TENANT_MIGRATION_RUNBOOK.md`** |
| Lab tenants must stay in catalog | **`LAB_FLEET_TENANTS.md`** |

---

## Tool reference

| Script | Where | Role |
|--------|-------|------|
| `fetch-latest-instance-backup.sh` | Mac — `pbx3-directory/tools` | Download newest `backup.zip` → `pbx3bak.{epoch}.zip` |
| `restore-backup-zip.sh` | Node — `/opt/pbx3/scripts` | Full restore from local zip + hostname sync + externip refresh |
| `refresh-pjsip-externip.sh` | Node — `/opt/pbx3/scripts` | Rewrite `pjsip_transport.conf` `external_*` + Asterisk restart |
| `sync-hostname-from-globals.sh` | Node — `/opt/pbx3/scripts` | OS hostname ← `globals.shortuid` (also called by restore) |
| `onboard-fleet-instance.sh` | Mac — `pbx3-directory/tools` | IAM + `.env` + catalog + S3 smoke |
| `reconcile-node-tenants.sh` | Mac — `pbx3-directory/tools` | Node `cluster` ↔ `tenants/*/meta` (lab / B′ guard) |
| `pbx3:fleet-preflight` | Node — `php artisan` | Pass/fail fleet health checks |
