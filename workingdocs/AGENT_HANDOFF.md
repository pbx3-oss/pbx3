# Agent handoff – pbx3 (backend)

**Purpose:** Get a new agent up to speed on the pbx3 repo and recent work. Read this first, then dive into specific workingdocs as needed.

---

## Workspace layout (where to commit)

**pbx3-master** is **not** a git repo. It is a **holding folder** for the repos inside it: **pbx3**, **pbx3api**, **pbx3cagi**, **pbx3spa**. Always run `git` (status, add, commit, etc.) from inside the relevant repo, e.g. `pbx3-master/pbx3` or `pbx3-master/pbx3api`.

---

## 1. What this repo is

**pbx3** = backend-only worker for an Asterisk-based PBX: SQLite DB, Asterisk config generation, scripts, shorewall/fail2ban, setip (network detection). **No HTTP server** – API/HTTP is provided by **pbx3api** (nginx + PHP-FPM). Target: Ubuntu 24.04 LTS.

- **Package content** lives under **`pbx3-1/`** (what gets installed into `/opt/pbx3`, `/etc`, etc.).
- **Workingdocs** (design, decisions, checklists) are in **`workingdocs/`**.
- **Branch in use:** `main` (cleanup merged).

---

## 2. Current state (recent work completed)

- **Backend-only:** Apache and HTTP config removed from pbx3. HTTP/API is pbx3api’s responsibility (see `APACHE_CONFIG_TO_PBX3API.md`).
- **pbx3api nginx installer path is now implemented and tested:** On Ubuntu 24.04, fresh-clone installer flow was validated end-to-end (nginx + php8.3-fpm + Laravel bootstrap + PBX sqlite link). Frontend login to API works in LAN HTTP dev mode; see TODO for HTTPS/LE completion pass.
- **setip:** No longer a systemd service. Installer runs `php/utilities/setip.php` **once** directly; `debsetlan.service` was removed from the package. Installer also disables/removes the unit if present. Package Depends: **php-cli**, **php-sqlite3** so setip and installer can run.
- **Installer** runs manually (`sudo /opt/pbx3/scripts/installer.sh`), **not** from postinst. Script is written to work under **sh** (dash) or bash (POSIX case/printf; no `[[` or `read -p`). Fixes and behaviour:
  - **Instance FQDN:** Prompts for instance FQDN (e.g. node1.pbx3.com) or uses `INSTANCE_FQDN` env; stores in `globals.fqdn`; sets hostname to 3LD (e.g. node1) via hostnamectl or fallback; updates `/etc/hosts` so `127.0.1.1` points to the new hostname.
  - **db_database_dumps:** `reloader.sh` does `mkdir -p "$DBDUMPS"` before copying DB to `last.db`.
  - **sqlite_sequence:** Removed from `sqlite_create_laravel.sql` (reserved by SQLite).
  - **Shorewall:** Shipped `pbx3_inline_fqdn` is comment-only; API/NetHelper overwrites when fqdninspect enabled.
  - **CDR MySQL:** Installer uses `mysql -u root --socket=...` for socket auth.
  - **Shorewall6:** Installer runs `mkdir -p /etc/shorewall6` when templates exist so the service can start even if the package didn’t create the dir.
  - **generator:** Removed; Asterisk config generation scripts live in `php/utilities/` (runAstGen.php, etc.).
- **genbashconfig.php** in installer is optional (run only if `php` is available).
- **setip.php:** dpkg-query and `/etc/issue` use **CODENAME** (pbx3), not SYSPREFIX (/pbx3).

---

## 3. Key paths (under pbx3-1 or opt/pbx3)

| What | Path |
|------|------|
| Installer | `pbx3-1/opt/pbx3/scripts/installer.sh` |
| Reloader (DB rebuild) | `pbx3-1/opt/pbx3/scripts/reloader.sh` |
| setip (network/shorewall/asterisk) | `pbx3-1/opt/pbx3/php/utilities/setip.php` (run once by installer; no systemd unit) |
| Path/config source of truth | `pbx3-1/opt/pbx3/php/config.php` → `scripts/bashconfig` (via genbashconfig.php) |
| Shorewall6 templates | `pbx3-1/opt/pbx3/etc/shorewall6/` (installer creates /etc/shorewall6 if missing) |
| Debian packaging | `pbx3-1/debian/` (control, postinst, prerm, rules) |
| SQL schemas | `pbx3-1/opt/pbx3/db/db_sql/` (instance, laravel, tenant, message) |
| Shorewall templates | `pbx3-1/opt/pbx3/etc/shorewall/` |
| Asterisk configs/templates | `pbx3-1/opt/pbx3/etc/asterisk/` |

---

## 4. Build and install

- Build the .deb from the **pbx3** repo (e.g. `dpkg-buildpackage` or project’s build script). Package files are under `pbx3-1/`.
- Install: `apt install ./pbx3_*.deb` (or equivalent).
- After install, run **once:** `sudo /opt/pbx3/scripts/installer.sh` (idempotent; prompts for **instance FQDN** or use `INSTANCE_FQDN=node1.pbx3.com`; stores in globals.fqdn, sets hostname and `/etc/hosts` 127.0.1.1; runs setip once; creates DB, shorewall, shorewall6 dir if needed, CDR MySQL, etc.). Works when invoked as `sh installer.sh` or `./installer.sh`.

---

## 5. Design decisions (summary)

- **pbx3 = backend only.** No Apache/nginx in this package; pbx3api owns nginx and the API.
- **TLS / Let’s Encrypt:** Cert acquisition and renewal live in **pbx3** (certbot, paths); both Asterisk and nginx (pbx3api) use the same cert paths. Details: `APACHE_CONFIG_TO_PBX3API.md`.
- **postinst** only writes `/opt/pbx3/.install-date`; it does **not** run the installer.
- **PHP:** Package depends on **php-cli** and **php-sqlite3** for setip and optional installer steps. See `PHP_SCRIPTS_AND_MODULES.md` for all PHP scripts and modules.

---

## 6. Workingdocs index

| File | Use when |
|------|----------|
| **APACHE_CONFIG_TO_PBX3API.md** | HTTP vs backend split, TLS/LE ownership, nginx in pbx3api, phases |
| **LETSENCRYPT_PLAN.md** | Let's Encrypt: HTTP-01 vs DNS-01, port 80, deploy hook, installer, Asterisk/nginx paths, implementation order |
| **PBX3API_INSTALLER_NGINX_ADDITIONS.md** | What pbx3api installer needs to add (nginx, site config) |
| **nginx-api-site-reference.conf** | Reference nginx server block for API (e.g. 44300) |
| **PHP_SCRIPTS_AND_MODULES.md** | Which PHP scripts exist, who calls them, php-cli/php-sqlite3 and extensions |
| **TODO.md** | Open items (e.g. LDAP columns globals vs tenant) |
| **DEBIAN_PACKAGE_IMPROVEMENTS.md** | postinst vs installer, rules, install file ideas |
| **CLEANUP_PLAN.md** | Phases (D, F, etc.), legacy web, installer scope |
| **PBX3_CLEANUP_CONTEXT.md** | General cleanup context and layout |

---

## 7. Open items (from TODO.md)

- **LDAP:** LDAPHelperClass reads LDAP from `globals`, but instance `globals` has no LDAP columns (they exist on tenant `cluster`). Either read from tenant `cluster` or add LDAP columns to instance `globals`.

---

## 8. Extension provisioning (planned; API + frontend in pbx3spa/pbx3api)

**Scope:** SIP extensions with optional MAC (provisioned/unprovisioned), WebRTC; Save vs Commit (generator runs on Commit, not on every Save). Plan is **finalised**; DB changes (add `provision`, `provisionwith` to ipphone) are applied **manually** by the user (PBX3 has no Laravel migrations). Implementation: API (ExtensionController save/update, getVendorFromMac, adjustAstProvSettings, Device/globals) then frontend (ExtensionCreateView extensionType/MAC, Save/Commit when designed).

**Docs (in pbx3spa/workingdocs):** **EXTENSION_PROVISIONING_QUICKSTART.md** (start here), **EXTENSION_PROVISIONING_DEPLOYMENT_PLAN.md**, **DATABASE_CHANGES_FOR_PROVISIONING.md**, **OLD_SYSTEM_EXTENSION_CREATE_REFERENCE.md**. Generator: `genAst.sh` → `runAstGen.php` → GenClass (genPjsipPhones, genPjsipWebrtc); endpoint files created on demand when generator runs.

---

## 9. For the next agent: nginx / API HTTP layer

**Confirmed:** pbx3 **does not install Apache**. The package has no apache2 dependency; the description states "No HTTP server" and "HTTP/API is provided by pbx3api (nginx + PHP-FPM)".

**Planned work (next session):**

1. **TLS completion pass (pbx3 + pbx3api):** Current dev testing intentionally uses LAN HTTP to avoid self-signed browser friction. Before release, switch API back to HTTPS on `44300`, wire LE cert paths (owned by pbx3), and re-verify frontend login/CORS/Sanctum with trusted certs.
2. **pbx3 fail2ban** – Shipped config still references **Apache**: `etc/fail2ban/jail.local` uses the `apache-badbots` jail and `logpath = /var/log/apache2/ssl_access.log`. Since the API is served by nginx (pbx3api), update to a nginx log path and a suitable filter (or nginx-badbots if available), or disable the jail until nginx logging is in place.

**References:** `APACHE_CONFIG_TO_PBX3API.md` (decision: nginx in pbx3api; TLS/LE in pbx3), `PBX3API_INSTALLER_NGINX_ADDITIONS.md`, `nginx-api-site-reference.conf`.

---

## 10. Conventions

- **config.php** is the PHP source of truth for paths; run `php utilities/genbashconfig.php` to regenerate `scripts/bashconfig` after editing config.php (or rely on shipped bashconfig if PHP not needed).
- **reloader.sh** rebuilds the SQLite DB (saves current to `db_database_dumps/last.db`, then recreates from SQL files). It **exits** partway through; code after that (e.g. genAst, sanitize-firewall) is currently dead.
- **setip.php** needs NetHelperClass (and DbClass for static IP from DB); both need php-sqlite3. Uses **CODENAME** (pbx3) for dpkg-query and `/etc/issue`, not SYSPREFIX.
