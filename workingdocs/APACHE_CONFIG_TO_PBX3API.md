# Move HTTP config to pbx3api (nginx)

**Created:** 2025-02-07  
**Status:** Decision recorded. **Phase 2 (pbx3) applied:** pbx3 no longer installs Apache; package is backend-only (no apache2 in Depends; Depends include php-cli, php-sqlite3 for setip/installer). **Remaining:** pbx3api repo is still Apache-oriented (`.htaccess` only; no nginx config in repo). Next session: make pbx3api nginx-ready; update pbx3 fail2ban from apache log path to nginx. See AGENT_HANDOFF.md §9 and TODO.md.

**Decision: use nginx, drop Apache.** We standardise on **nginx** for the API (and any minimal site on port 80 for HTTP-01). nginx is easier to deploy and maintain; Apache is not carried forward.

---

## 1. Decision

**HTTP server (nginx) configuration for the API should live in the pbx3api repo/package, not in pbx3.**

- **pbx3** = backend only: Asterisk, DB, scripts, config generation. No HTTP requirements of its own. It may be driven by the API (pbx3api) today, or in future by some other mechanism (config management, GitOps, another control plane).
- **pbx3api** = the Laravel API and the HTTP layer that serves it. It "owns" `/opt/pbx3api`, DocumentRoot, SSL, and API-specific nginx config (PHP via PHP-FPM).

Keeping HTTP config in pbx3api gives clear functional separation and keeps pbx3 agnostic of how it is driven.

---

## 2. Rationale

| Reason | Notes |
|--------|--------|
| **Functional separation** | The HTTP server exists only to serve the API. DocumentRoot, `open_basedir`, SSL, and rewrites are all about pbx3api. |
| **Single owner** | pbx3api already owns `/opt/pbx3api` and its layout; owning the HTTP config that points at that tree is consistent. |
| **Future flexibility** | A future PBX3 might get all config from something other than the API (e.g. Ansible, Terraform, direct DB). In that case there is no API and no need for nginx on the pbx3 host. Keeping HTTP out of pbx3 leaves that option open. |
| **Easier evolution** | If we change ports/paths or server layout, only pbx3api's repo and package need to change. |

---

## 3. TLS / Let's Encrypt (certificate ownership)

**Decision: certificate acquisition and renewal (e.g. Let's Encrypt) are homed in pbx3, not pbx3api.**

There are **two consumers** of TLS on the host:

1. **nginx** – serves the API (pbx3api) over HTTPS (e.g. port 44300).
2. **Asterisk** – its built-in HTTP/HTTPS stack is used for WebRTC SIP (WSS) and SRTP.

One host certificate (e.g. Let's Encrypt for the host FQDN) should serve both. Asterisk config (http.conf, pjsip TLS) already lives in pbx3, so pbx3 is the natural place to own cert acquisition and renewal.

| Responsibility | Where |
|----------------|--------|
| **Acquire and renew cert** (certbot / ACME) | **pbx3** – install certbot, config, systemd timer or cron; cert lands in e.g. `/etc/letsencrypt/live/<fqdn>/`. |
| **Initial cert at install** | **pbx3** – installer must prompt for (or determine) the **domain name** (FQDN) for the cert and run the initial ACME challenge so Let's Encrypt is set up correctly; port 80 must be available for the challenge. Renewal then runs automatically (timer/cron). |
| **Port 80 for ACME HTTP-01** | **pbx3** – owns listening on 80 for the challenge (standalone or minimal webroot vhost); pbx3api does not use port 80. |
| **Post-renewal reload** | **pbx3** – deploy hook (or equivalent) reloads **both** `nginx` and `asterisk` so both pick up the new cert. |
| **Asterisk TLS config** | **pbx3** – point at the same cert paths (already in pbx3). |
| **nginx TLS config** | **pbx3api** – server config uses the **same** paths (e.g. `ssl_certificate` / `ssl_certificate_key` pointing at `/etc/letsencrypt/live/<fqdn>/`). pbx3api does **not** run certbot; it only references the paths. Optional fallback to snakeoil when no LE cert exists yet. |

So: pbx3 = "host" cert layer (acquire, renew, reload both services); pbx3api = nginx config that references those cert paths. pbx3api's docs should state that the cert is provided by pbx3 / the host.

---

**Port 80 and ACME HTTP-01:** Let's Encrypt (ACME) validates domain control via HTTP-01: the CA requests `http://<domain>/.well-known/acme-challenge/<token>` and the host must respond on **port 80**. **pbx3 owns port 80** for this purpose: it is the cert layer and must provide the ACME challenge response (so renewal works with or without pbx3api). Implementation options: (1) **certbot standalone** – certbot temporarily binds to 80 for the challenge (and stops whatever is on 80 if needed), then exits; or (2) **certbot webroot** – pbx3 adds a minimal nginx server block (or fragment) that listens on 80 and serves only `/.well-known/acme-challenge/` from a known webroot; certbot writes the challenge file there. Either way, port 80 is pbx3's responsibility, not pbx3api's.

**Wildcard domains:** We will use wildcard certs; e.g. we own pbx3.com and instances are of the form `{node}.pbx3.com`. Wildcard certs (e.g. `*.pbx3.com`) require the **DNS-01** challenge (CA validates via TXT record in DNS). **Preferred approach:** automate via our **domain name supplier's API** (certbot DNS plugin or equivalent) – looks good, and is straightforward to automate. The installer / cert flow should support DNS-01 with API credentials (e.g. from installer prompt or env); port 80 is not required for wildcard issuance. Capture the domain pattern (e.g. `{node}.pbx3.com`) and any API credentials needed for the supplier when the installer prompts for domain.

---

## 4. Scope

### 4.1 What moves to pbx3api

- **Apache site config**  
  - Equivalent of current `pbx3.conf`: VirtualHost for port 44300, DocumentRoot `/opt/pbx3api/public`, SSL (snakeoil or Let's Encrypt), `open_basedir`, Directory, etc.  
  - Any optional fragment (e.g. snakeoil cert paths) if still needed.  
- **Install-time behaviour**  
  - Ensure `/opt/pbx3api` and `public/` exist (or are created by Laravel deploy).  
  - Install site config into `/etc/apache2/sites-available/` (or equivalent).  
  - Add `Listen [::]:44300` to `ports.conf` if not present.  
  - Enable the API site; enable required modules (ssl, rewrite, etc.); (re)start Apache.  
- **Uninstall/cleanup**  
  - Remove or disable the API site and optionally the Listen line on purge/remove, so pbx3 package is not required to clean up nginx.

### 4.2 What stays in pbx3 (for now)

- **No Apache site config** – no `pbx3.conf`, no symlinks into `sites-available`/`sites-enabled` from pbx3.
- **No Apache-specific installer steps** – no a2ensite, no ports.conf edits, no creation of `/opt/pbx3api/public` or stub `index.php` for Apache's DocumentRoot.
- **Optional:** If pbx3 is ever installed without pbx3api, we may document "install pbx3 then pbx3api" and accept that Apache is brought up by pbx3api. No stub DocumentRoot in pbx3.

### 4.3 What is removed from pbx3

- **Files**
  - `opt/pbx3/etc/apache2/sites-available/pbx3.conf`
  - `opt/pbx3/etc/apache2/sites-available/snakeoil-certs.conf` (if present and only used by this site)
  - Any `opt/pbx3/etc/apache2/` include or fragment used only for this site (e.g. `pbx3_includes/pbx3ServerName.conf` if unused elsewhere).
- **Installer (installer.sh)**
  - Entire "deal with Apache" block: a2dissite default sites, rm sark/pbx3 site links, mkdir/ownership/stub for `/opt/pbx3api/public`, symlink pbx3.conf, a2ensite pbx3, ports.conf Listen 44300, systemctl enable/start apache2.
- **Debian package**
  - **prerm:** Remove steps that delete `/etc/apache2/sites-enabled/pbx3*` and `sites-available/pbx3*` (pbx3api's package will own that cleanup, or leave site in place if only pbx3 is removed).
  - **control:** Revisit whether `apache2`, `libapache2-mod-php`, and PHP extensions remain as direct dependencies of pbx3. If pbx3api depends on them, pbx3 might drop them so a "pbx3-only" host doesn't require nginx until pbx3api is installed. *(Decision point.)*

---

## 5. Work plan

**Execution order:** Phase 1 (pbx3api nginx) → Phase 2 (pbx3 remove Apache config and installer block) so pbx3api owns the API site before pbx3 drops it. Phase 4 (pbx3 TLS) can be done in parallel with 1–2 or after; it does not block the move. Phase 5 verifies everything.

**Summary – what needs to be done**

| Phase | Where | What |
|-------|--------|------|
| **1** | pbx3api | Add nginx server config for API (port 44300), install/enable site, PHP-FPM, cleanup on remove. Config uses LE cert paths when present. |
| **2** | pbx3 | Remove Apache config files and installer block; adjust prerm and control. |
| **4** | pbx3 | Certbot + DNS plugin; installer prompts (domain, DNS API credentials); initial ACME challenge (DNS-01); Asterisk TLS → LE paths; deploy hook (reload nginx + asterisk); renewal timer. |
| **5** | both | Test: HTTP move (nginx), then TLS (initial cert, both services use cert, renewal + deploy hook). |

---

### Phase 1 – pbx3api (add HTTP config and install logic)

1. **Add nginx config to pbx3api repo**
   - Use **workingdocs/nginx-api-site-reference.conf** in this repo as the starting point: server block for 44300, root `/opt/pbx3api/public`, SSL (snakeoil or LE paths), PHP-FPM, `open_basedir`. Copy into pbx3api (e.g. `config/nginx/pbx3-api.conf` or `debian/nginx/sites-available/`) and adapt paths/fastcgi_pass for the target system.
   - Optionally include snakeoil (or LE) cert paths in the same file or an include.

2. **Install and enable in pbx3api's install path**
   - See **workingdocs/PBX3API_INSTALLER_NGINX_ADDITIONS.md** for the full checklist. In short: create `/opt/pbx3api/public` if missing; copy or symlink the nginx site config into `/etc/nginx/sites-available/` and enable via `sites-enabled/`; enable and reload nginx and php-fpm.
   - Ensure nginx and php-fpm (and required PHP packages) are dependencies of the pbx3api package.

3. **Cleanup on remove/purge**
   - In prerm/postrm: remove the site symlink from `sites-enabled/`, reload nginx. On purge, remove `/opt/pbx3api` if desired.

4. **Document**
   - In pbx3api: document that this package installs and owns the nginx site for the API; port 44300; that pbx3 does not install HTTP server config.

### Phase 2 – pbx3 (remove HTTP config and related logic)

5. **Remove Apache config and includes from pbx3**
   - Delete (or stop shipping):
     - `pbx3-1/opt/pbx3/etc/apache2/sites-available/pbx3.conf`
     - `pbx3-1/opt/pbx3/etc/apache2/sites-available/snakeoil-certs.conf`
     - `pbx3-1/opt/pbx3/etc/apache2/pbx3_includes/` (if it only contained API-site includes and is now redundant).

6. **Strip Apache section from installer.sh**
   - Remove the full block from "# deal with Apache" through "systemctl start apache2.service" (including creation of `/opt/pbx3api/public` and stub index.php).
   - Optionally add a one-line comment: "Apache/API site is installed by pbx3api; see pbx3api docs."

7. **Adjust Debian package (pbx3)**
   - **prerm:** Remove the two lines that remove `sites-enabled/pbx3*` and `sites-available/pbx3*`. Optionally document that pbx3api's package is responsible for disabling/removing the site when pbx3api is removed.
   - **control:** Decide whether to keep Apache/PHP in `Depends`. With nginx, pbx3api will depend on nginx and php-fpm. Consider dropping from pbx3 so a host can install pbx3 without nginx until pbx3api is installed. If kept, document that the HTTP stack is required only when using the API.

8. **Update docs**
   - **pbx3:** In CLEANUP_PLAN, PBX3_CLEANUP_CONTEXT, and any install docs: state that nginx/HTTP config for the API lives in pbx3api; pbx3 does not install or own it.
   - **workingdocs:** Add a short "Applied" note at the top of this document once the work plan is done (date, branch, "HTTP config moved to pbx3api (nginx); Apache dropped; pbx3 installer and prerm updated.").

### Phase 4 – pbx3 (Let's Encrypt / TLS layer)

**Goal:** pbx3 owns certificate acquisition and renewal (wildcard via DNS-01 + domain supplier API), installer prompts for domain and credentials and runs the initial challenge, Asterisk and (via pbx3api) nginx use the same cert; renewals reload both services.

10. **Certbot and DNS-01 plugin**
    - Add certbot (and the DNS plugin for our domain supplier) as pbx3 package dependencies or installer requirements.
    - Document which DNS provider is used and which certbot plugin (e.g. certbot-dns-*); install that plugin so DNS-01 can be automated via API.

11. **Stored config for cert**
    - Persist the chosen domain (e.g. `node.pbx3.com` or wildcard `*.pbx3.com`) and any API credentials (or path to a secrets file) in a location certbot and the installer can read (e.g. under `/opt/pbx3/` or `/etc/pbx3/`). Credentials must not be in version control; use installer prompt or env vars and write to a local config only.

12. **Installer: domain and credentials prompt**
    - During installer run, prompt for:
      - **Domain** for this instance (e.g. `pbxnode1.pbx3.com`). Optionally support wildcard (e.g. `*.pbx3.com`) if one cert will cover multiple nodes.
      - **DNS API credentials** (or path to credentials file) for the domain supplier, so certbot can perform DNS-01 without manual TXT records.
    - Store these for use by certbot and by renewal (e.g. certbot config, or a small wrapper that reads from the stored config).

13. **Installer: initial ACME challenge**
    - After (or as part of) installer, run the initial cert request: certbot certonly (or equivalent) using DNS-01 with the supplied credentials. Target the domain (or wildcard) from the prompt. Cert lands in e.g. `/etc/letsencrypt/live/<name>/`.
    - If cert request fails (e.g. API error, rate limit), leave a clear message and optionally fall back to snakeoil until the user fixes and re-runs a cert script.

14. **Asterisk TLS config**
    - Ensure Asterisk config (http.conf, pjsip TLS, etc.) points at the Let's Encrypt cert paths (e.g. `/etc/letsencrypt/live/<fqdn>/fullchain.pem` and `privkey.pem`). Use the same domain/cert name stored in step 11. If no LE cert exists yet, keep existing or snakeoil fallback.
    - Reload or restart Asterisk after cert is in place so it picks up the new cert.

15. **pbx3api nginx config and cert paths**
    - pbx3api site config (Phase 1) should reference the same paths, e.g. `SSLCertificateFile /etc/letsencrypt/live/<fqdn>/fullchain.pem`, `SSLCertificateKeyFile .../privkey.pem`. Either use a symlink or a config that is generated/parameterised with the fqdn (e.g. by pbx3 installer writing a snippet, or pbx3api reading a well-known path that pbx3 sets). Fallback to snakeoil when no LE cert exists.

16. **Renewal (cron or systemd timer)**
    - Enable certbot renewal (e.g. `certbot renew` via systemd timer or cron). Use the same DNS-01 credentials (from stored config) so renewal is non-interactive.

17. **Deploy hook (post-renewal reload)**
    - Certbot deploy hook (e.g. `/etc/letsencrypt/renewal-hooks/deploy/*`) or a script called by it must:
      - Reload `nginx` (so the API site picks up the new cert).
      - Reload or restart `asterisk` (so WebRTC/SRTP pick up the new cert).
    - Install this hook from the pbx3 package or installer.

18. **Port 80 (optional for this setup)**
    - For **wildcard-only** (DNS-01), port 80 is not required for issuance or renewal. If we later support single-name certs with HTTP-01, add a minimal nginx server block on 80 for `/.well-known/acme-challenge/` (pbx3-owned) or use certbot standalone; document in installer.

19. **Docs and Open points**
    - Document in pbx3: how to re-run cert request if initial run failed; where credentials are stored; that pbx3api and Asterisk both use the same cert. Update Open points (section 6) as decisions are made (e.g. exact credential storage, which DNS plugin).

### Phase 5 – Verification

20. **Test Apache move (Phases 1–2)**
   - Install pbx3 only: no Apache site for 44300; no DocumentRoot creation by pbx3.
   - Install pbx3 then pbx3api: Apache serves API on 44300; DocumentRoot is pbx3api's.
   - Remove pbx3api: site disabled/removed by pbx3api's prerm/postrm.
   - Remove pbx3: no Apache cleanup required from pbx3.

21. **Test TLS (Phase 4)**
   - Run installer with domain and DNS API credentials; confirm initial cert is issued and lands under `/etc/letsencrypt/live/`.
   - Confirm Asterisk and nginx (pbx3api site) both use the new cert (e.g. test HTTPS to API, test WSS/SRTP to Asterisk).
   - Trigger a renewal (or dry-run) and confirm deploy hook reloads nginx and asterisk; confirm both still serve with the (renewed) cert.

---

## 6. Open points

- **pbx3 Depends:** Keep `apache2` and PHP in pbx3's `Depends` (simpler for "single-server API + backend" installs) or drop them and let pbx3api bring them in (cleaner "pbx3-only" host). Decide in Phase 2.
- **Listen 44300:** If both packages might run on the same host, only one should add/remove the Listen line (pbx3api is the natural owner).
- **ServerName / includes:** Current pbx3 has `pbx3_includes/pbx3ServerName.conf` (e.g. `ServerName pbx3.local`). If needed, move that into the single site config in pbx3api or document where to set it.
- **Wildcard / DNS-01:** Covered by Phase 4 (DNS-01 via domain supplier API); see §3 wildcard paragraph for decision.
- **pbx3 Let's Encrypt:** pbx3 needs to add certbot (or equivalent), config, ownership of port 80 for ACME (standalone or minimal webroot vhost), installer step to prompt for domain and run the initial ACME challenge, and a renew/deploy hook that reloads both `nginx` and `asterisk`. Asterisk TLS config (http.conf, pjsip) must point at the same cert paths. Full task list is Phase 4 (steps 10–19). Open: exact credential storage path, which certbot DNS plugin for our supplier.

---

## 7. References

- **CLEANUP_PLAN.md** – Phase D (HTTP server hosts API); Phase F (installer).
- **PBX3_CLEANUP_CONTEXT.md** – "HTTP server on pbx3 host hosts the API (pbx3api)."
- Current Apache config (to be replaced by pbx3api nginx): `pbx3-1/opt/pbx3/etc/apache2/sites-available/pbx3.conf`.
- Current installer Apache block (to be removed): `pbx3-1/opt/pbx3/scripts/installer.sh` (lines ~58–108).
