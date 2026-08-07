# PBX3 ToDo list

**Branch:** **`main`** all product repos. Site Groups **C0–C6 lab green**. Fleet DNS/LE lock + instance-only Sync on **`main`**. Packages **pbx3 0.0.5-1** / **pbx3cagi 1.0.0-14** artefacts pushed; fleet nodes still on older debs until install / new instance. SPA via **`npm run dev`** for Site Groups + Certificates fleet warn.  
**Last updated:** 2026-08-06 (session end — fleet DNS/LE lock + tenant-A warning)

### Suggested “what next?” order

0. **First out triage** — **`FIRST_OUT_CHECKLIST.md`** (must-fix F1–F5 vs nice N* vs parked).  
1. **New instance / package install** — install **0.0.5-1** + **1.0.0-14** + API tip (instance-only LE Sync) when scheduled.  
2. **Product crumbs** (optional) — paid Twilio / drain / velocity V3; day-parts optional smokes beyond golden.  
3. **Multi-AZ lab** — instances in **different AZs** (WebRTC / RTP proof).  
4. **pbx3cagi Phase 4** (parked; day-parts merged — unblocked when wanted).  
5. **Velocity standalone** (parked).  
6. **Instance shadowing** / S10.7 / S8.9 (parked).  
7. **AMI wallboard** (parked).  
8. **Fleet node health ≠ Asterisk** (parked — also **N3** on first-out checklist).  
9. **Control plane duplex / HA** (parked).  
10. **Fleet auth cookie/SSO (blocked)**.  
11. **S7+** attested PCI — customer ask.  
12. **SBC Track A / STIR Twilio lab** — **`SBC_PRODUCT_TRACKS.md`**.  
13. **Grafana / door-knock geo** (parked).  
14. **Pre-first-release — SPA bundle diet** (parked — **N1**).  
15. **Lab / demo DB anonymize** (parked — **F5** if external demo).  
16. **Provisioning server** (parked — maybe don't build; see requirements §0).  
17. **SPA list action icons component** (parked).  
18. **Number wire Phase 2 / D2–D4** (parked).  
19. **Seed outbound US dialplan string (O4)** — optional; UK `_0. _00.` shipped.  
20. **Instance API digest deepen** (optional).  
21. **Device templates** — seed lean + nav done; prune existing DBs / drop routes residual.  
22. **SARK migration → Aelintra repo** — before PBX3 OSS org move (not first-out critical).  
23. **OSS org + repo transfer** — after SARK migration extract.  

**SIPp lab work** (pack teardown, traffic profiles, soak) lives in **[aelintra/sipplabs](https://github.com/aelintra/sipplabs)** `workingdocs/TODO.md` — not here.

---

## Open items

- [x] **Tenant FQDN DNS + instance-only LE — SBC fleet (2026-08-06):** No tenant public **A** records; SPA → instance DNS; SIP domain → OpenSIPS setid. Lab removed tenant As; golden/bzy LE instance-only. **Lock:** **`TLS_AND_CERTIFICATES.md` §0** (+ big DO-NOT-A-record warn). **Code:** fleet `certificateFqdnList` / Setup+Sync instance-only; SPA **Sync certificate** + fleet warn banner. Option A multi-SAN remains solo/direct only.

- [ ] **Fleet SPA — edge host health scrape (parked 2026-07-30):** Multi-edge load/mem/disk (and later door-knock country rollups) via Gatekeeper ← edge summary cron → S3 HoR → Fleet overlay. **Not** browser→SBC polling; **not** on-SBC heatmaps. Checklist in **`pbx3sbc-admin/workingdocs/HOME_SYSTEM_AND_FLEET_SCRAPE.md`**.

- [ ] **Door-knock geo heat / map (parked 2026-07-30):** Do **not** geolocate on every Home poll on the SBC. Prefer Fleet scrape path above. Edge keeps single-row geo on Door-knock View only.

- [ ] **Grafana / Homer — fleet view only, unmodified (parked 2026-07-30):** Stance locked. **SBC Home = Filament** (in-box). **Grafana** (and Homer if ever) = optional **fleet / multi-instance** observability later — operator-installed **unmodified** OSS (AGPL); no fork, no bundling into product installer, no on-licensing end users. If a use case needs modifying Grafana/Homer, **don’t do that use case**. Not next.

- [ ] **Pre-first-release — SPA production bundle diet (parked 2026-08-03):** Do **before first product release**, not now. Prod SPA is a single Vite chunk ~**1.1 MB** min / ~**295 kB** gzip (all instance + fleet panels + help markdown + **JsSIP**). Acceptable lab admin; want a deliberate diet prior to release. Prefer: (1) **dynamic `import()` of line-test + JsSIP** only when Line test opens; (2) **route-level code-split** for heavy views; (3) optional split of `marked`/`dompurify` off the critical path. Measure with `npm run build` before/after. Repo: **pbx3spa**.

- [ ] **Lab / demo SQLite anonymize (parked 2026-08-03):** Golden (and any other) test DB originated from a **real site** — still carries live **surnames**, **friendly tenant / sitename-style labels**, and similar PII-ish free text. **Do before** wider demos, third-party access, or public screenshots. Scope (at least): extension **`desc` / `description` / display names** → drop or fake surnames; **tenant / cluster friendly names** and any panel labels that identify the original org; scan for other human strings (callerid, greetings titles, mailbox labels, help/sysnotes if any). Prefer a **one-shot idempotent SQL + short runbook** (lab golden first; document how to re-apply after restore from production dump). Keep dial plans / shortuids functional for SIPp and WebRTC path tests. Not urgent for closed lab if access is operator-only; do not ship site-derived dump as “sample data” without this.

- [ ] **Device table — lean done in seed; residual (2026-08-06):** No in-house provisioner. **`sqlite_device_data.sql`** now **11** keepers (General SIP, WebRTC, MAILBOX + Yealink/Cisco/Polycom/Fanvil/Gigaset/Aastra/Vtech/Panasonic). Prune existing DBs: **`sqlite_device_lean_prune.sql`**. SPA **Devices** removed from System nav (routes/API still exist for break-glass). **Still open:** drop Devices routes/views entirely; Snom/Grandstream pkey gap; optional later move keepers to packaged JSON (no inline PHP). Not call-plane.

- [ ] **SPA list action icons — shared component (parked 2026-08-03):** Pencil/trash stroke SVGs are copy-pasted across list views; Dial prefixes briefly used emoji. Extract small **`ListEditIcon` / `ListDeleteIcon`** (or combined row-actions) in **pbx3spa** and reuse everywhere. Optional busy/spin state for delete. Not urgent polish.

- [ ] **Multi-AZ fleet lab (open 2026-08-03):** Lab today is effectively **same AZ** — under-tests ice_host / public identity / RTP / inter-instance and node↔SBC paths. **Need:** instances (at least two) in **different AZs**; smoke REGISTER, desk media, singleton-direct WebRTC if used, then SBC-faced path. Same-AZ success is not production multi-AZ proof. Notes: **`WEBRTC_WSS_LAB.md`** Next.

- [ ] **`ipphone.desc` vs `description` — clarify / rename (parked 2026-07-29):** Historical SARK/Asterisk ambivalence: schema has both columns; SPA “User (extension name)” → `desc`, “Description” → `description`; list **User** prefers `desc` so freeform Description never shows when `desc` is set (e.g. `1501` vs “WebRTC second ep”). GenAst `$desc` token actually substitutes **`description`** (else pkey), not the `desc` column. Model comment still calls `desc` “SIP username” — wrong now that **shortuid** is PJSIP identity. Proper fix later: map roles (display name vs notes vs any remaining Asterisk/SIP use), align SPA labels + list, GenAst templates, API, migrate/rename if needed. Do not drive-by.

- [ ] **SBC Track A lab — SARK (± FreePBX) behind SBC (2026-07-28):** Operator will stand up SARK (and maybe FreePBX) and prove REGISTER / calls via Magrathea or scratch pbx3sbc (domain → dispatcher → foreign Asterisk; phones registrar = SBC). No GenAst. Capture recipe / gaps when done — **`SBC_PRODUCT_TRACKS.md`** Track A. **After that lab:** FreePBX→pbx3 **data** migrate is a separate ETL chain (not shared with SARK `migrateLegacyDb` / `db_legacy_sql`) — requirements later.

- [ ] **pbx3cagi Phase 4 — domain file splits (parked 2026-07-26):** Direction OK; day-parts / CheckState **merged to `main`** — Phase 4 unblocked when scheduled. Spec: **`REFACTOR_PLAN.md`**.

- [ ] **Control plane duplex / HA (parked, pre-live 2026-07-27):** `control.pbx3.com` / Gatekeeper is a single host — ops SPOF (probes, Fleet UI, moves, notify, Edge promote). **Call plane fail-safe** by design (nodes+SBC keep routing). Not built. Later: active/standby + EIP/DNS; S3 catalog already shared HoR; local health SQLite/job queue need replicate-or-cold-standby story. Do **not** home on SBC. Spec seed: **`CONTROL_HOST.md`** · **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §2.5 fail-safe.

- [ ] **Fleet instance health includes Asterisk (parked, pre-live 2026-07-27):** Gatekeeper node badge uses HTTP **`/up`** only (Laravel app). Asterisk can be down while the instance shows Healthy. Before production: extend probe (custom `/up` checks and/or AMI/`asterisk -rx` core status) so Fleet Instances reflects **call-plane** liveness, not just API. Keep separate from Egress qualify badge. Do not block dial-alias.

- [ ] **AMI wallboard feed (side gig, parked 2026-07-27):** Feed-only live board (per-node AMI events → WS/SSE; optional summarized fleet overlay). **No** dependency on dialplan, moves, Gatekeeper call path, or operational running. Approximate tenant attribution (SUID-in-channel). Do not couple to drain/velocity act. When demand appears — separate small track.

- [ ] **Drain affordance — tenant-scoped “up calls” + wipe-when-drained (nice-to-have, parked 2026-07-23):** On move job `awaiting_cleanup` / Fleet Instances, show approximate active-channel count for the moving tenant on **source** (AMI `CoreShowChannels` → fleet.token → Gatekeeper overlay). Heuristic: phone channels carry extension **SUID** → tenant; SBC legs out of scope. **Follow-on:** optional **wipe-when-drained** — auto-advance Phase 8 when source tenant channel count stays at 0 for N probes (still a durable job; operator can opt in; never silent wipe without the gate existing). Best-effort — do not treat AMI as attested. Not built.

- [ ] **Toll fraud / velocity — standalone product (parked 2026-07-24):** Own **repo + installer** “just in case”; detect/notify portable to any Asterisk; **Go scanner** candidate (static binary); act via adapters (pbx3 reference). Do not fork this week. Spec § Future — **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`**.

- [ ] **Number dialect — paid Twilio + follow-ons:** Operator will sign up full Twilio; named Twilio Peer “recipe” (optional — today `strict-plus-e164`); US Egress `011:+` seed; Magrathea gwid **20** may still lack `dialect=uk-magrathea`; custom-dialect UI. Future product thread: global DID → EU CC on SBC (RTP bypass vs Asterisk/rtpengine stage). Spec: **`NUMBER_DIALECT_REQUIREMENTS.md`** · MkDocs **`fleet/number-dialect`**.

- [ ] **Number wire Phase 2 / D2–D4 (parked 2026-08-06):** Phase 1 = node Mangle (**D1 = C** locked). Phase 2 = SBC habit when gated. **Do not strip node Mangle** until Phase-2 gate. Specs: **`NUMBER_WIRE_POLICY.md`**, **`NUMBER_WIRE_STANDARD_DRAFT.md`**.

- [ ] **Seed outbound US dialplan string (O4) (optional):** UK `_0. _00.` shipped with **`SEED_OUTBOUND_ON_TENANT_CREATE.md`**. US seed string when wanted.

- [ ] **Fleet auth — cookie sessions / SSO (deferred — settled stance 2026-07-14):** Try-it-out auth is enough without a big IdP. **SSO-agnostic:** we own `fleet` / `fleet_*` abilities; optional OIDC later maps groups → abilities. Cookies need same-site Fleet UI (or BFF). Soft step-up via Exit Fleet revoke. **Also later:** tighten CORS to SPA origin; login rate-limit. Design: **`FLEET_AUTH_COOKIE_SSO.md`**.

- [ ] **Phase S10 — remaining:** **S10.7**/S10.2b orchestrated IAM onboard/rebuild — **parked** (2026-07-15) pending cloud-adapter / portability discussion; Mode 4 + Mac scripts stay. Plan: **`IMPLEMENTATION_PLAN.md`** § Phase S10.

- [ ] **S10.7 — Orchestrated onboard / rebuild (parked 2026-07-15):** Greenfield IAM join + S8.9 rebuild wizard behind cloud adapter (Rule 9). Explicitly not next. **Interim:** agent-assisted Mode 4 — MkDocs page seeded (**`pbx3-docs`** Fleet → Agent-assisted); source **`SELF_SERVICE_REBUILD_DESIGN.md`** § Mode 4. Design: **`SELF_SERVICE_REBUILD_DESIGN.md`**.

- [ ] **SBC Fail2ban — inbound Peer auto-whitelist + ban notify (deferred until next carrier onboard):** (1) Auto-sync **carrier inbound Peer IPs** into Fail2ban whitelist on Peer save/delete — implement when onboarding the next carrier so it can be lab-tested live. (2) **Customer site** IPs remain **manual** whitelist (existing UI) — no site CRM. (3) **Ban events → email** via ops notify delivery when that track ships. Edge-authored (Rule 13). Spec: **`PEERING-PLAN.md`** §0.1 · **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** § Fail2ban.

- [ ] **Instance shadowing (parked — framing locked 2026-07-21):** Paid SKU for customers who want min downtime: warm PBX twin + same promote mechanics as SBC edge HA (Manual/Auto, VIP/EIP, soft-state loss OK). Not default for every node. Implement after SBC HA is operational on real lab edge. Spec: **`pbx3-directory/docs/INSTANCE_SHADOWING_REQUIREMENTS.md`**. Related: **`SBC_HA_FAILOVER_REQUIREMENTS.md`**, egress availability.

- [ ] **Downstream peer registration edge (future — not next):** Separate **registration-edge** SBC instance class + own OpenSIPS image; auth HoR on that edge; trusted SIP link into main **pbx3sbc**. Not bolted onto current SBC. Interim lab workaround (extension-like REGISTER via Asterisk) documented — not product path. Spec: **`pbx3-directory/docs/DOWNSTREAM_PEER_REGISTRATION_REQUIREMENTS.md`**.

- [ ] **Fleet slug / org bucket naming (cosmetic — fix later):** Lab buckets `08jzwn-pbx3` (+ recordings) use first-node shortuid as stem; product should choose a **neutral fleet slug** at provision (`acme-pbx3`). No runtime impact. Design note: **`OPS_S3_RUNBOOK.md`** § Design note — fleet slug vs lab bucket name. Fold into onboard / S10.7 / create-fleet when that ships.

- [ ] **Phase S8 — Fleet (optional polish):** **S8.1–S8.6 shipped and drill-validated** (affcot **08jzwn → bzy54n**). Remaining optional: LE Sync post-cutover; **`move-tenant.sh`** if catalog workflow preferred over **`register-tenant.sh`** for first-time tenants. See **`TENANT_MIGRATION_RUNBOOK.md`**.

- [ ] **S7+ — Attested PCI / scale (deferred):** KMS CMK; CloudTrail→WORM audit bucket; Security Hub; QSA; PSP handoff; Athena/manifests. Do not start without customer ask. Design §6.2 / §7 S7+.

- [ ] **OSS org + repo registry:** Create GitHub org per **`OPEN_SOURCE_GITHUB_SETUP.md`** (e.g. `github.com/pbx3`). **Stay multi-repo** — transfer **`pbx3`**, **`pbx3api`**, **`pbx3spa`**, **`pbx3cagi`**, **`pbx3-docs`**. Maintain **`REPOS_AND_RELEASES.md`**. Interim docs repo already on **`aelintra/pbx3-docs`**. Update local clone remotes; keep **`pbx3-master/`** holding-folder layout. **Prerequisite before transfer:** extract **SARK migration** out of pbx3 into an **Aelintra-owned** repo (see next item) so legacy ETL does not move with the OSS product.

- [ ] **SARK migration → separate Aelintra repo (before PBX3 org move) (2026-08-06):** Break all **SARK V6 → pbx3** migration code/SQL out of the **pbx3** product tree into its **own repo that stays under `aelintra`** when PBX3 transfers to the new org. Scope at least: **`db_legacy_sql`**, `migrateLegacyDb` / related scripts, fixRi / normalize helpers, any sail-coupled import docs. Not critical for first out; **must be done before** OSS org transfer so product repos are clean and Aelintra keeps the legacy bridge. FreePBX→pbx3 ETL remains a separate future track. Cross-link: SARK V6 migration revisit item below · **`OPEN_SOURCE_GITHUB_SETUP.md`** / **`REPOS_AND_RELEASES.md`**.

- [ ] **pbx3cagi refactor (under Ast config generator + cagi track):** Phase 0 harness **golden-signed-off** on **08jzwn**. Resume Phase **1.3 → 1.1 → 2.x** with generator work; run **`make test`** after each step. Contract: **`AST_CONFIG_GENERATOR_SUBPROJECT.md`** §5. Gate: **`REFACTOR_PLAN.md`**, **`TEST_HARNESS.md`**, **`TEST_RECIPE.md`**.

- [ ] **Golden `pkey='default'` layout (investigate, low priority):** Pre-migration golden had only `f34ck1`/`5489nv` (node FQDN on `globals` only). Test instance uses **`default`** tenant row with `cluster.fqdn` = node FQDN. Post-restore golden matches test layout. Question: does SPA tenant-create-only provisioning ever skip creating `default`?

- [ ] **pbx3api astamis `PJSIPShowEndpoint/{id}`:** Calling `GET .../astamis/PJSIPShowEndpoint/{id}` returns `AMI Action invalid or unsupported` because **`AstAmiController::$eventList` only whitelists `PJSIPShowEndpoints` (plural)** — singular action never reaches Asterisk. **Follow-up when implementing:** (1) Allow `PJSIPShowEndpoint` (dedicated route/method like other `eventItem` actions, or extend `getlist` with a special case). (2) AMI body must include **`Endpoint: {id}`** (not only `Action:`). (3) Do not use plain `amiQuery()` for this action — use **`amiPjsipShowEndpointForLive()`** or **`amiQueryUntilComplete()`** and return structured JSON or raw response as needed. (4) Document in `astamis` index (`GET astamis`) if exposed.

- [ ] **LDAP — overall strategy deferred (kicked down the road):** How LDAP is provisioned/used across instance vs tenant is **not yet decided**; parking all LDAP work until a design is chosen. Known loose ends to fold in when picked up: **(1)** the config-source mismatch below (LDAPHelperClass vs `globals`/`cluster`); **(2)** backup export writes **`/tmp/pbx3.local.ldif`** and fails with `Permission denied` when the file is owned by another user (seen on golden scheduled `pbx3:backup-run` — backup still completes/uploads; ldif export is skipped). Fix ownership/tmp path (per-run temp file or `/opt/pbx3` scratch) and decide whether LDAP data belongs in the backup at all. See `create_new_backup()` LDAP dump step.

- [ ] **LDAP: LDAPHelperClass reads from `globals` but instance `globals` has no LDAP columns.**  
  Instance schema (`sqlite_create_instance.sql`) does not define `ldapbase`, `ldapou`, `ldapuser`, `ldappass` on `globals`. Those columns exist on the tenant `cluster` table (`sqlite_create_tenant.sql`).  
  **Action:** Either (1) have LDAPHelperClass read LDAP config from tenant `cluster` (e.g. for the current/default tenant), or (2) add LDAP columns to instance `globals` if LDAP is intended to be instance-wide.  
  **Current workaround:** Query uses `FROM globals LIMIT 1` with lowercase column names; empty-result guard avoids errors when columns are missing.

- [ ] **pjsipuser for extensions:** Address pjsipuser handling for extensions (PJSIP endpoint/user config, API/SPA and generator/templates as needed).

- [ ] **Extensions edit panel — Runtime section (re-examine):** Review **`ExtensionDetailView.vue`** Runtime block (cfim, cfbs, ringdelay; live SIP IP/latency via `GET extensions/{shortuid}/runtime`). Deferred until phones are registered on a test instance — cannot judge UX, live-data usefulness, or API behaviour without endpoints online. See **`pbx3spa/workingdocs/EXTENSIONS_LIVE_DATA.md`**, **`PANEL_PATTERN_DEPARTURES.md`** § Runtime subsection.

- [ ] **Inbound route panels — SWOCLIP (re-examine):** Review **`swoclip`** (Switch-On-CLIP) on inbound route create/detail panels — label vs help pkey **`swoclip`** (“SWOC?”), default **YES**, interaction with CLIP DDI routing (`pbx3cagi` reads `inroutes.swoclip`). Detail has **`FormToggle`**; create panel omits it today. Confirm field placement, parity create/edit, and whether UX matches operator expectations.

- [ ] **pbx3cagi — `maxin` / `maxout` call counters:** Fix concurrent-call limit enforcement in **`pbx3cagi/pbx3cagi-1.0.0/csource/pbx3cagi.c`**. Today only tenant **`maxin`** is loaded (`g_cluster_cfg.maxin_str`) and checked on inbound via `GROUP_COUNT(inbound)`; **`maxout`** is not enforced. Review counter semantics (inbound vs outbound scope, instance **`globals`** vs tenant **`cluster`** caps), comparison edge cases, and busy/reject behaviour. Validate against **`DBSTRUCT_SMOKE_CHECKLIST.md`** § ingress controls.

- [ ] **SPA session timeout (Instance Globals `sessiontimout`):** **`globals.sessiontimout`** is editable on **`SysglobalsEditView.vue`** (default **600** s) but the SPA does **not** auto-logout after that interval. Implement client-side idle/session expiry: read timeout from **`GET sysglobals`** (or auth bootstrap), reset on user activity, clear token and redirect to login when exceeded. Align with API token lifetime / revoke if needed. See **`pbx3spa/workingdocs/AUTH_PATTERNS.md`**.

- [ ] **tt_help_core cleanup — unreferenced rows (final pass):** Reverse audit found **230** `tt_help_core` rows with no SPA field help wiring (**`pbx3spa/scripts/audit-unreferenced-help.mjs`** → **`pbx3spa/workingdocs/HELP_UNREFERENCED_IN_SPA.md`**). Review each: retire legacy-only keys (e.g. DHCP server, factory-reset wizards, BLF bulk editor) vs keep for future panels. Re-run script after SPA changes; prune or rewire as needed. Pair with forward audit **`audit-field-help.mjs`** for missing help on live fields.

- [ ] **SPA hygiene (deferred — after S8 / R1 / core panels):** No work until functionality complete; runs fine on golden/LAN today. Then: **(1)** route lazy-loading in **`router/index.js`**; **(2)** extract shared list/detail patterns when adding panels (avoid new 600+ line views). See **`pbx3spa/workingdocs/PROJECT_PLAN.md`** § Current state, **`PBX3SPA_CODEBASE_ANALYSIS.md`** § Phase H / H2.

- [ ] **SARK V6 migration routines (revisit, low priority — end of list):** Golden demo data still had tenant-scoped **`cluster`** on pkey (e.g. `affcot`) because **`sqlite_fixRi.sql`** was never applied; new SPA/API writes use shortuid, which broke joins (CoS on extensions). Shipped interim repair: **`sqlite_normalize_cluster_to_shortuid.sql`** (idempotent; **pbx3 0.0.3-20**). **Later revisit:** full **`db_legacy_sql`** path (`sqlite_create_legacy.sql`, **`sqlite_fixRi.sql`**, lineio, etc.) — ensure import always runs fixRi (or the normalize script), document operator steps, cover tables fixRi omits (`dateseg`, `holiday`, `page`, `users`, CoS junctions), and decide whether fixRi stays one-shot-only with normalize as the supported repair. Do not run stock fixRi on mixed DBs (NULLs shortuid rows). **Repo destiny:** extract this bridge to an **Aelintra-owned** repo before PBX3 org move (see **SARK migration → separate Aelintra repo** above). **FreePBX→pbx3 migrate:** separate future ETL (no shared components with this SARK path); defer requirements until after FreePBX-behind-SBC lab.

---

## Closed this reconcile (2026-08-06)

Moved to **`archive/TODO_DONE_LOG.md`** (header block). Highlights:

- Site Groups C0–C6 + short dial A–F + naming lock + Fleet Delete + number wire D1 + day-parts + seed outbound  
- Packages **pbx3 0.0.5-1** / **pbx3cagi 1.0.0-14** artefacts on `main` (fleet install deferred)  
- Instance user privileges **P1–P4** + **B′** login homing  
- Log retention Phases 1–6 + SBC data aging WS0–WS4 (Phase 7 purge-only)  
- WebRTC residual + SPA WSS line test; OpenSIPS `alias_db_lookup` leave-as-is; dispatcher reverse-lookup live  

---

## Closed items

Checked-off ledger lives in **`archive/TODO_DONE_LOG.md`**. Do not re-grow a closed list here — archive on rare rationalization passes only.
