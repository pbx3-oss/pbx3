# PBX3 ToDo list

**Branch:** **`main`** — S10.6–S10.8 complete; S10.7 parked; **pbx3-docs** live on aelintra Pages.  
**Last updated:** 2026-07-15 (session end — MkDocs `pbx3-docs` seed + Pages)

### Suggested “what next?” order

1. **Egress availability & SBC failover (future)** — **`FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`**.  
2. **Failover + shadowing** (parked) — plan as its own mini-project later.  
3. **S10.7 / S8.9 orchestrated onboard/rebuild (parked)** — wait for AWS vs S3-compatible / adapter stance (Rule 9). Mode 4 + Mac scripts remain.  
4. **pbx3-docs polish** (optional) — human edit pass; SBC chapter / recordings page when useful. Live: **https://aelintra.github.io/pbx3-docs/**.  
5. **pbx3cagi** struct refactor (deferred) — **`REFACTOR_PLAN.md`**  
6. **Fleet auth cookie/SSO (blocked)** — **`FLEET_AUTH_COOKIE_SSO.md`** (orthogonal to login chooser).  
7. **S7+** attested PCI (KMS/CloudTrail/QSA/PSP) — only on customer ask.  

---

## Open items

- [x] **TLS / Let’s Encrypt — SBC admin HTTPS (2026-07-14):** **`https://sbc.pbx3.com/admin`** — certbot webroot, nginx 443 + HTTP→HTTPS, `APP_URL=https://sbc.pbx3.com`. SG needed world **80/443** (was office-IP-only). Runbook **`pbx3sbc/workingdocs/LE_HTTPS_SBC_ADMIN.md`**; nginx template **`pbx3sbc-admin/deploy/nginx-pbx3sbc-admin.conf`**. Branch **`lehttps`**. **Ops:** rotate Filament admin password. SIP TLS out of scope.

- [x] **TLS / Let’s Encrypt — control EC2 (2026-07-14 lab):** Host **`control.pbx3.com`** (`t4g.small`, us-east-1f, dynamic IP). Gatekeeper under nginx+LE; IAM instance profile **`pbx3-control-gatekeeper`**. Runbook **`pbx3-directory/docs/CONTROL_HOST.md`**.

- [x] **Fleet auth infra (2026-07-14):** Gatekeeper SQLite users + session tokens; `POST /api/v1/auth/login`, `/me`, `/logout`; bootstrap `bin/create-fleet-user.php`; break-glass `GATEKEEPER_API_TOKEN` retained. Lab user **`fleet@pbx3.com`**. Branch **`fleetauth`**. SPA login UI shipped same day.

- [x] **Fleet auth — SPA login UI (2026-07-14):** FleetTokenGate email/password → `POST /api/v1/auth/login`; sessionStorage Bearer; advanced paste for break-glass. Dev proxy → `https://control.pbx3.com`. Branch **`fleetauth`** (pbx3spa).

- [x] **Fleet auth polish — paste trim + Exit Fleet revoke (2026-07-14):** Break-glass paste collapsed under “Break-glass (ops only)”; Exit Fleet / reset call `logoutFleet` (server revoke + clear); removed redundant “Clear fleet token” topbar. Soft step-up = must Sign in again after exit. Branch **`fleetauthpolish` → `main`**.

- [ ] **Fleet auth — cookie sessions / SSO (deferred — settled stance 2026-07-14):** Try-it-out auth is enough without a big IdP. **SSO-agnostic:** we own `fleet` / `fleet_*` abilities; optional OIDC later maps groups → abilities. Cookies need same-site Fleet UI (or BFF). Soft step-up via Exit Fleet revoke. **Also later:** tighten CORS to SPA origin; login rate-limit. Design: **`FLEET_AUTH_COOKIE_SSO.md`**.

- [x] **S10.1 — Gatekeeper abilities (2026-07-14):** Persist `users.abilities`; login/`/me`; route checks; SPA `canFleet` / `fleet_read` gate; break-glass = `fleet_admin`. Live on control. Tips **pbx3** **`0a2632b`**, **pbx3spa** **`d7734b9`**.

- [x] **S10.2 — Instance catalog lifecycle v1 (2026-07-14):** Register (+ `verify_up`), PATCH, soft decommission; SPA Instances panel; move dest excludes maintenance. Branches **`s102`→`main`**. Tips **pbx3** **`1b5e75d`**, **pbx3spa** **`26e93e8`**. Lab: SG **tcp/44300** from control public IP for `/up` probes (EIP pending — refresh `/32` if control IP cycles).

- [x] **S10.3 — Move job control (2026-07-14):** Gatekeeper `abort` / `retry` / `rollback` + `created_by`/`last_action_by`; SPA job actions + Jobs “Started by”. Branches **`s103`→`main`**. Tips **pbx3** **`4498a4c`**, **pbx3spa** **`18f957d`**. Live on control.

- [x] **S10.4 — Catalog ↔ SBC reconcile (2026-07-14):** Gatekeeper `GET /api/v1/reconcile` + `POST /api/v1/reconcile/project` (apply catalog→SBC for `setid_mismatch` only); `SbcSetidGuard` rejects invented `sbc_dispatcher_setid` (must be live dispatcher set). **pbx3sbc-admin** `GET /api/fleet/domains` + `dispatcher-sets`. SPA Fleet **Reconcile** panel (Apply button only when mismatches); Instances **Link setid** from live sets only. Branches **`s104`→`main`**. Tips **pbx3** **`96e432e`**, **pbx3sbc-admin** **`2d232f8`**, **pbx3spa** **`15c5090`**. Live on control + SBC.

- [x] **S10.5 — DID path (2026-07-15):** Catalog DID ownership (`dids.json` + `did-index`) — list/assign/release/project; optional `sip_prefix`; SPA Fleet **DIDs**; SBC `POST /fleet/project-dids` + `POST /fleet/domains`. Assign/release auto-project. Lab Magrathea **`+441924918076`** / prefix **`01924918076`** → **duns** (`dhbm8x`) → setid 2 / gwid 10 — inbound call OK. Branches **`s105`→`main`**. Tips **pbx3** **`e8d2a8e`**, **pbx3spa** **`f44cc49`** (+ Exit Fleet **`854ca8b`**), **pbx3sbc-admin** **`95bd61c`**. Live on control + SBC.

- [x] **S10.5 residue — edge register (2026-07-15):** Tenant **Register on SBC**; Instances **Provision edge** (new setid + Asterisk Peer, catalog `sbc_backend_uri` default `sip:{fqdn}:5060`). **Link setid** remains catch-up (confusing — demote in polish). Rule 13 dual contract. Live on control + SBC.

- [x] **S10.6 — Fleet user manage (2026-07-15):** Create/disable/enable; abilities; revoke sessions; SPA **Users**. Live on control. Tips **pbx3** **`470a788`**, **pbx3spa** **`57efff0`**. Branch **`s105`→`main`** (branch deleted).

- [x] **S10.8 — Fleet entry polish (2026-07-15):** Login chooser (Manage instance vs Fleet console); `/fleet` without Sanctum; dual-hat Enter Fleet kept; Exit vs Logout split; one **FleetTokenGate** in FleetLayout with nav locked until Sign in; Link setid → Advanced.

- [ ] **Phase S10 — remaining:** **S10.7**/S10.2b orchestrated IAM onboard/rebuild — **parked** (2026-07-15) pending cloud-adapter / portability discussion; Mode 4 + Mac scripts stay. Plan: **`IMPLEMENTATION_PLAN.md`** § Phase S10.

- [ ] **S10.7 — Orchestrated onboard / rebuild (parked 2026-07-15):** Greenfield IAM join + S8.9 rebuild wizard behind cloud adapter (Rule 9). Explicitly not next. **Interim:** agent-assisted Mode 4 — MkDocs page seeded (**`pbx3-docs`** Fleet → Agent-assisted); source **`SELF_SERVICE_REBUILD_DESIGN.md`** § Mode 4. Design: **`SELF_SERVICE_REBUILD_DESIGN.md`**.

- [x] **Fleet entry — login chooser (2026-07-15):** Shipped S10.8. Nested Enter Fleet remains secondary for dual-hat. Keep Rule 10: two token planes. Ties **`FLEET_AUTH_COOKIE_SSO.md`** § Entry path · **`IMPLEMENTATION_PLAN.md`** § S10.8.

- [x] **Fleet login UI kinship (S10.8 slice 2026-07-15):** TokenGate form kinship with LoginView; Link setid demoted to Advanced. Remaining optional: DID row Edit; further Instances polish.

- [x] **Critical-path test pack Pack A (2026-07-14):** Offline regression net complete — **`TEST_CADENCE.md`**, **`CRITICAL_PATH_TEST_PACK.md`**. Prefix overlap, gatekeeper UserStore + break-glass, fleet list fixtures, SnapshotRetention, recordings HTTP 404/list (mocked), SPA fleet token Vitest. Branch **`packa` → `main`**. Ongoing habit: leave a unit/contract test when touching logic. Pack B = lab recipes; Pack C = UI E2E later.

- [x] **pbx3sbc-admin — Number routes prefix overlap (2026-07-14):** Reject identical `groupid`+`prefix`; amber “nested under / shorter than …” hint + post-save warning. OpenSIPS longest-prefix unchanged. Branch **`overlap` → `main`**; live on **`sbc.pbx3.com/admin`**.

- [x] **pbx3sbc-admin stylesync (2026-07-11):** Filament theme kinship with pbx3spa (slate/blue, brand in topbar, sidebar width/spacing, table canvas/row density). Branch **`stylesync` → `main`** **`624b0f3`**; live on **`sbc.pbx3.com/admin`**.

- [x] **Snapshots — S9.5–S9.7 (2026-07-11):** **pbx3api** **`d8c560c`** — snapshot on Commit + **`SnapshotRetention`** (`PBX3_SNAPSHOT_MAX_COUNT`, default 9); validated on golden. **pbx3spa** **`103ab34`** — dedicated **`/snapshots`** panel; **Backup** archives-only. See **`IMPLEMENTATION_PLAN.md`** § S9.5–S9.7.

- [x] **Peering Phase 5 — alias_db (2026-07-11):** **pbx3sbc** **`05ea925`** — `FROM_CARRIER` fallthrough to `alias_db_lookup` → domain dispatcher. **pbx3sbc-admin** **`2df6a60`** — **Peering → DID aliases**. Lab-validated Magrathea DID via alias; Phase 4 prefix restored. Lab alias row `01924918076` → `dhbm8x.pbx3.com` left in place.

- [x] **Peering Phase 2 — outbound failover (2026-07-13 lab):** Magrathea outbound **gwid 20** `sip:sipipgw.magrathea.net:5060` + Brindley **gwid 1**; rule gwlist **`20,1`**. `DR_FAILOVER`/`use_next_gw` already in SBC config. Seed script updated. Brindley→Magrathea upstream means diversity is limited; proves SBC mechanics. True multi-ITSP still optional (Twilio).

- [x] **Ops — Asterisk after Egress / genAst (2026-07-13):** **`workingdocs/OPS_ASTERISK_AFTER_EGRESS_GENAST.md`** — `systemctl restart asterisk` required after egress template changes; `pjsip reload` alone is not enough (Phase A lab).

- [x] **Peering — logical carrier Peers UX (attrs):** **`PEERING-PLAN.md` §0.1** + pbx3sbc-admin Peers form/table group by `carrier=` / `role=` in **`attrs`** (no OpenSIPS/schema change). Lab seed + Magrathea/Brindley backfill. Remaining: Fail2ban whitelist inbound IPs.

- [x] **Fleet mode in pbx3spa (2026-07-13 → `main`):** **Enter Fleet / Exit Fleet** shell swap, `/fleet/*` guards, Instances / Tenants / **Jobs**, `FleetTokenGate`. **pbx3spa** **`ba31dd4`**, gatekeeper list API **pbx3** **`c047743`**. Branch **`fleetadmin` deleted**.

- [ ] **Failover + shadowing (parked — plan later):** Future mini-project; do not expand here. Related scraps: peering Phase 2 outbound failover; **`FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`**. Shadowing undefined until that planning session.

- [x] **S8.10 — interim gatekeeper auth harden (2026-07-10):** Production SPA must not bake `VITE_FLEET_GATEKEEPER_TOKEN`. Token from **sessionStorage** (Fleet tenants paste) or **DEV-only** Vite env. Gatekeeper README documents lab vs prod vs future control-plane login. Catalog reconcile: nodes/SBC aligned; added missing SBC domain **sandycroft** `vqcwd4.pbx3.com` setid 2.

- [x] **S8.10 — live panel moves + phone POC (2026-07-10):** **willand** (`0ggybk`) 08jzwn→bzy54n job `tmj_bf41c7b45dfc97d72135faf1`. **affcot** (`9wvvnb`) bzy54n→08jzwn job `tmj_7efdc9646309ff3641d21839` — Snom followed SBC remount (setid 3→2); dest commit/`genAst` ran. Preflight gap: willand needed SBC `domain` row before move (added setid 2 then cutover). Linphone 1102 flaky — parked. **Merged to `main`** same day.
- [ ] **Fleet Egress availability & SBC failover (future — not Phase A lab):** Documented **`pbx3-directory/docs/FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`**. SBC must respond **OPTIONS** from fleet nodes so Egress qualify works; re-enable **`qualify_frequency`** on egress template; implement **EgressFailover** (or SRV) + **pbx3cagi** sequential dial; SPA/preflight trunk health. Lab workaround **`qualify_frequency=0`** (**`117340f`**) — do not treat as final. (May fold into **failover + shadowing** mini-project when that is planned.)

- [x] **Phase S8.10 — Fleet mobility scaffold (2026-07-10):** On **`movewizard`** then **`main`**: `tenant-move-job.v0.json`; gatekeeper presign + tenant-moves + phase runner; pbx3api `/api/fleet/*`; pbx3sbc-admin `/api/fleet` repoint; SPA Fleet tenants Move wizard + job view (**lab** — peer nav; product = Fleet **mode** in same SPA).

- [ ] **pbx3sbc — multi-tenant dispatcher reverse lookup:** Template + **`add-dispatcher.sh`** accept **`source_ip`** in dispatcher **`attrs`**. **Live:** golden **setid 2** (`54.236.153.81`), **bzy54n setid 3** (`98.82.174.36`); tenant domains on SBC. **Optional backfill:** hostname dispatcher rows (`sip:08jzwn.pbx3.com`) if needed. See **`opensips.cfg.template`** `route[GET_DOMAIN_FROM_SOURCE_IP]`.

- [ ] **Phase S8 — Fleet (optional polish):** **S8.1–S8.6 shipped and drill-validated** (affcot **08jzwn → bzy54n**). Remaining optional: LE Sync post-cutover; **`move-tenant.sh`** if catalog workflow preferred over **`register-tenant.sh`** for first-time tenants. See **`TENANT_MIGRATION_RUNBOOK.md`**.

- [x] **Phase S7 — PCI staging settled (docs 2026-07-14):** S7 = PCI-**shaped** baseline (dedicated private bucket, BPA, TLS, SSE-S3, gatekeeper presigns, non-attested wording); attested KMS/CloudTrail/Security Hub/QSA/PSP = **S7+**. Search stays SQLite on node; S3 = blobs only. **`d0801c5`**.

- [x] **Phase S7 — Recordings S3 offload (2026-07-14 evening):** Dedicated bucket **`08jzwn-pbx3-recordings`** (BPA/TLS/SSE-S3); gatekeeper **`POST /api/v1/s3/presign-recordings`**; pbx3api **`pbx3:recordings-s3-upload`** + `s3_key` + S3-only play proxy; SPA **Storage** column; `policy.json` + lifecycle `class=recording` 60d; retention keeps **`s3_only`** searchable; **S7.10** **`pbx3:recordings-reconcile`** sweeper (nightly 03:15). Live on control + golden. Tips: **pbx3** **`ed484f3`**, **pbx3api** **`6f46712`**, **pbx3spa** **`6e23fa3`**. Ops: **`OPS_S3_RUNBOOK.md`** §13. **Not** PCI-attested.

- [ ] **S7+ — Attested PCI / scale (deferred):** KMS CMK; CloudTrail→WORM audit bucket; Security Hub; QSA; PSP handoff; Athena/manifests. Do not start without customer ask. Design §6.2 / §7 S7+.

- [ ] **OSS org + repo registry:** Create GitHub org per **`OPEN_SOURCE_GITHUB_SETUP.md`** (e.g. `github.com/pbx3`). **Stay multi-repo** — transfer **`pbx3`**, **`pbx3api`**, **`pbx3spa`**, **`pbx3cagi`**, **`pbx3-docs`**. Maintain **`REPOS_AND_RELEASES.md`**. Interim docs repo already on **`aelintra/pbx3-docs`**. Update local clone remotes; keep **`pbx3-master/`** holding-folder layout.

- [x] **User guides — MkDocs site (`pbx3-docs`) seed (2026-07-15):** Holding-folder **`pbx3-docs/`** + GitHub **`aelintra/pbx3-docs`** → Pages **https://aelintra.github.io/pbx3-docs/**. Approved nav (Cloud/S3 + intro schematic); operator drafts for install/TLS/admin/fleet/cloud/troubleshoot (lab URLs). Content map updated. **Remaining:** human edit pass; optional SBC / recordings chapters; move to OSS org later. **`workingdocs/`** stay unpublished.

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
