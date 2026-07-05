# PBX3 ToDo list

**Branch:** **`main`** (pbx3, pbx3api, pbx3spa, pbx3cagi)  
**Last updated:** 2026-07-04 (golden Phase 0 harness signed off on **08jzwn**)

### Suggested “what next?” order

1. **Phase S8** — fleet rebuild / IAM + `.env` preflight / **`NEW_INSTANCE_CHECKLIST.md`** — then **S8.5–S8.6** tenant migration runbook + export/import  
2. **Phase R1** — call recordings **management** (API list/search/play + SPA panel; local disk first) — **`IMPLEMENTATION_PLAN.md`** § Phase R1  
3. **Phase S7** — recordings **S3 offload** (mirror backup upload pattern; IAM on same node role as S8.3)  
4. **pbx3cagi** — **Phase 1.3+ struct refactor deferred** until S8 + R1 underway (Phase 0 **golden-signed-off**) — **`REFACTOR_PLAN.md`**  
5. **Extension Runtime re-examine** — live SIP IP/latency when phones registered; **SWOCLIP** create/edit parity  
6. **`tt_help_core` cleanup** (230 rows) or **permissions Phase 1+**  
7. **Directory / central admin** — instance picker; Phase D private catalog for production MSP (`DESIGN_RULES.md`)  
8. **SARK migration routines** (end of list) — revisit `db_legacy_sql` import / fixRi path

---

## Open items

- [ ] **Phase S8 — Fleet instance lifecycle & tenant mobility (priority #1):** Consolidate instance (re)build (**`NEW_INSTANCE_CHECKLIST.md`**), harden **`onboard-fleet-instance.sh`** + IAM/`.env` preflight (**S8.1–S8.4** first), then **`TENANT_MIGRATION_RUNBOOK.md`** + export/import tooling (**S8.5–S8.6**). **Driver:** golden rebuild lost IAM + `.env`; backups invisible until fixed; tenant move is catalog-only today. See **`pbx3-directory/docs/IMPLEMENTATION_PLAN.md`** § Phase S8.

- [ ] **Phase R1 — Call recordings management (local-first, priority #2):** Operator list/search/play/download from on-node wav files under `/opt/pbx3/media/recordings/…`. **pbx3api:** `GET /recordings` (tenant, date range, caller/callee), stream/download endpoints. **pbx3spa:** port **`sarkrecordings`** panel (see **`SAIL65_PANEL_PORT_PLAN.md`**). Capture already works (`pbx3cagi` SetRecord + tenant config); **no S3 required** for R1 v1. Spec: **`IMPLEMENTATION_PLAN.md`** § Phase R1. **Defer:** bulk delete UI, per-user listen permissions, `recordings` catalog DB sync.

- [ ] **Phase S7 — Recordings S3 offload (priority #3):** Async PUT to `tenants/{shortuid}/recordings/media/…`, lifecycle tag, presigned play when local file aged off — mirror S5 backup pattern. Do after or parallel with R1 once **S8.3** IAM policy includes recordings prefix. Spec: **`IMPLEMENTATION_PLAN.md`** § Phase S7.

- [ ] **OSS org + repo registry:** Create GitHub org per **`OPEN_SOURCE_GITHUB_SETUP.md`** (e.g. `github.com/pbx3`). **Stay multi-repo** — transfer **`pbx3`**, **`pbx3api`**, **`pbx3spa`**, **`pbx3cagi`**; add **`pbx3-docs`** later. Maintain **`REPOS_AND_RELEASES.md`** (inventory, remotes, compatibility matrix). Update local clone remotes; keep **`pbx3-master/`** holding-folder layout. Tag first aligned release row in compatibility matrix when cutting public release.

- [ ] **User guides — MkDocs site (`pbx3-docs`):** Published **installer + admin** how-tos (MkDocs Material + GitHub Pages), **not** developer docs. **`workingdocs/`** stays for humans/AI implementers. **Content map:** **`USER_GUIDES_MKDOCS_CONTENT_MAP.md`** (nav tree, page inventory, P1–P3 priorities, promote-from-workingdoc table). **Phase 1:** new repo, fix top-level **`nav:`** in `mkdocs.yml`, CI like **`sail6-docs`**. **Phase 2:** P1 pages (install, TLS, login, backup). **Phase 3+:** admin guide from demo script; fleet chapter after S8. Target URL: `docs.pbx.com` (or org Pages). Do not auto-publish `SESSION_HANDOFF`, audits, or `DEV_ENVIRONMENT.md`.

- [ ] **pbx3cagi refactor (deferred — after S8 + R1 underway):** Phase 0 harness **golden-signed-off** on **08jzwn** (synthetic seed + `/opt/pbx3/db/sqlite.rdonly.db`; all CFIM scenarios PASS). **Do not start Phase 1.1+ struct refactor** until fleet/recordings momentum established; run **`make test`** after each refactor step when resumed. Gate: **`REFACTOR_PLAN.md`**, **`TEST_HARNESS.md`**, **`TEST_RECIPE.md`**.

- [ ] **Fleet catalog — SIP FQDN obscurity vs public S3 index:** Legacy ingress relies on **`fqdninspect`** (SIP INVITE URI string match on **5060**); dialable FQDNs are usually **not published** (sniffing/DNS can still expose them). Public **`catalog/instance-index.json`** aids admin discovery but can weaken that obscurity layer — **not** the same as Sanctum/API risk. **Policy:** v0/golden OK with eyes open; production MSP fleets → **Phase D private catalog** (auth-gated `GET` or signed URLs); minimize tenant FQDN enumeration in public JSON; use **`label`** + opaque **`id`**. See **`pbx3-directory/docs/DESIGN_RULES.md`** § *SIP FQDN obscurity vs public catalog*; **`OPS_S3_RUNBOOK.md`** § 5.3.

- [ ] **Golden `pkey='default'` layout (investigate, low priority):** Pre-migration golden had only `f34ck1`/`5489nv` (node FQDN on `globals` only). Test instance uses **`default`** tenant row with `cluster.fqdn` = node FQDN. Post-restore golden matches test layout. Question: does SPA tenant-create-only provisioning ever skip creating `default`?

- [ ] **pbx3api astamis `PJSIPShowEndpoint/{id}`:** Calling `GET .../astamis/PJSIPShowEndpoint/{id}` returns `AMI Action invalid or unsupported` because **`AstAmiController::$eventList` only whitelists `PJSIPShowEndpoints` (plural)** — singular action never reaches Asterisk. **Follow-up when implementing:** (1) Allow `PJSIPShowEndpoint` (dedicated route/method like other `eventItem` actions, or extend `getlist` with a special case). (2) AMI body must include **`Endpoint: {id}`** (not only `Action:`). (3) Do not use plain `amiQuery()` for this action — use **`amiPjsipShowEndpointForLive()`** or **`amiQueryUntilComplete()`** and return structured JSON or raw response as needed. (4) Document in `astamis` index (`GET astamis`) if exposed.

- [ ] **LDAP: LDAPHelperClass reads from `globals` but instance `globals` has no LDAP columns.**  
  Instance schema (`sqlite_create_instance.sql`) does not define `ldapbase`, `ldapou`, `ldapuser`, `ldappass` on `globals`. Those columns exist on the tenant `cluster` table (`sqlite_create_tenant.sql`).  
  **Action:** Either (1) have LDAPHelperClass read LDAP config from tenant `cluster` (e.g. for the current/default tenant), or (2) add LDAP columns to instance `globals` if LDAP is intended to be instance-wide.  
  **Current workaround:** Query uses `FROM globals LIMIT 1` with lowercase column names; empty-result guard avoids errors when columns are missing.

- [ ] **pjsipuser for extensions:** Address pjsipuser handling for extensions (PJSIP endpoint/user config, API/SPA and generator/templates as needed).
  It needs to expose the instance copy of the template and NOT the database column (although that might be an option).  TBD.
  Also, we need to settle the template handling of NAT, e.g. force_rport, Rewrite_contact. 

- [ ] **Extensions edit panel — Runtime section (re-examine):** Review **`ExtensionDetailView.vue`** Runtime block (cfim, cfbs, ringdelay; live SIP IP/latency via `GET extensions/{shortuid}/runtime`). Deferred until phones are registered on a test instance — cannot judge UX, live-data usefulness, or API behaviour without endpoints online. See **`pbx3spa/workingdocs/EXTENSIONS_LIVE_DATA.md`**, **`PANEL_PATTERN_DEPARTURES.md`** § Runtime subsection.

- [ ] **Inbound route panels — SWOCLIP (re-examine):** Review **`swoclip`** (Switch-On-CLIP) on inbound route create/detail panels — label vs help pkey **`swoclip`** (“SWOC?”), default **YES**, interaction with CLIP DDI routing (`pbx3cagi` reads `inroutes.swoclip`). Detail has **`FormToggle`**; create panel omits it today. Confirm field placement, parity create/edit, and whether UX matches operator expectations.

- [ ] **pbx3cagi — `maxin` / `maxout` call counters:** Fix concurrent-call limit enforcement in **`pbx3cagi/pbx3cagi-1.0.0/csource/pbx3cagi.c`**. Today only tenant **`maxin`** is loaded (`g_cluster_cfg.maxin_str`) and checked on inbound via `GROUP_COUNT(inbound)`; **`maxout`** is not enforced. Review counter semantics (inbound vs outbound scope, instance **`globals`** vs tenant **`cluster`** caps), comparison edge cases, and busy/reject behaviour. Validate against **`DBSTRUCT_SMOKE_CHECKLIST.md`** § ingress controls.

- [ ] **SPA session timeout (Instance Globals `sessiontimout`):** **`globals.sessiontimout`** is editable on **`SysglobalsEditView.vue`** (default **600** s) but the SPA does **not** auto-logout after that interval. Implement client-side idle/session expiry: read timeout from **`GET sysglobals`** (or auth bootstrap), reset on user activity, clear token and redirect to login when exceeded. Align with API token lifetime / revoke if needed. See **`pbx3spa/workingdocs/AUTH_PATTERNS.md`**.

- [ ] **User access privileges (SPA + API — Phase 1+):** Today the app is **admin-or-nothing** (`can('admin')` route guard; all API panel routes behind **`abilities:admin`**). **Phase 0 done** (minimal gate). **Deferred coordinated upgrade:** granular abilities (`view_*` / `edit_*`), tenant row-level scope (“allowed clusters”), per-route nav gating, API middleware alignment, and **admin user management panel** (create/edit users, assign privileges — API needs stronger user/privilege endpoints first). **Do not implement SPA Phase F in isolation** — ship **pbx3api** and **pbx3spa** together. See **`pbx3spa/workingdocs/ADMIN_PANELS_AND_PERMISSIONS.md`**, **`PERMISSIONS_MINIMAL_DEPLOY_PLAN.md`**, **`AUTH_PATTERNS.md`**, **`PROJECT_PLAN.md`** § admin user management; **`PBX3SPA_CODEBASE_ANALYSIS.md`** § Phase F.

- [ ] **tt_help_core cleanup — unreferenced rows (final pass):** Reverse audit found **230** `tt_help_core` rows with no SPA field help wiring (**`pbx3spa/scripts/audit-unreferenced-help.mjs`** → **`pbx3spa/workingdocs/HELP_UNREFERENCED_IN_SPA.md`**). Review each: retire legacy-only keys (e.g. DHCP server, factory-reset wizards, BLF bulk editor) vs keep for future panels. Re-run script after SPA changes; prune or rewire as needed. Pair with forward audit **`audit-field-help.mjs`** for missing help on live fields.

- [ ] **SARK V6 migration routines (revisit, low priority — end of list):** Golden demo data still had tenant-scoped **`cluster`** on pkey (e.g. `affcot`) because **`sqlite_fixRi.sql`** was never applied; new SPA/API writes use shortuid, which broke joins (CoS on extensions). Shipped interim repair: **`sqlite_normalize_cluster_to_shortuid.sql`** (idempotent; **pbx3 0.0.3-20**). **Later revisit:** full **`db_legacy_sql`** path (`sqlite_create_legacy.sql`, **`sqlite_fixRi.sql`**, lineio, etc.) — ensure import always runs fixRi (or the normalize script), document operator steps, cover tables fixRi omits (`dateseg`, `holiday`, `page`, `users`, CoS junctions), and decide whether fixRi stays one-shot-only with normalize as the supported repair. Do not run stock fixRi on mixed DBs (NULLs shortuid rows).

---

## Completed / deferred

- [x] **pbx3cagi Phase 0 — AGI test harness (2026-07-04):** Deliverables 0.1–0.8 on **`main`**. Synthetic **`minimal-tenant-seed.sql`**; CFIM local/external/none scenarios; **`make test`**; **`TEST_RECIPE.md`**. **Golden 08jzwn signed off:** default seed fixture and **`PBX3CAGI_SQLITE_DB=/opt/pbx3/db/sqlite.rdonly.db`** — all scenarios PASS. Gate cleared for Phase 1.1+ refactor when product priority allows.

- [x] **Golden operator QA — runtime / CFIM / GenAst / pbx3cagi (2026-07-04):** **`goldenQA` → `main`** merged and branch deleted (pbx3, pbx3api, pbx3spa, pbx3cagi). **pbx3api:** empty runtime cfim/cfbs allowed; AstDB keys under extension **shortuid**; native AMI **DBGet/DBPut/DBDel**; **DBGetResponse** `Val:` parse fix. **pbx3:** GenClass conference heredoc + **shortuid** for greetings/confBridge. **pbx3cagi 1.0.0-2:** **CFCheck** uses **`strlen(cfnum)`** (local divert no comfort tone); amd64 + arm64 binaries in deb install tree. Golden **08jzwn** validated: CoS, ext-to-ext, CFIM, runtime save/display, GenAst, local CFIM divert audio. **SWOCLIP** OK provisionally; Runtime live SIP/latency partial.

- [x] **Class of Service — extension assignment (2026-07-03):** Rules CRUD + editable **`defaultopen`** / **`defaultclosed`**; extension day/night CoS via **`GET/PUT extensions/{id}/cos`**; **`globals.cosstart`** on Instance Globals; help **`cosday`**, **`cosnight`**, **`cosopen`**, **`cosclosed`**, **`cosstart`**. Fixed cluster pkey/shortuid mismatch (normalize script + API aliases) and Cos model string **`pkey`** (was cast to `0`). Golden validated.

- [x] **Session-end handoff procedure (2026-07-02):** **`SESSION_END_CHECKLIST.md`** + **`.cursor/rules/session-end-handoff.mdc`** (pbx3, pbx3spa, workspace). User trigger: **`session end`** / **`New session — read handoff and summarize.`**
- [x] **User guides content map (2026-07-02):** **`USER_GUIDES_MKDOCS_CONTENT_MAP.md`** — MkDocs vs workingdocs split; P1–P3 page inventory (`67fe32a`).
- [x] **Phase 4 field help QA (2026-05-30):** Golden **08jzwn** demo path walked; Tier 1–2 wiring + Markdown help shipped (**0.0.3-19**). Forward audit: **`pbx3spa/scripts/audit-field-help.mjs`** → **`FIELD_HELP_COVERAGE_AUDIT.md`**. Remaining field gaps mostly Tier 3–4 / not-yet-built panels.
- [x] **Permissions Phase 0 (SPA admin gate):** `can('admin')`, route guard, optional nav gate — see **`pbx3spa/workingdocs/PERMISSIONS_MINIMAL_DEPLOY_PLAN.md`**. Phase 1+ deferred — see open item above.
- [x] **Golden demo data migration (2026-05-30):** Test DB → **08jzwn**; globals identity patch; tenant DNS; LE five-SAN cert; **`sqlite_message.sql`** applied for help rows.
- [x] **LE Sync drops removed tenant SANs (2026-05-30):** `le-sync-cert-sans.sh` no longer uses certbot `--expand`; deb **0.0.3-17**; SPA Certificates UX.
- [x] **Phase 4 Tier 1–2 help wiring + seeds (2026-05-30):** Audit script, `formHelpPkey.js`, **0.0.3-16** `tt_help_core` rows; Tier 1–2 audit gaps **0**.
- [x] **Unreferenced help reverse audit scripts (2026-05-30):** **`audit-unreferenced-help.mjs`** + **`HELP_UNREFERENCED_IN_SPA.md`** (230 rows); tenant-advanced parser fix in **`audit-field-help.mjs`**. Cleanup deferred — see open item above.
- [x] **TLS — fleet nodes (Track B Phase 1, 2026-05-30):** **08jzwn** + **bzy54n** trusted LE on `:44300`. **Remaining:** Pages/CORS when SPA is off localhost.
- [x] **pbx3api installer health checks (Track B Phase 2, 2026-05-30):** golden rebuild on **08jzwn** validated (install, restore, DNS, LE).
- [x] **pbx3 fail2ban → nginx (Track B Phase 3, 2026-05-30):** `jail.d/pbx3-jails.conf` + `pbx3-api.conf` (`pbx3-api-badbots`, **`apache-badbots`** filter, `/var/log/nginx/access.log`); no `jail.local` symlink (Ubuntu 24.04). Deb **0.0.3-15** on **`main`**. Validated on golden: sshd, asterisk, recidive, pbx3-api-badbots.
