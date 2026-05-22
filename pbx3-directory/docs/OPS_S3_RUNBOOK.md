# S3 ops runbook — org bucket, catalog, node IAM

**Status:** Ops guide (branch **`directory`**). Complements **`S3_LAYOUT_PROPOSAL.md`**, **`DESIGN_RULES.md`**, **`IMPLEMENTATION_PLAN.md`**.

**Golden test node:** `08jzwn.pbx3.com` — API `https://08jzwn.pbx3.com:44300/api` — example catalog in **`../schema/instance-index.json`** (same key in S3).

---

## Quick recipe (console — start here)

Repeatable checklist for a **fleet catalog** bucket. Example names: bucket **`08jzwn-pbx3`**, region **`us-east-1`**.

### A. Create bucket

1. **S3** → **Create bucket**.
2. **Bucket name:** `{shortid}-pbx3` (e.g. `08jzwn-pbx3`). **No dots** in the name (avoid `08jzwn.pbx3.com`).
3. **Region:** note it (e.g. `us-east-1`) — URLs depend on it.
4. Leave defaults (encryption SSE-S3 is fine). **Create bucket**.

### B. Allow a public catalog (bucket only)

5. Open the bucket → **Permissions** → **Block public access (bucket settings)** → **Edit**.
6. Turn **Off** → **Block all public access** (master switch for **this bucket only**). Save.
7. **Account check (if public read still fails later):** S3 left nav → **Block Public Access settings for this account** → ensure account is not forcing “block all” over your bucket (adjust for test if needed).

### C. Bucket policy (catalog prefix only)

8. Same **Permissions** tab → **Bucket policy** → **Edit** → paste (replace bucket name if not `08jzwn-pbx3`):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadCatalogOnly",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::08jzwn-pbx3/catalog/*"
    }
  ]
}
```

9. Save. AWS may warn “public” — expected for `catalog/*` only.

### D. Upload the catalog JSON

**Object key (repo and S3 — one name only):** `catalog/instance-index.json`

**Console (typical):**

10. Bucket → **Create folder** → name **`catalog`** → Create. (Console upload often needs this; CLI does not.)
11. Open the **`catalog/`** “folder” → **Upload** → select local file:
    - From repo: `pbx3-directory/schema/instance-index.json`
12. After upload, confirm **Object key** is exactly `catalog/instance-index.json` (not at bucket root).
13. **Properties** → **Content-Type** `application/json` (optional but nice).

**Before upload:** set `"id"` in JSON to the node’s real **`globals.id`** (KSUID) if different from the example.

**CLI (no folder step):**

```bash
aws s3 cp pbx3-directory/schema/instance-index.json \
  s3://08jzwn-pbx3/catalog/instance-index.json \
  --content-type application/json
```

### E. Verify public read

14. Copy **Object URL** from the console (or build it):

```text
https://08jzwn-pbx3.s3.us-east-1.amazonaws.com/catalog/instance-index.json
```

15. From any machine (no AWS login):

```bash
curl -sS "https://08jzwn-pbx3.s3.us-east-1.amazonaws.com/catalog/instance-index.json"
# expect JSON body

curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://08jzwn-pbx3.s3.us-east-1.amazonaws.com/instances/test/meta.json"
# expect 403
```

16. If catalog `curl` is still **AccessDenied**: object missing/wrong key, wrong region in URL, **account** Block Public Access, or object encrypted with KMS that blocks anonymous read.

### F. CORS (when SPA origin ≠ S3)

**Symptom:** Browser console `Access-Control-Allow-Origin` / `Fetch API cannot load` catalog URL; login shows catalog load failed (S3 may still return 200).

**Fix A — S3 CORS (required for production central admin):**

17. Bucket → **Permissions** → **Cross-origin resource sharing (CORS)** → paste and **Save**:

```json
[
  {
    "AllowedOrigins": [
      "http://localhost:5173",
      "http://127.0.0.1:5173"
    ],
    "AllowedMethods": ["GET", "HEAD"],
    "AllowedHeaders": ["*"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3600
  }
]
```

**Production (agreed):** central **pbx3spa** on **GitHub Pages** (optional custom domain, e.g. `https://app.example.com`). Add that origin to `AllowedOrigins`, plus `https://<user>.github.io` if you use the default Pages URL before DNS is wired.

Example (adjust hostnames):

```json
"AllowedOrigins": [
  "http://localhost:5173",
  "http://127.0.0.1:5173",
  "https://app.example.com",
  "https://yourorg.github.io"
]
```

**Instance API CORS:** Each `pbx3api` must also allow the same SPA origin for `Authorization` Bearer calls to `https://{fqdn}:44300/api` (configure when Pages goes live — not required for local Vite proxy dev).

See **`DESIGN_RULES.md`** § Central SPA hosting.

**Fix B — local dev only (no S3 CORS):** In **pbx3spa** `.env.development`:

```env
VITE_CATALOG_PROXY_TARGET=https://08jzwn-pbx3.s3.us-east-1.amazonaws.com
VITE_INSTANCE_DIRECTORY_URL=/dev-catalog/catalog/instance-index.json
```

Restart `npm run dev`. Vite proxies `/dev-catalog/*` to S3 server-side (no browser CORS).

### G. Wire pbx3spa (Phase 2)

18. **Exact URL that returned JSON** in step 15 → build env:

```env
VITE_INSTANCE_DIRECTORY_URL=https://08jzwn-pbx3.s3.us-east-1.amazonaws.com/catalog/instance-index.json
```

19. **Solo / no fleet:** omit `VITE_INSTANCE_DIRECTORY_URL`; login with API URL only (Rule 6).

### H. Mistakes cheat sheet

| Symptom | Usual cause |
|---------|-------------|
| AccessDenied on catalog URL | Empty bucket, file at **root** not under `catalog/`, account BPA still on, wrong region in URL |
| AccessDenied on `instances/…` | **Good** — policy is scoped correctly |
| Console upload landed at root | Did not create **`catalog/`** folder first or did not upload **inside** it |
| Policy “does nothing” | Bucket name in policy ARN ≠ real bucket; account-level block public access |

---

## Golden node playbook — `08jzwn.pbx3.com` (validated)

End-to-end steps used on the **golden** EC2 test instance. Other nodes follow the same pattern with their own `globals.id`, bucket name, and IAM role.

### Reference values (verify on box)

| Item | Golden example |
|------|----------------|
| **FQDN** | `08jzwn.pbx3.com` |
| **API** | `https://08jzwn.pbx3.com:44300/api` |
| **Org bucket** | `08jzwn-pbx3` (`us-east-1`) |
| **`globals.id` (KSUID)** | `3DmAsxePTWQZgynBYXE8obIRqEE` |
| **EC2 instance** | e.g. `i-0829f0a5ecbbf0cde` |
| **IAM instance role** | `pbx3-node-08jzwn` |
| **pbx3api deploy path** | `/opt/pbx3api` (nginx `root`; **not** `~/Git/…`) |
| **Local backups** | `/opt/pbx3/bkup/pbx3bak.{unixtime}.zip` |
| **S3 backup prefix** | `s3://08jzwn-pbx3/instances/3DmAsxePTWQZgynBYXE8obIRqEE/backups/{stamp}/` |

Refresh KSUID:

```bash
sqlite3 /opt/pbx3/db/sqlite.db "SELECT id, fqdn, shortuid FROM globals WHERE pkey='global';"
```

---

### Step 1 — EC2 security groups (network)

**IAM instance roles control S3 access.** Security groups control **network** reachability. Both matter on golden.

#### What S3 Phase 4 needs from the security group

| Direction | Port | Purpose |
|-----------|------|---------|
| **Outbound** | **443** (HTTPS) | PUT/GET to S3 (`s3.us-east-1.amazonaws.com` and bucket endpoints) |
| **Inbound** | — | **None** for S3 (uploads are outbound from the node) |

Default EC2 security groups often allow **all outbound** traffic — that is enough for S3. If uploads fail with network/timeout errors (not IAM), check that egress to the internet on **443** is allowed.

#### Golden node inbound (typical PBX + LE + admin)

Adjust to your fleet policy; golden used roughly:

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| **22** | TCP | Your admin IP / bastion | SSH |
| **44300** | TCP | Admin / tenant networks | **pbx3api** (HTTPS nginx) |
| **80** | TCP | `0.0.0.0/0` (or LE only) | **HTTP-01** Let’s Encrypt (see below) |
| **5060** | UDP/TCP | As designed | SIP (PJSIP) |
| **5061** | TCP | As designed | SIP TLS |
| *(others)* | — | Shorewall docs | RTP, etc. — **pbx3** firewall is separate from EC2 SG |

**Let’s Encrypt:** LE validators reach **port 80** on the public IP. Golden had **EC2 SG port 80 open** plus a **Shorewall** rule on the node (`le-port80-open.sh` / managed comment during issuance). A successful pre-check looked like:

```bash
curl -v --connect-timeout 5 http://08jzwn.pbx3.com/.well-known/acme-challenge/test
# Connected + HTTP response (404 on fake path is OK)
```

**Two firewalls:** open **80** (and **44300**, **22**, SIP) in **both** EC2 security group **and** Shorewall where applicable.

#### Build / attach a security group (console)

1. **EC2** → **Security groups** → **Create security group**.
2. **Name:** e.g. `pbx3-golden-08jzwn` — **VPC** = same as the instance.
3. **Inbound rules:** add rows from the table above (tighten `0.0.0.0/0` on 22/44300 in production).
4. **Outbound:** default **All traffic** → `0.0.0.0/0` (keeps S3, apt, LE working).
5. **EC2** → **Instances** → select golden instance → **Security** tab → **Security groups** → attach this group (replace or add to existing).

No security group change is required specifically for **IAM role** credentials (those use instance metadata, not inbound ports).

---

### Step 2 — S3 bucket + public catalog

Follow **Quick recipe §A–E** above with bucket **`08jzwn-pbx3`**, region **`us-east-1`**.

- Catalog URL: `https://08jzwn-pbx3.s3.us-east-1.amazonaws.com/catalog/instance-index.json`
- Ensure catalog row **`id`** = node **`globals.id`** (KSUID above).

**Phase 3 (laptop):** register instance + tenants with `pbx3-directory/tools/register-instance.sh` / `register-tenant.sh` and `PBX3_ORG_BUCKET=08jzwn-pbx3` (IAM user/role with write to `catalog/*`, `instances/*`, `tenants/*` — **not** the node role).

**Adding a second node to an existing fleet bucket:** see **`INSTANCE_ONBOARDING.md`** (full step-by-step with `bzy54n` commands).

---

### Step 3 — IAM instance role (no access keys on the node)

**Goal:** PBX node uploads backups via **instance profile**; no `AWS_ACCESS_KEY_ID` in `.env` or `~/.aws/credentials`.

#### 3.1 Create IAM policy (one node = one KSUID)

**IAM** → **Policies** → **Create policy** → **JSON**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListOrgBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::08jzwn-pbx3",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "instances/3DmAsxePTWQZgynBYXE8obIRqEE/*",
            "tenants/*"
          ]
        }
      }
    },
    {
      "Sid": "WriteInstanceAndTenantObjects",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectTagging",
        "s3:GetObject",
        "s3:GetObjectTagging",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::08jzwn-pbx3/instances/3DmAsxePTWQZgynBYXE8obIRqEE/*",
        "arn:aws:s3:::08jzwn-pbx3/tenants/*"
      ]
    }
  ]
}
```

**Name:** `pbx3-node-08jzwn-s3-writer` (or similar). Node does **not** need `catalog/*` write unless registrar runs on-box.

#### 3.2 Create role + instance profile

1. **IAM** → **Roles** → **Create role** → trusted entity **EC2**.
2. Attach policy from §3.1.
3. **Role name:** `pbx3-node-08jzwn` (console usually creates matching **instance profile**).

#### 3.3 Attach to the EC2 instance

1. **EC2** → **Instances** → golden instance → **Actions** → **Security** → **Modify IAM role**.
2. Choose **`pbx3-node-08jzwn`** → **Save**.

#### 3.4 Verify (on the node)

```bash
# Remove static keys so CLI uses the role (if present)
mv ~/.aws/credentials ~/.aws/credentials.bak 2>/dev/null || true
mv ~/.aws/config ~/.aws/config.bak 2>/dev/null || true
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

aws sts get-caller-identity
# Expect: "Arn": "...:assumed-role/pbx3-node-08jzwn/i-..."

sudo -u www-data aws sts get-caller-identity
# Same role (PHP-FPM / www-data path)
```

**Wrong:** `"Arn": "...:root"` or account id only → static **root/user keys** still in `~/.aws/credentials`; remove them.

**S3 write smoke test:**

```bash
echo test | aws s3 cp - \
  s3://08jzwn-pbx3/instances/3DmAsxePTWQZgynBYXE8obIRqEE/backups/_iam-test.txt
aws s3 rm s3://08jzwn-pbx3/instances/3DmAsxePTWQZgynBYXE8obIRqEE/backups/_iam-test.txt
```

#### 3.5 Add object tagging (backup lifecycle)

pbx3api tags `backup.zip` and `manifest.json` with **`class=backup`** on upload (lifecycle rule in § S3 lifecycle). The node policy must include **`s3:PutObjectTagging`** and **`s3:GetObjectTagging`** (see §3.1 JSON).

**From Mac (IAM admin):** update the attached policy and backfill tags on objects uploaded before tagging was allowed:

```bash
cd pbx3-directory/tools
chmod +x apply-node-s3-writer-policy.sh tag-s3-backups.sh

./apply-node-s3-writer-policy.sh pbx3-node-08jzwn-s3-writer \
  ../schema/pbx3-node-s3-writer.policy.json

./tag-s3-backups.sh 08jzwn-pbx3 3DmAsxePTWQZgynBYXE8obIRqEE
```

**Verify on golden** (after policy v2+):

```bash
aws s3api put-object-tagging \
  --bucket 08jzwn-pbx3 \
  --key instances/3DmAsxePTWQZgynBYXE8obIRqEE/backups/_tag-test.txt \
  --tagging 'TagSet=[{Key=class,Value=backup}]' 2>/dev/null || \
  echo test | aws s3 cp - s3://08jzwn-pbx3/instances/3DmAsxePTWQZgynBYXE8obIRqEE/backups/_tag-test.txt && \
  aws s3api put-object-tagging --bucket 08jzwn-pbx3 \
    --key instances/3DmAsxePTWQZgynBYXE8obIRqEE/backups/_tag-test.txt \
    --tagging 'TagSet=[{Key=class,Value=backup}]'
aws s3 rm s3://08jzwn-pbx3/instances/3DmAsxePTWQZgynBYXE8obIRqEE/backups/_tag-test.txt
```

New uploads should log **`directory backup upload complete`** without a PutObjectTagging warning.

---

### Step 4 — Deploy pbx3api Phase 4 on `/opt/pbx3api`

Production API is **`/opt/pbx3api`** (nginx `root /opt/pbx3api/public`). Do **not** rely on `~/Git/pbx3-master/pbx3api` for runtime unless you symlink/copy there.

```bash
cd /opt/pbx3api
sudo git fetch origin directory
sudo git checkout directory
sudo git pull origin directory
# Need commits through Phase 4 + composer lock (b313beb+, PHP fix a3d0751+, S3 cred fix 759fd9d+)

sudo composer install --no-dev
# Run as root on /opt/pbx3api — NOT: sudo -u www-data composer (permission errors in ~)

test -f vendor/league/flysystem-aws-s3-v3/PortableVisibilityConverter.php && echo "S3 package OK"

sudo php artisan config:clear
```

**`.env`** (golden):

```env
AWS_DEFAULT_REGION=us-east-1
PBX3_ORG_BUCKET=08jzwn-pbx3
PBX3_DIRECTORY_BACKUP_UPLOAD=true
```

**Do not** leave empty assignment lines for keys (they block the instance role in Laravel):

```env
# Comment out or delete — do NOT use:
# AWS_ACCESS_KEY_ID=
# AWS_SECRET_ACCESS_KEY=
```

After pull **`759fd9d+`**, `config/filesystems.php` treats empty env as `null` so the role works even if those lines exist — commenting them out is still clearer.

**PHP version:** lock file targets **PHP 8.3** (`composer.json` `config.platform.php`). Node on **8.3.6** is correct; if `composer install` complains about `symfony/filesystem` v8 / PHP 8.4, pull latest `directory` and re-run install.

---

### Step 5 — Create backup and upload to S3

**5a — Local backup** (SPA **Backups → Create** or API):

```bash
ls -lt /opt/pbx3/bkup/pbx3bak.*.zip
```

**5b — Upload** (use **real** filename, not a placeholder):

```bash
cd /opt/pbx3api
ZIP=$(ls -t /opt/pbx3/bkup/pbx3bak.*.zip | head -1)
sudo php artisan pbx3:upload-backup "$(basename "$ZIP")"
```

**5c — List S3:**

```bash
aws s3 ls s3://08jzwn-pbx3/instances/3DmAsxePTWQZgynBYXE8obIRqEE/backups/
```

Each prefix is a **UTC stamp folder** containing `backup.zip` + `manifest.json`. SPA/API backup create also triggers **async upload** after response when configured.

**Logs:**

```bash
sudo grep -i 'directory backup' /opt/pbx3api/storage/logs/laravel.log | tail -10
# Success: directory backup upload complete
```

---

### Step 6 — Reconcile local zip names vs S3 folders

**Product rule (`DESIGN_RULES.md` § time/display):** Operators see **ISO 8601 UTC** + **Archive ID** (`backup_stamp`) in the SPA; S3 console folder = Archive ID; local `pbx3bak.{epoch}.zip` is the technical file for restore/download.

| Local file | Archive ID (S3 prefix) | Created (UTC) |
|------------|------------------------|---------------|
| `pbx3bak.1779236226.zip` | `20260520T001706Z/` | `2026-05-20T00:17:06Z` |
| `pbx3bak.1779236663.zip` | `20260520T002423Z/` | `2026-05-20T00:24:23Z` |

```bash
EPOCH=1779236226
date -u -d "@$EPOCH" +%Y-%m-%dT%H:%M:%SZ    # display
date -u -d "@$EPOCH" +%Y%m%dT%H%M%SZ         # Archive ID / S3 folder
```

`instances/{ksuid}/meta.json` → `backup_latest_stamp` is only the **newest** upload, not a full list.

**Retention (option C — implemented in `pbx3api`):**

| Layer | What runs |
|-------|-----------|
| **Local (9 FIFO)** | After SPA/cron create: `LocalBackupRetention` keeps newest `PBX3_BACKUP_LOCAL_MAX_COUNT` (default **9**) under `/opt/pbx3/bkup/`. Manual delete still does **not** touch S3. |
| **Daily backup** | `php artisan pbx3:backup-run --trigger=scheduled` — see `pbx3api/scripts/cron.d/pbx3-backup.example` or Laravel `schedule:run` (02:00 in `bootstrap/app.php`). |
| **S3 (30 days)** | Lifecycle on objects tagged **`class=backup`** (set on `backup.zip` + `manifest.json` upload). **One-time ops on laptop** (see § below) — aligns with `policy.json` `maxage_days`. |

Local eviction does **not** delete S3 archives — see **`DESIGN_RULES.md`** § backup retention (option C).

#### S3 lifecycle (ops laptop — not the PBX node)

`pbx3-node-*` instance roles allow **object** PUT/GET under `instances/{ksuid}/*` only. They **must not** include `s3:PutLifecycleConfiguration` (bucket-wide setting).

If you run `apply-backup-lifecycle-rule.sh` on the golden server you will see:

`User: arn:aws:sts::…:assumed-role/pbx3-node-08jzwn/… is not authorized to perform: s3:PutLifecycleConfiguration`

**Do this once from your Mac** (root account, IAM admin user, or a dedicated ops role). Use credentials that created the bucket — **not** the EC2 node role.

From your **pbx3** git clone (you may already be in that directory). If you use a named AWS profile, set it **on its own line** (replace `YOUR_PROFILE` with a real name from `~/.aws/credentials`; omit both lines if default credentials are already admin):

```bash
export AWS_PROFILE=YOUR_PROFILE
aws sts get-caller-identity
```

Confirm the ARN is **not** `assumed-role/pbx3-node-…`. Then:

```bash
./pbx3-directory/tools/apply-backup-lifecycle-rule.sh 08jzwn-pbx3 30
aws s3api get-bucket-lifecycle-configuration --bucket 08jzwn-pbx3
```

**Do not paste** placeholder lines like `export AWS_PROFILE=...` or shell comments on the same line as commands — zsh will treat words after `#` as comments, but a bad paste can pass `/` and extra words to `export` and fail with `not valid in this context: /`.

**Console alternative:** S3 → bucket **`08jzwn-pbx3`** → **Management** → **Lifecycle rules** → **Create rule** → scope **Limit to prefix** `instances/` + **Tags** `class` = `backup` → **Expire current versions** after **30** days.

**Note:** Backups uploaded **before** pbx3api `119b1f7` (S3 object tags) are not tagged `class=backup` and will **not** match this rule until re-uploaded or tagged manually.

---

### Step 7 — pbx3spa (Phase 2) — local or GitHub Pages (not on golden for prod)

**Production:** build **pbx3spa** with `VITE_INSTANCE_DIRECTORY_URL` → deploy **`dist/`** to **GitHub Pages** (see **`DESIGN_RULES.md`** § Central SPA hosting). **Do not** rely on nginx-served SPA on fleet instances.

**Golden / dev:** run SPA locally (`npm run dev`) against `https://08jzwn.pbx3.com:44300/api`, or use Quick recipe §F catalog proxy. Optional nginx SPA on golden is **test-only**, not the fleet model.

```env
VITE_INSTANCE_DIRECTORY_URL=https://08jzwn-pbx3.s3.us-east-1.amazonaws.com/catalog/instance-index.json
```

Solo path: omit `VITE_INSTANCE_DIRECTORY_URL`.

---

### Golden checklist

- [ ] EC2 SG: outbound **443**; inbound **22**, **44300**, **80** (LE), SIP as needed
- [ ] Shorewall aligned with SG for **80** / **44300**
- [ ] Bucket `08jzwn-pbx3`; public read **only** `catalog/*`
- [ ] Catalog `id` = `globals.id` on node
- [ ] IAM role `pbx3-node-08jzwn` attached; `aws sts` shows `assumed-role/...`
- [ ] No static AWS keys in `~/.aws/` or `.env`
- [ ] `/opt/pbx3api` on `directory`; `composer install --no-dev`; Flysystem S3 package present
- [ ] `.env`: `PBX3_ORG_BUCKET`, region, upload enabled
- [ ] Local backup exists; S3 shows `backups/{stamp}/backup.zip` + `manifest.json`

---

## 1. What you are setting up

| Phase | S3 use | AWS on PBX node? |
|-------|--------|------------------|
| **Solo trial** | None | No |
| **Phase 2 — fleet picker** | `catalog/instance-index.json` (public **prefix** or static URL) | **No** — SPA `fetch()` only |
| **Phase 3 — registrar** | PUT catalog + `instances/…/meta.json`, `tenants/…/meta.json` | Optional — **AWS CLI on laptop** is enough |
| **Phase 4 — backups** | PUT `instances/{ksuid}/backups/…` | **Yes** — Laravel Flysystem S3 + IAM |

**One org bucket** (default): `s3://{org_shortuid}-pbx3/` with prefixes `catalog/`, `share/`, `instances/`, `tenants/`. Same bucket; **different IAM and policies per prefix**.

**Access model (committed):**

- **Catalog** — browser may read via **public HTTPS URL** (prefix policy or CloudFront). No AWS keys in SPA.
- **Bulk** — bucket **private**; node **IAM role** (or API presigned URLs) for PUT/GET.

---

## 2. Prerequisites

- AWS account; choose a **region** (e.g. `eu-west-1`) and use it consistently.
- `aws` CLI v2 configured (`aws sts get-caller-identity`).
- Org short id for bucket name (e.g. `acme` → bucket `acme-pbx3`).
- On the PBX node: **`globals.id`** (KSUID) for `instances/{ksuid}/` paths — must match catalog row `id`.

**AWS docs (public prefix only):**

- [Block public access](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html)
- [Bucket policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html)
- [CORS](https://docs.aws.amazon.com/AmazonS3/latest/userguide/enabling-cors-examples.html)

---

## 3. Create bucket (CLI)

Replace `ORG`, `REGION`, `ACCOUNT_ID`.

```bash
export ORG=acme
export REGION=eu-west-1
export BUCKET="${ORG}-pbx3"

aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION"
```

**Note:** `us-east-1` omits `LocationConstraint`. Adjust for your region.

Enable **default encryption** (SSE-S3):

```bash
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration '{
  "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
}'
```

Keep **Block Public Access** ON at account/bucket level until you add the **narrow** catalog policy in §5.

---

## 4. Bucket layout (first upload)

**Repo file = S3 key:** `schema/instance-index.json` → `s3://{bucket}/catalog/instance-index.json`

Validate locally (when `tools/validate-index.sh` exists) or eyeball against schema.

**CLI** (creates `catalog/` prefix automatically — no console folder):

```bash
aws s3 cp ../schema/instance-index.json \
  "s3://${BUCKET}/catalog/instance-index.json" \
  --content-type application/json
```

**Console:** create folder **`catalog`**, open it, then upload — see **Quick recipe §D**.

Optional instance meta (Phase 3+):

```bash
# KSUID from node globals.id
export INSTANCE_KSUID=3DmAsxePTWQZgynBYXE8obIRqEE
aws s3 cp instance-meta.json "s3://${BUCKET}/instances/${INSTANCE_KSUID}/meta.json"
```

---

## 5. Public read — catalog prefix only

### 5.1 Adjust Block Public Access (bucket)

In console: bucket → **Permissions** → **Block public access** → **Edit** → allow policies that grant public access (bucket still protected except where policy allows).

Or CLI (bucket-level; account-level may still block — check both):

```bash
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=false,RestrictPublicBuckets=false"
```

`BlockPublicPolicy=false` is required so the **bucket policy** in §5.2 can grant anonymous `GetObject` on `catalog/*` only.

### 5.2 Bucket policy (anonymous read `catalog/*` only)

Replace `BUCKET` and `ACCOUNT_ID`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadCatalogOnly",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::BUCKET/catalog/*"
    }
  ]
}
```

Apply:

```bash
# save as catalog-public-policy.json, edit BUCKET name in Resource ARN
aws s3api put-bucket-policy --bucket "$BUCKET" --policy file://catalog-public-policy.json
```

**Verify:**

```bash
curl -sS "https://${BUCKET}.s3.${REGION}.amazonaws.com/catalog/instance-index.json" | head
```

**Must fail** (403) for private prefixes:

```bash
curl -sS -o /dev/null -w "%{http_code}\n" \
  "https://${BUCKET}.s3.${REGION}.amazonaws.com/instances/${INSTANCE_KSUID}/meta.json"
# expect 403
```

### 5.3 Confidentiality

Anyone who knows the URL can read **`catalog/instance-index.json`** (instance hostnames, `api_base_url`). That does **not** grant admin access — Sanctum on each node still required. For stricter fleets, skip public policy and use **§8** (private bucket + API / signed URLs) — Phase D.

### 5.4 Optional: `share/` public read

Phone images only — separate statement or CloudFront (see **`S3_LAYOUT_PROPOSAL.md`**). Do not open `instances/` or `tenants/`.

---

## 6. CORS (SPA `fetch` from another origin)

Required when **pbx3spa** origin ≠ S3 URL (e.g. `http://localhost:5173` or `https://admin.example.com`).

`cors.json`:

```json
{
  "CORSRules": [
    {
      "AllowedOrigins": [
        "http://localhost:5173",
        "https://admin.example.com"
      ],
      "AllowedMethods": ["GET", "HEAD"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3600
    }
  ]
}
```

```bash
aws s3api put-bucket-cors --bucket "$BUCKET" --cors-configuration file://cors.json
```

**Solo / Model A:** If SPA is served from the same host as the API and catalog is on a static path on that host, CORS to S3 may be unnecessary.

---

## 7. IAM — PBX node (Phase 4 uploads)

Prefer **EC2 instance profile** (IAM role). No long-lived keys on disk if avoidable.

### 7.1 Policy (node writer)

Replace `BUCKET`, `INSTANCE_KSUID`, `ORG` as needed. Node should **not** need `catalog/*` unless registrar runs on-box.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListOrgBucket",
      "Effect": "Allow",
      "Action": ["s3:ListBucket"],
      "Resource": "arn:aws:s3:::BUCKET",
      "Condition": {
        "StringLike": {
          "s3:prefix": [
            "instances/INSTANCE_KSUID/*",
            "tenants/*"
          ]
        }
      }
    },
    {
      "Sid": "WriteInstanceAndTenantObjects",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::BUCKET/instances/INSTANCE_KSUID/*",
        "arn:aws:s3:::BUCKET/tenants/*"
      ]
    }
  ]
}
```

Attach role to instance; on node **no** `AWS_ACCESS_KEY_ID` in `.env` if the SDK picks up instance metadata.

### 7.2 Laravel (pbx3api) — Phase 4

**Package:** [`league/flysystem-aws-s3-v3`](https://packagist.org/packages/league/flysystem-aws-s3-v3) — in `composer.json` on branch **`directory`**; install on the node with `composer install`, not only on a dev laptop.

```bash
cd /opt/pbx3api
sudo git pull origin directory
sudo composer install --no-dev
test -f vendor/league/flysystem-aws-s3-v3/PortableVisibilityConverter.php && echo OK
sudo php artisan config:clear
```

Use `Storage::disk('pbx3_org')` for backup PUTs. Disk config uses `PBX3_ORG_BUCKET`; empty `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` must be **null** (not `""`) so the EC2 instance role is used — see **Golden node playbook §Step 4**.

**`.env` on the node (instance role — golden pattern):**

```env
AWS_DEFAULT_REGION=us-east-1
PBX3_ORG_BUCKET=08jzwn-pbx3
PBX3_DIRECTORY_BACKUP_UPLOAD=true
```

Do **not** set `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` when using an instance profile.

Creating a backup via SPA/API triggers **after-response** upload (`InstanceBackupDirectoryUpload`). Manual retry:

```bash
cd /opt/pbx3api
ZIP=$(ls -t /opt/pbx3/bkup/pbx3bak.*.zip | head -1)
sudo php artisan pbx3:upload-backup "$(basename "$ZIP")"
```

CLI without PHP (ops): `pbx3-directory/tools/upload-instance-backup.sh --zip /opt/pbx3/bkup/pbx3bak.….zip`

### 7.3 Registrar / ops user (Phase 3)

Separate IAM user or role for humans/CI with:

- `s3:GetObject`, `s3:PutObject` on `catalog/*`
- `s3:PutObject` on `instances/*`, `tenants/*`

Run from laptop:

```bash
aws s3 cp instance-index.json "s3://${BUCKET}/catalog/instance-index.json"
```

---

## 8. Tighter catalog (optional — not v0 default)

| Approach | Browser | Bucket |
|----------|---------|--------|
| Public `catalog/*` | `fetch` URL | Prefix policy §5 |
| CloudFront + OAC | `fetch` CDN URL | Bucket private |
| Catalog via API | `GET /directory/instances` after auth | Bucket fully private |

Phase 2 v0 assumes **public catalog prefix** or **non-S3 static URL** (repo file, nginx).

---

## 9. SPA hosting and env (Phase 2+)

**Agreed production home:** **GitHub Pages** for **pbx3spa** (one origin for all operators). **Instances** run **pbx3api** only. Catalog and backups use any **S3-compatible** bucket; AWS is a reference implementation, not a UI-hosting requirement.

### Build-time env

```env
# Fleet mode — HTTPS URL to catalog JSON (S3, R2, MinIO public URL, etc.)
VITE_INSTANCE_DIRECTORY_URL=https://acme-pbx3.s3.eu-west-1.amazonaws.com/catalog/instance-index.json

# Solo — omit VITE_INSTANCE_DIRECTORY_URL (Rule 6)
# VITE_DEFAULT_API_BASE_URL=https://08jzwn.pbx3.com:44300/api
```

Bake a **production** catalog URL in CI before `npm run build`; staging and prod may need separate Pages environments or build args.

### GitHub Pages checklist (when enabling)

1. **Repo:** **pbx3spa** — Actions workflow: `npm ci && npm run build` → upload `dist/` to Pages (or `gh-pages` branch).
2. **Custom domain** (optional): DNS → Pages; HTTPS automatic.
3. **S3 catalog CORS:** add Pages origin(s) to bucket CORS — § F above.
4. **Each instance:** allow same SPA origin on API CORS for Bearer requests to `:44300/api`.
5. **Do not** add SPA to instance debian packages for fleet production.

After deploy: login → picker (or auto-select if one row) → Sanctum token on chosen `api_base_url`.

**Dev without S3:** Vite `/dev-catalog` proxy or host `instance-index.json` on any static HTTPS URL; same env var.

---

## 10. Node-side config (future)

Documented for Phase 5; not required for catalog-only test:

| Variable | Purpose |
|----------|---------|
| `PBX3_ORG_BUCKET` | Target bucket name |
| `PBX3_ORG_ID` | Org id in catalog rows |

---

## 11. Verification checklist

- [ ] Bucket exists, encryption on, **no** blanket public access
- [ ] Policy allows **only** `catalog/*` anonymous `GetObject`
- [ ] `instances/*` and `tenants/*` return **403** anonymously
- [ ] CORS allows SPA origin (if cross-origin)
- [ ] `instance-index.json` validates against schema; `id` matches node `globals.id`
- [ ] `curl` / browser can load catalog URL
- [ ] SPA login to `08jzwn` still works with directory URL unset (solo path)
- [ ] EC2 SG egress **443**; IAM instance role attached; `aws sts get-caller-identity` → `assumed-role/...`
- [ ] No root/static keys in `~/.aws/credentials` on node
- [ ] `/opt/pbx3api`: `directory` branch, `composer install --no-dev`, Flysystem S3 package on disk
- [ ] Phase 4: local `pbx3bak.*.zip` → S3 `backups/{stamp}/backup.zip` + `manifest.json`

Full golden walkthrough: **Golden node playbook** (top of this doc).

---

## 12. Troubleshooting

| Symptom | Check |
|---------|--------|
| 403 on catalog URL | Block Public Access; bucket policy Resource ARN; object key exactly `catalog/instance-index.json` |
| CORS error in browser | `put-bucket-cors`; `AllowedOrigins` includes SPA origin; method GET |
| SPA shows empty list | JSON shape `instances[]`; `Content-Type: application/json` |
| `aws sts` shows `root` | Remove `~/.aws/credentials`; use instance role only |
| `www-data`/`ubuntu` differ on `aws sts` | Both should show same `assumed-role` after keys removed |
| `PortableVisibilityConverter` not found | Run `sudo composer install --no-dev` in **`/opt/pbx3api`**, not only in `~/Git/…` |
| Composer PHP 8.4 / symfony/filesystem v8 error | Pull `directory` (lock pinned to PHP 8.3); re-run `composer install` |
| `sudo -u www-data composer` permission denied | Composer as **root** in `/opt/pbx3api`; not in `ubuntu` home |
| `ls: pbx3bak.*.zip: No such file` | Create backup in SPA first; ensure `/opt/pbx3/bkup` exists |
| Upload failed, empty AWS keys in `.env` | Comment out `AWS_ACCESS_KEY_ID=` lines; `config:clear`; or pull cred-fix commit |
| Node upload fails (other) | IAM policy `INSTANCE_KSUID` matches `globals.id`; region = bucket region |
| S3 timeout / network | EC2 SG **outbound** 443 allowed |
| Local zip vs S3 folder names differ | Expected — see **Golden node playbook §Step 6** (epoch ↔ UTC stamp) |
| Whole bucket leaked | Policy must **not** use `"Resource": "arn:aws:s3:::BUCKET/*"` for public statement |

---

## 13. Related docs

| Doc | Topic |
|-----|--------|
| **`S3_LAYOUT_PROPOSAL.md`** | Key layout, manifest, policies |
| **`DESIGN_RULES.md`** | Rules 1, 3, 6 — telephony vs directory vs solo |
| **`IMPLEMENTATION_PLAN.md`** | Phases 2–5 |
| **`../schema/instance-index.json`** | Example catalog (same name in S3) |

---

## Changelog

| Date | Note |
|------|------|
| 2026-05 | Initial ops runbook (bucket, catalog policy, CORS, IAM, Laravel note) |
| 2026-05 | **Quick recipe** — console steps, folder upload |
| 2026-05 | Single catalog name: `instance-index.json` (repo + S3) |
| 2026-05 | **Golden node playbook** — EC2 SG, IAM role, `/opt/pbx3api` deploy, backup naming, troubleshooting (08jzwn) |
