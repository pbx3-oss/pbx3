# Let's Encrypt implementation plan (pbx3 backend)

**Status:** Plan for cleanup Phase 4. Complements **APACHE_CONFIG_TO_PBX3API.md** §3 (TLS ownership) and §5 Phase 4.

**Ownership:** pbx3 acquires and renews the host certificate. Same cert is used by **Asterisk** (WSS/TLS) and **nginx** (pbx3api, port 44300). pbx3api only references the cert paths; it does not run certbot.

---

## 1. Goals

- **Individual cert per hostname** (no wildcards). One Let's Encrypt certificate for **this** host's FQDN only (e.g. `myhost.mydomain.com`). Each server has its own FQDN and gets its own cert via HTTP-01; no cert sharing or distribution.
- Cert lives under `/etc/letsencrypt/live/<fqdn>/` (certbot layout; `<fqdn>` is the hostname, e.g. `myhost.mydomain.com`).
- Asterisk and nginx both use that cert; after renewal, both are reloaded.
- Installer obtains the first cert: prompt for **this host's FQDN** and **LE email**. Run certbot or lego with **HTTP-01** (port 80 reachable during issuance/renewal only). No DNS API. Renewal is automatic (timer + deploy hook).
- **Port 80** is required only **during** the ACME HTTP-01 challenge. Can be closed the rest of the time.

---

## 2. Individual cert = HTTP-01

| Item | Choice |
|------|--------|
| **Challenge** | **HTTP-01** (serve token at `http://<fqdn>/.well-known/acme-challenge/<token>`). |
| **Port 80** | Required only during issuance/renewal. **We control it:** `le-renew-with-80.sh` opens 80, runs certbot renew, closes 80 (Shorewall; managed rule only). Cron twice daily + "Renew now" use this script. |
| **DNS** | One **A record** for this host's FQDN pointing to this server. No TXT, no DNS API. |
| **Credentials** | None. No DNS API file. Only LE email for expiry notices. |

---

## 2b. DNS requirement (no API)

**No DNS API.** User creates one **A record** (and optionally AAAA) for this host's FQDN pointing to this server's IP, before running the installer or first renewal. Nothing else on the DNS side.


---

## 3. Cert paths and consumers

- **Cert dir:** `/etc/letsencrypt/live/<fqdn>/` (e.g. `myhost.mydomain.com`).  
  - `fullchain.pem`, `privkey.pem`  
- **Persist FQDN:** Store this host's FQDN in `/opt/pbx3/etc/identity/le-domain` so Asterisk/nginx and renewal use the same path.  
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

**Port 80 control:** We open port 80 only for the duration of issuance or renewal. Scripts under `/opt/pbx3/scripts/`:
- **le-port80-open.sh** — Adds a Shorewall rule for port 80 (IPv4 and IPv6) marked `# LE renewal (managed)`, then restarts Shorewall. Idempotent.
- **le-port80-close.sh** — Removes that managed rule and restarts Shorewall.
- **le-first-cert.sh** — First-time issuance: open 80 → certbot certonly --standalone -d &lt;fqdn&gt; -m &lt;email&gt; → write le-domain → apply-active-cert → close 80. Called by POST `/certificates/letsencrypt/setup` (Certificates panel "Get certificate"). Port 80 must be free for certbot --standalone.
- **le-renew-with-80.sh** — Runs open → certbot renew --deploy-hook apply-active-cert.sh → close; trap ensures close runs on exit. Used by POST `/certificates/letsencrypt/renew` and by cron (twice daily at 03:15 and 15:15, only if `le-domain` exists). For "Renew now" and setup, set `PBX3_SYSCMD_TIMEOUT` ≥ 90 so the request does not time out.

---

## 6. First-time setup (Certificates panel or installer)

- **Primary: Certificates panel.** User goes to Certificates, enters **this host's FQDN** and **LE email**, clicks "Get certificate". API POST `/certificates/letsencrypt/setup` runs `le-first-cert.sh <fqdn> <email>`: open port 80, `certbot certonly --standalone -d <fqdn> -m <email> --agree-tos --non-interactive`, write FQDN to `le-domain`, run apply-active-cert.sh, close 80. No DNS API; user must have an A record for the FQDN pointing to this server before clicking.
- **Optional: Installer.** Installer can also prompt for FQDN and LE email and run the same logic (or call `le-first-cert.sh`) so LE is configured at install time.
- **Script:** `le-first-cert.sh` (in `/opt/pbx3/scripts/`) takes two args: FQDN and email. Uses certbot --standalone (port 80 must be free for the run). After first cert, renewal is automatic (cron + "Renew now").

---

## 7. Package and dependencies (HTTP-01)

- **Certbot** (recommended): Add **certbot** to Depends. Use `certbot certonly --webroot` or `--standalone` for initial cert. **Renewal:** `le-renew-with-80.sh` (opens port 80, certbot renew, closes 80); cron runs it twice daily; "Renew now" calls it. Deploy hook apply-active-cert.sh reloads nginx + Asterisk.
- **Lego:** Alternative single-binary ACME client: `lego --http -d <fqdn> run`; certs go to `.lego/certificates/` — copy or symlink to `/etc/letsencrypt/live/<fqdn>/` for consistent paths. Systemd timer for renewal.
- **No credentials file** for DNS; no Name.com or other DNS API.

---

## 8. Suggested implementation order

1. **Certbot (or lego) + HTTP-01**  
   - Add certbot to Depends. Use `certbot certonly --webroot` or `--standalone` for one FQDN. Renewal: `le-renew-with-80.sh` (opens 80, certbot renew, closes 80); cron at 03:15 and 15:15; API "Renew now" invokes same script. No certbot.timer; we control port 80.

2. **Deploy hook**  
   - Script (e.g. apply-active-cert.sh) that reloads nginx and Asterisk. Read FQDN from `/opt/pbx3/etc/identity/le-domain`.

3. **Asterisk TLS config**  
   - When LE cert exists at `/etc/letsencrypt/live/<fqdn>/`, point http.conf and pjsip at it; else snakeoil.

4. **First cert: Certificates panel (or installer)**  
   - Panel: user enters FQDN + email, "Get certificate" → POST setup → `le-first-cert.sh`. Installer can optionally do the same. Persist FQDN to `le-domain`; run apply-active-cert.sh after issuance.

5. **pbx3api nginx**  
   - Nginx 44300 config uses LE paths when present (path from `le-domain`); fallback snakeoil.

---

## 9. Multi-server deployment (server #2, #3, …)

**Individual cert per server:** Each server has its own FQDN and gets its own cert via HTTP-01. No wildcard. (Obsolete text below referred to wildcard.) The cert for `*.pbx3.com` (and `pbx3.com`) is valid for **any** hostname under that domain: node1.pbx3.com, node2.pbx3.com, node3.pbx3.com, etc. So yes – conceptually they all “use the same cert” (same names in the cert). How each server gets that cert is a deployment choice.

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
