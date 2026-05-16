# Install sequence: pbx3 + pbx3api on Ubuntu 24.04

Target: one server, backend (pbx3) then API/frontend (pbx3api). pbx3 provides DB, Asterisk, scripts; pbx3api provides nginx + PHP-FPM and the API on HTTPS port 44300.

---

## Operator rules (read first)

**One command for first-time PBX setup on a server:**

```bash
sudo /opt/pbx3/scripts/installer.sh
```

Run it after `apt install pbx3` (required before production use). On **first** run it creates the database, instance FQDN, hostname, firewall baseline, and **globals identity** (`id`, `shortuid`, `domain`, `fqdn`). Subsequent runs behave as in the table below.

| Situation | What to do |
|-----------|------------|
| **New server** (no `/opt/pbx3/db/sqlite.db`) | `apt install ./pbx3_*.deb` then **`installer.sh`** once |
| **Upgrade pbx3 package** (new `.deb`, same server) | `apt install ./pbx3_*.deb` — postinst runs identity normalize automatically |
| **Upgrade scripts from git** on a live box | `git pull` in `/opt/pbx3` (and `/opt/pbx3api`), then **`sudo /opt/pbx3/scripts/normalize-globals-identity.sh`** only if the panel still shows empty UID/KSUID |
| **Configured system** (`sqlite.db` already exists) | **`installer.sh` does not call `reloader.sh`** — the DB is **not** recreated; **`globals`** FQDN / domain / **`shortuid`** are **preserved** unless you opt in with **`PBX3_APPLY_INSTANCE_IDENTITY=1`** and **`INSTANCE_FQDN=node.example.com`**. Re-runs still execute setip, Shorewall/service steps, etc., so prefer **normalize** or package upgrade for narrow fixes—not every re-run is a no-op. |
| **Full DB reload from SQL** (disaster / schema bake-off) | Run **`/opt/pbx3/scripts/reloader.sh`** deliberately (backs up current DB under `db_database_dumps/`). Not part of routine install. Legacy migration may use **`migrateLegacyDb.sh`**, which also invokes the reloader. |
| **First Let's Encrypt cert** (after DNS for **`globals.fqdn`**) | **`sudo /opt/pbx3/scripts/le-instance-bootstrap.sh your@email.com`** (HTTP-01 **webroot**; nginx stays up). Or use SPA Certificates panel. Renewal: **`/etc/cron.d/pbx3`** at **03:17**. Staging test: **`PBX3_LE_STAGING=1`** … |

**Instance Globals in the SPA:** UID = subdomain (`shortuid`), KSUID = `id`. Both are set on **first provision** by **`installer.sh`**; upgrades fix legacy DBs via **postinst** or **`normalize-globals-identity.sh`**.

---

## Prerequisites

- Ubuntu 24.04 LTS
- Root or sudo
- install dpkg-dev (`sudo apt install dpkg-dev debhelper build-essential devscripts`)
- pbx3 `.deb` built from the pbx3 repo (`cd pbx3-1 && dpkg-buildpackage -us -uc -b`)
- pbx3api source (clone or copy) to be deployed under `/opt/pbx3api`

---

## 1. Install pbx3 package

```bash
sudo apt install ./pbx3_*.deb
```

This installs files under `/opt/pbx3`, `/etc`, etc. It does **not** run the full installer. If the database already exists (upgrade), **postinst** runs **`normalize-globals-identity.sh`** so Instance Globals stay correct.

---

## 2. Run pbx3 installer

```bash
sudo /opt/pbx3/scripts/installer.sh
```

- Sets **domain apex** and **FQDN** for the node (for later Let’s Encrypt). Non-interactive examples:
  ```bash
  sudo DOMAIN_TLD=example.com /opt/pbx3/scripts/installer.sh
  ```
  Default apex when unset and non-interactive is `pbx3.com`. The installer generates a **6-character subdomain** with `idpwgen`, sets `globals.domain`, `globals.fqdn`, `globals.shortuid`, and sets the system hostname to that subdomain. Legacy full-FQDN override:
  ```bash
  sudo INSTANCE_FQDN=node1.example.com /opt/pbx3/scripts/installer.sh
  ```
- **First provision only** (no `sqlite.db` yet): runs **`create.initial.db`** then **`reloader.sh`** to materialize the full schema and seed data, then applies instance identity (FQDN, hostname, **`shortuid`**, default tenant FQDN where applicable).
- **If `sqlite.db` already exists:** skips **`reloader.sh`** and keeps existing tenant data and instance FQDN. Runs **`normalize-globals-identity.sh`**. To **overwrite** instance FQDN / hostname / globals identity on purpose:  
  `sudo PBX3_APPLY_INSTANCE_IDENTITY=1 INSTANCE_FQDN=node.example.com /opt/pbx3/scripts/installer.sh`
- On every run (with or without an existing DB): refreshes Asterisk/Shorewall/fail2ban links, **`setip`**, CDR MySQL bootstrap (if MySQL is present), dnsmasq, helper restarts, etc.—so avoid treating a re-run as a harmless no-op unless you intend those side effects.

Creates on **first run**: SQLite DB at `/opt/pbx3/db/sqlite.db`, hostname, `/etc/hosts`, Shorewall/Shorewall6 baseline, **`id` / `shortuid`** in **`globals`** (via installer + normalize), etc.

---

## 3. Deploy pbx3api to /opt/pbx3api

pbx3api has no .deb; deploy by cloning or copying the repo into `/opt/pbx3api`:

```bash
sudo mkdir -p /opt
sudo git clone <pbx3api-repo-url> /opt/pbx3api
# or: sudo cp -a /path/to/pbx3api /opt/pbx3api
```

Ensure the tree is at `/opt/pbx3api` (so `scripts/installer.sh` and `config/nginx/` are under it).

---

## 4. Run pbx3api installer (once)

```bash
sudo /opt/pbx3api/scripts/installer.sh
```

- Installs nginx, php8.3-fpm, composer, and PHP extensions if not present.
- Runs `composer install` if needed.
- Bootstraps Laravel (`.env`, symlinks `database/database.sqlite` → `/opt/pbx3/db/sqlite.db`, writable dirs, artisan key/cache).
- Deploys nginx site for the API on port **44300** (HTTPS with snakeoil by default).

If pbx3’s DB is not at `/opt/pbx3/db/sqlite.db`, set it explicitly:

```bash
sudo PBX3_SQLITE_PATH=/opt/pbx3/db/sqlite.db /opt/pbx3api/scripts/installer.sh
```

---

## 5. Optional: TLS (Let’s Encrypt and custom certs)

- **Docs:** **`TLS_AND_CERTIFICATES.md`** (index) → **`CERTIFICATES_PANEL_AND_API.md`** → **`LETSENCRYPT_PER_TENANT_FQDN.md`** (Option A **§12**). Certificates are managed by **pbx3** (certbot / LE scripts, custom upload paths). Use the Certificates panel or pbx3’s LE scripts.
- After a cert is in place, pbx3’s `apply-active-cert.sh` applies it to nginx and Asterisk; nginx config can be pointed at `/etc/letsencrypt/live/<fqdn>/` (see **`TLS_AND_CERTIFICATES.md`** and pbx3api `docs/deployment-nginx.md`).

---

## Summary order

| Step | Command / action |
|------|-------------------|
| 1 | `sudo apt install ./pbx3_*.deb` |
| 2 | `sudo /opt/pbx3/scripts/installer.sh` (set `DOMAIN_TLD` or `INSTANCE_FQDN` if non-interactive) |
| 3 | Deploy pbx3api to `/opt/pbx3api` (clone or copy) |
| 4 | `sudo /opt/pbx3api/scripts/installer.sh` |
| 5 | (Optional) Configure Let’s Encrypt via pbx3; apply certs |

After step 4, the API is available at `https://<host>:44300` (snakeoil until LE is configured).
