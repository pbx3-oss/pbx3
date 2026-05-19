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

Add `https://admin.example.com` (your real admin host) before production deploy.

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

**Package (still current for Laravel 11.x / 12.x):** [`league/flysystem-aws-s3-v3`](https://packagist.org/packages/league/flysystem-aws-s3-v3) — official optional dependency for the `s3` disk ([Laravel 11 filesystem](https://laravel.com/docs/11.x/filesystem#driver-prerequisites), [Laravel 12 filesystem](https://laravel.com/docs/12.x/filesystem#driver-prerequisites)). Pulls in `aws/aws-sdk-php` transitively; do **not** install the AWS SDK as a separate top-level dependency unless you need low-level calls outside `Storage::`.

On deploy host (`/opt/pbx3api`):

```bash
composer require league/flysystem-aws-s3-v3 "^3.0" --with-all-dependencies
```

Use `Storage::disk('s3')` (or a scoped disk — see Laravel **“Scoped Filesystems”**) for backup PUTs; use `temporaryUrl()` for presigned GETs to the SPA when bulk download UI ships.

**`.env`** (only if not using instance role):

```env
FILESYSTEM_DISK=local
AWS_DEFAULT_REGION=eu-west-1
AWS_BUCKET=acme-pbx3
# AWS_ACCESS_KEY_ID=     # omit when using IAM role
# AWS_SECRET_ACCESS_KEY=
```

Use a dedicated disk in code (future): `Storage::disk('s3')->put("instances/{$ksuid}/backups/…")`. **`config/filesystems.php`** already defines an `s3` disk stub.

**Not implemented yet:** backup job calling S3 — installing Composer alone does nothing until Phase 4 code lands.

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

## 9. SPA and env (Phase 2)

**pbx3spa** (build-time):

```env
# Fleet mode — HTTPS URL to catalog JSON (S3 or CloudFront)
VITE_INSTANCE_DIRECTORY_URL=https://acme-pbx3.s3.eu-west-1.amazonaws.com/catalog/instance-index.json

# Solo — omit VITE_INSTANCE_DIRECTORY_URL (Rule 6)
# VITE_DEFAULT_API_BASE_URL=https://08jzwn.pbx3.com:44300/api
```

After deploy: login → picker (or auto-select if one row) → Sanctum on chosen `api_base_url`.

**Dev without S3:** host `instance-index.json` on any static server or paste URL to raw GitHub gist; same env var.

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
- [ ] Phase 4: test PUT from node with IAM role after Laravel package + code exist

---

## 12. Troubleshooting

| Symptom | Check |
|---------|--------|
| 403 on catalog URL | Block Public Access; bucket policy Resource ARN; object key exactly `catalog/instance-index.json` |
| CORS error in browser | `put-bucket-cors`; `AllowedOrigins` includes SPA origin; method GET |
| SPA shows empty list | JSON shape `instances[]`; `Content-Type: application/json` |
| Node upload fails | IAM role attached; policy prefix matches `globals.id`; region matches bucket |
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
