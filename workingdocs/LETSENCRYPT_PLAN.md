# Let's Encrypt implementation plan (pbx3 backend)

**Status:** Plan for cleanup Phase 4. Complements **APACHE_CONFIG_TO_PBX3API.md** §3 (TLS ownership) and §5 Phase 4.

**Ownership:** pbx3 acquires and renews the host certificate. Same cert is used by **Asterisk** (WSS/TLS) and **nginx** (pbx3api, port 44300). pbx3api only references the cert paths; it does not run certbot.

---

## 1. Goals

- **Wildcard** Let's Encrypt certificate (e.g. `*.pbx3.com` + `pbx3.com`) so any node (e.g. `node1.pbx3.com`) can use the same cert pattern. On a **multi-tenant** instance, the same cert is valid for the instance hostname and all tenant hostnames (tenant1.pbx3.com, tenant2.pbx3.com, …) as long as they are single-level subdomains. **Tenant mobility:** Tenants can be moved between nodes (instances) for load and failover; because every node obtains its own wildcard cert covering `*.pbx3.com`, a tenant’s hostname remains valid on whichever node it is moved to—no cert migration when moving tenants.
- Cert lives under `/etc/letsencrypt/live/<domain>/` (certbot layout; `<domain>` is the cert name, e.g. `pbx3.com` for `-d '*.pbx3.com' -d 'pbx3.com'`).
- Asterisk and nginx both use that cert; after renewal, both are reloaded.
- Installer obtains the first cert: prompt only for the **instance FQDN** (e.g. `node1.pbx3.com`); we derive the cert domain from it (e.g. `pbx3.com`) and request the wildcard (`*.pbx3.com` + `pbx3.com`). Also prompt for Name.com credentials and LE email. Renewal is automatic (timer + deploy hook).
- **Port 80 is not required** for wildcard (DNS-01 challenge only).

---

## 2. Wildcard = DNS-01 only

| Item | Choice |
|------|--------|
| **Challenge** | **DNS-01** only (wildcard certs require it). |
| **Port 80** | Not used for ACME; no need for pbx3 to own or listen on 80 for cert issuance/renewal. |
| **Automation** | certbot + a **certbot-dns-&lt;provider&gt;** plugin (e.g. Cloudflare, Route53, OVH). Plugin uses the provider’s API to create/delete the TXT record for the challenge. |
| **Credentials** | DNS API token or key/secret stored in a file (e.g. `/opt/pbx3/etc/le-dns-credentials.ini` or under `/etc/pbx3/`) with mode 0600; installer prompts for path or values and writes the file. Never commit to git. |

---

## 2b. Name.com as DNS provider

**Current choice: Name.com.** We use Name.com for DNS; subdomains (node1.pbx3.com, node2.pbx3.com, …) are free. Wildcard certs require DNS-01; Name.com supports this via API (username + API token from account settings).

**Credentials:** From Name.com → Account → API Access: create an API token. We need **username** and **API token** (not password). Store in `/opt/pbx3/etc/le-dns-credentials.ini` (mode 0600), e.g.:
- For **lego:** `NAMECOM_USERNAME=...` and `NAMECOM_API_TOKEN=...` (or export as env vars).
- For **certbot hooks:** `NAME_USERNAME=...` and `NAME_API_TOKEN=...` (or equivalent; hook scripts read these to call Name.com API).

**Two ways to run ACME with Name.com:**

| Approach | Pros | Cons |
|----------|------|------|
| **Certbot + manual DNS hooks** | Cert layout is standard `/etc/letsencrypt/live/<domain>/`; `certbot.timer` handles renewal; no new binary. | No official certbot Name.com plugin in Debian/Ubuntu; we maintain two small scripts (auth + cleanup) that call Name.com API (curl + jq) to create/delete `_acme-challenge.<domain>` TXT. |
| **Lego** | Native Name.com support (`--dns namedotcom`), no hooks. Single binary, well maintained. | Writes certs to `.lego/certificates/` (e.g. `_.domain.crt`, `_.domain.key`); we need a timer (no certbot.timer) and either point Asterisk/nginx at lego paths or copy/symlink into `/etc/letsencrypt/live/<domain>/` so the rest of the plan stays unchanged. |

**Recommendation:** Use **lego** for Name.com: no hook scripting, native support, credentials are just two env vars. Add a small wrapper or systemd timer that runs lego, then copies or symlinks `_.<domain>.crt` / `_.<domain>.key` to `/etc/letsencrypt/live/<domain>/fullchain.pem` and `privkey.pem` so Asterisk and nginx config stays the same. Alternatively, use **certbot + auth/cleanup hooks** if you prefer to keep certbot and its timer; hooks call Name.com API to set/remove the TXT record.

**Changing DNS provider later:** If we move to Cloudflare, Route53, etc., we’d switch to that provider’s certbot plugin or lego provider; credential format and installer prompts would change; cert paths and deploy/reload logic stay the same.

---

## 3. Cert paths and consumers

- **Cert dir:** `/etc/letsencrypt/live/<domain>/` (e.g. `pbx3.com` for wildcard `*.pbx3.com` + `pbx3.com`).  
  - `fullchain.pem`, `privkey.pem`  
- **Persist domain:** Store the **derived** cert domain (e.g. `pbx3.com`) in `/opt/pbx3/etc/identity/le-domain` so Asterisk/nginx and renewal use the same path. Optionally persist the instance FQDN (e.g. `node1.pbx3.com`) for server_name / Asterisk if not already in DB (e.g. `globals.fqdn`).  
- **Asterisk** (pbx3): http.conf and pjsip TLS → LE paths when cert exists; else snakeoil.  
- **nginx** (pbx3api): 44300 server block uses LE paths when present; fallback snakeoil.  
- **Permissions:** Ensure `asterisk` and `www-data` can read LE certs (certbot default dir permissions or a deploy-hook step).

---

## 5. Deploy hook (post-renewal)

- When certbot renews a cert, it should run a **deploy hook** that:
  1. Reload **nginx** (e.g. `systemctl reload nginx`) so it picks up the new cert.
  2. Reload **Asterisk** (e.g. `asterisk -rx 'core reload'` or reload http/pjsip as appropriate) so it picks up the new cert.
- Hook location: certbot’s `--deploy-hook` or drop a script in `/etc/letsencrypt/renewal-hooks/deploy/` (e.g. `reload-pbx3-services.sh`).  
- Script should be idempotent and safe (only reload, no restart of unrelated services).

---

## 6. Installer integration (wildcard)

- **Prompt for (only these):**  
  - **Instance FQDN** (e.g. `node1.pbx3.com`) – the hostname for this PBX3 instance. We use it to **derive** the cert domain: strip the first label → `pbx3.com`. The wildcard cert will be requested for `*.pbx3.com` and `pbx3.com`, which covers this instance and all tenant hostnames (tenant1.pbx3.com, etc.).  
  - **Name.com credentials** – username and API token (Name.com → Account → API Access). Write to `/opt/pbx3/etc/le-dns-credentials.ini` (mode 0600).  
  - **Email** for Let's Encrypt (recommended).  
- **Derive domain:** From instance FQDN (e.g. `node1.pbx3.com`) set `domain=pbx3.com` (everything after the first dot). Request cert for `-d '*.<domain>' -d '<domain>'`.  
- **Run:** **Lego:** `lego --dns namedotcom -d '*.domain' -d 'domain' --email <email> run`; then copy/symlink certs to `/etc/letsencrypt/live/<domain>/`. **Certbot:** same `-d` with manual hooks.  
- **Persist:** Write derived `<domain>` to `/opt/pbx3/etc/identity/le-domain`. Optionally write instance FQDN to identity or DB for nginx/Asterisk.  
- **After first cert:** Point Asterisk and (via doc) pbx3api nginx at LE paths; install reload script; enable renewal.

---

## 7. Package and dependencies (Name.com)

- **Option A – Lego:** Add **lego** (ACME client with native Name.com support) to Depends. No certbot. Lego is available as a single binary; on Debian/Ubuntu install from [lego releases](https://github.com/go-acme/lego/releases) or a PPA/package if available; or vendor the binary. Renewal: systemd timer that runs lego (renew), then copies/symlinks certs to `/etc/letsencrypt/live/<domain>/` and runs the reload script.
- **Option B – Certbot + hooks:** Add **certbot** to Depends. No Name.com plugin in distro; use `certbot certonly --manual --preferred-challenges dns --manual-auth-hook ./name-auth.sh --manual-cleanup-hook ./name-cleanup.sh -d '*.domain' -d 'domain'`. Ship two scripts that read `NAME_USERNAME` and `NAME_API_TOKEN` and call Name.com API (curl + jq) to create/delete the `_acme-challenge.<domain>` TXT record. Certbot writes to `/etc/letsencrypt/live/<domain>/`; use certbot.timer for renewal.
- **Credentials file:** Same for both: `/opt/pbx3/etc/le-dns-credentials.ini` with `NAMECOM_USERNAME` and `NAMECOM_API_TOKEN` (lego) or `NAME_USERNAME` and `NAME_API_TOKEN` (hooks). Mode 0600.

---

## 8. Suggested implementation order

1. **Certbot + DNS plugin and timer**  
   - Add certbot and certbot-dns-&lt;provider&gt; to package; ensure certbot.timer is enabled.  
   - Manually test: create credentials file, run `certbot certonly --dns-<provider> ... -d '*.domain' -d 'domain'`; run `certbot renew --dry-run`.

2. **Credentials path and format**  
   - Define where installer writes DNS API credentials (e.g. `/opt/pbx3/etc/le-dns-credentials.ini`) and the format (per certbot plugin; e.g. `dns_cloudflare_api_token = ...`). Document in installer or LETSENCRYPT_PLAN.

3. **Deploy hook**  
   - Script in `/etc/letsencrypt/renewal-hooks/deploy/` that reloads nginx and Asterisk. Read domain from `/opt/pbx3/etc/identity/le-domain` if needed for logic.

4. **Asterisk TLS config**  
   - When LE cert exists at `/etc/letsencrypt/live/<domain>/`, point http.conf and pjsip at it; else snakeoil.

5. **Installer: domain + credentials + initial cert**  
   - Prompt for domain, DNS credentials (or path), and LE email; write credentials file; run certonly (DNS plugin); persist domain to `le-domain`; update Asterisk paths.

6. **pbx3api nginx**  
   - Nginx 44300 config uses LE paths when present (path from `le-domain` or fixed convention); fallback snakeoil.

---

## 9. Multi-server deployment (server #2, #3, …)

**Same wildcard, many servers:** The cert for `*.pbx3.com` (and `pbx3.com`) is valid for **any** hostname under that domain: node1.pbx3.com, node2.pbx3.com, node3.pbx3.com, etc. So yes – conceptually they all “use the same cert” (same names in the cert). How each server gets that cert is a deployment choice.

### Option A: Certbot on every server — **chosen**

- **Deploy server #2, #3, …** the same way as server #1: install pbx3, run the installer, and when prompted give the **same domain** (e.g. `pbx3.com`) and **same DNS API credentials** (or the same credentials file).
- Each server runs certbot (via installer or manually) and gets its **own** certificate from Let’s Encrypt – same SANs (`*.pbx3.com`, `pbx3.com`), possibly different serial number and key pair. LE allows multiple certs for the same names.
- **No key distribution:** each machine keeps its own private key; you never copy keys between servers.
- **Renewal:** each server runs certbot.timer and renews itself; deploy hook on each reloads local nginx and Asterisk.
- **Credentials:** each server needs the DNS API credentials (e.g. copy `le-dns-credentials.ini` from server #1, or re-enter / paste when running the installer on #2, #3). Optionally pull credentials from a central secrets store (vault, env, etc.) instead of storing a file on every node.
- **DNS:** Our DNS provider allows as many subdomains as we need (node1.pbx3.com, node2.pbx3.com, …). The wildcard cert covers all of them; no extra DNS setup per node beyond the initial API credentials for the domain.

**Summary:** Same installer flow on every server; same domain and DNS credentials; each server ends up with a valid wildcard cert and no shared private keys.

### Option B: One “cert server”, distribute to the rest

- One machine (e.g. server #1 or a dedicated cert host) runs certbot and obtains the wildcard cert. The cert and **private key** are then copied to every other server (e.g. via Ansible, a secure copy, or a secrets store) into `/etc/letsencrypt/live/<domain>/` (or a symlink layout so Asterisk/nginx still find them).
- **Same cert and same key** on all servers. Renewal runs only on the cert server; after renewal, the new fullchain.pem and privkey.pem must be pushed to all other servers and nginx/Asterisk reloaded there (e.g. by a script or Ansible).
- **Pros:** Single place to renew; one cert, one key. **Cons:** Key distribution and post-renewal sync must be secure and automated; more moving parts.

**Summary:** Use if you want a single source of truth for the cert and are willing to manage secure distribution and reload on every node.

### Decision

- **Option A (certbot on every server)** is the chosen approach. Deploy server #2, #3, … by running the same installer with the same domain and DNS API credentials; each gets its own LE-issued wildcard cert. Document in the installer or handoff: “For additional servers, run the installer on each; use the same domain and DNS API credentials.”

---

## 10. Security notes

- Do not commit API credentials or real FQDN secrets to the repo.  
- Store DNS API credentials in a file with mode 0600 (or 0640 with a dedicated group) and readable only by root/certbot.  
- Deploy hook runs as root; keep it minimal (reload only).

---

## 11. Work steps (implementation checklist)

Concrete changes to make wildcard LE work (Option A). Order is implementation order.

### Package (pbx3-1)

| Step | What | Where / action |
|------|------|----------------|
| **11.1** | ACME client and renewal (Name.com) | **Lego path:** Add **lego** to Depends (install binary or package). No certbot. Renewal: systemd timer runs lego, then script copies/symlinks certs from lego output (e.g. `./.lego/certificates/_.<domain>.crt` → `fullchain.pem`) into `/etc/letsencrypt/live/<domain>/` and runs reload script. **Certbot path:** Add **certbot** to Depends; ship auth + cleanup hook scripts that call Name.com API (curl + jq) using `NAME_USERNAME` and `NAME_API_TOKEN`; certbot --manual --preferred-challenges dns; use certbot.timer for renewal. |
| **11.2** | Deploy-hook / reload script (reload nginx + Asterisk) | New file `opt/pbx3/scripts/le-reload-services.sh`: read domain from `/opt/pbx3/etc/identity/le-domain`; optionally chmod so `asterisk`/`www-data` can read cert dir; `systemctl reload nginx`; `asterisk -rx 'core reload'`. For **certbot**: installer copies this into `/etc/letsencrypt/renewal-hooks/deploy/`. For **lego**: timer or lego post-hook runs this after copying certs. |
| **11.3** | Identity dir for le-domain | Ensure `opt/pbx3/etc/identity/` exists in package (e.g. keep existing instance-id/domain-id layout). Installer will write `le-domain` here after first cert. |
| **11.4** | Credentials path | Installer will write DNS API credentials to `/opt/pbx3/etc/le-dns-credentials.ini` (mode 0600). Ensure `opt/pbx3/etc/` exists; add `le-dns-credentials.ini` to .gitignore or ensure it is never shipped. |

### Asterisk TLS (use LE when present)

| Step | What | Where / action |
|------|------|----------------|
| **11.5** | Script to switch Asterisk to LE paths | New script `opt/pbx3/scripts/update-asterisk-le-certs.sh`: if `/opt/pbx3/etc/identity/le-domain` exists and `/etc/letsencrypt/live/$(cat le-domain)/fullchain.pem` exists, rewrite `http.conf` and `pjsip_transport.conf` (in place or under `opt/pbx3/etc/asterisk/configs/` then copy to Asterisk dir) to use that cert and privkey; else leave or restore snakeoil. Call this after certbot certonly in installer, and from deploy hook after reload. |
| **11.6** | Or: installer inline | Alternatively, installer (and deploy hook) directly sed/writes `tlscertfile` / `tlsprivatekey` and pjsip `cert_file` / `priv_key_file` to LE paths when cert exists, without a separate script. Same effect; script is easier to reuse. |

### Installer (installer.sh)

| Step | What | Where / action |
|------|------|----------------|
| **11.7** | LE block in installer (Name.com) | New section in `opt/pbx3/scripts/installer.sh`: prompt for **instance FQDN only** (e.g. `node1.pbx3.com`); derive cert domain (strip first label → e.g. `pbx3.com`). Prompt for Name.com username and API token; write `/opt/pbx3/etc/le-dns-credentials.ini`; prompt for LE email. Run lego (or certbot with hooks) for `-d '*.<domain>' -d '<domain>'`; copy/symlink certs to `/etc/letsencrypt/live/<domain>/`. On success write derived `<domain>` to `/opt/pbx3/etc/identity/le-domain`. No separate “domain” prompt – instance FQDN is enough to get the wildcard cert. |
| **11.8** | After cert: Asterisk + reload hook + timer | Run `update-asterisk-le-certs.sh` so Asterisk uses LE; install reload script (certbot: copy to `/etc/letsencrypt/renewal-hooks/deploy/`; lego: ensure timer runs it after lego). Enable renewal: **certbot** `systemctl enable --now certbot.timer`; **lego** systemd timer (e.g. monthly) that runs lego renew, copies certs, then reload script. Reload nginx and Asterisk once. |
| **11.9** | Permissions for LE certs | In deploy hook or once in installer: ensure `asterisk` (and `www-data` if nginx reads LE) can read certs (e.g. `chmod -R o+rX /etc/letsencrypt/archive/<domain>/` or add group; certbot default is root-only). |
| **11.10** | Optional / skip LE | If no domain or credentials provided, skip certbot and leave Asterisk/nginx on snakeoil; document that user can run certbot and the update script later. |

### pbx3api (separate repo)

| Step | What | Where / action |
|------|------|----------------|
| **11.11** | Nginx use LE when present | In pbx3api nginx site for 44300: if `/opt/pbx3/etc/identity/le-domain` exists, set `ssl_certificate` / `ssl_certificate_key` to `/etc/letsencrypt/live/$(cat le-domain)/fullchain.pem` and `.../privkey.pem` (e.g. via include or map); else use snakeoil. So pbx3api does not run certbot; it only reads the path. |

### Documentation

| Step | What | Where / action |
|------|------|----------------|
| **11.12** | Document LE and multi-server | In AGENT_HANDOFF or package README: “Let’s Encrypt wildcard: installer prompts for **instance FQDN** (e.g. node1.pbx3.com) and Name.com username + API token; we derive the cert domain and request *.domain. For server #2, #3, … run the same installer with that server’s instance FQDN (e.g. node2.pbx3.com) and the same Name.com credentials.” Credential file: `NAMECOM_USERNAME`, `NAMECOM_API_TOKEN`. Certs valid 90 days; renewal automated. |

---

## 12. References

- **APACHE_CONFIG_TO_PBX3API.md** – TLS ownership, Phase 4 summary.  
- **AGENT_HANDOFF.md** – Current layout, paths, installer.  
- **Name.com:** API token from Account → API Access; DNS-01 via API (TXT record for `_acme-challenge.<domain>`).  
- **Lego (Name.com):** [lego DNS namedotcom](https://go-acme.github.io/lego/dns/namedotcom/) – `NAMECOM_USERNAME`, `NAMECOM_API_TOKEN`; `lego --dns namedotcom -d '*.domain' -d 'domain' run`.  
- **Certbot manual hooks:** [Certbot Name.com DNS challenge hooks](https://hjr265.me/blog/certbot-name-com-dns-challenge-hooks/) – auth/cleanup scripts + `NAME_USERNAME` / `NAME_API_TOKEN`.
