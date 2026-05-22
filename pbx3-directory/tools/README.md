# pbx3-directory tools (Phase 3)

Registrar scripts update **`catalog/instance-index.json`** and **`instances/`** / **`tenants/`** meta files in the org S3 bucket.

**Fleet onboarding (IAM + node + catalog + SPA):** see **`../docs/INSTANCE_ONBOARDING.md`**.  
**Planned (S6.4):** **`onboard-fleet-instance.sh`** — one Mac command after AMI boot (`IMPLEMENTATION_PLAN.md` § S6.4).

**Requires:** `aws` CLI, `jq`, and **IAM write** access (catalog public read does **not** allow anonymous PUT).

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
