# PBX3 fleet gatekeeper (Phase B′ — slice 1)

Minimal **registrar-as-a-service** — sole writer for `catalog/instance-index.json`, `catalog/tenant-home.json` (B′ login rollup), and `tenants/*/meta.json`.

Replaces direct `aws s3 cp` from Mac scripts for catalog mutations (calls still fail-safe if gatekeeper is down).

**Lab control host (D1):** **`../tools/install-control-host.sh`** — Garage + catalog seed + nginx. Do not paste keys.

## Setup

```bash
cd pbx3-directory/gatekeeper
cp .env.example .env
# Set PBX3_ORG_BUCKET, GATEKEEPER_API_TOKEN, AWS_DEFAULT_REGION
# Lab: prefer the control installer (writes /etc/pbx3-gatekeeper/.env)
# For S7 recordings presigns also set PBX3_RECORDINGS_BUCKET (dedicated; not org bucket)
composer install
php -S 127.0.0.1:8090 -t public
```

## Tests (Pack A)

```bash
composer install   # pulls phpunit from require-dev
composer test      # UserStore auth + TOTP 2FA + Pack A
```

See **`pbx3/workingdocs/CRITICAL_PATH_TEST_PACK.md`**.

## Fleet ops notify (instance /up probe)

| Piece | Detail |
|-------|--------|
| Job | `bin/probe-fleet-instances.php` — probe each active catalog `api_base_url` → `/up` |
| State | SQLite `instance_health` (same `GATEKEEPER_AUTH_DB`); catalog `last_seen_at` on success |
| Hysteresis | Down after **2** consecutive misses; cleared on first success |
| Mail | SMTP via `GATEKEEPER_SMTP_*` (`Mailer` + `SmtpMailer`). Unset SMTP → log only |
| Subscribers | Fleet users with `notify_failures` + optional `GATEKEEPER_OPS_NOTIFY_EMAIL` |
| Signals | Instance down/cleared; catalog lifecycle; misconfig REGISTER; **move job failed/aborted**; **Fail2ban ban** (`fail2ban_ban` ops-event) |
| Timer | `deploy/pbx3-fleet-probe.service` + `.timer` (60s). Install on control: |

```bash
sudo cp deploy/pbx3-fleet-probe.service deploy/pbx3-fleet-probe.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now pbx3-fleet-probe.timer
# Optional: set GATEKEEPER_SMTP_* in /etc/pbx3-gatekeeper/.env
# Enable notify for a user: Fleet → Users → "Email on instance down"
```

See **`docs/FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** · **`docs/CONTROL_HOST.md`**.

## Auth

| Mode | How |
|------|-----|
| **Fleet user (preferred)** | `POST /api/v1/auth/login` with `{ "email", "password" }` → Bearer token (store hashed in SQLite). If TOTP enabled → `requires_2fa` + `challenge_id` (no token); complete with `POST /api/v1/auth/2fa/verify`. Bootstrap: `php bin/create-fleet-user.php --email … --password …` `[--abilities fleet_admin]` |
| **Break-glass** | Static `GATEKEEPER_API_TOKEN` still accepted as Bearer (ops / emergency) — treated as **`fleet_admin`**. **Not** subject to TOTP. |
| **SPA** | Login form on FleetTokenGate (+ challenge step); optional break-glass paste. Enroll at **Fleet → Fleet 2FA**. Abilities from login/`/me` gate UI (server still enforces). |

### TOTP 2FA (opt-in)

| Piece | Detail |
|-------|--------|
| Spec | `pbx3/workingdocs/FLEET_GATEKEEPER_TOTP_REQUIREMENTS.md` |
| Issuer | **`Aelintra Fleet`** (`GATEKEEPER_TOTP_ISSUER`); encrypt key `GATEKEEPER_TOTP_KEY` (falls back to `GATEKEEPER_API_TOKEN`) |
| Enroll | Authenticated `POST /api/v1/auth/2fa/setup` → confirm → recovery codes once |
| Admin clear | `POST /api/v1/fleet-users/{id}/clear-2fa` (`fleet_admin`) — clears secret + revokes sessions |
| Create user | Password-only; enroll after login |

Bearer **required** on every `/api/v1/*` **except** `/api/v1/auth/login`, `/api/v1/auth/2fa/verify`, and `/api/v1/auth/status`. `GET /health` stays open. `/api/v1/auth/me` and logout need Bearer only (no ability).

### Abilities (S10.1)

| Ability | Gates |
|---------|--------|
| `fleet_read` | `GET` catalog, tenants, tenant-moves; required to enter Fleet mode |
| `fleet_instances` | `POST` instances, tenants (register) |
| `fleet_moves` | Move job create/run/advance; catalog move; org migration `s3/presign` |
| `fleet_edge` | `GET` reconcile + `POST` reconcile/project (S10.4); `POST` dids/assign + release (S10.5) |
| `fleet_admin` | All of the above + recordings `presign-recordings` + fleet-user manage (S10.6) |

`fleet_admin` grants every `fleet_*`. Existing auth DBs get an `abilities` column defaulting to `["fleet_admin"]` on migrate.

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
| `GET` | `/api/v1/velocity-policy` | Read fleet velocity policy (`catalog/velocity-policy.json`; defaults if missing) (`fleet_read`) |
| `PUT` | `/api/v1/velocity-policy` | Replace velocity policy (Gatekeeper sole S3 writer) (`fleet_admin`) |
| Ops-events | `velocity_irsf`, `velocity_off_hours` | Node CDR detectors → fleet SMTP |
| `POST` | `/api/v1/catalog/tenant-home/rebuild` | Rebuild `catalog/tenant-home.json` from tenant metas (`fleet_instances`) — also runs automatically on tenant register/move |
| `GET` | `/api/v1/fleet-users` | S10.6 list fleet users + ability vocab (`fleet_admin`) |
| `POST` | `/api/v1/fleet-users` | Create user `{email,password,name?,abilities?}` |
| `PATCH` | `/api/v1/fleet-users/{id}` | Update name / password / abilities / `notify_failures` |
| `POST` | `/api/v1/fleet-users/{id}/disable` | Soft-disable + revoke sessions (cannot self / last admin) |
| `POST` | `/api/v1/fleet-users/{id}/enable` | Re-enable |
| `POST` | `/api/v1/fleet-users/{id}/revoke-sessions` | Kill all Bearers for user |
| `GET` | `/api/v1/tenants` | List tenant meta rows |
| `GET` | `/api/v1/dial-cohorts` | C1 Site Groups index (`catalog/dial-cohort-index.json`) (`fleet_read`) |
| `POST` | `/api/v1/dial-cohorts` | Create dial cohort `{name, prefix_width?}` (`fleet_dial_cohorts`) |
| `GET` | `/api/v1/dial-cohorts/{id}` | Read cohort document (`fleet_read`) |
| `PATCH` | `/api/v1/dial-cohorts/{id}` | Rename / change `prefix_width` (`fleet_dial_cohorts`) |
| `POST` | `/api/v1/dial-cohorts/{id}/members` | Add member `{tenant_shortuid, routing_prefix}` — catalog + materialise job unless `materialise:false` (`fleet_dial_cohorts`) |
| `DELETE` | `/api/v1/dial-cohorts/{id}/members/{shortuid}` | Remove member; clears prefix + cohort back-pointer; materialise+prune (`fleet_dial_cohorts`) |
| `POST` | `/api/v1/dial-cohorts/{id}/decommission` | Soft-decommission cohort (`confirm: true`); prunes managed node rows (`fleet_dial_cohorts`) |
| `POST` | `/api/v1/dial-cohorts/{id}/sync` | C3 Sync now — materialise mesh + prune unmanaged + one commit/home (`fleet_dial_cohorts`) |
| `GET` | `/api/v1/dial-cohorts/{id}/jobs` | List materialise jobs (`fleet_read`) |
| `GET` | `/api/v1/dial-cohorts/{id}/jobs/{job_id}` | Read job (`fleet_read`) |
| `POST` | `/api/v1/dial-cohorts/{id}/jobs/{job_id}/run` | Run pending job (`fleet_dial_cohorts`) |
| `POST` | `/api/v1/dial-cohorts/{id}/jobs/{job_id}/retry` | Retry failed job (`fleet_dial_cohorts`) |
| `PATCH` | `/api/v1/tenants/{shortuid}/routing-prefix` | Set/clear destination `routing_prefix`; materialise if in cohort (`fleet_dial_cohorts`) |
| `POST` | `/api/v1/catalog/dial-cohort-index/rebuild` | Rebuild Site Groups index from cohort docs (`fleet_dial_cohorts`) |
| `POST` | `/api/v1/tenants/provision` | Fleet-first create: node `/fleet/tenants` → catalog meta → SBC domain (`fleet_instances`). Body: `instance_id`, `pkey`, `description`; optional `clusterclid`/`localarea`; resume after catalog fail: `resume`+`shortuid`+`fqdn` |
| `GET` | `/api/v1/dids` | S10.5 catalog DID ownership flat list (`fleet_read`) |
| `GET` | `/api/v1/dids/reconcile` | Catalog active/porting ↔ SBC `fleet=did` rules (prefix/tenant/setid drift) (`fleet_edge`) |
| `POST` | `/api/v1/dids/assign` | Assign/reassign DID or hop-1 block → tenant (`delivery`: `singleton`\|`block`, optional `sip_prefix`); writes `dids.json` + `did-index`; projects SBC unless `project:false` (`fleet_edge`). **Singleton:** omit `sip_prefix` (digit E.164); clears stale prefix on re-assign. **Block:** digit-E.164 `sip_prefix` (no UK national `0…`) |
| `POST` | `/api/v1/dids/release` | Soft-release DID in catalog (+ project) (`fleet_edge`) |
| `POST` | `/api/v1/dids/project` | Force-project catalog DIDs → SBC inbound `dr_rules` — Apply for DID drift (`fleet_edge`) |
| `POST` | `/api/v1/tenants/{shortuid}/register-domain` | Ensure SBC `domain` row for tenant fqdn + catalog setid (`fleet_edge`) |
| `POST` | `/api/v1/instances/{id}/provision-edge` | S10.5: allocate/update dispatcher set + Asterisk Peer; write catalog `sbc_dispatcher_setid` + `sbc_backend_uri` (`fleet_edge`). Body: optional `backend_uri`, `confirm` (required to update existing setid), `source_ip`, `dry_run` |
| `GET` | `/api/v1/sbc/dispatcher-sets` | Live SBC dispatcher setids (`fleet_read`) — catalog setid must be one of these |
| `GET` | `/api/v1/reconcile` | S10.4 drift: catalog tenants ↔ SBC `domain.setid` (`fleet_edge`) |
| `POST` | `/api/v1/reconcile/project` | Apply catalog → SBC for `setid_mismatch` / `missing_fleet_tag` (`confirm` / `dry_run`) |
| `POST` | `/api/v1/reconcile/prune-orphans` | Remove `orphan_on_sbc` fleet-owned domain rows (`confirm` / `dry_run`). Also runs automatically after successful **provision-edge** (lab reinstall hygiene). |

### Reconcile vs project (read this)

| Surface | What it writes | Home of record? |
|---------|----------------|-----------------|
| **Fleet → Instances** (PATCH `sbc_dispatcher_setid`) | **S3 catalog** only | Yes — catalog |
| **SBC Filament / `repoint`** | **SBC MySQL** `domain.setid` | No — projection |
| **`POST /reconcile/project`** | **SBC only** (via adapter repoint) | Makes edge match catalog |

**Drift** after an Instances edit is normal: you changed catalog intent; the SBC has not followed yet.

- If the new catalog setid is **wrong** (typo / lab mess-up): **edit Instances again** — do **not** project.
- If the catalog setid is **correct** and the SBC drifted (or you intentionally want the edge to follow): **project** pushes catalog → SBC.
- Project is **not** “fix my mistake” / undo. It never writes the catalog from the SBC (Rule 13).
- Project to a setid with **no dispatcher destinations** fails (422); mismatches remain until catalog is corrected or the set exists.
- **Catalog `sbc_dispatcher_setid`:** register/PATCH must name a **live** SBC dispatcher set (`GET /api/v1/sbc/dispatcher-sets`). Invented values (e.g. `99`) are rejected. SPA: no free-typed number — pick from live sets only.

DID / missing domain rows: **S10.5**. DID delivery drift: **`GET /api/v1/dids/reconcile`**; Apply = **`POST /api/v1/dids/project`** (catalog → edge). Domain setid drift stays on **`/reconcile`**.
| `POST` | `/api/v1/instances` | Register/upsert instance (`verify_up` optional; stamps `updated_by`) |
| `PATCH` | `/api/v1/instances/{id}` | Update label/notes/environment/status/… (`fleet_instances`) |
| `POST` | `/api/v1/instances/{id}/decommission` | Soft decommission (`confirm: true`, optional `notes`); **422** if active tenants still home on instance; retires SBC Fail2ban fleet-home whitelist |
| `POST` | `/api/v1/instances/{id}/remove` | Hard drop catalog row (`confirm: true`; **decommissioned** only; keeps S3 meta/backups) |
| `POST` | `/api/v1/tenants` | Register tenant meta only (legacy / CLI repair — prefer `/tenants/provision`) |
| `POST` | `/api/v1/tenants/{shortuid}/move` | Move tenant homing |
| `POST` | `/api/v1/tenants/{shortuid}/decommission` | Soft-decommission tenant meta (`confirm: true`; `fleet_instances`) |
| `POST` | `/api/v1/tenant-deletes` | Create delete job + run to `awaiting_confirm` (`fleet_instances`) |
| `GET` | `/api/v1/tenant-deletes` | List recent delete jobs |
| `GET` | `/api/v1/tenant-deletes/{job_id}` | Read delete job (`?tenant=shortuid` optional; includes `wipe_counts` after preflight) |
| `POST` | `/api/v1/tenant-deletes/{job_id}/run` | Run until confirm gate |
| `POST` | `/api/v1/tenant-deletes/{job_id}/confirm` | `{confirm:true, typed_shortuid}` then mesh prune → edge wipe + node wipe + catalog |
| `POST` | `/api/v1/tenant-deletes/{job_id}/abort` | Abort before node wipe |
| `POST` | `/api/v1/tenant-deletes/{job_id}/retry` | Resume after `failed` |
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
