# PBX3 ToDo list

**Branch:** main · **Track B:** `hardening`  
**Last updated:** 2026-05-30

---

## Open items

- [ ] **pbx3api astamis `PJSIPShowEndpoint/{id}`:** Calling `GET .../astamis/PJSIPShowEndpoint/{id}` returns `AMI Action invalid or unsupported` because **`AstAmiController::$eventList` only whitelists `PJSIPShowEndpoints` (plural)** — singular action never reaches Asterisk. **Follow-up when implementing:** (1) Allow `PJSIPShowEndpoint` (dedicated route/method like other `eventItem` actions, or extend `getlist` with a special case). (2) AMI body must include **`Endpoint: {id}`** (not only `Action:`). (3) Do not use plain `amiQuery()` for this action — use **`amiPjsipShowEndpointForLive()`** or **`amiQueryUntilComplete()`** and return structured JSON or raw response as needed. (4) Document in `astamis` index (`GET astamis`) if exposed.

- [ ] **LDAP: LDAPHelperClass reads from `globals` but instance `globals` has no LDAP columns.**  
  Instance schema (`sqlite_create_instance.sql`) does not define `ldapbase`, `ldapou`, `ldapuser`, `ldappass` on `globals`. Those columns exist on the tenant `cluster` table (`sqlite_create_tenant.sql`).  
  **Action:** Either (1) have LDAPHelperClass read LDAP config from tenant `cluster` (e.g. for the current/default tenant), or (2) add LDAP columns to instance `globals` if LDAP is intended to be instance-wide.  
  **Current workaround:** Query uses `FROM globals LIMIT 1` with lowercase column names; empty-result guard avoids errors when columns are missing.

- [ ] **pjsipuser for extensions:** Address pjsipuser handling for extensions (PJSIP endpoint/user config, API/SPA and generator/templates as needed).
  It needs to expose the instance copy of the template and NOT the database column (although that might be an option).  TBD.
  Also, we need to settle the template handling of NAT, e.g. force_rport, Rewrite_contact. 

---

## Completed / deferred

- [x] **TLS — fleet nodes (Track B Phase 1, 2026-05-30):** **08jzwn** + **bzy54n** trusted LE on `:44300`. **Remaining:** Pages/CORS when SPA is off localhost.
- [x] **pbx3api installer health checks (Track B Phase 2, 2026-06-28):** golden rebuild on **0.0.3-12** validated (install, restore, DNS, LE).
- [x] **pbx3 fail2ban → nginx (Track B Phase 3, 2026-06-28):** `jail.d/pbx3-api.conf` (`nginx-badbots`, `/var/log/nginx/access.log`); removed `apache-badbots` from `jail.local`. **Manual:** `fail2ban-client status` on node after upgrade/re-run installer.
