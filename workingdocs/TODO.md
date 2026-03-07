# PBX3 ToDo list

**Branch:** main  
**Last updated:** 2026-03-06

---

## Open items

- [ ] **pbx3 fail2ban:** pbx3api serves the API via nginx; pbx3’s shipped `etc/fail2ban/jail.local` still references Apache (`apache-badbots`, `/var/log/apache2/ssl_access.log`). Update to nginx log path and a suitable filter (or nginx-badbots if available), or disable the jail until nginx logging is in place.

- [ ] **TLS finish pass after LAN HTTP dev cycle:** current frontend/API integration is validated over HTTP in LAN for development speed. Before release, switch back to HTTPS on `44300`, wire hostname-aligned certs (Let's Encrypt owned by pbx3), re-test browser login/CORS/Sanctum with trusted cert. **Installer health-check follow-up:** add to pbx3api `scripts/installer.sh` after nginx/php-fpm setup: (1) DB symlink check (exists, target resolves, www-data can r/w); (2) nginx upstream/socket check, `nginx -t`; (3) HTTP readiness e.g. `curl -k -s -o /dev/null -w "%{http_code}" https://127.0.0.1:44300/`. Fail installer non-zero if validation fails.

- [ ] **LDAP: LDAPHelperClass reads from `globals` but instance `globals` has no LDAP columns.**  
  Instance schema (`sqlite_create_instance.sql`) does not define `ldapbase`, `ldapou`, `ldapuser`, `ldappass` on `globals`. Those columns exist on the tenant `cluster` table (`sqlite_create_tenant.sql`).  
  **Action:** Either (1) have LDAPHelperClass read LDAP config from tenant `cluster` (e.g. for the current/default tenant), or (2) add LDAP columns to instance `globals` if LDAP is intended to be instance-wide.  
  **Current workaround:** Query uses `FROM globals LIMIT 1` with lowercase column names; empty-result guard avoids errors when columns are missing.

- [ ] **pjsipuser for extensions:** Address pjsipuser handling for extensions (PJSIP endpoint/user config, API/SPA and generator/templates as needed).
  It needs to expose the instance copy of the template and NOT the database column (although that might be an option).  TBD.
  Also, we need to settle the template handling of NAT, e.g. force_rport, Rewrite_contact. 

---

## Completed / deferred

_(Move items here when done or parked.)_
