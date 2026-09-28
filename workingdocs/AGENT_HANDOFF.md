# Agent handoff – pbx3 (backend)

**AI:** Session state lives in private **`~/GiT/pbx3-ops`**. This file is the **public-ready stub** (behavior + read-order + permanent reference).

**Purpose:** Orient agents on product docs. For **Next agent session notes**, read **`~/GiT/pbx3-ops/AGENT_HANDOFF.md`**.

---

## Agent behavior (handoff reminder)

Bias toward **caution over speed** on non-trivial work. Full detail lives in **Cursor user rules**; this is the short checklist for agents landing on pbx3.

- **Think first** — state assumptions; ask if unclear; surface tradeoffs before coding.
- **Minimal diff** — only what the request needs; match existing style; no drive-by refactors.
- **Verify** — turn tasks into checks (e.g. “Pages live → catalog loads → login on 08jzwn”).

**Repo-specific (always):**

- **Git:** `pbx3-master/` is not a repo. Commit from **`pbx3/`**, **`pbx3api/`**, **`pbx3spa/`**, **`pbx3cagi/`**, or **`pbx3sbc/`** (SBC edge, moved into holding folder 2026-07-07) as appropriate.
- **Naming — SBC:** Call the edge **SBC**, never a commercial ITSP name. Prefer **upstream carrier** / **carrier Peer** for ITSPs. Recipe ids like `uk-magrathea` are legacy wire tokens until renamed — do not use the brand in new prose. See Cursor rule **`sbc-naming-not-magrathea`**.
- **Fleet / S3 / directory:** on **`main`**. **Track B** Phases 0–4 Tier 1–2 + **panelfixes** panel QA merged to **`main`** (2026-07-02). Branches **`helptext`**, **`panelfixes`**, **`directory`** deleted.
- **Multi-repo tasks:** state which repo each change belongs in; don’t assume a single root commit.
- **Private ops:** clone **`aelintra/pbx3-ops`** to **`~/GiT/pbx3-ops`** and add it to the Cursor workspace.

**Session end:** When the user says **`session end`**, **`end session`**, or **`update handoff`**, follow **`~/GiT/pbx3-ops/SESSION_END_CHECKLIST.md`**.

---

## Read order by task

| Task | Read (in order) |
|------|------------------|
| Any / first time | **`~/GiT/pbx3-ops/AGENT_HANDOFF.md`** (§ Next agent session notes) → this repo **`TODO.md`** → **`~/GiT/pbx3-ops/TODO_OPS.md`** → **`~/GiT/pbx3-ops/SESSION_HANDOFF.md`** (top block) |
| **First out / cleanup triage** | **`FIRST_OUT_CHECKLIST.md`** (must-fix vs nice vs parked) → TODO.md |
| **Session end** (user request) | **`~/GiT/pbx3-ops/SESSION_END_CHECKLIST.md`** (product roadmap **`TODO.md`** + private ops handoffs) |
| **New session** (user request) | **`~/GiT/pbx3-ops/AGENT_HANDOFF.md`** § Next agent session notes → **`TODO.md`** → **`~/GiT/pbx3-ops/TODO_OPS.md`** → **`~/GiT/pbx3-ops/SESSION_HANDOFF.md`** (top block) |
| **Track B — release hardening** | **`~/GiT/pbx3-ops/devdocs/pbx3/workingdocs/TRACK_B_RELEASE_HARDENING.md`** (stub) → **STAKEHOLDER_DEMO_SCRIPT.md** → TODO.md → TLS_IMPLEMENTATION_STEPS.md §4.3 |
| New GitHub org / OSS | **OPEN_SOURCE_GITHUB_SETUP.md** → **REPOS_AND_RELEASES.md** |
| Install / deploy | INSTALL_SEQUENCE_UBUNTU.md (pbx3 then pbx3api on Ubuntu 24.04) |
| Cleanup / installer | APACHE_CONFIG_TO_PBX3API.md, PBX3API_INSTALLER_NGINX_ADDITIONS.md (cleanup plan → ops `devdocs`) |
| Schema / DB | DB_PBX3_VS_PBX3API_VARIANCE.md; for API alignment see pbx3api/workingdocs/PLAN_MODELS_AND_VALIDATION_HARMONISATION.md |
| TLS / certificates | **TLS_AND_CERTIFICATES.md** (**§0 fleet lock**) → **TLS_IMPLEMENTATION_STEPS.md** → **CERTIFICATES_PANEL_AND_API.md** → **LETSENCRYPT_PER_TENANT_FQDN.md** (**solo/direct Option A only**) |
| SPA admin (Vue shell, layout) | **`~/GiT/pbx3-ops/SESSION_HANDOFF.md`** (Quick start) → **pbx3spa**/workingdocs/**SPA_SHELL_ROADMAP.md** |
| **Instance user privileges** | **pbx3spa**/workingdocs/**INSTANCE_USER_PRIVILEGES_REQUIREMENTS.md** (P1–P4 + **B′ login homing** shipped) → **ADMIN_PANELS_AND_PERMISSIONS.md** → **AUTH_PATTERNS.md** |
| **TOTP 2FA** (instance + SBC + Fleet) | **`TOTP_2FA_REQUIREMENTS.md`** → **`FLEET_GATEKEEPER_TOTP_REQUIREMENTS.md`** → **pbx3spa**/workingdocs/**AUTH_PATTERNS.md** §2 · SBC **`pbx3sbc-admin/workingdocs/TOTP_2FA_SBC.md`** |
| Fleet / S3 catalog / onboard | **pbx3-directory/docs/FLEET_SYSTEM_OVERVIEW.md** (stakeholder intro) → **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** (S8.10, §2.5 one SPA / two modes + control plane, §13 implementer map) → **IMPLEMENTATION_PLAN.md** § **S8** → **`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`** (ease/cost; 1-box / 2-box try-it) → **`LAB_INSTALL_AUTOMATION_HARNESS.md`** (local VM snapshot install loop; no calls) → **`OPERATOR_MAC_SETUP.md`** (Mac SSH + AWS CLI) → **REBUILD_INSTANCE_RUNBOOK.md** → **`SELF_SERVICE_REBUILD_DESIGN.md`** (S8.9 + **Mode 4 agent-assisted**) → **`LAB_FLEET_TENANTS.md`** (no node-only lab tenants) → **`GREENFIELD_FLEET_INSTANCE_INSTALL.md`** (EC2 → packages → onboard, step-by-step) → **NEW_INSTANCE_CHECKLIST.md** → **INSTANCE_ONBOARDING.md** → **OPS_S3_RUNBOOK.md**; tools **`onboard-fleet-instance.sh`**, **`reconcile-node-tenants.sh`**, **`fetch-latest-instance-backup.sh`** |
| **Fleet naming** | **`FLEET_NAMING_LOCK.md`** (shortuid + Name + Description + FQDN=`{suid}.{apex}`; **D6 cancelled**) → instance sitename detail **pbx3spa**/workingdocs/**NETWORK_SYSGLOBALS_OVERLAP.md** · Delete **`FLEET_TENANT_DELETE_REQUIREMENTS.md`** |
| **Asterisk after Egress / genAst** | **`OPS_ASTERISK_AFTER_EGRESS_GENAST.md`** — full restart vs pjsip reload |
| **Ast config generator + CAGI cleanup** | **`AST_CONFIG_GENERATOR_SUBPROJECT.md`** (one track: staging/overlay + GenAst↔CAGI contract) → **pbx3cagi**/workingdocs/**`REFACTOR_PLAN.md`** → **`TEST_RECIPE.md`** |
| **Time-based routing (day-parts)** | **`TIME_BASED_ROUTING_REQUIREMENTS.md`** — **done on `main`** (A–E + DOW ranges + DID open-seed); golden **0.0.4-8** / cagi **1.0.0-13**; before CAGI Phase 4 |
| **Tenant short dial (cross-tenant)** | **`TENANT_SHORT_DIAL_REQUIREMENTS.md`** — A–E + **D Path 1** lab green; **F** migrate docs. **Site Groups / dial cohort:** **`DIAL_COHORT_REQUIREMENTS.md`** — **C0–C6 lab green** (UI Site Group; hand prefixes = lab only). Slice D shortuid repair kept as PAI-CLIP fallback. |
| **Fleet-first tenant create** | **`FLEET_TENANT_CREATE_REQUIREMENTS.md`** — policy locked; implement when scheduled |
| **Call / SIP testing (SIPp)** | **`CALL_TYPE_INVENTORY.md`** → **`CALL_TEST_STRATEGY.md`** → recipes **[aelintra/sipplabs](https://github.com/aelintra/sipplabs)** (`AGENTS.md` / `workingdocs/TODO.md`) · **site-dial pack gate plan** sipplab **`SITE_DIAL_PACK_GATE_PLAN.md`** · **`TEST_CADENCE.md`** · **`CRITICAL_PATH_TEST_PACK.md`** Pack B · CAGI L0 **`TEST_RECIPE.md`** · pbx3 stub **`call-tests/README.md`** only |
| **Fleet mode UX** (future) | **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §2.5, §4 — one SPA, two modes; separate control-plane API; lab peer-nav → mode swap |
| **Failover + shadowing** (parked) | Edge HA: **`SBC_HA_FAILOVER_REQUIREMENTS.md`**. Instance shadow SKU framing: **`INSTANCE_SHADOWING_REQUIREMENTS.md`** (same mechanics, paid twin) |
| **Fleet egress lab rollback** (2026-07-09) | **`~/GiT/pbx3-ops/devdocs/pbx3/workingdocs/FLEET_EGRESS_LAB_ROLLBACK.md`** (stub in product) — git tags, revert steps |
| **SBC HA (VIP/EIP promote)** | **`SBC_HA_FAILOVER_REQUIREMENTS.md`** — requirements locked; implement later |
| **Edge portability (Rule 7 debt)** | **`EDGE_PORTABILITY_SCORECARD.md`** — adapter vs OpenSIPS vocabulary leaks |
| **SBC product tracks & roadmap** | **`SBC_PRODUCT_TRACKS.md`** — A/B/C posture + capability gaps (SIP TLS, media mode, registration-edge, …); WebRTC committed |
| **Fleet Egress availability** | **`FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`** — R1+R2 shipped; R3 EgressFailover/cagi parked |
| **Ops failure notification** | **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** — probe+SMTP + lifecycle + misconfig + move-job + Fail2ban ban + **Egress Unavail** shipped; SPA badges later |
| **Toll fraud / velocity** | **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`** — V1–V5 fleshed (fixture-first, batch CDR, `active=NO` act); competitive notes |
| **WebRTC / WSS (demo)** | **`WEBRTC_WSS_LAB.md`** (golden `:8089` baseline) → **`FLEET_TRUNK_PEERING_DECISION.md`** §6.1 → **`SBC_PRODUCT_TRACKS.md`** · IMPLEMENTATION_PLAN **W1** |
| **PSTN number dialects / wire** | **`NUMBER_WIRE_POLICY.md`** (who does what) → **`NUMBER_DIALECT_REQUIREMENTS.md`** → MkDocs **`fleet/number-dialect`** → Peer dialect + OpenSIPS `DIALECT_*`; Phase 1 node Egress = DNID/`+CC` by serving country (**D1 = C**) |
| **Number wire policy / D1** | **`NUMBER_WIRE_POLICY.md`** → draft research in **`~/GiT/pbx3-ops/devdocs/.../NUMBER_WIRE_STANDARD_DRAFT.md`** + carrier research stub — **D1 = C** locked; Phase 2 not scheduled |

| **Log retention / SIP capture** | **`FLEET_LOG_RETENTION_REQUIREMENTS.md`** — Phases 1–6 done; **`SBC_DATA_RETENTION_REQUIREMENTS.md`** — aging WS0–WS4 **done** (lab); **`SBC_BACKUP_RESTORE_REQUIREMENTS.md`** — SBC DR **v1 done** (scripts + scratch drill + MkDocs) |
| **Downstream peer REGISTER (future)** | **`DOWNSTREAM_PEER_REGISTRATION_REQUIREMENTS.md`** — separate registration-edge instance class; no shared OpenSIPS image; interim Asterisk-proxied workaround only |
| **Agent-assisted fleet rebuild** | **`REBUILD_INSTANCE_RUNBOOK.md`** (kickoff prompt) → **`SELF_SERVICE_REBUILD_DESIGN.md`** § Mode 4 → **`OPERATOR_MAC_SETUP.md`** |
| Call recordings | **`RECORDINGS_STORAGE_DESIGN.md`** → **`IMPLEMENTATION_PLAN.md`** § **R1** (done) / **R1.5** / **S7** |
| **CDR timezone / Home “today”** | **`CDR_TIMEZONE_POLICY.md`** — local CDR vs Laravel UTC; near-term day buckets = node local; end-state UTC CDR + site TZ |
| **pbx3 0.0.4-1 + cagi + golden rebuild** | **`~/GiT/pbx3-ops/devdocs/.../BUILD_PLAN_0.0.4.md`** (stub) → Mode 4 **`REBUILD_INSTANCE_RUNBOOK.md`** |
| SPA GitHub Pages (S6.2) | **pbx3-directory/docs/OPS_S3_RUNBOOK.md** § 9; **pbx3spa** `.env.production` / CI; verify S3 + **each node API CORS** for Pages origin |

**Source of truth:** Schema and code. Verify against pbx3 db_sql and code when changing behaviour; workingdocs may be outdated.

---

## Session state (private)

Live **Next agent session notes**, SPA **Session end** blocks, tip gossip, and handoff archives:

- **`~/GiT/pbx3-ops/AGENT_HANDOFF.md`**
- **`~/GiT/pbx3-ops/SESSION_HANDOFF.md`**
- **`~/GiT/pbx3-ops/TODO_OPS.md`**
- **`~/GiT/pbx3-ops/archive/`**

Do **not** reintroduce session blocks into this product file.

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
- **Certificates:** **SBC fleet:** instance-only LE (**`TLS_AND_CERTIFICATES.md` §0**); Setup/Sync omit tenant SANs. **Solo/direct:** Option A multi-SAN (**`LETSENCRYPT_PER_TENANT_FQDN.md`**). **custom → LE → snakeoil** via **`apply-active-cert.sh`**. **pbx3spa** stubs → **pbx3** `workingdocs/`.
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
| LE re-issue with current SAN list (sync) | `pbx3-1/opt/pbx3/scripts/le-sync-cert-sans.sh` |
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
| **pbx3-directory/docs/OPERATOR_MAC_SETUP.md** | Mac SSH to golden, AWS CLI ops identity, troubleshooting (agents + operators) |
| **pbx3-directory/docs/REBUILD_INSTANCE_RUNBOOK.md** | Replace failed EC2 from latest S3 backup (same KSUID) |
| **pbx3-directory/docs/INSTANCE_ONBOARDING.md** | Add/remove fleet nodes; operator pre-flight; **`onboard-fleet-instance.sh`** |
| **pbx3-directory/docs/OPS_S3_RUNBOOK.md** | Bucket policy, CORS, node IAM, SPA hosting (GitHub Pages § 9) |
| **OPEN_SOURCE_GITHUB_SETUP.md** | New GitHub org checklist (PBX3 will be OSS) |

---

## 7. Open items (from TODO.md)

- **LDAP:** LDAPHelperClass reads LDAP from `globals`, but instance `globals` has no LDAP columns (they exist on tenant `cluster`). Either read from tenant `cluster` or add LDAP columns to instance `globals`.

---

## 8. Extension provisioning (planned; API + frontend in pbx3spa/pbx3api)

**Scope:** SIP extensions with optional MAC (provisioned/unprovisioned), WebRTC; Save vs Commit (generator runs on Commit, not on every Save). Plan is **finalised**; DB changes (add `provision`, `provisionwith` to ipphone) are applied **manually** by the user (PBX3 has no Laravel migrations). Implementation: API (ExtensionController save/update, getVendorFromMac, adjustAstProvSettings, Device/globals) then frontend (ExtensionCreateView extensionType/MAC, Save/Commit when designed).

**Docs (in pbx3spa/workingdocs):** **EXTENSION_PROVISIONING_QUICKSTART.md** (start here), **EXTENSION_PROVISIONING_DEPLOYMENT_PLAN.md**, **DATABASE_CHANGES_FOR_PROVISIONING.md**, **LEGACY_PBX_EXTENSION_CREATE_REFERENCE.md**. Generator: `genAst.sh` → `runAstGen.php` → GenClass (genPjsipPhones, genPjsipWebrtc); endpoint files created on demand when generator runs.

---

## 9. nginx / API HTTP layer (status)

**Confirmed:** pbx3 **does not install Apache**. HTTP/API is **pbx3api** (nginx + PHP-FPM). TLS/LE in **pbx3**; fleet nodes use trusted LE on **:44300**.

**fail2ban (Phase 3, 2026-05-30):** `jail.d/pbx3-jails.conf` + `pbx3-api.conf` (not `jail.local` — Ubuntu 24.04). Jail **`pbx3-api-badbots`** uses **`apache-badbots`** filter on nginx `access.log` (noble has no `nginx-badbots`). Deb **0.0.3-15** on **`main`**.

**References:** `APACHE_CONFIG_TO_PBX3API.md`, `PBX3API_INSTALLER_NGINX_ADDITIONS.md`, `etc/fail2ban/README`.

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
