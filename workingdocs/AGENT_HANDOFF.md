# Agent handoff – pbx3 (backend)

**Purpose:** Get a new agent up to speed on the pbx3 repo and recent work. Read this first, then dive into specific workingdocs as needed.

---

## 1. What this repo is

**pbx3** = backend-only worker for an Asterisk-based PBX: SQLite DB, Asterisk config generation, scripts, shorewall/fail2ban, setip (network detection). **No HTTP server** – API/HTTP is provided by **pbx3api** (nginx + PHP-FPM). Target: Ubuntu 24.04 LTS.

- **Package content** lives under **`pbx3-1/`** (what gets installed into `/opt/pbx3`, `/etc`, etc.).
- **Workingdocs** (design, decisions, checklists) are in **`workingdocs/`**.
- **Branch in use:** `cleanup`.

---

## 2. Current state (recent work completed)

- **Backend-only:** Apache and HTTP config removed from pbx3. HTTP/API is pbx3api’s responsibility (see `APACHE_CONFIG_TO_PBX3API.md`).
- **setip / debsetlan:** systemd unit `debsetlan.service` runs `php/utilities/setip.php` (path fixed to `php/utilities/`). Package Depends: **php-cli**, **php-sqlite3** so setip and installer can run.
- **Installer** runs manually (`sudo /opt/pbx3/scripts/installer.sh`), **not** from postinst. Fixes applied:
  - **db_database_dumps:** `reloader.sh` does `mkdir -p "$DBDUMPS"` before copying DB to `last.db`.
  - **sqlite_sequence:** Removed `CREATE TABLE sqlite_sequence` from `sqlite_create_laravel.sql` (reserved by SQLite).
  - **Shorewall:** Shipped `etc/shorewall/pbx3_inline_fqdn` is comment-only so `$FQDN` is not undefined at compile; API/NetHelper overwrites it when fqdninspect is enabled.
  - **CDR MySQL:** Installer uses `mysql -u root --socket=...` so it uses socket auth (same as `sudo mysql -u root`).
- **genbashconfig.php** in installer is optional: run only if `php` is available; otherwise use shipped `scripts/bashconfig`.

---

## 3. Key paths (under pbx3-1 or opt/pbx3)

| What | Path |
|------|------|
| Installer | `pbx3-1/opt/pbx3/scripts/installer.sh` |
| Reloader (DB rebuild) | `pbx3-1/opt/pbx3/scripts/reloader.sh` |
| setip (network/shorewall/asterisk) | `pbx3-1/opt/pbx3/php/utilities/setip.php` |
| systemd setip unit | `pbx3-1/etc/systemd/system/debsetlan.service` |
| Path/config source of truth | `pbx3-1/opt/pbx3/php/config.php` → `scripts/bashconfig` (via genbashconfig.php) |
| Debian packaging | `pbx3-1/debian/` (control, postinst, prerm, rules) |
| SQL schemas | `pbx3-1/opt/pbx3/db/db_sql/` (instance, laravel, tenant, message) |
| Shorewall templates | `pbx3-1/opt/pbx3/etc/shorewall/` |
| Asterisk configs/templates | `pbx3-1/opt/pbx3/etc/asterisk/` |

---

## 4. Build and install

- Build the .deb from the **pbx3** repo (e.g. `dpkg-buildpackage` or project’s build script). Package files are under `pbx3-1/`.
- Install: `apt install ./pbx3_*.deb` (or equivalent).
- After install, run **once:** `sudo /opt/pbx3/scripts/installer.sh` (idempotent; creates DB, shorewall, setip, CDR MySQL, etc.).

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

## 8. Conventions

- **config.php** is the PHP source of truth for paths; run `php utilities/genbashconfig.php` to regenerate `scripts/bashconfig` after editing config.php (or rely on shipped bashconfig if PHP not needed).
- **reloader.sh** rebuilds the SQLite DB (saves current to `db_database_dumps/last.db`, then recreates from SQL files). It **exits** partway through; code after that (e.g. genAst, sanitize-firewall) is currently dead.
- **setip.php** needs NetHelperClass (and DbClass for static IP from DB); both need php-sqlite3.
