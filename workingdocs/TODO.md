# PBX3 ToDo list

**Branch:** main · **Track B:** Phases 0–3 on `main` (merged 2026-05-30); Phase 4 next  
**Last updated:** 2026-05-30

---

## Open items

- [ ] **Golden `08jzwn` has no `cluster` row with `pkey='default'` (investigate).**  
  **Observed (2026-05-30):** Golden has only named tenants (`f34ck1`, `5489nv`) with `{shortuid}.pbx3.com` FQDNs; node identity lives on **`globals`** (`08jzwn` / `08jzwn.pbx3.com`). Test instance (`vpqtc7`) uses the **classic** layout: five tenants including **`pkey='default'`** with **`cluster.fqdn = globals.fqdn`** (`vpqtc7.pbx3.com`).  
  **Why it matters:** `installer.sh` (`PBX3_APPLY_INSTANCE_IDENTITY=1`) and TLS step0 tests expect `pkey='default'` when present; LE still works on golden because **`le-instance-bootstrap.sh`** uses **`globals.fqdn`** as cert primary plus all **`cluster.fqdn`** SANs.  
  **Investigate:** How golden was provisioned (fresh install vs backup restore vs SPA tenant-create-only); whether SPA/API ever skip creating `default`; whether golden’s layout is intentional (node FQDN only on `globals`) or a gap. **Post-restore from test:** patch `globals` + update test’s `default` tenant `fqdn`/`domain` to `08jzwn.pbx3.com` / `pbx3.com`; other tenant rows unchanged.

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

- [x] **LE Sync drops removed tenant SANs (2026-05-30):** `le-sync-cert-sans.sh` no longer uses certbot `--expand`; SPA Certificates warns when cert ≠ DB tenant list; Sync is primary action.
- [x] **pbx3api installer health checks (Track B Phase 2, 2026-05-30):** golden rebuild on **08jzwn** validated (install, restore, DNS, LE).
- [x] **pbx3 fail2ban → nginx (Track B Phase 3, 2026-05-30):** `jail.d/pbx3-jails.conf` + `pbx3-api.conf` (`pbx3-api-badbots`, **`apache-badbots`** filter, `/var/log/nginx/access.log`); no `jail.local` symlink (Ubuntu 24.04). Deb **0.0.3-15** on **`main`**. Validated on golden: sshd, asterisk, recidive, pbx3-api-badbots.
