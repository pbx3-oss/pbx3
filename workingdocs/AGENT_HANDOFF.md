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

- **Git:** `pbx3-master/` is not a repo. Commit from **`pbx3/`**, **`pbx3api/`**, **`pbx3spa/`**, **`pbx3cagi/`**, or **`pbx3sbc/`** (SBC edge, moved into holding folder 2026-07-07) as appropriate.
- **Fleet / S3 / directory:** on **`main`**. **Track B** Phases 0–4 Tier 1–2 + **panelfixes** panel QA merged to **`main`** (2026-07-02). Branches **`helptext`**, **`panelfixes`**, **`directory`** deleted.
- **Multi-repo tasks:** state which repo each change belongs in; don’t assume a single root commit.

**Session end:** When the user says **`session end`**, **`end session`**, or **`update handoff`**, follow **`SESSION_END_CHECKLIST.md`** (update **`TODO.md`**, this file’s **Next agent session notes**, and **`pbx3spa/workingdocs/SESSION_HANDOFF.md`** only).

---


## Read order by task

| Task | Read (in order) |
|------|------------------|
| Any / first time | This file (**§ Next agent session notes**), then TODO.md |
| **Session end** (user request) | **SESSION_END_CHECKLIST.md** → update TODO.md + this file + **pbx3spa/SESSION_HANDOFF.md** |
| **New session** (user request) | This file § **Next agent session notes** → TODO.md → **pbx3spa/SESSION_HANDOFF.md** (top block); **`SESSION_END_CHECKLIST.md`** § new session |
| **Track B — release hardening** | **TRACK_B_RELEASE_HARDENING.md** → **STAKEHOLDER_DEMO_SCRIPT.md** → TODO.md → TLS_IMPLEMENTATION_STEPS.md §4.3 |
| New GitHub org / OSS | **OPEN_SOURCE_GITHUB_SETUP.md** → **REPOS_AND_RELEASES.md** |
| Install / deploy | INSTALL_SEQUENCE_UBUNTU.md (pbx3 then pbx3api on Ubuntu 24.04) |
| Cleanup / installer | CLEANUP_PLAN.md, APACHE_CONFIG_TO_PBX3API.md, PBX3API_INSTALLER_NGINX_ADDITIONS.md |
| Schema / DB | DB_PBX3_VS_PBX3API_VARIANCE.md; for API alignment see pbx3api/workingdocs/PLAN_MODELS_AND_VALIDATION_HARMONISATION.md |
| TLS / certificates | **TLS_AND_CERTIFICATES.md** (index) → **TLS_IMPLEMENTATION_STEPS.md** (linear checklist) → **CERTIFICATES_PANEL_AND_API.md** → **LETSENCRYPT_PER_TENANT_FQDN.md** (**Option A** spec + §11–§12). **pbx3spa**/workingdocs has stubs pointing here. |
| SPA admin (Vue shell, layout) | **pbx3spa**/workingdocs/**SESSION_HANDOFF.md** (Quick start), **SPA_SHELL_ROADMAP.md** |
| **Instance user privileges** | **pbx3spa**/workingdocs/**INSTANCE_USER_PRIVILEGES_REQUIREMENTS.md** (P1–P4 + **B′ login homing** shipped) → **ADMIN_PANELS_AND_PERMISSIONS.md** → **AUTH_PATTERNS.md** |
| Fleet / S3 catalog / onboard | **pbx3-directory/docs/FLEET_SYSTEM_OVERVIEW.md** (stakeholder intro) → **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** (S8.10, §2.5 one SPA / two modes + control plane, §13 implementer map) → **IMPLEMENTATION_PLAN.md** § **S8** → **`OPERATOR_MAC_SETUP.md`** (Mac SSH + AWS CLI) → **REBUILD_INSTANCE_RUNBOOK.md** → **`SELF_SERVICE_REBUILD_DESIGN.md`** (S8.9 + **Mode 4 agent-assisted**) → **`LAB_FLEET_TENANTS.md`** (no node-only lab tenants) → **`GREENFIELD_FLEET_INSTANCE_INSTALL.md`** (EC2 → packages → onboard, step-by-step) → **NEW_INSTANCE_CHECKLIST.md** → **INSTANCE_ONBOARDING.md** → **OPS_S3_RUNBOOK.md**; tools **`onboard-fleet-instance.sh`**, **`reconcile-node-tenants.sh`**, **`fetch-latest-instance-backup.sh`** |
| **Asterisk after Egress / genAst** | **`OPS_ASTERISK_AFTER_EGRESS_GENAST.md`** — full restart vs pjsip reload |
| **Ast config generator + CAGI cleanup** | **`AST_CONFIG_GENERATOR_SUBPROJECT.md`** (one track: staging/overlay + GenAst↔CAGI contract) → **pbx3cagi**/workingdocs/**`REFACTOR_PLAN.md`** → **`TEST_RECIPE.md`** |
| **Time-based routing (day-parts)** | **`TIME_BASED_ROUTING_REQUIREMENTS.md`** — requirements draft; implement after §8 lock; before CAGI Phase 4 |
| **Tenant short dial (cross-tenant)** | **`TENANT_SHORT_DIAL_REQUIREMENTS.md`** — §8 locked; implement slices A–F when scheduled; 2nd SIPp phone host at alias lab |
| **Fleet-first tenant create** | **`FLEET_TENANT_CREATE_REQUIREMENTS.md`** — policy locked; implement when scheduled |
| **Call / SIP testing (SIPp)** | **`CALL_TYPE_INVENTORY.md`** → **`CALL_TEST_STRATEGY.md`** → recipes **[aelintra/sipplabs](https://github.com/aelintra/sipplabs)** (`AGENTS.md` / `workingdocs/TODO.md`) · **`TEST_CADENCE.md`** · **`CRITICAL_PATH_TEST_PACK.md`** Pack B · CAGI L0 **`TEST_RECIPE.md`** · pbx3 stub **`call-tests/README.md`** only |
| **Fleet mode UX** (future) | **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §2.5, §4 — one SPA, two modes; separate control-plane API; lab peer-nav → mode swap |
| **Failover + shadowing** (parked) | Edge HA: **`SBC_HA_FAILOVER_REQUIREMENTS.md`**. Instance shadow SKU framing: **`INSTANCE_SHADOWING_REQUIREMENTS.md`** (same mechanics, paid twin) |
| **Fleet egress lab rollback** (2026-07-09) | **`FLEET_EGRESS_LAB_ROLLBACK.md`** — git tags, revert steps, SBC/golden/SPA recovery |
| **SBC HA (VIP/EIP promote)** | **`SBC_HA_FAILOVER_REQUIREMENTS.md`** — requirements locked; implement later |
| **Edge portability (Rule 7 debt)** | **`EDGE_PORTABILITY_SCORECARD.md`** — adapter vs OpenSIPS vocabulary leaks |
| **SBC product tracks & roadmap** | **`SBC_PRODUCT_TRACKS.md`** — A/B/C posture + capability gaps (SIP TLS, media mode, registration-edge, …); WebRTC committed |
| **Fleet Egress availability** | **`FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`** — R1+R2 shipped; R3 EgressFailover/cagi parked |
| **Ops failure notification** | **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** — probe+SMTP + lifecycle + misconfig + move-job + Fail2ban ban + **Egress Unavail** shipped; SPA badges later |
| **Toll fraud / velocity** | **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`** — V1–V5 fleshed (fixture-first, batch CDR, `active=NO` act); competitive notes |
| **WebRTC / WSS (demo)** | **`WEBRTC_WSS_LAB.md`** (golden `:8089` baseline) → **`FLEET_TRUNK_PEERING_DECISION.md`** §6.1 → **`SBC_PRODUCT_TRACKS.md`** · IMPLEMENTATION_PLAN **W1** |
| **PSTN number dialects** | **`NUMBER_DIALECT_REQUIREMENTS.md`** → MkDocs **`fleet/number-dialect`** → Peer dialect + OpenSIPS `DIALECT_*`; node Egress transform = DNID/`+CC` by serving country (Model A status quo) |
| **Number wire standard (open)** | **`NUMBER_WIRE_STANDARD_DRAFT.md`** + research **`CARRIER_NUMBERING_EXPECTATIONS_RESEARCH.md`** — PTT “dial as dialled / upstream fixes”; Model B open |

| **Log retention / SIP capture** | **`FLEET_LOG_RETENTION_REQUIREMENTS.md`** — Phases 1–6 done; **`SBC_DATA_RETENTION_REQUIREMENTS.md`** — aging WS0–WS4 **done** (lab); **`SBC_BACKUP_RESTORE_REQUIREMENTS.md`** — SBC DR **v1 done** (scripts + scratch drill + MkDocs) |
| **Downstream peer REGISTER (future)** | **`DOWNSTREAM_PEER_REGISTRATION_REQUIREMENTS.md`** — separate registration-edge instance class; no shared OpenSIPS image; interim Asterisk-proxied workaround only |
| **Agent-assisted fleet rebuild** | **`REBUILD_INSTANCE_RUNBOOK.md`** (kickoff prompt) → **`SELF_SERVICE_REBUILD_DESIGN.md`** § Mode 4 → **`OPERATOR_MAC_SETUP.md`** |
| Call recordings | **`RECORDINGS_STORAGE_DESIGN.md`** → **`IMPLEMENTATION_PLAN.md`** § **R1** (done) / **R1.5** / **S7** |
| **CDR timezone / Home “today”** | **`CDR_TIMEZONE_POLICY.md`** — local CDR vs Laravel UTC; near-term day buckets = node local; end-state UTC CDR + site TZ |
| **pbx3 0.0.4-1 + cagi + golden rebuild** | **`BUILD_PLAN_0.0.4.md`** → Mode 4 **`REBUILD_INSTANCE_RUNBOOK.md`** |
| SPA GitHub Pages (S6.2) | **pbx3-directory/docs/OPS_S3_RUNBOOK.md** § 9; **pbx3spa** `.env.production` / CI; verify S3 + **each node API CORS** for Pages origin |

**Source of truth:** Schema and code. Verify against pbx3 db_sql and code when changing behaviour; workingdocs may be outdated.

---

## Next agent session notes (2026-08-03 — package roll + bzy Magrathea)

**Branch:** **`main`** (pbx3, pbx3cagi, pbx3sbc, pbx3spa).

### Shipped (this continuous session arc)
- **Magrathea W1 lab green** (earlier): WSS on edge only; SIP UDP to homes; RTP bypass; desk↔WebRTC both ways; golden instance **8089 closed**.
- **Packages:** **pbx3 0.0.4-5** + **pbx3cagi 1.0.0-10** installed on **08jzwn**, **bzy54n** (`54.158.236.215`), **kildare**. Debs on `main` (`pbx3_0.0.4-5_all.deb`, `pbx3cagi_1.0.0-10_all.deb`).
- **bzy Magrathea ops:** Fail2Ban had banned new public IP — unbanned; **whitelist** `54.158.236.215/32`; **dispatcher setid 3** updated from stale `98.82.174.36` → `sip:54.158.236.215:5060` + `source_ip=…`; **ds_reload** OK.
- **SPA line test:** direction locked **`WSS_LINE_TEST_REQUIREMENTS.md`** (not implemented).

### Lab notes
- Edge WebRTC: `wss://sbc.pbx3.com:8089/ws` · shortuid **`8af9ee`** · tenant **`dhbm8x.pbx3.com`** · golden `~/webrtc-1500.env`.
- Open item still: domain setid drift for some name.com tenants (0ggybk/vqcwd4 setid=3 vs DNS→golden) — see TODO.
- Optional: golden dispatcher row still has no `source_ip` in attrs (setid 2 works by destination).

### Resume
- Wait for operator task. Backlog top: number-wire D1, SPA line-test implement, multi-AZ, fleet delete, etc.

---

## Next agent session notes (2026-08-03 — docs garden)

**Superseded for “read first”** by WebRTC WSS block above.

**Branches:** **pbx3** + **pbx3spa** docs only — **`main`**.

### Shipped
- **Handoff slim:** older session blocks → **`workingdocs/archive/AGENT_HANDOFF_HISTORY.md`** (pbx3) and **`pbx3spa/workingdocs/archive/SESSION_HANDOFF_HISTORY.md`**. Live files keep current block + permanent reference / Quick start.
- **TODO slim:** open items only in **`TODO.md`**; 157 closed rows → **`archive/TODO_DONE_LOG.md`**.
- **Maps:** pbx3 + SPA **workingdocs/README.md**; **SESSION_END_CHECKLIST** notes archive pointer (do not re-append history every session).

### Resume
- Product from TODO / number-wire D1 / etc. Wait for task.

---

## Next agent session notes (2026-08-02 — Kildare PSTN + Mangle + wire draft) — recent

**Superseded for “read first”** by 2026-08-03 WebRTC block; still the latest PSTN/Kildare product arc.

**Branches:** **pbx3cagi** **`502596e`** (Mangle fix **1.0.0-9** changelog), **pbx3** seed/docs + this handoff, **pbx3-docs** number-dialect seed order — **`main`**. Earlier same day: greenfield/route **`eb8961d`** / install tips.

**Lab:** golden **`08jzwn`** / EIP **`44.196.98.191`**. Magrathea VIP **`3.93.26.82`**. **Kildare:** `3.93.253.1` / `kildare.pbx3.com` / shortuid **`kildare`** / **`aelsip.pem`**. Tenant **`18c8z3`**. MainOut → Egress. DID **`+441924918076`** (inroute) / national **`01924918076`** on Brindley.

### Shipped
- **Mangle:** `sizeof(char*)` strlcat bug truncated UK transform to e.g. `+441924`. Fix = sized buffer. Changelog **1.0.0-9**; **hot binary on Kildare** (deb not rebuilt/packaged fleet-wide yet). Tips **pbx3cagi `502596e`**.
- **Egress seed:** transform **`00:+ 0:+44`** (00 before 0); re-seed rewrites inverted `0:+44 00:+`. **pbx3 `35a6c50`**.
- **Lab PSTN (ops, not all git):** Brindley peer host fixed (was EIP-hairpin); gwid1 **strip=2 / pri_prefix=0** for national face; Twilio off default gwlist (`1,20`); DID rule **21** prefix **`441924918076`** → gwid **100**; Kildare inroute pkey **`+441924918076`**; Brindley CPE context fixed by operator. **In+out OK on Kildare.**
- **Research / open design (not locked):** **`NUMBER_WIRE_STANDARD_DRAFT.md`**; **`CARRIER_NUMBERING_EXPECTATIONS_RESEARCH.md`** (PTT: PBX sends dialled digits; upstream owns network shape; Model A vs B). Operator leaning Model B / maybe.

### Golden / operator follow-up
- Package/deploy cagi **1.0.0-9** to golden when convenient (Kildare has hot binary; golden transform still often NULL → may not hit Mangle).
- Magrathea: prefer **named Brindley dialect** over long-term strip/prefix; Magrathea **407** if failover beyond Brindley.
- **Wire standard D1 open** — do not implement Model B without lock.
- WebRTC far-end blocked; clamp SG **8089** when done.

### Resume
- Product TODO (Fleet Delete / dial alias) or continue number-wire decision. Wait for task. Do not invent fleet token (**`INSTALL_NODE_SIMPLE` Act 2**).


---

## Session history (archived)

Older **Next agent session notes** (pre–2026-08-02 greenfield and earlier) live in **`archive/AGENT_HANDOFF_HISTORY.md`**. Do not re-append full history here — session end prepends a new **current** block only; optional move of superseded blocks into that archive when the live file grows again.

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

**Docs (in pbx3spa/workingdocs):** **EXTENSION_PROVISIONING_QUICKSTART.md** (start here), **EXTENSION_PROVISIONING_DEPLOYMENT_PLAN.md**, **DATABASE_CHANGES_FOR_PROVISIONING.md**, **OLD_SYSTEM_EXTENSION_CREATE_REFERENCE.md**. Generator: `genAst.sh` → `runAstGen.php` → GenClass (genPjsipPhones, genPjsipWebrtc); endpoint files created on demand when generator runs.

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
