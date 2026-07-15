# PBX3 fleet gatekeeper (Phase B′ — slice 1)

Minimal **registrar-as-a-service** — sole writer for `catalog/instance-index.json` and `tenants/*/meta.json`.

Replaces direct `aws s3 cp` from Mac scripts for catalog mutations (calls still fail-safe if gatekeeper is down).

## Setup

```bash
cd pbx3-directory/gatekeeper
cp .env.example .env
# Set PBX3_ORG_BUCKET, GATEKEEPER_API_TOKEN, AWS_DEFAULT_REGION
# For S7 recordings presigns also set PBX3_RECORDINGS_BUCKET (dedicated; not org bucket)
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
| **Fleet user (preferred)** | `POST /api/v1/auth/login` with `{ "email", "password" }` → Bearer token (store hashed in SQLite). Bootstrap: `php bin/create-fleet-user.php --email … --password …` `[--abilities fleet_admin]` |
| **Break-glass** | Static `GATEKEEPER_API_TOKEN` still accepted as Bearer (ops / emergency) — treated as **`fleet_admin`**. |
| **SPA** | Login form on FleetTokenGate; optional break-glass paste. Abilities from login/`/me` gate UI (server still enforces). |

### Abilities (S10.1)

| Ability | Gates |
|---------|--------|
| `fleet_read` | `GET` catalog, tenants, tenant-moves; required to enter Fleet mode |
| `fleet_instances` | `POST` instances, tenants (register) |
| `fleet_moves` | Move job create/run/advance; catalog move; org migration `s3/presign` |
| `fleet_edge` | Reserved for S10.4–S10.5 (reconcile / DID) |
| `fleet_admin` | All of the above + recordings `presign-recordings` + future fleet-user manage |

`fleet_admin` grants every `fleet_*`. Existing auth DBs get an `abilities` column defaulting to `["fleet_admin"]` on migrate.

Bearer **required** on every `/api/v1/*` **except** `/api/v1/auth/login` and `/api/v1/auth/status`. `GET /health` stays open. `/api/v1/auth/me` and logout need Bearer only (no ability).

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
| `POST` | `/api/v1/instances` | Register/upsert instance (`verify_up` optional; stamps `updated_by`) |
| `PATCH` | `/api/v1/instances/{id}` | Update label/notes/environment/status/… (`fleet_instances`) |
| `POST` | `/api/v1/instances/{id}/decommission` | Soft decommission (`confirm: true`, optional `notes`) |
| `POST` | `/api/v1/tenants` | Register tenant meta |
| `POST` | `/api/v1/tenants/{shortuid}/move` | Move tenant homing |
| `POST` | `/api/v1/s3/presign` | Scoped PUT/GET for `tenants/{shortuid}/migration/{job_id}/…` only (org bucket) |
| `POST` | `/api/v1/s3/presign-recordings` | S7: PUT/GET on **`PBX3_RECORDINGS_BUCKET`**, keys `tenants/{shortuid}/recordings/…` only |
| `POST` | `/api/v1/tenant-moves` | Create move job (`job.json` in S3) |
| `GET` | `/api/v1/tenant-moves` | List recent move jobs (lab-scale S3 scan; `?limit=50`) |
| `GET` | `/api/v1/tenant-moves/{job_id}` | Read job (`?tenant=shortuid` optional) |
| `POST` | `/api/v1/tenant-moves/{job_id}/run` | Run automated phases until human gate |
| `POST` | `/api/v1/tenant-moves/{job_id}/advance` | `{confirm: verifying\|cleanup}` or `{state}` patch or empty = run |
| `POST` | `/api/v1/tenant-moves/{job_id}/abort` | Soft-abort before cutover (`fleet_moves`) |
| `POST` | `/api/v1/tenant-moves/{job_id}/retry` | Resume after `failed` then run until gate |
| `POST` | `/api/v1/tenant-moves/{job_id}/rollback` | After cutover: SBC rollback-repoint (+ catalog flip) |

### Presign body

```json
{
  "method": "PUT",
  "key": "tenants/9wvvnb/migration/JOBID/pbx3tenant.9wvvnb.1720612800.zip",
  "expires_in": 900
}
```

Returns `{ url, method, key, expires_in, bucket }`. Nodes use the URL for export PUT / import GET — no `tenants/*` on the node IAM role.

### Recordings presign body (S7)

```json
{
  "method": "PUT",
  "key": "tenants/9wvvnb/recordings/media/2026/07/14/1716123456-9wvvnb-1000-2000.wav",
  "expires_in": 900,
  "tagging": "class=recording"
}
```

`tagging` is optional (PUT only) — passed through to the S3 `PutObject` command for lifecycle. Returns `{ url, method, key, expires_in, bucket }` on the **recordings** bucket. Requires `PBX3_RECORDINGS_BUCKET` and control-host IAM policy **`pbx3-control-gatekeeper-recordings`**. See **`OPS_S3_RUNBOOK.md`** §13.

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
