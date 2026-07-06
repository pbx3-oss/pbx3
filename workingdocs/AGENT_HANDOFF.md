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

- **Git:** `pbx3-master/` is not a repo. Commit from **`pbx3/`**, **`pbx3api/`**, **`pbx3spa/`**, or **`pbx3cagi/`** as appropriate.
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
| Fleet / S3 catalog / onboard | **pbx3-directory/docs/IMPLEMENTATION_PLAN.md** § **S8** → **`OPERATOR_MAC_SETUP.md`** (Mac SSH + AWS CLI) → **REBUILD_INSTANCE_RUNBOOK.md** → **`SELF_SERVICE_REBUILD_DESIGN.md`** (S8.9 + **Mode 4 agent-assisted**) → **NEW_INSTANCE_CHECKLIST.md** → **INSTANCE_ONBOARDING.md** → **OPS_S3_RUNBOOK.md**; tools **`onboard-fleet-instance.sh`**, **`fetch-latest-instance-backup.sh`** |
| **Agent-assisted fleet rebuild** | **`REBUILD_INSTANCE_RUNBOOK.md`** (kickoff prompt) → **`SELF_SERVICE_REBUILD_DESIGN.md`** § Mode 4 → **`OPERATOR_MAC_SETUP.md`** |
| Call recordings | **`IMPLEMENTATION_PLAN.md`** § **Phase R1** (local SPA/API) → **Phase S7** (S3 offload) |
| SPA GitHub Pages (S6.2) | **pbx3-directory/docs/OPS_S3_RUNBOOK.md** § 9; **pbx3spa** `.env.production` / CI; verify S3 + **each node API CORS** for Pages origin |

**Source of truth:** Schema and code. Verify against pbx3 db_sql and code when changing behaviour; workingdocs may be outdated.

---

## Next agent session notes (2026-07-06, session end)

**Branch:** **`main`** in **pbx3**, **pbx3api**, **pbx3spa**, **pbx3cagi**.

### Shipped this session

| Item | Notes |
|------|--------|
| **Snapshots backlog** | **S9.5–S9.7** in **`IMPLEMENTATION_PLAN.md`** + TODO open item — **`ea34c69`** pushed |
| **Backup retention Q&A** | Local prune is **count FIFO (9)**, not time-based; **local+S3** is expected until 10th local backup; S3 lifecycle **30d** — see **`DESIGN_RULES.md`** § option C, **`LocalBackupRetention`** |

### Golden (production)

| Field | Value |
|-------|--------|
| EC2 | `i-02ec2b05b5baacb5d` · `54.236.153.81` |
| FQDN | `08jzwn.pbx3.com` |
| KSUID | `3DmAsxePTWQZgynBYXE8obIRqEE` |
| IAM | `pbx3-node-08jzwn` |
| Latest backup | `20260706T001010Z` / `pbx3bak.1783296610.zip` — **local+S3** (normal with fewer than 10 local zips) |

### Resume

1. **S8.5–S8.6** — tenant migration runbook + export/import.
2. **R1** — call recordings API + SPA panel.

**SPA dev:** **`https://08jzwn.pbx3.com:44300/api`** at login, or **`VITE_API_PROXY_TARGET`** to golden.

**Open items:** **`TODO.md`**. **SPA:** **`pbx3spa/workingdocs/SESSION_HANDOFF.md`**.

---

## Next agent session notes (2026-07-06, drill complete) — historical

**Branch:** **`main`** in **pbx3**, **pbx3api**, **pbx3spa**, **pbx3cagi**.

### Shipped / validated this session

| Item | Notes |
|------|--------|
| **S8 rebuild drill #2** | Lab `i-09b5e1853b40f10db` → restore `20260706T001010Z` → onboard → preflight → SPA OK; lab terminated |
| **Golden restored** | Re-onboard `i-02ec2b05b5baacb5d`; IAM + S3 smoke on production |
| **Runbook** | Phase 1: `apt upgrade`, `ssmtp` before pbx3 — **`15c5e9b`** on **`main`** |
| **Package** | **`pbx3 0.0.3-21`** (restore + hostname sync) |

### Golden (production)

| Field | Value |
|-------|--------|
| EC2 | `i-02ec2b05b5baacb5d` · `54.236.153.81` |
| FQDN | `08jzwn.pbx3.com` |
| KSUID | `3DmAsxePTWQZgynBYXE8obIRqEE` |
| IAM | `pbx3-node-08jzwn` |

### Resume

1. **S8.5–S8.6** — tenant migration runbook + export/import.
2. **R1** — call recordings API + SPA panel.

**SPA dev:** log in with **`https://08jzwn.pbx3.com:44300/api`** or set **`VITE_API_PROXY_TARGET`** to golden; Home IPs are under **System info → Network** (not the page title).

**Open items:** **`TODO.md`**. **SPA:** **`pbx3spa/workingdocs/SESSION_HANDOFF.md`**.

---

## Next agent session notes (2026-07-06, morning) — historical

**Branch:** **`main`** in **pbx3**, **pbx3api**, **pbx3spa**, **pbx3cagi**. **`s8build`** merged and deleted (pbx3 + pbx3api).

### Shipped (S8.1–S8.4)

| Item | Location |
|------|----------|
| Rebuild runbook | **`pbx3-directory/docs/REBUILD_INSTANCE_RUNBOOK.md`** |
| Mac SSH/AWS guide | **`pbx3-directory/docs/OPERATOR_MAC_SETUP.md`** |
| Fetch latest S3 backup | **`pbx3-directory/tools/fetch-latest-instance-backup.sh`** |
| Node restore + hostname sync | **`pbx3-1/opt/pbx3/scripts/restore-backup-zip.sh`**, **`sync-hostname-from-globals.sh`** |
| Onboard hardening | **`pbx3-directory/tools/lib/onboard-common.sh`** |
| Fleet preflight | **`pbx3api`** — `pbx3:fleet-preflight`, **`FleetPreflightService`** |
| Package | **`pbx3 0.0.3-21`** on **`main`** (`2e018f4`) — use for new lab install |

### Fleet reference (golden test, us-east-1)

| | Golden | Lab (drill) |
|--|--------|-------------|
| FQDN | `08jzwn.pbx3.com` | same identity after restore |
| KSUID | `3DmAsxePTWQZgynBYXE8obIRqEE` | |
| EC2 | `i-02ec2b05b5baacb5d` (`54.236.153.81`) | **terminated** `i-09272d75c5c410038` |
| Bucket | `08jzwn-pbx3` | |
| S3 backup (use) | `20260706T001010Z` | |

DNS still → golden. IAM **`pbx3-node-08jzwn`** on golden after lab teardown.

### Golden / operator follow-up

- Golden on **`0.0.3-21`** (user built/pushed). Optional `apt install` on golden if not already upgraded.
- Mac **`pbx3spa/.env.development`**: revert **`VITE_API_PROXY_TARGET`** to **`https://08jzwn.pbx3.com:44300`** if still pointing at old lab IP.

### Resume

1. Launch new lab EC2: **`t4g.micro`**, AMI **`ami-09f7444a9a9604198`**, SG **`sg-0dc14081063abb41f`**, key **`pbx3test`**, **no IAM profile**.
2. Phase 1 — `apt install ./pbx3_0.0.3-21_all.deb`, deploy pbx3api, installers, `/up` → 200.
3. Phases 2–4 per **`REBUILD_INSTANCE_RUNBOOK.md`** (same S3 backup; onboard with new instance id).
4. `pbx3:fleet-preflight` + SPA smoke via Vite proxy to new IP.

**Open items:** **`TODO.md`**. **SPA:** **`pbx3spa/workingdocs/SESSION_HANDOFF.md`**.

---

## Next agent session notes (2026-07-05, session end) — historical

**Branch:** **`main`** in **pbx3**, **pbx3api**, **pbx3spa**, **pbx3cagi**. Docs-only session; no code changes.

### This session

| Item | Notes |
|------|--------|
| **Phase 0** | User confirmed golden **`make test`** PASS (synthetic seed + live **`sqlite.rdonly.db`**) — already signed off in prior handoff |
| **SPA size review** | ~38k LOC; single bundle ~743 kB / ~183 kB gzip; runs fine on golden/LAN. **No changes** — efficiency deferred until **S8 / R1 / core panels** done |
| **SPA plan** | Deferred **Phase H** (lazy routes) + **Phase H2** (list/detail extraction) documented in **`pbx3spa/workingdocs/PROJECT_PLAN.md`**, **`PBX3SPA_CODEBASE_ANALYSIS.md`** |
| **Cleanup** | Deleted obsolete **`pbx3-master/ROLLBACK_NOTE.txt`** (Feb 2025 lowercase rollback; not in git) |

### Priority order (unchanged)

| # | Track |
|---|--------|
| **1** | **S8.1–S8.4** — fleet checklist, IAM/`.env` hardening |
| **2** | **R1** — call recordings management (API + SPA) |
| **3** | **S7** — recordings S3 offload |
| **4** | **S8.5–S8.6** — tenant migration + export/import |

### Resume

1. **S8.1–S8.4** — fleet ops.
2. **R1** — recordings API + **`sarkrecordings`** port.

**Open items:** **`TODO.md`**. **SPA:** **`pbx3spa/workingdocs/SESSION_HANDOFF.md`**.

---

## Prior session notes (2026-07-04, session end — Phase 0 complete)

**Branch:** **`main`** in **pbx3**, **pbx3api**, **pbx3spa**. Documentation session — fleet/SIP catalog policy, MkDocs content map, session-end checklist. CoS extension assignment completed next session (2026-07-03).

---

## Prior session notes (2026-07-02 — panel QA on `main`)

Queues (outcome/divert/greetnum), trunk field trim, route auth removed, globals/network tidy, **Site name** on Home, **extcode** help — merged **`panelfixes`** → **`main`**. Commits **`7d3bc3f`** (spa), **`428209f`** (api), **`ae06476`** (pbx3).

---

## Prior session notes (2026-05-30, Phase 4 pause — historical)

**Program:** **Track B Phase 4** merged to **`main`** with **`helptext`** (2026-05-30). Golden **08jzwn** carries **demo data** for field-help QA.

### Golden **08jzwn** (validated 2026-05-30)

| Item | State |
|------|--------|
| **Data** | Full DB restored from test instance (`vpqtc7`); **`globals`** patched to golden KSUID/FQDN; **`default`** tenant `fqdn` = `08jzwn.pbx3.com` |
| **Tenants** | `default`, `affcot`, `duns`, `sandycroft`, `willand` (+ DNS `{shortuid}.pbx3.com`) |
| **Packages** | **pbx3 0.0.3-16** (help SQL seeds), **0.0.3-17** (LE sync fix — drop certbot `--expand`) |
| **LE** | Five SANs on cert; use **Sync with tenant list** after tenant add/remove or restore (**Renew** only extends expiry) |
| **`tt_help_core`** | After restore: `sudo sqlite3 /opt/pbx3/db/sqlite.db < /opt/pbx3/db/db_sql/sqlite_message.sql` → **410** rows (package upgrade alone does not merge seeds) |

**Post-restore identity (do not run `reloader.sh`):** `UPDATE globals` (id, shortuid, fqdn, domain) + `UPDATE cluster … WHERE pkey='default'` + `normalize-globals-identity.sh`.

### Phase 4 field help (`helptext`)

| Done | Notes |
|------|--------|
| Audit tooling | `pbx3spa/scripts/audit-field-help.mjs` + **FIELD_HELP_COVERAGE_AUDIT.md** |
| Tier 1–2 gaps | **0** (373/456 fields with help; 73 remaining mostly Tier 3–4) |
| `tt_help_core` | ~30 new rows in **0.0.3-16** |
| LE / Certificates UX | Sync primary; mismatch warning; **`le-sync-cert-sans.sh`** replaces full SAN list |
| Tenant panel | **Mix monitor** removed from create/edit (obsolete `cluster.mixmonitor`) |

**Done (merged to `main`):** Operator walked Tier 1–2 demo panels on golden (**0.0.3-19**). **Deferred:** Backup/Certificates/Login help wiring; IVR dynamic keys; KSUID readouts; **`tt_help_core` cleanup** (230 unreferenced rows — see **`TODO.md`**).

**Fleet friction (S8 — planned):** Instance create/rebuild steps scattered; IAM + `.env` not preserved on rebuild; tenant move = `move-tenant.sh` only. See **`IMPLEMENTATION_PLAN.md`** § Phase S8, **`NEW_INSTANCE_CHECKLIST.md`**, **`TENANT_MIGRATION_RUNBOOK.md`**.

### Prior session (Track B 0–3 on `main`)

| Area | Notes |
|------|--------|
| **S5 backups** | Merged local+S3 index, presigned GET, rehydrate, lifecycle from `policy.json` — golden **08jzwn** |
| **S5 archive round-trip (bzy54n)** | S3-only restore from older backup removed added tenant/extension; restore from later backup brought them back |
| **S6 fleet** | Two-node catalog; SPA picker flips instances; dev proxies work |
| **S6.4 onboard** | `pbx3-directory/tools/onboard-fleet-instance.sh` (Mac IAM + SSH + catalog + node `.env`) |
| **S6.5 offboard** | `unregister-instance.sh`; SPA hides `status=decommissioned` (`pbx3spa` `1e06679`) |
| **S6 backup smoke (bzy54n)** | `pbx3:backup-run --trigger=manual` → S3 `20260526T230950Z` (8.2 MB zip + manifest); `meta.json` updated |
| **Track B Phase 1 TLS** | Both fleet nodes LE on `:44300`; bzy54n via Certificates **Get certificate** (2026-05-30) after DNS for tenant `wfh69h.pbx3.com` |
| **Track B Phase 2** | pbx3api `validate_install_health` in installer; golden rebuild validated (2026-05-30) |
| **Track B Phase 3** | fail2ban `jail.d` only (not `jail.local`); **`pbx3-api-badbots`** + **`apache-badbots`** filter; deb **0.0.3-15** on **`main`** |
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
| **Phase R1 recordings management** | Local list/play API + SPA (`sarkrecordings` port) — **`IMPLEMENTATION_PLAN.md`** § R1 — **priority #2** |
| **S7 recordings S3 offload** | After R1 (or parallel with S8.3 IAM) — **`IMPLEMENTATION_PLAN.md`** § S7 |
| **S8 fleet lifecycle + tenant move** | **`IMPLEMENTATION_PLAN.md`** § S8 — **priority #1** (S8.1–S8.4 first) |
| **Phase 5 install hook** | Registrar hint on postinst — optional |
| **Golden missing `pkey='default'` tenant** | **Superseded on golden** after test DB restore (now has `default` + four named tenants). Pre-migration layout (`f34ck1`/`5489nv` only) — see **TODO.md** if investigating provision path |

| **Fleet catalog vs SIP obscurity** | Public `catalog/instance-index.json` weakens FQDN obscurity layer — see **`DESIGN_RULES.md`** § SIP FQDN obscurity; Phase D private catalog for production MSP |

### Suggested next session pick (user preference order)

*Superseded by **§ Next agent session notes (2026-07-02)** → Suggested “what next?” order above. Retained for grep:*

1. ~~Phase 4 field help QA~~ — **done** (2026-05-30)
2. **Phase S8 fleet lifecycle** — instance checklist, IAM/`.env` preflight, tenant migration runbook + tooling
3. **Open-source org setup** — `OPEN_SOURCE_GITHUB_SETUP.md` (unblocks S6.2 hostname)

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
