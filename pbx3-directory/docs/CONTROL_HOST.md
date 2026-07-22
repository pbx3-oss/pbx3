# Control host — `control.pbx3.com`

**Stood up:** 2026-07-14 (lab)  
**Instance:** `i-01fc97d42ac15286d` · **AZ** us-east-1f · **type** `t4g.small` · **AMI** Ubuntu 24.04 arm64  
**SSH:** `ubuntu@control.pbx3.com` with `~/Documents/pemfiles/pbx3test.pem`  
**IP:** dynamic public (set A record when it changes; prefer Elastic IP when available)

## Fleet auth (infra 2026-07-14)

| Piece | Detail |
|-------|--------|
| Users / tokens | SQLite `/var/lib/pbx3-gatekeeper/auth.sqlite` (`GATEKEEPER_AUTH_DB`) |
| Login | `POST /api/v1/auth/login` `{email,password}` → Bearer token |
| Me / logout | `GET /api/v1/auth/me`, `POST /api/v1/auth/logout` (Bearer) |
| Status | `GET /api/v1/auth/status` (public) |
| Bootstrap user | `sudo -u www-data php8.4 bin/create-fleet-user.php --email … --password …` |
| First lab user | `fleet@pbx3.com` (password in ops secret store — generated at bootstrap) |
| Break-glass | Static `GATEKEEPER_API_TOKEN` still works as Bearer |

SPA Fleet mode uses control-plane **email/password login** (Bearer in sessionStorage). Break-glass paste is collapsed (ops only). Exit Fleet revokes the session.

## What’s running

| Piece | Detail |
|-------|--------|
| App | Gatekeeper at `/home/ubuntu/gatekeeper` (rsync from `pbx3-directory/gatekeeper`) |
| PHP | **8.4** (ondrej PPA) + php-fpm — lockfile needs ≥8.4 |
| nginx | HTTPS + HTTP→HTTPS; ACME webroot under `public/.well-known` |
| LE | `control.pbx3.com` — `certbot.timer` + deploy hook reloads nginx |
| IAM | Instance profile **`pbx3-control-gatekeeper`** + **`pbx3-control-gatekeeper-s3`** on org bucket `08jzwn-pbx3` (`catalog/*`, `tenants/*`, `instances/*`, **`control/*`**) + **`pbx3-control-gatekeeper-recordings`** on `08jzwn-pbx3-recordings` (`tenants/*/recordings/*`) |
| Log retention | After IAM `control/*`: **`sudo gatekeeper/deploy/install-control-log-retention.sh`** (nginx rotate + daily ship). See § Log retention |

**Endpoints:**

- `GET https://control.pbx3.com/health` — no auth  
- `GET https://control.pbx3.com/api/v1/*` — Bearer `GATEKEEPER_API_TOKEN`

`.env` lives at `/etc/pbx3-gatekeeper/.env` (symlinked into app). Contains org bucket, gatekeeper token, fleet service token, `PBX3_SBC_ADMIN_API_URL=https://sbc.pbx3.com/api`. For S7 also set **`PBX3_RECORDINGS_BUCKET=08jzwn-pbx3-recordings`** (dedicated; never the org/catalog bucket).

## Recordings bucket (S7)

Lab bucket **`08jzwn-pbx3-recordings`** (PCI-shaped: BPA on, TLS-only, SSE-S3 — **not** attested). Create / harden: **`OPS_S3_RUNBOOK.md`** §13 · tool **`tools/create-recordings-bucket.sh`**. IAM JSON: **`schema/pbx3-control-gatekeeper-recordings.policy.json`**.

**Gatekeeper `.env`:** set `PBX3_RECORDINGS_BUCKET=08jzwn-pbx3-recordings`. API: `POST /api/v1/s3/presign-recordings`.

**Node (`pbx3api`) `.env` for upload:** `PBX3_RECORDING_UPLOAD_ENABLED=true`, `PBX3_GATEKEEPER_URL=https://control.pbx3.com`, `PBX3_GATEKEEPER_TOKEN=<break-glass or fleet token>`, optional `PBX3_RECORDING_UPLOAD_TENANTS=duns`.

## Operator notes

- Prefer fleet user login in SPA; break-glass `GATEKEEPER_API_TOKEN` for emergencies only. Identity / cookies / SSO / abilities: **`workingdocs/FLEET_AUTH_COOKIE_SSO.md`**.  
- After stop/start without EIP, **update DNS** before renew/client use.  
- Redeploy code: rsync gatekeeper tree (exclude `.env`), `composer install` with **php8.4**, `sudo systemctl reload php8.4-fpm`.  
- Policy JSON in repo: `pbx3-directory/schema/pbx3-control-gatekeeper-s3.policy.json` (org) + `…-recordings.policy.json` (S7).

## Fleet ops notify (probe + SMTP)

| Piece | Detail |
|-------|--------|
| Probe | `php8.4 bin/probe-fleet-instances.php` — active catalog instances → `/up`; skip `maintenance` / `decommissioned` |
| Timer | Copy `gatekeeper/deploy/pbx3-fleet-probe.{service,timer}` → `/etc/systemd/system/`; `enable --now pbx3-fleet-probe.timer` (~60s) |
| Health | SQLite `instance_health` in `GATEKEEPER_AUTH_DB`; down after 2 misses; `last_rtt_ms` on success; S3 `last_seen_at` on success; `GET /api/v1/catalog` overlays `health` for SPA |
| SMTP | `GATEKEEPER_SMTP_HOST`, `PORT`, `USER`, `PASS`, `FROM`, `TLS` in `/etc/pbx3-gatekeeper/.env`. Unset → log-only. Optional `GATEKEEPER_OPS_NOTIFY_EMAIL`, `GATEKEEPER_FLEET_UI_URL` |
| Subscribe | Fleet → Users → **Email on instance down** (`notify_failures`) |

### SBC edge HA (FO lab)

| Piece | Detail |
|-------|--------|
| Registry | SQLite `edge_pairs` + `edge_pair_health` |
| API | `GET/PATCH /api/v1/edge-settings` (SBC URL); `GET/POST/PATCH /api/v1/edge-pairs`, `POST …/promote`, `POST …/warm-sync` (`fleet_admin`) |
| Probe | `php8.4 bin/probe-edge-pairs.php` — SIP OPTIONS on VIP; timer `pbx3-edge-probe.timer` |
| Warm sync | `php8.4 bin/sync-edge-warm.php` — active backup+upload → standby `--db-only`; timer `pbx3-edge-warm-sync.timer` (daily 05:30 UTC) |
| Modes | `managed` (alert only) \| `auto` (EIP promote when `GATEKEEPER_EDGE_AUTO_PROMOTE=true`) |
| IAM | Lab policy **`pbx3-control-gatekeeper-fo-eip`** (`AssociateAddress` / describe — also used for standby public IP) |
| SPA | Fleet → **Edge HA** (`/fleet/edge`) — Sync now + last warm sync |

**Install warm-sync timer:** copy `gatekeeper/deploy/pbx3-edge-warm-sync.{service,timer}` → `/etc/systemd/system/`; `sudo systemctl enable --now pbx3-edge-warm-sync.timer`.

**Lab check:** enable notify for ops mailbox; stop node API or block `/up` from control → within ~2 min one down mail (or log); restore → cleared.

**Move jobs:** Gatekeeper mails on job `failed` or `aborted` (same subscribers). No extra enable flag.

**Misconfig REGISTER loops (node):** On each fleet node set `PBX3_OPS_REGISTER_LOOP_ENABLED=true` (reuses `PBX3_GATEKEEPER_URL` / `TOKEN`). Put **SBC signaling IPs** in node `ignoreip` (peer allowlist for the scanner — instance Asterisk Fail2ban jail is **disabled**). Scheduler runs `pbx3:ops-register-loops` every minute → Gatekeeper `POST /api/v1/ops-events`. SIP ban/whitelist for real client IPs is on the **SBC** only.

**SBC Fail2ban ban → email:** On SBC admin set `PBX3_OPS_FAIL2BAN_BAN_NOTIFY=true` + Gatekeeper URL/token; install cron from `pbx3sbc-admin/deploy/cron.d/pbx3sbc-fail2ban-notify.example`. First run seeds current bans (no mail); new bans → `fail2ban_ban` ops-event.

## Log retention (Phase 4)

Ship rotated **syslog** + **nginx** to org bucket `control/{PBX3_CONTROL_ID}/logs/…`.

| Piece | Detail |
|-------|--------|
| Install | From repo: `sudo gatekeeper/deploy/install-control-log-retention.sh` |
| Env | `/etc/pbx3-gatekeeper/log-ship.env` (`PBX3_ORG_BUCKET`, `PBX3_CONTROL_ID=control`) |
| Cron | `/etc/cron.d/pbx3-control-logs` → `pbx3-control-ship-logs` at 06:45 |
| IAM | Update live role with **`schema/pbx3-control-gatekeeper-s3.policy.json`** (includes `control/*`) |

```bash
sudo /usr/local/bin/pbx3-control-ship-logs --dry-run
sudo /usr/local/bin/pbx3-control-ship-logs --limit=5
```

## Verify

```bash
curl -sS https://control.pbx3.com/health
curl -sS -H "Authorization: Bearer $GATEKEEPER_API_TOKEN" \
  https://control.pbx3.com/api/v1/catalog | head
```
