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
| IAM | Instance profile **`pbx3-control-gatekeeper`** + policy **`pbx3-control-gatekeeper-s3`** on bucket `08jzwn-pbx3` (`catalog/*`, `tenants/*`, `instances/*`) |

**Endpoints:**

- `GET https://control.pbx3.com/health` — no auth  
- `GET https://control.pbx3.com/api/v1/*` — Bearer `GATEKEEPER_API_TOKEN`

`.env` lives at `/etc/pbx3-gatekeeper/.env` (symlinked into app). Contains org bucket, gatekeeper token, fleet service token, `PBX3_SBC_ADMIN_API_URL=https://sbc.pbx3.com/api`.

## Operator notes

- Prefer fleet user login in SPA; break-glass `GATEKEEPER_API_TOKEN` for emergencies only. Identity / cookies / SSO / abilities: **`workingdocs/FLEET_AUTH_COOKIE_SSO.md`**.  
- After stop/start without EIP, **update DNS** before renew/client use.  
- Redeploy code: rsync gatekeeper tree (exclude `.env`), `composer install` with **php8.4**, `sudo systemctl reload php8.4-fpm`.  
- Policy JSON in repo: `pbx3-directory/schema/pbx3-control-gatekeeper-s3.policy.json`.

## Verify

```bash
curl -sS https://control.pbx3.com/health
curl -sS -H "Authorization: Bearer $GATEKEEPER_API_TOKEN" \
  https://control.pbx3.com/api/v1/catalog | head
```
