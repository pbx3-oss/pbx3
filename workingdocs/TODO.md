# PBX3 ToDo list

**Branch:** cleanup  
**Last updated:** 2025-02-05

---

## Open items

- [ ] **API HTTP layer (next session):** pbx3 does not install Apache; API is pbx3api (nginx + PHP-FPM). pbx3api repo still has only `.htaccess` (no nginx config). **Tasks:** (1) Make pbx3api nginx-ready (add nginx site config or installer steps; see `APACHE_CONFIG_TO_PBX3API.md`, `PBX3API_INSTALLER_NGINX_ADDITIONS.md`, `nginx-api-site-reference.conf`). (2) In pbx3: update fail2ban `etc/fail2ban/jail.local` from apache-badbots / `/var/log/apache2/ssl_access.log` to nginx log path and suitable filter.

- [ ] **LDAP: LDAPHelperClass reads from `globals` but instance `globals` has no LDAP columns.**  
  Instance schema (`sqlite_create_instance.sql`) does not define `ldapbase`, `ldapou`, `ldapuser`, `ldappass` on `globals`. Those columns exist on the tenant `cluster` table (`sqlite_create_tenant.sql`).  
  **Action:** Either (1) have LDAPHelperClass read LDAP config from tenant `cluster` (e.g. for the current/default tenant), or (2) add LDAP columns to instance `globals` if LDAP is intended to be instance-wide.  
  **Current workaround:** Query uses `FROM globals LIMIT 1` with lowercase column names; empty-result guard avoids errors when columns are missing.

---

## Completed / deferred

_(Move items here when done or parked.)_
