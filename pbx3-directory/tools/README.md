# pbx3-directory tools

**Lab / try-it (D1):** on the control VM run **`./tools/install-control-host.sh`** (Garage + catalog + Gatekeeper). Home VM: **`pbx3/scripts/install-home-host.sh`**. MkDocs: **`pbx3-docs`** `installation/install-lab-control.md` · `installation/install-lab-home.md`. Mac AWS onboard below is **not** the Lab happy path.

## install-control-host.sh (Lab D1)

Prompted installer on the **control guest**: Garage + `bootstrap-org-bucket` + Gatekeeper nginx + first fleet user. Keys stay in `/etc/pbx3-gatekeeper/.env`.

```bash
sudo ./tools/install-control-host.sh
```

Unattended: `PBX3_FLEET_SLUG`, `PBX3_CONTROL_IP`, `GATEKEEPER_ADMIN_EMAIL`, `GATEKEEPER_ADMIN_PASSWORD` (min 10 chars).

**Mac SSH + AWS CLI:** **`../docs/OPERATOR_MAC_SETUP.md`** — read before running scripts (golden key, `aws sts`, agent pitfalls).

**Rebuild a failed EC2 (same KSUID):** start with **`../docs/REBUILD_INSTANCE_RUNBOOK.md`** — `fetch-latest-instance-backup.sh` → node `restore-backup-zip.sh` → `onboard-fleet-instance.sh`.

**Add a new node to the fleet:** **`onboard-fleet-instance.sh`** — one Mac command after AMI boot.

**Before onboard:** complete **Operator pre-flight (Mac)** and **Fleet-ready AMI (EC2)** in **`../docs/INSTANCE_ONBOARDING.md`** § Automation.

Registrar scripts update **`catalog/instance-index.json`** and **`instances/`** / **`tenants/`** meta files in the org S3 bucket.

**Requires (onboard + registrar):** logged-in **AWS CLI** session on the Mac (`aws sts get-caller-identity`), `jq`, `ssh`, and operator IAM for fleet bucket + IAM (not the EC2 node role).

## fetch-latest-instance-backup.sh (S8)

Download the newest `backup.zip` from `instances/{ksuid}/backups/` to `pbx3bak.{epoch}.zip` (Mac/ops credentials).

```bash
chmod +x fetch-latest-instance-backup.sh

export PBX3_ORG_BUCKET=08jzwn-pbx3

./fetch-latest-instance-backup.sh \
  --instance-id 3DmAsxePTWQZgynBYXE8obIRqEE \
  --output-dir ~/Downloads
```

Optional `--stamp YYYYMMDDTHHMMSSZ` to pin a specific archive. See **`../docs/REBUILD_INSTANCE_RUNBOOK.md`**.

## onboard-fleet-instance.sh (S6.4 / S8.3)

Idempotent: IAM (policy from template) → catalog → node `.env` + S3 smoke. Discovers KSUID from node `globals` — do not pass `--id` by hand.

```bash
chmod +x onboard-fleet-instance.sh register-instance.sh register-tenant.sh

export PBX3_ORG_BUCKET=08jzwn-pbx3

./onboard-fleet-instance.sh \
  --instance-id i-0bb601e7b1253c3f5 \
  --ssh ubuntu@bzy54n.pbx3.com \
  --ssh-key ~/Documents/pemfiles/pbx3test.pem \
  --region us-east-1
```

`--dry-run` — discover from node; print IAM/catalog/node steps without writes.  
`--git-pull` — pull `origin/directory` on node before S3 smoke.  
`--smoke-backup` — run `pbx3:upload-backup` if a local zip exists.  
`--skip-iam` / `--skip-catalog` / `--skip-node` — partial re-run.

**S8.3:** Fails if IAM instance profile is not `associated` or EC2 metadata returns no role (404) before S3 smoke. Writes `AWS_DEFAULT_REGION` in node `.env`.

Optional defaults: `~/.pbx3/fleet.yaml` or `--fleet-config PATH` (`org_bucket`, `region`, `ssh_key`, …).

Policy template: **`../schema/pbx3-node-s3-writer.policy.json.tmpl`** (`__BUCKET__`, `__INSTANCE_KSUID__`). **§2.6.1:** nodes get `instances/{ksuid}/*` only — no `tenants/*` (gatekeeper / presign path for future recordings and staging).

## Environment

```bash
export PBX3_ORG_BUCKET=08jzwn-pbx3
# optional:
export AWS_PROFILE=your-profile
export AWS_DEFAULT_REGION=us-east-1
```

## register-instance.sh

Upserts one row in the catalog and writes `instances/{ksuid}/meta.json`. Idempotent on `--id`.

```bash
chmod +x register-instance.sh register-tenant.sh move-tenant.sh validate-index.sh

./register-instance.sh \
  --id 3DmAsxePTWQZgynBYXE8obIRqEE \
  --fqdn 08jzwn.pbx3.com \
  --api-base-url 'https://08jzwn.pbx3.com:44300/api' \
  --label 08jzwn \
  --environment production \
  --org-id example-org \
  --region us-east-1 \
  --package-version 'pbx3 0.0.3-10'
```

`--dry-run` prints intended `aws s3 cp` without uploading.

## unregister-instance.sh

Remove an instance from the fleet directory (SPA picker). Default: **soft decommission** (`status=decommissioned`). `--remove` deletes the catalog row; S3 backups are kept.

```bash
./unregister-instance.sh --id 3E3gAOVGBhvc6vEPTBIYCBPycIk \
  --notes 'Node retired'

# Hard remove catalog row:
./unregister-instance.sh --id 3E3gAOVGBhvc6vEPTBIYCBPycIk --remove
```

See **`../docs/INSTANCE_ONBOARDING.md`** § Remove instance from fleet. Does not detach IAM or delete S3 backups.

## register-tenant.sh

```bash
./register-tenant.sh \
  --tenant-shortuid f34ck1 \
  --instance-id 3DmAsxePTWQZgynBYXE8obIRqEE \
  --cname f34ck1.pbx3.com
```

## move-tenant.sh

Updates tenant meta for a new hosting instance; sets `moved_at` and `previous_instance_id`. Does **not** copy `tenants/{shortuid}/recordings/`.

```bash
./move-tenant.sh \
  --tenant-shortuid f34ck1 \
  --instance-id NEW_KSUID \
  --cname f34ck1.pbx3.com
```

## Tenant export / import (S8.6)

Run on the **PBX node** (not Mac). See **`../docs/TENANT_MIGRATION_RUNBOOK.md`**.

```bash
# Source node — export one tenant (shortuid, pkey, or cluster KSUID)
cd /opt/pbx3api
sudo -u www-data php artisan tenant:export affcot
sudo -u www-data php artisan tenant:export affcot --include-recordings

# Copy pbx3tenant.{shortuid}.{epoch}.zip to destination /opt/pbx3/bkup/

# Destination node — import (preserves cluster.id KSUID)
sudo -u www-data php artisan tenant:import /opt/pbx3/bkup/pbx3tenant.affcot.*.zip
sudo -u www-data php artisan tenant:import /opt/pbx3/bkup/pbx3tenant.affcot.*.zip --replace
```

Zip layout: `manifest.json`, `tenant.sqlite.db`, optional `media/greetings/{shortuid}/`, `media/recordings/`. Trunks are **not** exported (instance-owned).

## upload-instance-backup.sh (Phase 4)

Uploads a local `pbx3bak.{unixtime}.zip` to `instances/{ksuid}/backups/{stamp}/` with manifest + policy + meta update. Same layout as pbx3api async upload.

```bash
chmod +x upload-instance-backup.sh

./upload-instance-backup.sh --zip /opt/pbx3/bkup/pbx3bak.1716123456.zip
```

On the node with Laravel:

```bash
cd /opt/pbx3api && php artisan pbx3:upload-backup pbx3bak.1716123456.zip
```

## validate-index.sh

```bash
./validate-index.sh ../schema/instance-index.json
```

## Verify

```bash
curl -sS "https://${PBX3_ORG_BUCKET}.s3.us-east-1.amazonaws.com/catalog/instance-index.json" | jq .
aws s3 cp "s3://${PBX3_ORG_BUCKET}/instances/3DmAsxePTWQZgynBYXE8obIRqEE/meta.json" -
```

In **pbx3spa**: **Refresh catalog** on login.

## apply-node-s3-writer-policy.sh

Update (or create) a node IAM policy JSON — includes `s3:PutObjectTagging` for backup lifecycle. Run from **Mac/ops**, not EC2.

```bash
./apply-node-s3-writer-policy.sh pbx3-node-08jzwn-s3-writer \
  ../schema/pbx3-node-s3-writer.policy.json
```

Golden template: **`../schema/pbx3-node-s3-writer.policy.json`** (edit bucket + KSUID per node).

## tag-s3-backups.sh

Backfill `class=backup` on existing `backup.zip` / `manifest.json` under `instances/{ksuid}/backups/`.

```bash
./tag-s3-backups.sh 08jzwn-pbx3 3DmAsxePTWQZgynBYXE8obIRqEE
```

## apply-backup-lifecycle-rule.sh

Bucket lifecycle: expire objects tagged `class=backup` after N days. **Mac/ops only** (not node role).

```bash
./apply-backup-lifecycle-rule.sh 08jzwn-pbx3 30
./apply-backup-lifecycle-rule.sh 08jzwn-pbx3 3DmAsxePTWQZgynBYXE8obIRqEE
```

## Ops

See **`../docs/OPS_S3_RUNBOOK.md`** for bucket policy (public `catalog/*` read only).
