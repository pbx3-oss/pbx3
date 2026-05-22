# Fleet instance onboarding — step-by-step

**Audience:** Operators adding a **second (or Nth) PBX node** to an existing fleet catalog and S3 org bucket.

**Validated example:** `bzy54n.pbx3.com` joined fleet bucket `08jzwn-pbx3` alongside golden `08jzwn.pbx3.com` (May 2026).

**Related docs:** `OPS_S3_RUNBOOK.md` (bucket policy, CORS, golden node), `tools/README.md` (registrar scripts), `DESIGN_RULES.md` (fleet bucket naming).

---

## Fleet model (read first)

| Concept | Golden + bzy54n pattern |
|--------|-------------------------|
| **Org / fleet bucket** | One S3 bucket for the fleet, e.g. `08jzwn-pbx3` (production naming: `{fleetname}-pbx3`) |
| **Catalog** | Single `catalog/instance-index.json` — **multiple** instance rows |
| **Per-node data** | Prefix `instances/{globals.id}/` (KSUID from SQLite `globals`) |
| **IAM** | **One EC2 instance role per node**, scoped to **that node’s** `instances/{ksuid}/*` only |
| **Registrar** | Run from **Mac / ops** with IAM that can write `catalog/*` and `instances/*` — **not** the node role |

Do **not** create a new bucket per node unless you are starting a **new org/fleet**. The bucket name `08jzwn-pbx3` reflects the first fleet id, not “only 08jzwn may use it.”

---

## Values to collect before you start

On the **new node** (SSH):

```bash
sqlite3 /opt/pbx3/db/sqlite.db "SELECT shortuid, fqdn, id FROM globals WHERE pkey='global';"
curl -k -sS -o /dev/null -w "up %{http_code}\n" https://127.0.0.1:44300/up
sudo systemctl is-active nginx php8.3-fpm
```

**bzy54n example:**

| Field | Value |
|-------|--------|
| shortuid | `bzy54n` |
| FQDN | `bzy54n.pbx3.com` |
| KSUID (`globals.id`) | `3E3gAOVGBhvc6vEPTBIYCBPycIk` |
| API base URL | `https://bzy54n.pbx3.com:44300/api` |
| Fleet bucket | `08jzwn-pbx3` |
| EC2 instance id | `i-0bb601e7b1253c3f5` |
| Public IP (SSH) | `3.87.115.210` |
| Region | `us-east-1` |

From **AWS console / CLI:** note EC2 instance id and ensure security group allows **44300** (and **22** for SSH) from your IP.

---

## Phase 0 — Node install (PBX stack)

Complete normal PBX install on the new EC2 instance before fleet onboarding:

1. Packages: `pbx3`, `pbx3api` (branch `directory`), nginx, PHP, SQLite populated.
2. **nginx / API healthy:** `curl -k https://127.0.0.1:44300/up` → `200`.
3. **TLS / LE:** If `installer.sh` fails on `nginx -t` with duplicate `default_server` on port 80, remove the default site then re-run nginx install:

   ```bash
   sudo rm -f /etc/nginx/sites-enabled/default
   sudo /opt/pbx3api/scripts/install-nginx-site.sh   # or your installer path
   sudo nginx -t && sudo systemctl reload nginx
   ```

4. Confirm `globals.id` (KSUID) is stable — catalog and IAM paths depend on it.

---

## Phase A — IAM (Mac / ops workstation)

Use credentials that can manage IAM (e.g. account admin). **Do not** run these on the EC2 node.

### A.1 — Verify Mac AWS CLI

```bash
aws sts get-caller-identity
# Example: arn:aws:iam::334063106996:root
```

### A.2 — Node-scoped S3 writer policy

Copy `schema/pbx3-node-s3-writer.policy.json`, replace bucket name and KSUID, save as e.g. `schema/pbx3-node-bzy54n-s3-writer.policy.json`.

**bzy54n** policy file (committed in repo):

`pbx3-directory/schema/pbx3-node-bzy54n-s3-writer.policy.json`

Create or update the policy:

```bash
cd ~/GiT/pbx3-master/pbx3/pbx3-directory/tools

./apply-node-s3-writer-policy.sh pbx3-node-bzy54n-s3-writer \
  ../schema/pbx3-node-bzy54n-s3-writer.policy.json
```

Or without the helper script:

```bash
aws iam create-policy \
  --policy-name pbx3-node-bzy54n-s3-writer \
  --policy-document file://pbx3/pbx3-directory/schema/pbx3-node-bzy54n-s3-writer.policy.json
```

### A.3 — EC2 instance role + profile

Naming convention: role and profile `pbx3-node-{shortuid}` (e.g. `pbx3-node-bzy54n`).

```bash
TRUST='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
POLICY_ARN='arn:aws:iam::334063106996:policy/pbx3-node-bzy54n-s3-writer'
ROLE='pbx3-node-bzy54n'
PROFILE='pbx3-node-bzy54n'
INSTANCE='i-0bb601e7b1253c3f5'

aws iam create-role --role-name "$ROLE" --assume-role-policy-document "$TRUST"
aws iam attach-role-policy --role-name "$ROLE" --policy-arn "$POLICY_ARN"
aws iam create-instance-profile --instance-profile-name "$PROFILE"
aws iam add-role-to-instance-profile --instance-profile-name "$PROFILE" --role-name "$ROLE"
```

If `add-role-to-instance-profile` reports the role is already attached, continue.

### A.4 — Attach profile to EC2

Use the profile **ARN** if `Name=` fails with “Invalid IAM Instance Profile name” (propagation delay right after create):

```bash
PROFILE_ARN=$(aws iam get-instance-profile --instance-profile-name pbx3-node-bzy54n --query 'InstanceProfile.Arn' --output text)

aws ec2 associate-iam-instance-profile \
  --instance-id i-0bb601e7b1253c3f5 \
  --iam-instance-profile "Arn=$PROFILE_ARN" \
  --region us-east-1
```

Verify:

```bash
aws ec2 describe-iam-instance-profile-associations \
  --filters "Name=instance-id,Values=i-0bb601e7b1253c3f5" \
  --region us-east-1 \
  --query 'IamInstanceProfileAssociations[0].{State:State,Profile:IamInstanceProfile.Arn}'
# State: "associated"
```

Wait ~30s before testing S3 from the node.

---

## Phase B — Node configuration (SSH)

SSH as `ubuntu` (replace host/key):

```bash
ssh -i ~/Documents/pemfiles/pbx3test.pem ubuntu@3.87.115.210
```

### B.1 — `.env` for fleet bucket (instance role)

Edit `/opt/pbx3api/.env`:

```env
AWS_DEFAULT_REGION=us-east-1
PBX3_ORG_BUCKET=08jzwn-pbx3
PBX3_DIRECTORY_BACKUP_UPLOAD=true
```

**Important:** Do **not** set `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` when using an instance profile. **Remove** lines that set them to empty strings — Laravel treats `""` as credentials and blocks the instance role.

```bash
sudo sed -i '/^AWS_ACCESS_KEY_ID=$/d;/^AWS_SECRET_ACCESS_KEY=$/d' /opt/pbx3api/.env
# Uncomment or append PBX3_ORG_BUCKET / PBX3_DIRECTORY_BACKUP_UPLOAD if still commented
sudo php artisan config:clear
```

Confirm config:

```bash
sudo php /opt/pbx3api/artisan tinker --execute="echo config('pbx3_directory.org_bucket') . PHP_EOL;"
# 08jzwn-pbx3
```

### B.2 — Pull `directory` branch on API

If git reports “dubious ownership”:

```bash
sudo git config --global --add safe.directory /opt/pbx3api
cd /opt/pbx3api
sudo git fetch origin directory
sudo git pull origin directory
sudo composer install --no-dev
test -f vendor/league/flysystem-aws-s3-v3/PortableVisibilityConverter.php && echo OK
sudo php artisan config:clear
```

**bzy54n** pulled through `6616120` (`install-nginx-site.sh` default-site fix).

### B.3 — S3 smoke test (Laravel / instance role)

`aws` CLI on the node is optional; this uses the same path as backup uploads:

```bash
sudo -u www-data env HOME=/tmp php /opt/pbx3api/artisan tinker --execute="
use Illuminate\Support\Facades\Storage;
\$disk = Storage::disk('pbx3_org');
\$key = 'instances/3E3gAOVGBhvc6vEPTBIYCBPycIk/_smoke.txt';
\$disk->put(\$key, 's6-smoke ' . gmdate('c'));
echo 'put ok' . PHP_EOL;
\$disk->delete(\$key);
echo 'deleted' . PHP_EOL;
"
```

Optional — instance metadata shows role:

```bash
TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60")
curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/info
```

### B.4 — Backup upload smoke (when a local zip exists)

```bash
ZIP=$(ls -t /opt/pbx3/bkup/pbx3bak.*.zip | head -1)
sudo php artisan pbx3:upload-backup "$(basename "$ZIP")"
```

Verify on Mac:

```bash
aws s3 ls s3://08jzwn-pbx3/instances/3E3gAOVGBhvc6vEPTBIYCBPycIk/backups/
```

---

## Phase C — Register in catalog (Mac / ops)

Requires IAM write on `catalog/*` and `instances/*` (root or registrar user — **not** the node role).

```bash
cd ~/GiT/pbx3-master/pbx3/pbx3-directory/tools
export PBX3_ORG_BUCKET=08jzwn-pbx3

./register-instance.sh \
  --id 3E3gAOVGBhvc6vEPTBIYCBPycIk \
  --fqdn bzy54n.pbx3.com \
  --api-base-url 'https://bzy54n.pbx3.com:44300/api' \
  --label bzy54n \
  --environment production \
  --org-id example-org \
  --region us-east-1 \
  --notes 'Second fleet node — S6 onboarding'
```

Dry-run first (optional):

```bash
REGISTRAR_DRY_RUN=1 ./register-instance.sh --dry-run \
  --id 3E3gAOVGBhvc6vEPTBIYCBPycIk \
  --fqdn bzy54n.pbx3.com \
  --api-base-url 'https://bzy54n.pbx3.com:44300/api' \
  --label bzy54n
```

Verify catalog:

```bash
aws s3 cp s3://08jzwn-pbx3/catalog/instance-index.json - | jq '.instances[] | {label, fqdn, id}'
```

Expected: **two** rows (`08jzwn`, `bzy54n`).

Register tenants on that node when ready:

```bash
./register-tenant.sh \
  --tenant-shortuid YOUR_TENANT \
  --instance-id 3E3gAOVGBhvc6vEPTBIYCBPycIk \
  --cname YOUR_TENANT.pbx3.com
```

---

## Phase D — Central SPA (local dev)

Production fleet SPA targets **GitHub Pages**; for dev, use **pbx3spa** with catalog proxy + per-node API proxy.

### D.1 — `.env.development` (pbx3spa)

```env
# API for login/admin calls — switch per node under test
VITE_API_PROXY_TARGET=https://bzy54n.pbx3.com:44300

# Catalog stays on fleet bucket (Vite proxies /dev-catalog → S3)
VITE_CATALOG_PROXY_TARGET=https://08jzwn-pbx3.s3.us-east-1.amazonaws.com
VITE_INSTANCE_DIRECTORY_URL=/dev-catalog/catalog/instance-index.json
```

Restart after changes:

```bash
cd pbx3spa && npm run dev
```

### D.2 — Picker validation

1. Open `http://localhost:5173`
2. **Refresh catalog** (or reload) — both **08jzwn** and **bzy54n** appear
3. Select **bzy54n** → sign in (proxy must reach `https://bzy54n.pbx3.com:44300`)

**CORS / TLS notes:**

- If login fails with “Load failed”, from Mac: `curl -k -m 8 -o /dev/null -w "%{http_code}\n" https://bzy54n.pbx3.com:44300/up` (expect `200`).
- Open EC2 SG **44300** from your IP; align Shorewall on the node.
- Self-signed cert: keep using Vite proxy (`VITE_API_PROXY_TARGET`), not direct browser HTTPS to the node.
- To test **08jzwn** while catalog is shared, change only `VITE_API_PROXY_TARGET` and restart dev server.

---

## Onboarding checklist

| Step | Where | Done (bzy54n) |
|------|--------|----------------|
| Node install + `/up` 200 | EC2 | ✓ |
| `globals.id` recorded | EC2 | ✓ `3E3gAOVG…` |
| IAM policy scoped to KSUID prefix | Mac | ✓ `pbx3-node-bzy54n-s3-writer` |
| IAM role + instance profile | Mac | ✓ `pbx3-node-bzy54n` |
| Profile associated with EC2 | Mac | ✓ `associated` |
| `.env` bucket + no static AWS keys | EC2 | ✓ |
| `pbx3api` on `directory` + Flysystem S3 | EC2 | ✓ |
| S3 PUT/DELETE smoke | EC2 | ✓ |
| `register-instance.sh` | Mac | ✓ |
| SPA shows two instances | Mac dev | ✓ |
| First backup in S3 | EC2 | — (no local zip yet) |

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `nginx -t` duplicate `default_server` on :80 | `sudo rm /etc/nginx/sites-enabled/default`; re-run `install-nginx-site.sh` |
| `associate-iam-instance-profile` invalid profile name | Use `Arn=$(aws iam get-instance-profile …)`; wait a few seconds after create |
| `Storage::disk('pbx3_org')` bucket null | Set `PBX3_ORG_BUCKET=08jzwn-pbx3`; `php artisan config:clear` |
| S3 auth fails with keys in `.env` | Delete `AWS_ACCESS_KEY_ID=` / `AWS_SECRET_ACCESS_KEY=` empty lines |
| `git pull` dubious ownership | `sudo git config --global --add safe.directory /opt/pbx3api` |
| SPA login “Load failed” | SG 44300, proxy target, `curl -k` to `/up` |
| Registrar denied on node | Run `register-instance.sh` from Mac, not EC2 |
| Node `aws` CLI missing | Normal — use Laravel/`artisan` or install CLI only for ops debugging |

---

## Execution split (quick reference)

| Where | Use for |
|--------|---------|
| **Mac (root / ops IAM)** | IAM policies, roles, instance profiles, `register-instance.sh`, lifecycle scripts |
| **EC2 node (instance role)** | Backup upload, recording upload (future), `Storage::disk('pbx3_org')` |
| **Not node role** | Catalog writes, IAM administration |

---

## Next steps after onboarding

- Run first backup + `pbx3:upload-backup` (Phase B.4)
- **S6.2:** deploy pbx3spa to GitHub Pages; add Pages origin to bucket CORS and each node API CORS
- **S7:** tenant recording offload to `tenants/{shortuid}/recordings/…`

See `IMPLEMENTATION_PLAN.md` phases S6–S7.
