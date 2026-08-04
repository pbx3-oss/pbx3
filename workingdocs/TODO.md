# PBX3 ToDo list

**Branch:** **`main`** — fleet nodes **08jzwn** / **bzy54n** / **kildare** on **pbx3 0.0.4-5** + **pbx3cagi 1.0.0-10**. EIPs: golden **`44.196.98.191`**, Kildare **`3.93.253.1`** (`kildare.pbx3.com`), bzy **`54.158.236.215`**. Magrathea VIP **`3.93.26.82`** (`sbc.pbx3.com`).  
**Last updated:** 2026-08-03 (SPA line test + pre-release SPA diet; lab DB anonymize parked)


### Suggested “what next?” order

1. **Number wire standard (open)** — decide Model A (node Mangle) vs B (PBX dials-as-typed; SBC normalizes) — **`NUMBER_WIRE_STANDARD_DRAFT.md`** · research **`CARRIER_NUMBERING_EXPECTATIONS_RESEARCH.md`**. No implement until D1.  
2. **Fleet Delete + FQDN rename** (parked) — **`FLEET_TENANT_CREATE_REQUIREMENTS.md`**.  
3. **Tenant dial alias** — **`TENANT_SHORT_DIAL_REQUIREMENTS.md`**.  
4. **Product crumbs** (optional) — paid Twilio / drain / velocity V3.  
5. **Time-based routing** — **`TIME_BASED_ROUTING_REQUIREMENTS.md`**.  
6. **pbx3cagi Phase 4** (parked).  
7. **Velocity standalone** (parked).  
8. **Instance shadowing** / S10.7 / S8.9 (parked).  
9. **AMI wallboard** (parked).  
10. **Fleet node health ≠ Asterisk** (parked).  
11. **Control plane duplex / HA** (parked).  
12. **Fleet auth cookie/SSO (blocked)**.  
13. **S7+** attested PCI — customer ask.  
14. **SBC Track A / STIR Twilio lab** — **`SBC_PRODUCT_TRACKS.md`**.  
15. **Grafana / door-knock geo** (parked).  
16. **WebRTC residual** — Magrathea W1 done; **pbx3 0.0.4-5** + **cagi 1.0.0-10** on 08jzwn/bzy/kildare; multi-AZ still open. Spec: **`WEBRTC_WSS_LAB.md`**.  
17. **SPA WSS line test** — **done / lab green** (JsSIP dialler + post-call report on WebRTC extension detail). Spec: **`pbx3spa/workingdocs/WSS_LINE_TEST_REQUIREMENTS.md`**.  
18. **Multi-AZ lab** — place fleet instances in **different AZs** (same-AZ lab under-tests NAT/ICE/media).  
19. **Pre-first-release — SPA bundle diet** (parked) — single ~1.1 MB / ~295 kB gzip main chunk; defer until before first product release.  
20. **Lab / demo DB anonymize** (parked) — real-site source data still has live surnames / friendly names; scrub before wider demos or exports.  
21. **OpenSIPS `alias_db_lookup`** — **leave as-is** (panel hidden; empty table; fallthrough harmless).  

**SIPp lab work** (pack teardown, traffic profiles, soak) lives in **[aelintra/sipplabs](https://github.com/aelintra/sipplabs)** `workingdocs/TODO.md` — not here.

---

## Open items

- [ ] **Number wire standard — Model A vs B (open 2026-08-02):** Draft **`NUMBER_WIRE_STANDARD_DRAFT.md`**; research **`CARRIER_NUMBERING_EXPECTATIONS_RESEARCH.md`**. Preference lean: PBX sends dialled digits; SBC owns habit + peer face (PTT). **Not locked** — do not strip node Mangle without D1.

- [x] **Fleet package roll (2026-08-03):** **pbx3 0.0.4-5** + **pbx3cagi 1.0.0-10** on **08jzwn**, **bzy54n**, **kildare** (includes PrepDial WebRTC FQDN + fleet webrtc tmpl + Mangle fix from 1.0.0-9).

- [ ] **OpenSIPS domain setid drift (parked 2026-08-01):** name.com `0ggybk` / `vqcwd4` A→golden EIP, but Magrathea **domain** table still **setid=3** (bzy). SIP via SBC ≠ DNS/LE path until moved to setid=2 (or DNS corrected).

- [ ] **Catalog `label` ↔ node `sitename` (parked 2026-07-30):** On-node friendly name is HoR (`globals.sitename`; lab golden → “Golden”). Fleet directory `label` is separate today — can drift. Later: sync or seed catalog `label` from sitename on onboard / when Network saves (Gatekeeper / catalog write path; Rule 9). Do not invent a second node-local field. Spec: **`NETWORK_SYSGLOBALS_OVERLAP.md`**, **`instance-record.v0.json`**.

- [ ] **Fleet SPA — edge host health scrape (parked 2026-07-30):** Multi-edge load/mem/disk (and later door-knock country rollups) via Gatekeeper ← edge summary cron → S3 HoR → Fleet overlay. **Not** browser→SBC polling; **not** on-SBC heatmaps. Checklist in **`pbx3sbc-admin/workingdocs/HOME_SYSTEM_AND_FLEET_SCRAPE.md`**.

- [ ] **Door-knock geo heat / map (parked 2026-07-30):** Do **not** geolocate on every Home poll on the SBC. Prefer Fleet scrape path above. Edge keeps single-row geo on Door-knock View only.

- [ ] **Grafana / Homer — fleet view only, unmodified (parked 2026-07-30):** Stance locked. **SBC Home = Filament** (in-box). **Grafana** (and Homer if ever) = optional **fleet / multi-instance** observability later — operator-installed **unmodified** OSS (AGPL); no fork, no bundling into product installer, no on-licensing end users. If a use case needs modifying Grafana/Homer, **don’t do that use case**. Not next.

- [x] **WebRTC package residual (2026-08-03):** **pbx3 0.0.4-5** + **pbx3cagi 1.0.0-10** on **08jzwn** + **bzy54n** + **kildare**. Architecture: **`WEBRTC_WSS_LAB.md`**.

- [x] **SPA WSS line test (lab green 2026-08-03):** **pbx3spa** `main` — JsSIP diagnostic dialler on WebRTC extension detail; edge WSS; post-call report. Spec: **`pbx3spa/workingdocs/WSS_LINE_TEST_REQUIREMENTS.md`**.

- [ ] **Pre-first-release — SPA production bundle diet (parked 2026-08-03):** Do **before first product release**, not now. Prod SPA is a single Vite chunk ~**1.1 MB** min / ~**295 kB** gzip (all instance + fleet panels + help markdown + **JsSIP**). Acceptable lab admin; want a deliberate diet prior to release. Prefer: (1) **dynamic `import()` of line-test + JsSIP** only when Line test opens; (2) **route-level code-split** for heavy views; (3) optional split of `marked`/`dompurify` off the critical path. Measure with `npm run build` before/after. Repo: **pbx3spa**.

- [ ] **Lab / demo SQLite anonymize (parked 2026-08-03):** Golden (and any other) test DB originated from a **real site** — still carries live **surnames**, **friendly tenant / sitename-style labels**, and similar PII-ish free text. **Do before** wider demos, third-party access, or public screenshots. Scope (at least): extension **`desc` / `description` / display names** → drop or fake surnames; **tenant / cluster friendly names** and any panel labels that identify the original org; scan for other human strings (callerid, greetings titles, mailbox labels, help/sysnotes if any). Prefer a **one-shot idempotent SQL + short runbook** (lab golden first; document how to re-apply after restore from production dump). Keep dial plans / shortuids functional for SIPp and WebRTC path tests. Not urgent for closed lab if access is operator-only; do not ship site-derived dump as “sample data” without this.

- [ ] **Multi-AZ fleet lab (open 2026-08-03):** Lab today is effectively **same AZ** — under-tests ice_host / public identity / RTP / inter-instance and node↔SBC paths. **Need:** instances (at least two) in **different AZs**; smoke REGISTER, desk media, singleton-direct WebRTC if used, then SBC-faced path. Same-AZ success is not production multi-AZ proof. Notes: **`WEBRTC_WSS_LAB.md`** Next.

- [ ] **`ipphone.desc` vs `description` — clarify / rename (parked 2026-07-29):** Historical SARK/Asterisk ambivalence: schema has both columns; SPA “User (extension name)” → `desc`, “Description” → `description`; list **User** prefers `desc` so freeform Description never shows when `desc` is set (e.g. `1501` vs “WebRTC second ep”). GenAst `$desc` token actually substitutes **`description`** (else pkey), not the `desc` column. Model comment still calls `desc` “SIP username” — wrong now that **shortuid** is PJSIP identity. Proper fix later: map roles (display name vs notes vs any remaining Asterisk/SIP use), align SPA labels + list, GenAst templates, API, migrate/rename if needed. Do not drive-by.

- [ ] **Fleet Delete + FQDN rename (parked 2026-07-30):** Policy locked (Fleet owns lifecycle). **Rule 14:** confirm-gated **durable jobs** (not create-style sync). Primitives still needed: catalog tenant remove/soft-decommission; SBC `DELETE` domain. Node wipe already `DELETE /api/fleet/tenants/{shortuid}`. Spec: **`FLEET_TENANT_CREATE_REQUIREMENTS.md`**.

- [ ] **SBC Track A lab — SARK (± FreePBX) behind SBC (2026-07-28):** Operator will stand up SARK (and maybe FreePBX) and prove REGISTER / calls via Magrathea or scratch pbx3sbc (domain → dispatcher → foreign Asterisk; phones registrar = SBC). No GenAst. Capture recipe / gaps when done — **`SBC_PRODUCT_TRACKS.md`** Track A. **After that lab:** FreePBX→pbx3 **data** migrate is a separate ETL chain (not shared with SARK `migrateLegacyDb` / `db_legacy_sql`) — requirements later.

- [ ] **pbx3cagi Phase 4 — domain file splits (parked 2026-07-26):** Direction OK; hold until cross-cutting design (esp. time-based routing / CheckState) settles — **`REFACTOR_PLAN.md`**.

- [ ] **Time-based routing — day-parts + route profiles (requirements 2026-07-26):** Replace binary DID open/close with tenant **schedule modes** + reusable **route profiles**; keep cron precompute (no GotoIfTime forest); FreePBX TC chains deferred. SARK convert first-class (dual-read). Lock §8 Q1–Q7 before code. Spec: **`TIME_BASED_ROUTING_REQUIREMENTS.md`**. Cross-repo when scheduled (pbx3 / api / cagi / spa).

- [ ] **Control plane duplex / HA (parked, pre-live 2026-07-27):** `control.pbx3.com` / Gatekeeper is a single host — ops SPOF (probes, Fleet UI, moves, notify, Edge promote). **Call plane fail-safe** by design (nodes+SBC keep routing). Not built. Later: active/standby + EIP/DNS; S3 catalog already shared HoR; local health SQLite/job queue need replicate-or-cold-standby story. Do **not** home on SBC. Spec seed: **`CONTROL_HOST.md`** · **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §2.5 fail-safe.

- [ ] **Fleet instance health includes Asterisk (parked, pre-live 2026-07-27):** Gatekeeper node badge uses HTTP **`/up`** only (Laravel app). Asterisk can be down while the instance shows Healthy. Before production: extend probe (custom `/up` checks and/or AMI/`asterisk -rx` core status) so Fleet Instances reflects **call-plane** liveness, not just API. Keep separate from Egress qualify badge. Do not block dial-alias.

- [ ] **AMI wallboard feed (side gig, parked 2026-07-27):** Feed-only live board (per-node AMI events → WS/SSE; optional summarized fleet overlay). **No** dependency on dialplan, moves, Gatekeeper call path, or operational running. Approximate tenant attribution (SUID-in-channel). Do not couple to drain/velocity act. When demand appears — separate small track.

- [ ] **Drain affordance — tenant-scoped “up calls” + wipe-when-drained (nice-to-have, parked 2026-07-23):** On move job `awaiting_cleanup` / Fleet Instances, show approximate active-channel count for the moving tenant on **source** (AMI `CoreShowChannels` → fleet.token → Gatekeeper overlay). Heuristic: phone channels carry extension **SUID** → tenant; SBC legs out of scope. **Follow-on:** optional **wipe-when-drained** — auto-advance Phase 8 when source tenant channel count stays at 0 for N probes (still a durable job; operator can opt in; never silent wipe without the gate existing). Best-effort — do not treat AMI as attested. Not built.

- [ ] **Toll fraud / velocity — standalone product (parked 2026-07-24):** Own **repo + installer** “just in case”; detect/notify portable to any Asterisk; **Go scanner** candidate (static binary); act via adapters (pbx3 reference). Do not fork this week. Spec § Future — **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`**.

- [ ] **Number dialect — paid Twilio + follow-ons:** Operator will sign up full Twilio; named Twilio Peer “recipe” (optional — today `strict-plus-e164`); US Egress `011:+` seed; Magrathea gwid **20** may still lack `dialect=uk-magrathea`; custom-dialect UI. Future product thread: global DID → EU CC on SBC (RTP bypass vs Asterisk/rtpengine stage). Spec: **`NUMBER_DIALECT_REQUIREMENTS.md`** · MkDocs **`fleet/number-dialect`**.

- [ ] **Fleet auth — cookie sessions / SSO (deferred — settled stance 2026-07-14):** Try-it-out auth is enough without a big IdP. **SSO-agnostic:** we own `fleet` / `fleet_*` abilities; optional OIDC later maps groups → abilities. Cookies need same-site Fleet UI (or BFF). Soft step-up via Exit Fleet revoke. **Also later:** tighten CORS to SPA origin; login rate-limit. Design: **`FLEET_AUTH_COOKIE_SSO.md`**.

- [ ] **Phase S10 — remaining:** **S10.7**/S10.2b orchestrated IAM onboard/rebuild — **parked** (2026-07-15) pending cloud-adapter / portability discussion; Mode 4 + Mac scripts stay. Plan: **`IMPLEMENTATION_PLAN.md`** § Phase S10.

- [ ] **S10.7 — Orchestrated onboard / rebuild (parked 2026-07-15):** Greenfield IAM join + S8.9 rebuild wizard behind cloud adapter (Rule 9). Explicitly not next. **Interim:** agent-assisted Mode 4 — MkDocs page seeded (**`pbx3-docs`** Fleet → Agent-assisted); source **`SELF_SERVICE_REBUILD_DESIGN.md`** § Mode 4. Design: **`SELF_SERVICE_REBUILD_DESIGN.md`**.

- [ ] **SBC Fail2ban — inbound Peer auto-whitelist + ban notify (deferred until next carrier onboard):** (1) Auto-sync **carrier inbound Peer IPs** into Fail2ban whitelist on Peer save/delete — implement when onboarding the next carrier so it can be lab-tested live. (2) **Customer site** IPs remain **manual** whitelist (existing UI) — no site CRM. (3) **Ban events → email** via ops notify delivery when that track ships. Edge-authored (Rule 13). Spec: **`PEERING-PLAN.md`** §0.1 · **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** § Fail2ban.

- [ ] **Instance shadowing (parked — framing locked 2026-07-21):** Paid SKU for customers who want min downtime: warm PBX twin + same promote mechanics as SBC edge HA (Manual/Auto, VIP/EIP, soft-state loss OK). Not default for every node. Implement after SBC HA is operational on real lab edge. Spec: **`pbx3-directory/docs/INSTANCE_SHADOWING_REQUIREMENTS.md`**. Related: **`SBC_HA_FAILOVER_REQUIREMENTS.md`**, egress availability.

- [ ] **Log retention Phase 7 / SBC `acc` (superseded by broader review):** Planning moved to **`SBC_DATA_RETENTION_REQUIREMENTS.md`**. See open item **SBC data & log aging review**.

- [ ] **Downstream peer registration edge (future — not next):** Separate **registration-edge** SBC instance class + own OpenSIPS image; auth HoR on that edge; trusted SIP link into main **pbx3sbc**. Not bolted onto current SBC. Interim lab workaround (extension-like REGISTER via Asterisk) documented — not product path. Spec: **`pbx3-directory/docs/DOWNSTREAM_PEER_REGISTRATION_REQUIREMENTS.md`**.

- [ ] **Fleet slug / org bucket naming (cosmetic — fix later):** Lab buckets `08jzwn-pbx3` (+ recordings) use first-node shortuid as stem; product should choose a **neutral fleet slug** at provision (`acme-pbx3`). No runtime impact. Design note: **`OPS_S3_RUNBOOK.md`** § Design note — fleet slug vs lab bucket name. Fold into onboard / S10.7 / create-fleet when that ships.

- [ ] **pbx3sbc — multi-tenant dispatcher reverse lookup:** Template + **`add-dispatcher.sh`** accept **`source_ip`** in dispatcher **`attrs`**. **Live:** golden **setid 2** (`54.236.153.81`), **bzy54n setid 3** (`98.82.174.36`); tenant domains on SBC. **Optional backfill:** hostname dispatcher rows (`sip:08jzwn.pbx3.com`) if needed. See **`opensips.cfg.template`** `route[GET_DOMAIN_FROM_SOURCE_IP]`.

- [ ] **Phase S8 — Fleet (optional polish):** **S8.1–S8.6 shipped and drill-validated** (affcot **08jzwn → bzy54n**). Remaining optional: LE Sync post-cutover; **`move-tenant.sh`** if catalog workflow preferred over **`register-tenant.sh`** for first-time tenants. See **`TENANT_MIGRATION_RUNBOOK.md`**.

- [ ] **S7+ — Attested PCI / scale (deferred):** KMS CMK; CloudTrail→WORM audit bucket; Security Hub; QSA; PSP handoff; Athena/manifests. Do not start without customer ask. Design §6.2 / §7 S7+.

- [ ] **OSS org + repo registry:** Create GitHub org per **`OPEN_SOURCE_GITHUB_SETUP.md`** (e.g. `github.com/pbx3`). **Stay multi-repo** — transfer **`pbx3`**, **`pbx3api`**, **`pbx3spa`**, **`pbx3cagi`**, **`pbx3-docs`**. Maintain **`REPOS_AND_RELEASES.md`**. Interim docs repo already on **`aelintra/pbx3-docs`**. Update local clone remotes; keep **`pbx3-master/`** holding-folder layout.

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

- [ ] **User access privileges (SPA + API — P1–P3):** Phase 0 done (admin-or-nothing gate). Implement per **`INSTANCE_USER_PRIVILEGES_REQUIREMENTS.md`**. Do **not** implement SPA Phase F in isolation — ship **pbx3api** + **pbx3spa** together. Pattern: **`ADMIN_PANELS_AND_PERMISSIONS.md`**; **`AUTH_PATTERNS.md`**.

- [ ] **tt_help_core cleanup — unreferenced rows (final pass):** Reverse audit found **230** `tt_help_core` rows with no SPA field help wiring (**`pbx3spa/scripts/audit-unreferenced-help.mjs`** → **`pbx3spa/workingdocs/HELP_UNREFERENCED_IN_SPA.md`**). Review each: retire legacy-only keys (e.g. DHCP server, factory-reset wizards, BLF bulk editor) vs keep for future panels. Re-run script after SPA changes; prune or rewire as needed. Pair with forward audit **`audit-field-help.mjs`** for missing help on live fields.

- [ ] **SPA hygiene (deferred — after S8 / R1 / core panels):** No work until functionality complete; runs fine on golden/LAN today. Then: **(1)** route lazy-loading in **`router/index.js`**; **(2)** extract shared list/detail patterns when adding panels (avoid new 600+ line views). See **`pbx3spa/workingdocs/PROJECT_PLAN.md`** § Current state, **`PBX3SPA_CODEBASE_ANALYSIS.md`** § Phase H / H2.

- [ ] **SARK V6 migration routines (revisit, low priority — end of list):** Golden demo data still had tenant-scoped **`cluster`** on pkey (e.g. `affcot`) because **`sqlite_fixRi.sql`** was never applied; new SPA/API writes use shortuid, which broke joins (CoS on extensions). Shipped interim repair: **`sqlite_normalize_cluster_to_shortuid.sql`** (idempotent; **pbx3 0.0.3-20**). **Later revisit:** full **`db_legacy_sql`** path (`sqlite_create_legacy.sql`, **`sqlite_fixRi.sql`**, lineio, etc.) — ensure import always runs fixRi (or the normalize script), document operator steps, cover tables fixRi omits (`dateseg`, `holiday`, `page`, `users`, CoS junctions), and decide whether fixRi stays one-shot-only with normalize as the supported repair. Do not run stock fixRi on mixed DBs (NULLs shortuid rows). **FreePBX→pbx3 migrate:** separate future ETL (no shared components with this SARK path); defer requirements until after FreePBX-behind-SBC lab.

---

## Closed items

Checked-off ledger moved **2026-08-03** to **`archive/TODO_DONE_LOG.md`** (157 entries). Do not re-grow a closed list here — archive on rare rationalization passes only.
