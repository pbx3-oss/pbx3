# Agent handoff – pbx3 (backend)

**AI: read this first.**

**Purpose:** Get a new agent up to speed on the pbx3 repo and recent work. Read this first, then dive into specific workingdocs as needed.

---

## Agent behavior (handoff reminder)

Bias toward **caution over speed** on non-trivial work. Full detail lives in **Cursor user rules**; this is the short checklist for agents landing on pbx3.

- **Think first** — state assumptions; ask if unclear; surface tradeoffs before coding.
- **Minimal diff** — only what the request needs; match existing style; no drive-by refactors.
- **Verify** — turn tasks into checks (e.g. “Pages live → catalog loads → login on 08jzwn”).

**Repo-specific (always):**

- **Git:** `pbx3-master/` is not a repo. Commit from **`pbx3/`**, **`pbx3api/`**, or **`pbx3spa/`** only.
- **Fleet / S3 / directory:** on **`main`**. **Track B:** branch **`hardening`** in pbx3, pbx3api, pbx3spa.
- **Multi-repo tasks:** state which repo each change belongs in; don’t assume a single root commit.

---


## Read order by task

| Task | Read (in order) |
|------|------------------|
| Any / first time | This file (**§ Next agent session notes**), then TODO.md |
| **Track B — release hardening** | **TRACK_B_RELEASE_HARDENING.md** → **STAKEHOLDER_DEMO_SCRIPT.md** → TODO.md → TLS_IMPLEMENTATION_STEPS.md §4.3 |
| New GitHub org / OSS | **OPEN_SOURCE_GITHUB_SETUP.md** |
| Install / deploy | INSTALL_SEQUENCE_UBUNTU.md (pbx3 then pbx3api on Ubuntu 24.04) |
| Cleanup / installer | CLEANUP_PLAN.md, APACHE_CONFIG_TO_PBX3API.md, PBX3API_INSTALLER_NGINX_ADDITIONS.md |
| Schema / DB | DB_PBX3_VS_PBX3API_VARIANCE.md; for API alignment see pbx3api/workingdocs/PLAN_MODELS_AND_VALIDATION_HARMONISATION.md |
| TLS / certificates | **TLS_AND_CERTIFICATES.md** (index) → **TLS_IMPLEMENTATION_STEPS.md** (linear checklist) → **CERTIFICATES_PANEL_AND_API.md** → **LETSENCRYPT_PER_TENANT_FQDN.md** (**Option A** spec + §11–§12). **pbx3spa**/workingdocs has stubs pointing here. |
| SPA admin (Vue shell, layout) | **pbx3spa**/workingdocs/**SESSION_HANDOFF.md** (Quick start), **SPA_SHELL_ROADMAP.md** |
| Fleet / S3 catalog / onboard | **pbx3-directory/docs/IMPLEMENTATION_PLAN.md** → **INSTANCE_ONBOARDING.md** → **OPS_S3_RUNBOOK.md**; tools **`onboard-fleet-instance.sh`**, **`unregister-instance.sh`** |
| SPA GitHub Pages (S6.2) | **pbx3-directory/docs/OPS_S3_RUNBOOK.md** § 9; **pbx3spa** `.env.production` / CI; verify S3 + **each node API CORS** for Pages origin |

**Source of truth:** Schema and code. Verify against pbx3 db_sql and code when changing behaviour; workingdocs may be outdated.

---

## Next agent session notes (2026-05-26)

**Program:** **Track B — release hardening** on branch **`hardening`** (see **`TRACK_B_RELEASE_HARDENING.md`**). **Phase 0 ✓** · **Phase 1 ✓** (2026-05-30): trusted LE on **08jzwn** + **bzy54n**. **Phase 2 ✓** (code, 2026-05-30): `validate_install_health` in pbx3api installer. **Next:** Phase 2 VM sign-off (2.4–2.5), then **Phase 3** (fail2ban).

### Done and validated

| Area | Notes |
|------|--------|
| **S5 backups** | Merged local+S3 index, presigned GET, rehydrate, lifecycle from `policy.json` — golden **08jzwn** |
| **S5 archive round-trip (bzy54n)** | S3-only restore from older backup removed added tenant/extension; restore from later backup brought them back |
| **S6 fleet** | Two-node catalog; SPA picker flips instances; dev proxies work |
| **S6.4 onboard** | `pbx3-directory/tools/onboard-fleet-instance.sh` (Mac IAM + SSH + catalog + node `.env`) |
| **S6.5 offboard** | `unregister-instance.sh`; SPA hides `status=decommissioned` (`pbx3spa` `1e06679`) |
| **S6 backup smoke (bzy54n)** | `pbx3:backup-run --trigger=manual` → S3 `20260526T230950Z` (8.2 MB zip + manifest); `meta.json` updated |
| **Track B Phase 1 TLS** | Both fleet nodes LE on `:44300`; bzy54n via Certificates **Get certificate** (2026-05-30) after DNS for tenant `wfh69h.pbx3.com` |
| **Docs** | `INSTANCE_ONBOARDING.md` (manual + operator pre-flight), `OPS_S3_RUNBOOK.md` |

**S3 v1 closeout (2026-05-26):** Directory, instance backups (both nodes), onboard/offboard, and ops runbooks are **done for now**. **`directory` merged to `main`** in pbx3, pbx3api, pbx3spa after S5 archive validation. Deferred without blocking: **S6.2 Pages + CORS**, **S7 recordings**, optional postinst registrar hint.

### Fleet reference (verify live before ops)

| | Golden | Second node |
|--|--------|-------------|
| FQDN | `08jzwn.pbx3.com` | `bzy54n.pbx3.com` |
| KSUID | `3DmAsxePTWQZgynBYXE8obIRqEE` | `3E3gAOVGBhvc6vEPTBIYCBPycIk` |
| EC2 | (golden test IP in notes) | `i-0bb601e7b1253c3f5` |

- **Fleet bucket:** `08jzwn-pbx3` (one org bucket, many `instances/{ksuid}/` prefixes — not one bucket per node)
- **Catalog:** `s3://08jzwn-pbx3/catalog/instance-index.json` (public read on `catalog/*` only)
- **Mac ops:** AWS CLI with **IAM admin** (not node role) for onboard/offboard/registrar; **`aws sts get-caller-identity`** before scripts
- **SSH:** `pbx3test.pem`, user `ubuntu`; SG must allow **22** and **44300** from operator IP

### Local dev (pbx3spa) — unchanged by Pages plan

```bash
cd pbx3spa && npm run dev   # http://localhost:5173
```

`.env.development`: `VITE_CATALOG_PROXY_TARGET` + `/dev-catalog` for catalog; `VITE_API_PROXY_TARGET=https://{node}:44300` per node under test. **No S3/API CORS needed for localhost** (Vite proxies `/api` with **`secure: false`** — login/backup work with snakeoil or LE; **validate LE** with `curl https://{fqdn}:44300/up` without `-k` or Certificates panel). See **`TRACK_B_RELEASE_HARDENING.md`** § Dev proxy vs node TLS and **pbx3spa** **`DEV_ENVIRONMENT.md`** §7.

### Decisions for next work (do not re-litigate without user)

1. **S6.2 GitHub Pages — deferred public cutover.** Dev via `npm run dev` is sufficient for now. **Do not** roll S3 + node API CORS until GitHub org / hostname is settled.
2. **PBX3 will be open source** — plan a **new GitHub org** (not a shared personal account). Checklist: **`OPEN_SOURCE_GITHUB_SETUP.md`**.
3. **Production SPA URL:** prefer **`app.pbx.com`** (or similar on owned **`pbx.com`**) over locking to `aelintra.github.io/pbx3spa`. Custom domain survives org/repo moves; update CORS once at go-live.
4. **S6.2 “do now” without CORS:** optional workflow in **pbx3spa** (`base` path, `404.html`, `.env.production`) — safe to implement before org exists.

### Gaps / not done yet

| Item | Blocker / note |
|------|----------------|
| **S6.2 Pages live + CORS** | Wait for org + final origin (`app.pbx.com`?) |
| **pbx3api CORS** | Not configured for cross-origin SPA yet; required for Pages, not for Vite dev proxy |
| **S7 recordings offload** | Whole phase open (`IMPLEMENTATION_PLAN.md`) — parked with S3 v1 |
| **Phase 5 install hook** | Registrar hint on postinst — optional |

### Suggested next session pick (user preference order)

1. **Track B Phase 2.4–2.5** — run full/failure-path installer on clean Ubuntu 24.04 VM
2. **Track B Phase 3** — fail2ban → nginx (**`TRACK_B_RELEASE_HARDENING.md`**)
3. **Track B Phase 4** — SPA field help audit (stakeholder demo)
4. **Open-source org setup** — `OPEN_SOURCE_GITHUB_SETUP.md` (unblocks S6.2 hostname)

### Recent commits (directory branch)

- **pbx3:** `36700f8` handoff + OSS checklist; `ddc222c` onboard script; `d554b57` unregister
- **pbx3spa:** `1e06679` decommissioned filter
- **pbx3api:** `6616120` nginx default-site fix for ACME

---

## Workspace layout (where to commit)

**pbx3-master** is **not** a git repo. It is a **holding folder** for the repos inside it: **pbx3**, **pbx3api**, **pbx3cagi**, **pbx3spa**. Always run `git` (status, add, commit, etc.) from inside the relevant repo, e.g. `pbx3-master/pbx3` or `pbx3-master/pbx3api`.

---

## 1. What this repo is

**pbx3** = backend-only worker for an Asterisk-based PBX: SQLite DB, Asterisk config generation, scripts, shorewall/fail2ban, setip (network detection). **No HTTP server** – API/HTTP is provided by **pbx3api** (nginx + PHP-FPM). Target: Ubuntu 24.04 LTS.

- **Package content** lives under **`pbx3-1/`** (what gets installed into `/opt/pbx3`, `/etc`, etc.).
- **Workingdocs** (design, decisions, checklists) are in **`workingdocs/`**.
- **Fleet directory / S3 ops** live in **`pbx3-directory/`** (docs + registrar scripts).
- **Branches:** **`main`** — includes fleet catalog, S3 backups, onboard/offboard (merged from **`directory`** 2026-05-26); **`directory`** may remain for reference until deleted.

---

## 2. Current state (recent work completed)

- **Backend-only:** Apache and HTTP config removed from pbx3. HTTP/API is pbx3api’s responsibility (see `APACHE_CONFIG_TO_PBX3API.md`).
- **pbx3api nginx installer path is now implemented and tested:** On Ubuntu 24.04, fresh-clone installer flow was validated end-to-end (nginx + php8.3-fpm + Laravel bootstrap + PBX sqlite link). Fleet nodes **08jzwn** + **bzy54n** use **trusted LE** on `:44300` (Track B Phase 1, 2026-05-30). Local dev: **`npm run dev`** + HTTPS **`VITE_API_PROXY_TARGET`** (proxy `secure: false` — see **`DEV_ENVIRONMENT.md`** §7).
- **setip:** No longer a systemd service. Installer runs `php/utilities/setip.php` **once** directly; `debsetlan.service` was removed from the package. Installer also disables/removes the unit if present. Package Depends: **php-cli**, **php-sqlite3** so setip and installer can run.
- **Installer** runs manually (`sudo /opt/pbx3/scripts/installer.sh`), **not** from postinst. Script is written to work under **sh** (dash) or bash (POSIX case/printf; no `[[` or `read -p`). Fixes and behaviour:
  - **Instance identity (LE prep):** Builds `idpwgen` locally, then sets `globals.domain` (apex / TLD, e.g. `pbx3.com`) and `globals.fqdn` as `{subdomain}.{domain}`. Subdomain is a unique 6-character value from `idpwgen` unless overridden by legacy `INSTANCE_FQDN=host.example.com` or recovered from existing `globals` when `sqlite.db` is already present (installer **skips** `reloader.sh` then). On **first provision**, identity is applied after `create.initial.db` + `reloader.sh`. To overwrite FQDN/hostname on an existing DB: `PBX3_APPLY_INSTANCE_IDENTITY=1 INSTANCE_FQDN=host.example.com installer.sh`. `DOMAIN_TLD` env or interactive prompt supplies the apex; default apex is `pbx3.com` when unset and non-interactive. Hostname is the subdomain (same as the first label of the FQDN); updates `/etc/hosts` so `127.0.1.1` points to that hostname.
  - **db_database_dumps:** `reloader.sh` does `mkdir -p "$DBDUMPS"` before copying DB to `last.db`.
  - **sqlite_sequence:** Removed from `sqlite_create_laravel.sql` (reserved by SQLite).
  - **Shorewall:** Shipped `pbx3_inline_fqdn` is comment-only; API/NetHelper overwrites when fqdninspect enabled.
  - **CDR MySQL:** Installer uses `mysql -u root --socket=...` for socket auth.
  - **Shorewall6:** Installer runs `mkdir -p /etc/shorewall6` when templates exist so the service can start even if the package didn’t create the dir.
  - **generator:** Removed; Asterisk config generation scripts live in `php/utilities/` (runAstGen.php, etc.).
- **genbashconfig.php** in installer is optional (run only if `php` is available).
- **setip.php:** dpkg-query and `/etc/issue` use **CODENAME** (pbx3), not SYSPREFIX (/pbx3).
- **Certificates:** **Let’s Encrypt** **Option A** (multi-SAN HTTP-01: node + tenant **`cluster.fqdn`**); **commercial/custom** → **custom → LE → snakeoil** via **`apply-active-cert.sh`**. **All TLS docs:** **`workingdocs/TLS_AND_CERTIFICATES.md`** (index), **`TLS_IMPLEMENTATION_STEPS.md`** (execution order), **`CERTIFICATES_PANEL_AND_API.md`**, **`LETSENCRYPT_PER_TENANT_FQDN.md`**. **pbx3spa** `CERTIFICATES_ADOPTION_PLAN.md` / `LETSENCRYPT_PER_TENANT_FQDN_OPTIONS.md` are **stubs** → read **pbx3** `workingdocs/` instead.
- **Fleet / S3 (branch `directory`):** Shared org bucket + `catalog/instance-index.json`; per-node IAM; **`onboard-fleet-instance.sh`** / **`unregister-instance.sh`**; golden **08jzwn** + second node **bzy54n** validated in dev. **S6.2 Pages:** prep workflow OK; **defer public URL + CORS** until new OSS org + **`app.pbx.com`** (see **§ Next agent session notes**). See **`pbx3-directory/docs/IMPLEMENTATION_PLAN.md`**.

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
| LE port 80 open/close | `pbx3-1/opt/pbx3/scripts/le-port80-open.sh`, `le-port80-close.sh` |
| LE renewal (with port 80) | `pbx3-1/opt/pbx3/scripts/le-renew-with-80.sh` |
| LE first-time cert | `pbx3-1/opt/pbx3/scripts/le-first-cert.sh` |
| LE first-time cert (multi-SAN, Option A) | `pbx3-1/opt/pbx3/scripts/le-first-cert-multi.sh` |
| LE re-issue with expanded SANs (sync) | `pbx3-1/opt/pbx3/scripts/le-sync-cert-sans.sh` |
| Regenerate Shorewall `pbx3_inline_fqdn` + restart | `pbx3-1/opt/pbx3/scripts/update-fqdn-inline.sh` (runs `shorewallreload.php`) |
| Apply active cert (nginx + Asterisk) | `pbx3-1/opt/pbx3/scripts/apply-active-cert.sh` |

---

## 4. Build and install

- Build the .deb from the **pbx3** repo (e.g. `dpkg-buildpackage` or project’s build script). Package files are under `pbx3-1/`.
- Install: `apt install ./pbx3_*.deb` (or equivalent).
- After install, run **at least once:** `sudo /opt/pbx3/scripts/installer.sh` (**first provision:** prompts for **domain apex** (e.g. `pbx3.com`) or use `DOMAIN_TLD=example.com`, or legacy `INSTANCE_FQDN=node1.example.com`; writes `globals` + hostname/`/etc/hosts`; runs `create.initial.db`, `reloader.sh`, setip; shorewall baseline, Shorewall6 dir if needed, CDR MySQL, etc.). With an existing `sqlite.db`, **reloader is skipped** and instance FQDN is preserved unless `PBX3_APPLY_INSTANCE_IDENTITY=1` (still runs setip/Shorewall/service steps—see **INSTALL_SEQUENCE_UBUNTU.md**). Works when invoked as `sh installer.sh` or `./installer.sh`. Full sequence (pbx3 then pbx3api) is in **INSTALL_SEQUENCE_UBUNTU.md**.

---

## 5. Design decisions (summary)

- **pbx3 = backend only.** No Apache/nginx in this package; pbx3api owns nginx and the API.
- **TLS / Let’s Encrypt:** Cert acquisition and renewal live in **pbx3** (certbot, paths); both Asterisk and nginx (pbx3api) use the same cert paths. Details: `APACHE_CONFIG_TO_PBX3API.md`.
- **postinst** writes `/opt/pbx3/.install-date`, runs **`normalize-globals-identity.sh`** when `sqlite.db` exists, prints next-step hints when it does **not**. It does **not** run the full **`installer.sh`**.
- **PHP:** Package depends on **php-cli** and **php-sqlite3** for setip and optional installer steps. See `PHP_SCRIPTS_AND_MODULES.md` for all PHP scripts and modules.

---

## 6. Workingdocs index

| File | Use when |
|------|----------|
| **INSTALL_SEQUENCE_UBUNTU.md** | Full install order: pbx3 package, pbx3 installer, pbx3api deploy, pbx3api installer (Ubuntu 24.04) |
| **APACHE_CONFIG_TO_PBX3API.md** | HTTP vs backend split, TLS/LE ownership, nginx in pbx3api, phases |
| **TLS_AND_CERTIFICATES.md** | TLS index + overview: ownership, **Option A** summary, API table, links |
| **CERTIFICATES_PANEL_AND_API.md** | Certificates panel (SPA), `/certificates/*` API, code checklist |
| **LETSENCRYPT_PER_TENANT_FQDN.md** | **Option A** full spec, firewall **pbx3_inline_fqdn**, §11–§12 implementation |
| **PBX3API_INSTALLER_NGINX_ADDITIONS.md** | What pbx3api installer needs to add (nginx, site config) |
| **nginx-api-site-reference.conf** | Reference nginx server block for API (e.g. 44300) |
| **PHP_SCRIPTS_AND_MODULES.md** | Which PHP scripts exist, who calls them, php-cli/php-sqlite3 and extensions |
| **DB_RESTORE_REGRESSION_CHECKLIST.md** | Release-candidate validation for backup/restore + reloader data retention |
| **TODO.md** | Open items (e.g. LDAP columns globals vs tenant) |
| **TRACK_B_RELEASE_HARDENING.md** | **Active:** TLS HTTPS, installer health checks, fail2ban, SPA field help before stakeholder demo |
| **STAKEHOLDER_DEMO_SCRIPT.md** | Tier 1–2 demo path + help checkboxes for stakeholder rehearsal |
| **DEBIAN_PACKAGE_IMPROVEMENTS.md** | postinst vs installer, rules, install file ideas |
| **CLEANUP_PLAN.md** | Phases (D, F, etc.), legacy web, installer scope, repo layout (§3a) |
| **pbx3-directory/docs/IMPLEMENTATION_PLAN.md** | S3 + fleet program phases (S5–S8); current backlog |
| **pbx3-directory/docs/INSTANCE_ONBOARDING.md** | Add/remove fleet nodes; operator pre-flight; **`onboard-fleet-instance.sh`** |
| **pbx3-directory/docs/OPS_S3_RUNBOOK.md** | Bucket policy, CORS, node IAM, SPA hosting (GitHub Pages § 9) |
| **OPEN_SOURCE_GITHUB_SETUP.md** | New GitHub org checklist (PBX3 will be OSS) |

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

1. **TLS completion pass (pbx3 + pbx3api):** Current dev testing intentionally uses LAN HTTP to avoid self-signed browser friction. Before release, switch API back to HTTPS on `44300`, wire cert paths (owned by pbx3), and re-verify frontend login/CORS/Sanctum with trusted certs. **Certificates panel and LE scripts are in place:** panel setup (FQDN + email, Get certificate), Renew now, port 80 open/close around issuance and renewal, cron twice daily; see **TLS_AND_CERTIFICATES.md**.
2. **pbx3 fail2ban** – Shipped config still references **Apache**: `etc/fail2ban/jail.local` uses the `apache-badbots` jail and `logpath = /var/log/apache2/ssl_access.log`. Since the API is served by nginx (pbx3api), update to a nginx log path and a suitable filter (or nginx-badbots if available), or disable the jail until nginx logging is in place.

**References:** `APACHE_CONFIG_TO_PBX3API.md` (decision: nginx in pbx3api; TLS/LE in pbx3), `PBX3API_INSTALLER_NGINX_ADDITIONS.md`, `nginx-api-site-reference.conf`.

---

## 10. Conventions

- **config.php** is the PHP source of truth for paths; run `php utilities/genbashconfig.php` to regenerate `scripts/bashconfig` after editing config.php (or rely on shipped bashconfig if PHP not needed).
- **reloader.sh** rebuilds the SQLite DB (saves current to `db_database_dumps/last.db`, then recreates from SQL files). It **exits** partway through; code after that (e.g. genAst, sanitize-firewall) is currently dead.
- **setip.php** needs NetHelperClass (and DbClass for static IP from DB); both need php-sqlite3. Uses **CODENAME** (pbx3) for dpkg-query and `/etc/issue`, not SYSPREFIX.

---

## 11. Regression checklist (backup/restore + DB rebuild)

Run this checklist on release-candidate builds to catch DB restore regressions:

1. **Create backup A** from the UI/API.
2. **Delete one extension** (or other tenant row), then **Save + Commit**.
3. **Restore backup A** with **restoredb** selected.
4. Verify the deleted row is present again in UI and DB (`/opt/pbx3/db/sqlite.db`).
5. Check API logs for restore path:
   - backup zip resolved from route filename,
   - database copied from backup payload,
   - no DB rebuild script run during restore.
6. Run `reloader.sh` once and verify:
   - dump step runs before DB delete/rebuild,
   - `db_database_dumps/last_data.sql` is produced,
   - customer rows still present after rebuild.
7. Re-run **Commit** and verify generated Asterisk config/reload behaves normally.
