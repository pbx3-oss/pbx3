# PBX3 ToDo list

**Branch:** **`main`** (S8.10 merged) — pbx3 **`79700ee`**, pbx3api **`0fb0019`**, pbx3spa **`c828fe0`**, pbx3sbc-admin **`6036bcb`**. Nodes/SBC still on prior `movewizard` deploy until pulled.  
**Last updated:** 2026-07-10 (S8.10 merged to main — live moves + interim gatekeeper auth)

### Suggested “what next?” order

1. **Pull `main` on nodes/SBC** if not already at fleet API tips (08jzwn / bzy54n `/opt/pbx3api`, sbc-admin).  
2. **Optional peering polish** — Phase 2 outbound failover; Phase 5 `alias_db`.  
3. **Ops runbook** — **`systemctl restart asterisk`** after egress / **`genAst.sh`**.  
4. **Fleet UI polish** (deferred) — dispatcher/Peers clarity; visuals after product harden.  
5. **Phase S7** — recordings S3 offload — **deferred**.  
6. **Snapshots UX + commit hook** — **`IMPLEMENTATION_PLAN.md`** § S9.5–S9.7  
7. **Egress availability & SBC failover (future)** — **`FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`**.  
8. **pbx3cagi** struct refactor (deferred) — **`REFACTOR_PLAN.md`**
9. **Full control-plane login** (future) — replace session-paste gatekeeper token with dedicated fleet auth tier.

---

## Open items

- [x] **S8.10 — interim gatekeeper auth harden (2026-07-10):** Production SPA must not bake `VITE_FLEET_GATEKEEPER_TOKEN`. Token from **sessionStorage** (Fleet tenants paste) or **DEV-only** Vite env. Gatekeeper README documents lab vs prod vs future control-plane login. Catalog reconcile: nodes/SBC aligned; added missing SBC domain **sandycroft** `vqcwd4.pbx3.com` setid 2.

- [x] **S8.10 — live panel moves + phone POC (2026-07-10):** **willand** (`0ggybk`) 08jzwn→bzy54n job `tmj_bf41c7b45dfc97d72135faf1`. **affcot** (`9wvvnb`) bzy54n→08jzwn job `tmj_7efdc9646309ff3641d21839` — Snom followed SBC remount (setid 3→2); dest commit/`genAst` ran. Preflight gap: willand needed SBC `domain` row before move (added setid 2 then cutover). Linphone 1102 flaky — parked. **Merged to `main`** same day.
- [ ] **Fleet Egress availability & SBC failover (future — not Phase A lab):** Documented **`pbx3-directory/docs/FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`**. SBC must respond **OPTIONS** from fleet nodes so Egress qualify works; re-enable **`qualify_frequency`** on egress template; implement **EgressFailover** (or SRV) + **pbx3cagi** sequential dial; SPA/preflight trunk health. Lab workaround **`qualify_frequency=0`** (**`117340f`**) — do not treat as final.

- [ ] **Snapshots — separate panel, commit hook, FIFO retention (ops polish):** **Backups** (`backup.zip`, local 9 + S3 30d) and **snapshots** (`sqlite.db` copies in `/opt/pbx3/snap/`) are different jobs but share **`BackupView.vue`** — long backup lists push snapshots below the fold. **Gap:** legacy **`snap.sh`** is a stub; SPA **`GET syscommands/commit`** runs `genAst.sh` + reload but does **not** call **`create_new_snapshot()`** (legacy SARK took a snap on commit). **No snapshot FIFO** today (old “keep 9” in `snap.sh` commented out; backups have **`LocalBackupRetention`**). **Target:** **(1)** **pbx3spa** — `/snapshots` panel (extract from BackupView); **(2)** **pbx3api** — `create_new_snapshot()` after successful Commit; **(3)** **`SnapshotRetention`** (e.g. 9 newest, env `PBX3_SNAPSHOT_MAX_COUNT`); optional revive **`snap.sh`** or deprecate in favour of API. See **`IMPLEMENTATION_PLAN.md`** § **S9.5–S9.7**. **Priority:** after **R1** or parallel low-touch ops; not blocking fleet rebuild.

- [x] **Phase S8.10 — Fleet mobility scaffold (2026-07-10):** On **`movewizard`** then **`main`**: `tenant-move-job.v0.json`; gatekeeper presign + tenant-moves + phase runner; pbx3api `/api/fleet/*`; pbx3sbc-admin `/api/fleet` repoint; SPA Fleet tenants Move wizard + job view. Live moves + phone POC + interim auth harden. **Still open:** full control-plane login (future).

- [ ] **pbx3sbc — multi-tenant dispatcher reverse lookup:** Template + **`add-dispatcher.sh`** accept **`source_ip`** in dispatcher **`attrs`**. **Live:** golden **setid 2** (`54.236.153.81`), **bzy54n setid 3** (`98.82.174.36`); tenant domains on SBC. **Optional backfill:** hostname dispatcher rows (`sip:08jzwn.pbx3.com`) if needed. See **`opensips.cfg.template`** `route[GET_DOMAIN_FROM_SOURCE_IP]`.

- [ ] **Phase S8 — Fleet (optional polish):** **S8.1–S8.6 shipped and drill-validated** (affcot **08jzwn → bzy54n**). Remaining optional: LE Sync post-cutover; **`move-tenant.sh`** if catalog workflow preferred over **`register-tenant.sh`** for first-time tenants. See **`TENANT_MIGRATION_RUNBOOK.md`**.

- [ ] **Phase S7 — Recordings S3 offload (priority #1):** Dedicated **`PBX3_RECORDINGS_BUCKET`** (not org/catalog bucket); async upload; presigned play; PCI controls (§6.2–6.3); SQLite `s3_key`. After R1.5 + gatekeeper presigns. **`RECORDINGS_STORAGE_DESIGN.md`** §7 S7; defer S7+.3 PSP handoff until customer need.

- [ ] **OSS org + repo registry:** Create GitHub org per **`OPEN_SOURCE_GITHUB_SETUP.md`** (e.g. `github.com/pbx3`). **Stay multi-repo** — transfer **`pbx3`**, **`pbx3api`**, **`pbx3spa`**, **`pbx3cagi`**; add **`pbx3-docs`** later. Maintain **`REPOS_AND_RELEASES.md`** (inventory, remotes, compatibility matrix). Update local clone remotes; keep **`pbx3-master/`** holding-folder layout. Tag first aligned release row in compatibility matrix when cutting public release.

- [ ] **User guides — MkDocs site (`pbx3-docs`):** Published **installer + admin** how-tos (MkDocs Material + GitHub Pages), **not** developer docs. **`workingdocs/`** stays for humans/AI implementers. **Content map:** **`USER_GUIDES_MKDOCS_CONTENT_MAP.md`** (nav tree, page inventory, P1–P3 priorities, promote-from-workingdoc table). **Phase 1:** new repo, fix top-level **`nav:`** in `mkdocs.yml`, CI like **`sail6-docs`**. **Phase 2:** P1 pages (install, TLS, login, backup). **Phase 3+:** admin guide from demo script; fleet chapter after S8. Target URL: `docs.pbx.com` (or org Pages). Do not auto-publish `SESSION_HANDOFF`, audits, or `DEV_ENVIRONMENT.md`.

- [ ] **pbx3cagi refactor (deferred — after S8 + R1 underway):** Phase 0 harness **golden-signed-off** on **08jzwn** (synthetic seed + `/opt/pbx3/db/sqlite.rdonly.db`; all CFIM scenarios PASS). **Do not start Phase 1.1+ struct refactor** until fleet/recordings momentum established; run **`make test`** after each refactor step when resumed. Gate: **`REFACTOR_PLAN.md`**, **`TEST_HARNESS.md`**, **`TEST_RECIPE.md`**.

- [x] **Fleet S3 node IAM (§2.6.1 — 2026-07-07):** Dropped blanket **`tenants/*`** from **`pbx3-node-s3-writer.policy.json.tmpl`** + golden/bzy54n policy JSON; **`OPS_S3_RUNBOOK.md`** §3.1 / §7.1 updated. **`FleetPreflightService`** deny probe (`S3 tenants/* denied`). Future recordings/staging via control-plane presigns. Apply live policies with **`apply-node-s3-writer-policy.sh`** on fleet nodes.
 Legacy ingress relies on **`fqdninspect`** (SIP INVITE URI string match on **5060**); dialable FQDNs are usually **not published** (sniffing/DNS can still expose them). Public **`catalog/instance-index.json`** aids admin discovery but can weaken that obscurity layer — **not** the same as Sanctum/API risk. **Policy:** v0/golden OK with eyes open; production MSP fleets → **Phase D private catalog** (auth-gated `GET` or signed URLs); minimize tenant FQDN enumeration in public JSON; use **`label`** + opaque **`id`**. See **`pbx3-directory/docs/DESIGN_RULES.md`** § *SIP FQDN obscurity vs public catalog*; **`OPS_S3_RUNBOOK.md`** § 5.3.

- [ ] **Golden `pkey='default'` layout (investigate, low priority):** Pre-migration golden had only `f34ck1`/`5489nv` (node FQDN on `globals` only). Test instance uses **`default`** tenant row with `cluster.fqdn` = node FQDN. Post-restore golden matches test layout. Question: does SPA tenant-create-only provisioning ever skip creating `default`?

- [ ] **pbx3api astamis `PJSIPShowEndpoint/{id}`:** Calling `GET .../astamis/PJSIPShowEndpoint/{id}` returns `AMI Action invalid or unsupported` because **`AstAmiController::$eventList` only whitelists `PJSIPShowEndpoints` (plural)** — singular action never reaches Asterisk. **Follow-up when implementing:** (1) Allow `PJSIPShowEndpoint` (dedicated route/method like other `eventItem` actions, or extend `getlist` with a special case). (2) AMI body must include **`Endpoint: {id}`** (not only `Action:`). (3) Do not use plain `amiQuery()` for this action — use **`amiPjsipShowEndpointForLive()`** or **`amiQueryUntilComplete()`** and return structured JSON or raw response as needed. (4) Document in `astamis` index (`GET astamis`) if exposed.

- [ ] **LDAP — overall strategy deferred (kicked down the road):** How LDAP is provisioned/used across instance vs tenant is **not yet decided**; parking all LDAP work until a design is chosen. Known loose ends to fold in when picked up: **(1)** the config-source mismatch below (LDAPHelperClass vs `globals`/`cluster`); **(2)** backup export writes **`/tmp/pbx3.local.ldif`** and fails with `Permission denied` when the file is owned by another user (seen on golden scheduled `pbx3:backup-run` — backup still completes/uploads; ldif export is skipped). Fix ownership/tmp path (per-run temp file or `/opt/pbx3` scratch) and decide whether LDAP data belongs in the backup at all. See `create_new_backup()` LDAP dump step.

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

- [ ] **SPA hygiene (deferred — after S8 / R1 / core panels):** No work until functionality complete; runs fine on golden/LAN today. Then: **(1)** route lazy-loading in **`router/index.js`**; **(2)** extract shared list/detail patterns when adding panels (avoid new 600+ line views). See **`pbx3spa/workingdocs/PROJECT_PLAN.md`** § Current state, **`PBX3SPA_CODEBASE_ANALYSIS.md`** § Phase H / H2.

- [ ] **SARK V6 migration routines (revisit, low priority — end of list):** Golden demo data still had tenant-scoped **`cluster`** on pkey (e.g. `affcot`) because **`sqlite_fixRi.sql`** was never applied; new SPA/API writes use shortuid, which broke joins (CoS on extensions). Shipped interim repair: **`sqlite_normalize_cluster_to_shortuid.sql`** (idempotent; **pbx3 0.0.3-20**). **Later revisit:** full **`db_legacy_sql`** path (`sqlite_create_legacy.sql`, **`sqlite_fixRi.sql`**, lineio, etc.) — ensure import always runs fixRi (or the normalize script), document operator steps, cover tables fixRi omits (`dateseg`, `holiday`, `page`, `users`, CoS junctions), and decide whether fixRi stays one-shot-only with normalize as the supported repair. Do not run stock fixRi on mixed DBs (NULLs shortuid rows).

---

## Completed / deferred

- [x] **pbx3 0.0.3-25 Egress identify (2026-07-10):** Built/pushed **`1bed066`**; installed on **08jzwn** + **bzy54n**. Template `type=identify` + `endpoint=` + `username,ip,anonymous`; seed `privileged=NO`.

- [x] **SBC peering Phases 3–4 lab (2026-07-10):** Magrathea inbound DID **`01924918076`** → golden **1000**; CLI E.164 OK; hangup both ways (`record_route` on `FROM_CARRIER`); Active Calls shows two legs (`create_dialog` on peering). **Gotchas fixed:** skip `FROM_CARRIER` when source is fleet Asterisk; Egress `type=identify` + `endpoint=` + `username,ip,anonymous`. **pbx3sbc** **`b914e1c`**, **pbx3sbc-admin** Peers/Number routes **`138d65d`**, **pbx3** identify **`3af4519`** / deb **0.0.3-25**.

- [x] **Merge `fleet-phase-a` → `main` (2026-07-10):** Fleet repos on **`main`**; **pbx3 0.0.3-24** / **pbx3cagi 1.0.0-4** installed on nodes earlier in session; **0.0.3-25** later same day.

- [x] **bzy54n Linphone softphone (2026-07-10):** Registered on **bzy54n** with no issues; makes and receives calls across the SBC.

- [x] **Phase A fleet egress + PSTN lab (2026-07-09):** **08jzwn** + **bzy54n** — register, ext-to-ext, PSTN outbound via **Egress** → SBC → test carrier. **`qualify_frequency=0`**, routes → **Egress**, **`117340f`/`ded9b76`**. **SBC peering Phase 0–2** live (**`8c702fb`**). **Ops:** **`systemctl restart asterisk`** after egress template change (not **`pjsip reload` alone**).

- [x] **bzy54n standup + affcot phone (2026-07-09):** SBC dispatcher **setid 3** + domains **`9wvvnb`/`wfh69h`**; Snom register auth **`59507r`** (not ext **1101**); PSTN **`01924918076`** validated.

- [x] **Phase A fleet egress live on 08jzwn + bzy54n (2026-07-09):** **`seed-fleet-egress-trunk.sh`**, fleet `.env`, **pbx3cagi 1.0.0-4**, **`pbx3:fleet-preflight`** all green. **pbx3** egress PJSIP fix **`67d2376`** on **`fleet-phase-a`** (hot-patched on nodes). Golden **pbx3cagi** dirs consolidated under **`~/Git/pbx3cagi`**.

- [x] **SBC soak + admin (2026-07-09):** Golden + SBC reboot; phones register and call. **pbx3sbc** REGISTER/NAT on **`main`** **`1d9433d`** (live config persisted). **pbx3sbc-admin** profile + password change **`4282261`** deployed on **`sbc.pbx3.com`**.

- [x] **Fleet egress + B′ scaffold merged to `main` (2026-07-09):** **`fleet-egress`** fast-forwarded in **pbx3** **`9a25470`**, **pbx3api** **`2e25076`**, **pbx3spa** **`308af87`**, **pbx3cagi** **`9fe15e2`**, **pbx3sbc** **`d84c192`**. **Pulled live:** **08jzwn** + **bzy54n** `/opt/pbx3api`; **sbc** `/home/ubuntu/pbx3sbc` (SSH key **`opensips.pem`**). **`pbx3:fleet-preflight`** fails only on missing **Egress** trunk (expected until seed).

- [x] **pbx3sbc — inter-extension calling via SBC (2026-07-08):** **`pbx3sbc` `8174dfe`** on **`main`**. **`sbc.pbx3.com`** + tenant **`dhbm8x.pbx3.com`** → Golden **`08jzwn`**. Fixes: INVITE NAT (`received`), Yealink 401/407 relay, Snom `line=` on NAT rewrite, single-tenant dispatcher fallback. Snom 1000 + Yealinks 1001/1002 all directions. Live server hot-patched; PSTN peering not tested. **`pbx3sbc/workingdocs/QUICK-START.md`**.

- [x] **Phase R1.5 — Recordings local archive + SQLite index (2026-07-07):** **pbx3api** **`27ff302`…`f5237de`** + **pbx3** **`ac2d90a`/`a8c9cb2`/`efdc78a`** (`0.0.3-23`). Offload spool → `{tenant}/{yyyy}/{mm}/{dd}/`; `recordings` table + index on offload; retention (`recmaxage`, `rec_grace`, `recmaxsize`, `recused`); API SQLite-first + spool fallback. Cron: **`/etc/cron.d/pbx3-recordings`** (offload every 10 min, retain daily 02:30). Golden + **bzy54n** validated (list/play/archive; retention smoke on golden). **`rec_mount`** deferred (on-prem SAN/EFS corner case). **`pbx3api` installer** drops backup + recordings cron on install.

- [x] **Scheduled instance backups (2026-07-07):** Prior S3 backups were **SPA manual** (`GET /backups/new`). Installed **`/etc/cron.d/pbx3-backup`** on **08jzwn** + **bzy54n** (daily 02:00 `pbx3:backup-run`). Verified on golden (zip + S3 upload). LDAP ldif export logs `Permission denied` on `/tmp/pbx3.local.ldif` — non-fatal; see LDAP deferred item.

- [x] **Phase R1 — Call recordings management (2026-07-07):** **pbx3api** **`4f52853`** + **pbx3spa** **`ea0fefc`** on **`main`** (`r1` merged). `GET /recordings`, stream/download; SPA Recordings panel (filters, tenant name, play/download). Golden smoke: tenant **duns** on **08jzwn** (`/var/spool/asterisk/monitor`). **`RECORDINGS_STORAGE_DESIGN.md`** — storage/search/ageing/PCI shape for R1.5/S7.

- [x] **S8.10 fleet mobility + stakeholder docs (2026-07-07):** **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** (panel-first move, SBC cutover, control-plane + S3 gatekeeper, gotchas, §13 implementer readiness) + **`FLEET_SYSTEM_OVERVIEW.md`** (stakeholder intro). **`IMPLEMENTATION_PLAN.md`** S8.10 row updated; **`pbx3-directory/README.md`** pointer.

- [x] **S8.5–S8.6 tenant migration + fleet packages (2026-07-07):** **`s8-tenant-move` → `main`** (pbx3 **`9076e9e`/`e4f9a88`**, pbx3api **`a7cb907`**). **`pbx3 0.0.3-22`** deb on **`main`** (postinst **runLinker**); **`pbx3cagi 1.0.0-3`** sailhpe **`_all.deb`**. Golden + **bzy54n** on **`main`** API; affcot live on bzy54n. Node updates: **`git pull`** — avoid **`scp`** into `/opt/pbx3api`.

- [x] **Phase S8.5–S8.6 tenant migration drill (2026-07-06):** **affcot** (`9wvvnb`) exported golden → imported **bzy54n**; DNS cutover; phone register + ext-to-ext calls; golden tenant removed; S3 catalog **`register-tenant.sh`** → bzy54n KSUID `3E3gAOVGBhvc6vEPTBIYCBPycIk`.

- [x] **pbx3cagi 1.0.0-3 packaging (2026-07-06):** Sailhpe-style **`Architecture: all`** `_all.deb`; stage **`usr/share/asterisk/agi-bin/pbx3cagi.{amd64,arm64}`** at package root; no compile in **`debuild`**. **`bf8774e`** on **`main`**.

- [x] **Snapshots backlog (S9.5–S9.7, 2026-07-06):** Separate SPA panel, snapshot-on-commit, FIFO retention — open item + **`IMPLEMENTATION_PLAN.md`** rows; **`ea34c69`** on **`main`**.

- [x] **Phase S8 rebuild drill #2 (2026-07-06):** Lab **`i-09b5e1853b40f10db`** (`54.144.41.8`) — Phase 1 **`0.0.3-21`**, restore **`20260706T001010Z`**, onboard, **`pbx3:fleet-preflight`** green, SPA smoke (login with lab API URL). DNS/LE not tested (by design). Lab terminated; golden **`i-02ec2b05b5baacb5d`** re-onboarded (IAM + S3 smoke).

- [x] **Phase S8.1–S8.4 — fleet rebuild tooling (2026-07-05/06):** **`s8build` → `main`** (pbx3 + pbx3api); branch deleted. Runbook, Mac ops, S3 fetch + node restore + hostname sync, onboard hardening, **`pbx3:fleet-preflight`**. **`pbx3 0.0.3-21`** on **`main`**.

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
