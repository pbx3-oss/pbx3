# What to add to the pbx3api installer for nginx

Checklist for the pbx3api **webserver** branch so the API site works after install.

---

## 1. Package dependencies

Ensure the pbx3api package (or its installer) depends on:

- **nginx**
- **php-fpm** (e.g. `php8.2-fpm` or `php-fpm` for the target Ubuntu version)
- **PHP extensions** the Laravel API needs: e.g. `php-mbstring`, `php-gd`, `php-sqlite3`, `php-curl`, `php-mysql`, `php-xml`, `php-zip`, `php-ldap`, etc. (match current Laravel/pbx3api requirements)

---

## 2. Site config file

- Ship the nginx server block (from **pbx3 workingdocs/nginx-api-site-reference.conf**) in the pbx3api repo, e.g.:
  - `config/nginx/pbx3-api.conf` or
  - `debian/nginx/sites-available/pbx3-api.conf`
- Set **root** to `/opt/pbx3api/public`, **listen** to `[::]:44300 ssl`.
- Set **fastcgi_pass** to the PHP-FPM socket for your target (e.g. `unix:/run/php/php8.2-fpm.sock` on Ubuntu 24.04).
- SSL: use snakeoil paths by default; when pbx3 has Let's Encrypt, the same config can point at `/etc/letsencrypt/live/<fqdn>/` (or use an include/snippet that pbx3 can override).

---

## 3. Installer / postinst steps (in order)

1. **Create document root** (if Laravel doesn't already):
   - `mkdir -p /opt/pbx3api/public`
   - `chown -R www-data:www-data /opt/pbx3api` (or the php-fpm user)

2. **Install nginx site config**:
   - Copy or symlink the site config into `/etc/nginx/sites-available/` (e.g. `pbx3-api.conf`).
   - Enable it: `ln -sf /etc/nginx/sites-available/pbx3-api.conf /etc/nginx/sites-enabled/` (or use the distro’s `sites-enabled` pattern).

3. **Ensure nginx and php-fpm are enabled and running**:
   - `systemctl enable nginx`
   - `systemctl enable php*-fpm` (or the specific version)
   - `systemctl reload nginx` (or `restart` if first time)
   - `systemctl start php*-fpm` if not already running

4. **Optional – fail2ban**: If pbx3’s jail.local is installed, enable the API jail with nginx log path; or ship a small fragment (e.g. under `/etc/fail2ban/jail.d/`) that enables a badbots-style jail with `logpath = /var/log/nginx/access.log` (or the nginx log path you use).

5. **Optional – sudoers**: If the API needs to reload nginx (e.g. after cert renewal), add:
   - `www-data ALL=NOPASSWD: /usr/sbin/nginx -s reload`
   (or the path returned by `which nginx` on the target.)

---

## 4. Remove / purge cleanup (prerm or postrm)

- Disable the site: remove the symlink from `/etc/nginx/sites-enabled/` (e.g. `rm -f /etc/nginx/sites-enabled/pbx3-api.conf`).
- `systemctl reload nginx`.
- On purge, decide whether to remove `/opt/pbx3api` (likely yes for the pbx3api package).

---

## 5. Cert paths

- Certificates are provided by **pbx3** (Let's Encrypt or snakeoil). nginx only references the paths (e.g. `/etc/letsencrypt/live/<fqdn>/fullchain.pem`). No certbot or ACME in pbx3api.
- If no LE cert exists yet, the reference config uses snakeoil; once pbx3 runs certbot, point the same server block at the LE paths (or use an include that pbx3’s deploy hook can update).

---

## 6. Reference files in pbx3 repo

- **workingdocs/nginx-api-site-reference.conf** – nginx server block to copy/adapt.
- **workingdocs/APACHE_CONFIG_TO_PBX3API.md** – decisions, Phase 1 work plan, TLS ownership.
- **opt/pbx3/etc/fail2ban/jail.local** – `[apache-badbots]` (disabled) as reference for nginx logpath and params.
