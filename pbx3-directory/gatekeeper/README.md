# PBX3 fleet gatekeeper (Phase B′ — slice 1)

Minimal **registrar-as-a-service** — sole writer for `catalog/instance-index.json` and `tenants/*/meta.json`.

Replaces direct `aws s3 cp` from Mac scripts for catalog mutations (calls still fail-safe if gatekeeper is down).

## Setup

```bash
cd pbx3-directory/gatekeeper
cp .env.example .env
# Set PBX3_ORG_BUCKET, GATEKEEPER_API_TOKEN, AWS_DEFAULT_REGION
composer install
php -S 127.0.0.1:8090 -t public
```

## Tests (Pack A)

```bash
composer install   # pulls phpunit from require-dev
composer test      # UserStore create / login / revoke / bad password
```

See **`pbx3/workingdocs/CRITICAL_PATH_TEST_PACK.md`**.

## Auth

| Mode | How |
|------|-----|
| **Fleet user (preferred)** | `POST /api/v1/auth/login` with `{ "email", "password" }` → Bearer token (store hashed in SQLite). Bootstrap: `php bin/create-fleet-user.php --email … --password …` |
| **Break-glass** | Static `GATEKEEPER_API_TOKEN` still accepted as Bearer (ops / emergency). |
| **SPA (interim)** | Paste either login token or break-glass into Fleet token gate. Login form wiring comes next. |

Bearer **required** on every `/api/v1/*` **except** `/api/v1/auth/login` and `/api/v1/auth/status`. `GET /health` stays open.

| Environment | How the SPA gets the token |
|-------------|----------------------------|
| **Lab / Vite DEV** | Optional `VITE_FLEET_GATEKEEPER_TOKEN` in `.env.development` (browser-visible; DEV only) |
| **Production SPA** | Login response token (preferred) or operator paste into **Fleet** gate. **Do not** bake tokens into production builds. |
| **Future** | Cookie session / SSO step-up — see `TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md` §2.5–2.6 |

Gatekeeper → node/SBC still uses **`PBX3_FLEET_SERVICE_TOKEN`** (server-side only; never in the SPA).

## API (Bearer `GATEKEEPER_API_TOKEN`)

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/health` | Liveness (no auth) |
| `GET` | `/api/v1/catalog` | Read instance index |
| `GET` | `/api/v1/tenants` | List tenant meta rows |
| `POST` | `/api/v1/instances` | Register/upsert instance |
| `POST` | `/api/v1/tenants` | Register tenant meta |
| `POST` | `/api/v1/tenants/{shortuid}/move` | Move tenant homing |
| `POST` | `/api/v1/s3/presign` | Scoped PUT/GET for `tenants/{shortuid}/migration/{job_id}/…` only |
| `POST` | `/api/v1/tenant-moves` | Create move job (`job.json` in S3) |
| `GET` | `/api/v1/tenant-moves` | List recent move jobs (lab-scale S3 scan; `?limit=50`) |
| `GET` | `/api/v1/tenant-moves/{job_id}` | Read job (`?tenant=shortuid` optional) |
| `POST` | `/api/v1/tenant-moves/{job_id}/run` | Run automated phases until human gate |
| `POST` | `/api/v1/tenant-moves/{job_id}/advance` | `{confirm: verifying\|cleanup}` or `{state}` patch or empty = run |

### Presign body

```json
{
  "method": "PUT",
  "key": "tenants/9wvvnb/migration/JOBID/pbx3tenant.9wvvnb.1720612800.zip",
  "expires_in": 900
}
```

Returns `{ url, method, key, expires_in, bucket }`. Nodes use the URL for export PUT / import GET — no `tenants/*` on the node IAM role.

### Runner env (gatekeeper `.env`)

| Var | Purpose |
|-----|---------|
| `PBX3_FLEET_SERVICE_TOKEN` | Bearer to node + SBC fleet APIs |
| `PBX3_SBC_ADMIN_API_URL` | e.g. `http://sbc.pbx3.com/api` |
| `PBX3_FLEET_HTTP_VERIFY` | `false` for self-signed lab TLS |
| `PBX3_LE_EMAIL` | optional cert sync on dest |

## Deferred (slice 2+)

- SPA Move wizard
- Audit log persistence

## Related

- `../tools/` — shell registrars (adopt to call this API)
- `../schema/sbc-fleet.v0.json`
- `../schema/tenant-move-job.v0.json`
- `TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md` §2.5–2.6
