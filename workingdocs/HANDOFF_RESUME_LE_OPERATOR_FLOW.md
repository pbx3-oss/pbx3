# Handoff: LE operator flow, webroot vs standalone (resume here)

Created: 2026-05-17 (Europe time). Replace or trim when work is merged.

## Context (facts from recent work)

- **Instance identity:** **`globals.fqdn`** / **`shortuid`** = DNS-visible node; **`globals.id`** (KSUID) + **`/opt/pbx3/etc/identity/instance-id.txt`** = stable machine id (not hostname).
- **Installer (`pbx3` `installer.sh`):** Does **not** run Let’s Encrypt. First LE is manual: **`le-first-cert.sh`** / **`POST /api/certificates/letsencrypt/setup`** / SPA **Get certificate** after DNS + port 80.
- **Certs on disk:** **`/etc/letsencrypt/live/<le-domain>/`**, **`le-domain`** in **`/opt/pbx3/etc/identity/le-domain`**. Nginx snippet: **`apply-active-cert.sh`** → **`/etc/nginx/snippets/pbx3-ssl-active.conf`**.
- **Standalone pain:** **`certbot --standalone`** needs exclusive **port 80** → often **`systemctl stop nginx`**, which **drops SPA/API on nginx** during the window.SPA **Renew now** has the same class of issue.
- **`POST …/certificates/letsencrypt/sync`:** Exists in **`pbx3api`**; **SPA Certificates panel does not wire Sync yet** — use **curl** + admin **Bearer** + JSON **`{"email":"…"}`** until Step 3.3 is implemented.
- **New tenant:** DB + **`update-fqdn-inline`** on create; **DNS A/AAAA per `cluster.fqdn`** remains operator-owned; cert **SAN** does **not** auto-expand → **sync** / re-issue after DNS exists.
- **DNS policy (agreed):** No wildcard for now — **explicit A/AAAA per** node **`globals.fqdn`** **and per** tenant **`cluster.fqdn`**.
- **Rate limits:** At ~50 tenants and manual/occasional sync, prod limits are unlikely; **staging** remains useful while iterating (**[staging environment](https://letsencrypt.org/docs/staging-environment/)**). Scripts today use **production** ACME unless extended.

## Implemented (2026-05-17 resume)

| Item | Detail |
|------|--------|
| **Webroot** | `/opt/pbx3/var/acme-challenge` (`www-data`, mode 755) |
| **Nginx :80** | `pbx3-acme-http.conf` — `default_server`, only `/.well-known/acme-challenge/` |
| **ACME scripts** | `le-acme-common.sh`; **`le-first-cert*`**, **`le-sync-cert-sans`**, **`le-renew-with-80`** use **webroot** by default |
| **Break-glass** | `PBX3_LE_STANDALONE=1` → `--standalone` |
| **Staging** | `PBX3_LE_STAGING=1` → `certbot --test-cert` |
| **Bootstrap** | `le-instance-bootstrap.sh <email>` — node + tenant FQDNs → `le-first-cert-multi.sh` |
| **Cron** | `/etc/cron.d/pbx3` — **`17 3 * * *`** → `le-renew-with-80.sh` → `/var/log/pbx3-le-renew.log` |
| **Nginx install** | `le-install-nginx-acme.sh`; **pbx3** `installer.sh` + **pbx3api** `install-nginx-site.sh` |

**Existing boxes** issued with **standalone** must **re-issue once** (bootstrap or sync) so renewal profile uses **webroot**.

## Repo pointers

| Topic | Location |
|--------|----------|
| Shared LE helpers | `pbx3-1/opt/pbx3/scripts/le-acme-common.sh` |
| Operator bootstrap | `pbx3-1/opt/pbx3/scripts/le-instance-bootstrap.sh` |
| First issue multi-SAN | `le-first-cert-multi.sh` |
| Nginx ACME site | `pbx3api/config/nginx/pbx3-acme-http.conf` (copy in `pbx3-1/opt/pbx3/etc/nginx/`) |
| SPA (no Sync button yet) | `pbx3spa/src/views/CertificatesView.vue` |

## Still to do

1. **SPA:** wire **Sync** → `POST certificates/letsencrypt/sync`.
2. **Docs:** operator steps in `INSTALL_SEQUENCE_UBUNTU.md` / `TLS_AND_CERTIFICATES.md`.
3. **On test node:** deploy package/git pull, run `le-install-nginx-acme.sh`, re-issue if cert was standalone-only.

End of handoff file.
