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

## API (Bearer `GATEKEEPER_API_TOKEN`)

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/health` | Liveness (no auth) |
| `GET` | `/api/v1/catalog` | Read instance index |
| `GET` | `/api/v1/tenants` | List tenant meta rows |
| `POST` | `/api/v1/instances` | Register/upsert instance |
| `POST` | `/api/v1/tenants` | Register tenant meta |
| `POST` | `/api/v1/tenants/{shortuid}/move` | Move tenant homing |

## Deferred (slice 2+)

- `POST /api/v1/s3/presign`
- `tenant-move-job.v0.json` orchestrator
- `SbcFleetAdapter` proxy
- Audit log persistence

## Related

- `../tools/` — shell registrars (adopt to call this API)
- `../schema/sbc-fleet.v0.json`
- `TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md` §2.5–2.6
