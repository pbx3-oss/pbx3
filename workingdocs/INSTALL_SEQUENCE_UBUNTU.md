# Install sequence: pbx3 + pbx3api on Ubuntu 24.04

Target: one server, backend (pbx3) then API/frontend (pbx3api). pbx3 provides DB, Asterisk, scripts; pbx3api provides nginx + PHP-FPM and the API on HTTPS port 44300.

---

## Prerequisites

- Ubuntu 24.04 LTS
- Root or sudo
- pbx3 `.deb` built from the pbx3 repo (`cd pbx3-1 && dpkg-buildpackage -us -uc -b`)
- pbx3api source (clone or copy) to be deployed under `/opt/pbx3api`

---

## 1. Install pbx3 package

```bash
sudo apt install ./pbx3_*.deb
```

This installs files under `/opt/pbx3`, `/etc`, etc. It does **not** run the full installer (postinst only writes `/opt/pbx3/.install-date`).

---

## 2. Run pbx3 installer (once)

```bash
sudo /opt/pbx3/scripts/installer.sh
```

- Sets **domain apex** and **FQDN** for the node (for later Let’s Encrypt). Non-interactive examples:
  ```bash
  sudo DOMAIN_TLD=example.com /opt/pbx3/scripts/installer.sh
  ```
  Default apex when unset and non-interactive is `pbx3.com`. The installer generates a **6-character subdomain** with `idpwgen`, sets `globals.domain` / `globals.fqdn`, and sets the system hostname to that subdomain. Legacy full-FQDN override:
  ```bash
  sudo INSTANCE_FQDN=node1.example.com /opt/pbx3/scripts/installer.sh
  ```
- Idempotent: safe to run again.
- Creates/updates: SQLite DB at `/opt/pbx3/db/sqlite.db`, hostname, `/etc/hosts`, Shorewall/Shorewall6, runs setip once, CDR MySQL, etc.

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
