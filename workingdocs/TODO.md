# PBX3 ToDo list

**Branch:** **`main`** — golden on **EIP `44.196.98.191`**; **pbx3 0.0.4-3** + **pbx3cagi 1.0.0-8**; CDR site-TZ (SPA/API + SBC) shipped. Lab: Magrathea VIP; Catcher **`98.82.58.59`**; Domain **`sippuac`**.  
**Last updated:** 2026-08-01 (session end: tenant login simplify + lab catalog reconcile)


### Suggested “what next?” order

1. **Fleet Delete + FQDN rename** (parked) — **`FLEET_TENANT_CREATE_REQUIREMENTS.md`**.  
2. **Tenant dial alias** — **`TENANT_SHORT_DIAL_REQUIREMENTS.md`**.  
3. **Product crumbs** (optional) — paid Twilio / drain / velocity V3.  
4. **Time-based routing** — **`TIME_BASED_ROUTING_REQUIREMENTS.md`**.  
5. **pbx3cagi Phase 4** (parked).  
6. **Velocity standalone** (parked).  
7. **Instance shadowing** / S10.7 / S8.9 (parked).  
8. **AMI wallboard** (parked).  
9. **Fleet node health ≠ Asterisk** (parked).  
10. **Control plane duplex / HA** (parked).  
11. **Fleet auth cookie/SSO (blocked)**.  
12. **S7+** attested PCI — customer ask.  
13. **SBC Track A / STIR Twilio lab** — **`SBC_PRODUCT_TRACKS.md`**.  
14. **Grafana / door-knock geo** (parked).  
15. **WebRTC / WSS demo (SBC #1)** — **blocked:** await far-end SPA team. Spec: **`WEBRTC_WSS_LAB.md`**.  
16. **OpenSIPS `alias_db_lookup`** — **leave as-is** (panel hidden; empty table; fallthrough harmless).  

**SIPp lab work** (pack teardown, traffic profiles, soak) lives in **[aelintra/sipplabs](https://github.com/aelintra/sipplabs)** `workingdocs/TODO.md` — not here.

---

## Open items

- [x] **pbx3 0.0.4 + cagi 1.0.0-7 + golden rebuild (2026-08-01):** Executed **`BUILD_PLAN_0.0.4.md`**. Packages **pbx3 0.0.4-3** / **pbx3cagi 1.0.0-7** on new golden; EIP **`44.196.98.191`**; DNS four A records; Magrathea setid=2 → EIP; onboard + LE (4 SANs); preflight green. Tags **`pbx3-0.0.4-3`**, **`pbx3cagi-1.0.0-7`**. Later same day: cagi **1.0.0-8** (CLIP); catalog setid linked; operator smoke green; old EC2 terminated.

- [x] **GenAst `$outbound_proxy` comment mangling (2026-08-01):** Comment token in `pjsip_phone.tmpl` was expanded by unanchored replace → bare prose in `pjsip_ready_phones.conf`. Fix: reword comment + line-anchored `/^\$outbound_proxy/m` in `GenClass::xlatePjsipBuff` (**`c8888cf`**). Hot on golden.

- [x] **Terminate old golden EC2 (2026-08-01):** `i-02ec2b05b5baacb5d` (`54.236.153.81`) terminated by operator.

- [x] **Lab tenants must use catalog (2026-08-01):** Doc **`LAB_FLEET_TENANTS.md`** + tool **`reconcile-node-tenants.sh`** (Mode 4 Phase 5 + BUILD_PLAN). Golden reconcile OK after registering `pb0wsk`. No node-only invent on fleet boxes.

- [x] **SPA tenant login one-form (2026-08-01):** Tenant id + email + password; enforce typed UID ∈ `allowed_clusters`; autofill focus guard; catalog `no-store`. Lab: `pb0wsk` / `sipusert…` CDR/Home scoped OK. Spec: **`INSTANCE_USER_PRIVILEGES_REQUIREMENTS.md`**.

- [ ] **OpenSIPS domain setid drift (parked 2026-08-01):** name.com `0ggybk` / `vqcwd4` A→golden EIP, but Magrathea **domain** table still **setid=3** (bzy). SIP via SBC ≠ DNS/LE path until moved to setid=2 (or DNS corrected).

- [x] **Home CDR Outcomes (today) — TZ mismatch (2026-07-31):** Cause = Laravel UTC `today` vs local `calldate`. **HoR UTC shipped** (`cdr_sqlite3_custom` STRFTIME); golden verified. **2026-08-01:** SPA + API site-TZ display/filters; SBC Filament Home/CDR same clock (`pbx3sbc-admin` `SiteTimezone`). Mixed pre-UTC rows ignored (lab only). Policy: **`CDR_TIMEZONE_POLICY.md`**.

- [x] **SIPp traffic-profile sim — schema + mixed-office + rrmemory smoke (2026-07-31):** YAML schema + **`mixed-office.yaml`** (concurrent **4**). Dedicated queue **2160** (`rrmemory`, members 2120–2123). `run-queue-rr.sh` **GREEN** on sippuac (each agent 2 calls; graceful stop; Magrathea dialogs→0). Later: Numbers %; inbound-/outbound-heavy; freephone-trunk CDR. Spec: **sipplab** `docs/PROFILES.md` (was call-tests).

- [x] **Numbers lab — pretend DID + Peer 99 PSTN UAS (2026-07-31):** DID **01924234567** (Number route prefix **`441924234567`** after UK dialect); golden Ingress → pb0wsk **2120**. Peer **99** = SIPp Catcher. **Outbound coexistence:** prefix **`019242*`** → gwid **99**; default empty-prefix **`1,20,50`** unchanged. Scripts: `run-peer-pstn-uas.sh`, `run-did-lab-in.sh`, `run-did-lab-out.sh`. Both directions **GREEN**. Spec: **sipplab** `docs/HOST_SETUP.md` / `docs/examples/aelintra-lab.md`.

- [x] **SBC — orphaned dialogs / dialog timeout align (2026-07-31):** OpenSIPS `default_timeout` **14400** (was implicit 12h). Kinship: node Globals `abstimeout` default. Template + Magrathea live. Filament **System → Call limits** read-only from `/etc/opensips/opensips.cfg` (no browser edit). Ping deferred. Refs: [dialog module](https://opensips.org/docs/modules/devel/dialog.html).

- [x] **L2 soak — graceful stop (2026-07-31):** `./run-soak.sh stop` drains hold+BYE before killing UAS; `stop force` + Mac `./clear-sbc-dialogs.sh` for residue. Proven on **`sippuac`** (dialogs→0).

- [x] **SBC Home — Filament ops pulse + thin system (2026-07-30):** Merged to **pbx3sbc-admin `main`** **`0073471`** (via `rename-domain-routes`). Live on VIP: system strip (load/mem/disk) → SIP live posture → 24h CDR line + outcome doughnut → security pulse/trend; chart click-throughs; `HomeDashboardMetrics` short-TTL cache. Old period-sprawl widgets undiscovered. Spec: **`pbx3sbc-admin/workingdocs/HOME_SYSTEM_AND_FLEET_SCRAPE.md`**. **Not** Grafana on edge.

- [x] **SBC Home — usage meters on system strip (2026-07-30):** Filament `SystemPostureWidget` thin green→amber→red meters (Load = load1/CPUs; Memory/Disk = used %). Home title **Home** only (FQDN on INSTANCE chip). Spec: **`HOME_SYSTEM_AND_FLEET_SCRAPE.md`**. Friendly SBC sitename still deferred. Tip **pbx3sbc-admin** **`a92aed5`** (VIP surgical).

- [x] **SIPp extension platform = local ARM VM (2026-07-30):** **`sippuac`** `tech@192.168.1.51` (Ubuntu 24.04 aarch64, `sip-tester`); `~/call-tests` rsync; A→B `./run-phone-a-b.sh` green. Not 2nd EC2 unless NAT fails. Spec: **sipplab** `docs/HOST_SETUP.md` / `docs/examples/aelintra-lab.md`.

- [x] **SIPp L2 soak scaffolding (2026-07-30):** `provision-soak-phones.sh` (40 exts 2100–2139 on `pb0wsk`) + `./run-soak.sh start demo|busy`. Spec: **sipplab** + **`CALL_TEST_STRATEGY.md`** §6.

- [x] **L2 soak — Magrathea ACK/dialog residue (2026-07-30):** Root cause = SIPp UAS missing Record-Route echo (not NAT / not OpenSIPS.cfg). Fix: `[last_Record-Route:]` in `soak-answer` 180/200 (**`36c9ea8`**). EC2 one-call + demo 10-pair stable. Leanings: **sipplab** `docs/LEANINGS.md`.

- [x] **Instance Home ops-pulse + sitename (2026-07-30):** SPA/API **`main`** merge tips **pbx3spa** **`5ea90df`**, **pbx3api** **`9db216b`**. Host/live/CDR pulse; usage meters; `GET /home/pulse`; `displayInstanceLabel` sitename→FQDN; installer Site name. **Uncommitted:** SPA `HomeBarChart` axis/summary numbers. Catalog label sync parked.

- [x] **Instance friendly name = `sysglobals.sitename` (2026-07-30):** Locked — **`NETWORK_SYSGLOBALS_OVERLAP.md`**. **Installer** prompts Site name on first provision / identity apply → `globals.sitename` (`INSTANCE_SITENAME` non-interactive). SPA **`displayInstanceLabel`**: sitename → FQDN. Editable via Network Site Name. Help text updated in `sqlite_message.sql` (seed on new DB; existing nodes: Network still works; merge help when convenient).

- [ ] **Catalog `label` ↔ node `sitename` (parked 2026-07-30):** On-node friendly name is HoR (`globals.sitename`; lab golden → “Golden”). Fleet directory `label` is separate today — can drift. Later: sync or seed catalog `label` from sitename on onboard / when Network saves (Gatekeeper / catalog write path; Rule 9). Do not invent a second node-local field. Spec: **`NETWORK_SYSGLOBALS_OVERLAP.md`**, **`instance-record.v0.json`**.

- [ ] **Fleet SPA — edge host health scrape (parked 2026-07-30):** Multi-edge load/mem/disk (and later door-knock country rollups) via Gatekeeper ← edge summary cron → S3 HoR → Fleet overlay. **Not** browser→SBC polling; **not** on-SBC heatmaps. Checklist in **`pbx3sbc-admin/workingdocs/HOME_SYSTEM_AND_FLEET_SCRAPE.md`**.

- [ ] **Door-knock geo heat / map (parked 2026-07-30):** Do **not** geolocate on every Home poll on the SBC. Prefer Fleet scrape path above. Edge keeps single-row geo on Door-knock View only.

- [ ] **Grafana / Homer — fleet view only, unmodified (parked 2026-07-30):** Stance locked. **SBC Home = Filament** (in-box). **Grafana** (and Homer if ever) = optional **fleet / multi-instance** observability later — operator-installed **unmodified** OSS (AGPL); no fork, no bundling into product installer, no on-licensing end users. If a use case needs modifying Grafana/Homer, **don’t do that use case**. Not next.

- [x] **SBC Filament Backup — merge S3-only into list (2026-08-01):** Kinship with SPA instance Backup: show local, **S3**, and **local+S3**. `sbc-backup-panel.sh list` merges S3 stamps aged out of local FIFO (keep 9); Filament **Archives** tags; restore still CLI. Live on Magrathea (33 rows: 9 both + 24 S3-only). Spec: **`SBC_BACKUP_RESTORE_REQUIREMENTS.md`**.

- [x] **SBC — hide Filament DID aliases (2026-07-30):** Lab aliases cleared by operator; `DbAliasResource` nav + `canViewAny` false; on **`main`**. Spec: **`SBC_PRODUCT_TRACKS.md`**.

- [x] **SBC — review `alias_db_lookup` (decided 2026-08-01):** Leave OpenSIPS Phase 5 fallthrough in `FROM_CARRIER` as-is. Filament DID aliases stay hidden; lab table empty — harmless. No inert/remove work now. Spec: **`SBC_PRODUCT_TRACKS.md`** · **`FLEET_TRUNK_PEERING_DECISION.md`**. Not tenant short-dial.

- [x] **WebRTC / WSS — golden demo path (2026-07-28):** Priority #1 on **golden `:8089`** (no Magrathea UDP impact). JsSIP **REGISTER + bidirectional audio OK** (Echo; ICE; channelstats 279/279). **`pjsip_webrtc.tmpl`** fixed to **`$id`/shortuid** (PBX3 phone pattern); ready conf symlink. Third-party test-mule SPA **REGISTER OK** as **`8af9ee`** (admin hint Idle); **outbound dial from that SPA still sends no INVITE** (operator comparing to SARK 6.5). SG **8089/tcp** temporarily world-open for SPA host — clamp when done. SBC WSS later (`webrtc-wss`). Recovery **`pre-webrtc-wss-20260728`**. Spec: **`WEBRTC_WSS_LAB.md`** · §6.1.

- [x] **WebRTC — fleet PrepDial skip FQDN for WebRTC (2026-07-29):** Inbound desk→`8af9ee` was `Dial(PJSIP/8af9ee/sip:8af9ee@dhbm8x.pbx3.com)` → self-INVITE / “no auth ids” → VM. **Fix:** fleet PrepDial omits `/sip:user@tenant.fqdn` when `ipphone.device=WebRTC` (WSS contact). Tip **pbx3cagi** **`3a9b7d7`**; hot on golden (`pbx3cagi.arm64` bak `…20260729091530`). After fix: Dial=`PJSIP/8af9ee`; INVITE on WSS confirmed (tshark + pjsip history); SPA TCP-ACKs, no SIP 180/200.

- [x] **Extension create — undefined `$desc` (2026-07-29):** SPA Create Extension fatals under Laravel (“Undefined variable $desc”). Store now reads `desc` from request (default `Ext{pkey}`) and persists `description` when sent. Tip **pbx3api** **`60262a0`**; hot on golden.

- [ ] **WebRTC — third-party SPA far-end (blocked 2026-08-01):** Await WebRTC/dev-team SPA. Open issues: (1) **digit-only sip-user sanitize** rejects alphanumeric shortuid — must accept `[a-z0-9]` (SIP user=`8af9ee`, dialable=`1500`). (2) Inbound: INVITE arrives on WSS but no SIP response (media/permissions / `newRTCSession` likely). Outbound from SPA previously “no INVITE” may be same class of client bug. Not a golden Asterisk gate. Clamp SG **8089** when SPA host test done.

- [ ] **`ipphone.desc` vs `description` — clarify / rename (parked 2026-07-29):** Historical SARK/Asterisk ambivalence: schema has both columns; SPA “User (extension name)” → `desc`, “Description” → `description`; list **User** prefers `desc` so freeform Description never shows when `desc` is set (e.g. `1501` vs “WebRTC second ep”). GenAst `$desc` token actually substitutes **`description`** (else pkey), not the `desc` column. Model comment still calls `desc` “SIP username” — wrong now that **shortuid** is PJSIP identity. Proper fix later: map roles (display name vs notes vs any remaining Asterisk/SIP use), align SPA labels + list, GenAst templates, API, migrate/rename if needed. Do not drive-by.

- [x] **Fleet-first tenant create — implement + lab + merge (2026-07-30):** Merged **`fleet-first-tenant-create` → `main`**: **pbx3api** **`05ab501`**, **pbx3** **`9f153f0`** (Gatekeeper provision), **pbx3spa** **`6c1e4ac`**. Lab: **Aelintra** / **`s07zmy`** on golden. Spec: **`FLEET_TENANT_CREATE_REQUIREMENTS.md`**.

- [ ] **Fleet Delete + FQDN rename (parked 2026-07-30):** Policy locked (Fleet owns lifecycle). **Rule 14:** confirm-gated **durable jobs** (not create-style sync). Primitives still needed: catalog tenant remove/soft-decommission; SBC `DELETE` domain. Node wipe already `DELETE /api/fleet/tenants/{shortuid}`. Spec: **`FLEET_TENANT_CREATE_REQUIREMENTS.md`**.

- [x] **SBC admin — Domain Routes + System nav + Home (2026-07-30):** Filament **Call Routes → Domain Routes**; **Active Calls** + **Locations** → **System**; Home ops-pulse. Merged **`rename-domain-routes` → `main`** tip **`0073471`**; feature branches deleted. Live on VIP (surgical).

- [ ] **SBC Track A lab — SARK (± FreePBX) behind SBC (2026-07-28):** Operator will stand up SARK (and maybe FreePBX) and prove REGISTER / calls via Magrathea or scratch pbx3sbc (domain → dispatcher → foreign Asterisk; phones registrar = SBC). No GenAst. Capture recipe / gaps when done — **`SBC_PRODUCT_TRACKS.md`** Track A. **After that lab:** FreePBX→pbx3 **data** migrate is a separate ETL chain (not shared with SARK `migrateLegacyDb` / `db_legacy_sql`) — requirements later.

- [x] **SBC product tracks — posture locked (2026-07-28):** Spec **`pbx3-directory/docs/SBC_PRODUCT_TRACKS.md`** (tracks **and** capability roadmap). **Teams:** C1 only. **STIR:** Twilio for now. **Gaps (ex WebRTC):** SIP TLS; optional rtpengine; downstream registration-edge; Fail2ban Peer auto-whitelist; standalone polish; dial-alias OpenSIPS miss path; second-tier restore/CPS/regex DID/observability. **Pending (non-blocking):** Bandwidth contract confirm with trunking colleague (belief: DIDs + intl).

- [x] **SBC admin — door-knock geo + SPA-kinship polish (2026-07-28):** View Door-knock shows Geographic origin (ip-api.com + 7d cache) + OSM embed map; System nav between Routing and Fail2Ban; **Backups** rename; Certificates under System with Hostname/Cert covers/Expires/Issuer (LE sudoers refreshed on VIP). CDR filters above table; blank date range = all records (Reset clears). Tips **pbx3sbc-admin** **`919938c`** (CDR layout) / **`58e35cf`** (CDR filters) / **`a904513`** (certs) / **`d506294`** (geo+Backups). Live on **`sbc.pbx3.com`**. No SIP header capture (OpenSIPS insert path unchanged).

- [x] **SPA Home — Reboot right-aligned (2026-07-28):** Start/Stop + Reboot one row; Reboot `margin-left: auto`. Tip **pbx3spa** **`368196b`**.

- [x] **Fleet multi-tenant phone dial / SBC AoR (2026-07-23):** Root cause was Asterisk→SBC `INVITE shortuid@VIP` → OpenSIPS domain guess (`LIMIT 1`) → 404 / hairpin. Fix: PrepDial + GenAst Q dials use `sip:shortuid@tenant.fqdn`; phone `$outbound_proxy` → `sbc.pbx3.com`; OpenSIPS usrloc for from-Asterisk FQDN RURIs. **Fleet-gated** (`PBX3_FLEET_MODE` / Egress) so singleton stays direct-to-contact. Lab: golden multi-tenant both ways + ring groups; rolled **08jzwn** + **bzy54n** (`pbx3cagi` **1.0.0-6**). Tips **pbx3cagi** **`fd9b146`**, **pbx3** **`1ea1210`**, **pbx3sbc** **`4509b5d`**. **Residue** (tmpl→staged phone copy, hardcoded SBC FQDN, Page/`***` presets, tighter OpenSIPS gate, tenant DNS ≠ VIP) → **`AST_CONFIG_GENERATOR_SUBPROJECT.md`**.

- [x] **Phone PJSIP G2 file overlay (2026-07-25 lab):** Tmpl + key merge; golden `fkdd5d` qualify override; calls OK. Branch **`genast-hermit`**.

- [x] **Phone PJSIP overlay — DB home of record (C2) (2026-07-25 lab):** `ipphone.pjsip_overlay`; Commit prefers DB; SPA admin textarea; golden set/clear/Commit OK. Tips **pbx3** **`9d7225f`**, **pbx3api** **`5e44203`**, **pbx3spa** **`f4e9838`**.

- [x] **WebRTC overlay Phase D (2026-07-25):** Same pattern as phones; live WSS lab **deferred**. Tip **pbx3** **`287db3d`**.

- [x] **Q* short-run Phase E (2026-07-25 lab):** GenAst `agi(Dial,…,queue)` + `Dial(${PBX3_DIAL})`; CAGI PrepDial set-and-return. Golden **Q1060** OK. Deploy cagi **before** GenAst Commit. Tips **pbx3** **`74b19ab`**, **pbx3cagi** **`e3d8522`**.

- [x] **G3 hygiene Phase F (2026-07-25):** `PBX3_SBC_EGRESS_HOST`; `$clstkey`→`park-{tenant}` before `$clst`. Tip **pbx3** **`d1ddccc`** (+ session-end tip).

- [x] **LepDial short-run Phase G (2026-07-25 lab):** PreDial → `Dial(${PBX3_DIAL})` → PostDial; ANSWER/CANCEL skip second AGI. Golden: answer, cancel→VM, timeout→VM, AstDB CFIM, SIP DIVERT OK. Tips **pbx3** **`ae1364f`**, **pbx3cagi** **`b9dd195`**.

- [x] **Trunk/queue/park C2 overlay Phase H (2026-07-25 lab):** Always tmpl + DB overlay (`trunks.pjsip_overlay`, `queue.queue_overlay`, `cluster.park_overlay`); SPA admin fields on Trunk/Queue/Tenant; golden migrate + legacy freeze rm + Commit OK. Tips **pbx3** **`91949be`**, **pbx3api** **`2c429ab`**, **pbx3spa** **`51b0fa3`** (cagi G already **`b9dd195`**).

- [x] **Ast config generator — merge hermit → main:** Merged + pushed 2026-07-25 (pbx3/api/cagi). **bzy rolled** same day (G+H call OK). Deferred D WebRTC REGISTER lab. **`AST_CONFIG_GENERATOR_SUBPROJECT.md`**. **Emergency roll back point (§5.5):** pbx3cagi **`fd9b146`** + pbx3 **`4d862e0`** (pair; not CAGI alone).

- [x] **PHP classes — drop extensionless symlink workaround (2026-07-25):** `config.php` / `bashconfig` / tls step1 point at `*.php`; extensionless names (`GenClass`, `HelperClass`, `PDFClass!`, …) removed. Hot-patch **`GenClass.php`** (not a bare name). Classes: AmiHelper, Db, Gen, Helper, LDAPHelper, NetHelper, S3Helper, PDF.

- [x] **pbx3cagi struct refactor Phases 1.3–3.1 (2026-07-25):** Dead code; `g_call`/`g_parms`; command table; `agi_sqlite.c`; `agi_init_call_context`; `agi_session_t` + name macros dropped. Offline `make test` green. Golden build+install **`c4b06bd`**; simple calls + CFIM OK. Leave LGPL `cagi.c` alone.

- [x] **pbx3cagi thread `s` + Phase 3.2 AGI wrap (2026-07-26):** Helpers take `agi_session_t *s` (PR **#1** → `main`). Thin `agi_wrap` over `AGITool_*` (PR **#2** → **`9e4bfa9`**). Golden + bzy live (md5 `8837a592…`); calls + local CF / diverted OK. **Emergency roll back point** still **`AST_CONFIG_GENERATOR_SUBPROJECT.md` §5.5**.

- [x] **Call / SIP test — Step 1 `in-open-ext` green (2026-07-27):** Mac SIPp → Magrathea VIP → DID `01924918076` → golden 1000; Snom always-auto-answer; BYE clean after scenario `rrs="true"`. Recipes now **sipplab** (was `workingdocs/call-tests/`). Full map **`CALL_TYPE_INVENTORY.md`** (U/H attendance).

- [x] **Call / SIP test — L1 pack v1 + SIPp catcher (2026-07-27):** Golden tenant **`sipp`** (`pb0wsk.pbx3.com`) exts **2000/2001** + queue **2060**; Twilio DID **`+15139279738`** → catcher. **`run-pack.sh`** / **`lab-state.sh`** / catcher UAS. **Off-box host** EIP **`98.82.58.59`** (was `98.93.98.162`; Peer gwid **99** updated; pack **11/11 green** after move 2026-07-27). Never Peer office IP. Mac: `ssh … ubuntu@98.82.58.59 'cd ~/call-tests && ./run-pack.sh'` when host up. Host notes: **sipplab** `docs/examples/aelintra-lab.md`.

- [x] **Call / SIP test — phone 302 divert (2026-07-27):** Catcher A `uas-302` → Contact `2001`; B answers. Pack id **`phone-302-local`** green on SIPp EC2 (full pack still green). Distinct from AstDB CFIM. Inventory `maj-in-phone-302-local`.

- [x] **Call / SIP test — multi-tenant AoR (2026-07-27):** Peer catcher on affcot **1199** (`s6rd88` / `9wvvnb.pbx3.com`) REGISTER’d while DID→sipp A. Pack id **`in-multi-tenant-a-b`**. Creds: golden `/tmp/sipp-peer-catcher.env` (run-pack autoloads).

- [x] **Tenant dial alias — requirements locked (2026-07-27):** §8 closed (digit plan, fleet/SBC gate, CallerID num=`suid@fqdn` + name=human, deny/CoS, return-call). Spec: **`TENANT_SHORT_DIAL_REQUIREMENTS.md`**. **Implement** when scheduled (slices A–F); at alias lab start bring **2nd SIPp** (phones, non-Peer EIP — **sipplab** `docs/HOST_SETUP.md`); L1 `site-dial-a-b` when built. Tip **`f07dd3f`**.

- [x] **Call / SIP test — grow L1 (2026-07-27):** Pack + **`feat-master-closed`** (STAT/OCSTAT) + **`in-cfim-external`** + **`out-egress-ok`** (Local→Egress; SIPp phone UAC blocked by Peer 99 IP). Catcher **`SIPP_MAIN`** OutRoute. **CAGI OutVoip** fix: `desc`→`description` (+ callprogress col). Full pack **9/9 green** on EC2.

- [x] **Call / SIP test — queue-cancel-vm + out-busy (2026-07-27):** `in-queue-cancel-vm` (agent 486→failover→VM) + `out-busy-or-reject` (Local→486→PostDial). Catcher **`uas-486`**. Holiday left for day-parts.

- [x] **Call / SIP test — optional polish / L1 pack graceful teardown — moved to sipplabs (2026-08-01):** Tracked on **[aelintra/sipplabs](https://github.com/aelintra/sipplabs)** `workingdocs/TODO.md` (pack graceful catcher teardown + post-pack dialog drain). Do not reopen here.

- [x] **sipplabs extract (2026-08-01):** Recipes moved to **https://github.com/aelintra/sipplabs**; `workingdocs/call-tests/` stub only. Live SIPp opens → sipplabs TODO.

- [x] **Inbound route pkey allows +E.164 (2026-07-27):** Digits-only regex blocked Edit Inbound Route on `+44…` DIDs. Fixed **pbx3api** + **pbx3spa**; hot-deployed controller on golden (full `git pull` still blocked by local overlay drift).

- [x] **SBC-admin numeric gwid allocate (2026-07-27):** String `MAX(gwid)` suggested 10 after Magrathea 9. Fixed **pbx3sbc-admin** `d8ea56e` — deploy on VIP when convenient.

- [ ] **pbx3cagi Phase 4 — domain file splits (parked 2026-07-26):** Direction OK; hold until cross-cutting design (esp. time-based routing / CheckState) settles — **`REFACTOR_PLAN.md`**.

- [ ] **Time-based routing — day-parts + route profiles (requirements 2026-07-26):** Replace binary DID open/close with tenant **schedule modes** + reusable **route profiles**; keep cron precompute (no GotoIfTime forest); FreePBX TC chains deferred. SARK convert first-class (dual-read). Lock §8 Q1–Q7 before code. Spec: **`TIME_BASED_ROUTING_REQUIREMENTS.md`**. Cross-repo when scheduled (pbx3 / api / cagi / spa).

- [ ] **Control plane duplex / HA (parked, pre-live 2026-07-27):** `control.pbx3.com` / Gatekeeper is a single host — ops SPOF (probes, Fleet UI, moves, notify, Edge promote). **Call plane fail-safe** by design (nodes+SBC keep routing). Not built. Later: active/standby + EIP/DNS; S3 catalog already shared HoR; local health SQLite/job queue need replicate-or-cold-standby story. Do **not** home on SBC. Spec seed: **`CONTROL_HOST.md`** · **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §2.5 fail-safe.

- [ ] **Fleet instance health includes Asterisk (parked, pre-live 2026-07-27):** Gatekeeper node badge uses HTTP **`/up`** only (Laravel app). Asterisk can be down while the instance shows Healthy. Before production: extend probe (custom `/up` checks and/or AMI/`asterisk -rx` core status) so Fleet Instances reflects **call-plane** liveness, not just API. Keep separate from Egress qualify badge. Do not block dial-alias.

- [ ] **AMI wallboard feed (side gig, parked 2026-07-27):** Feed-only live board (per-node AMI events → WS/SSE; optional summarized fleet overlay). **No** dependency on dialplan, moves, Gatekeeper call path, or operational running. Approximate tenant attribution (SUID-in-channel). Do not couple to drain/velocity act. When demand appears — separate small track.

- [ ] **Drain affordance — tenant-scoped “up calls” + wipe-when-drained (nice-to-have, parked 2026-07-23):** On move job `awaiting_cleanup` / Fleet Instances, show approximate active-channel count for the moving tenant on **source** (AMI `CoreShowChannels` → fleet.token → Gatekeeper overlay). Heuristic: phone channels carry extension **SUID** → tenant; SBC legs out of scope. **Follow-on:** optional **wipe-when-drained** — auto-advance Phase 8 when source tenant channel count stays at 0 for N probes (still a durable job; operator can opt in; never silent wipe without the gate existing). Best-effort — do not treat AMI as attested. Not built.

- [x] **PSTN number dialects v1 (2026-07-22):** Spec **`NUMBER_DIALECT_REQUIREMENTS.md`**; Peer Filament **Number dialect** presets (`uk-magrathea` / `uk-gamma` / `strict-plus-e164`); OpenSIPS inbound normalize + outbound render/PAID live Magrathea+companion; UK Egress seed `0:+44 00:+` (DNID only — CLID as-is). MkDocs **`fleet/number-dialect`**. Tips **pbx3** **`f36db55`**, **pbx3sbc** **`3404608`**, **pbx3sbc-admin** **`c623d0c`**, **pbx3-docs** **`12f32e3`**, spa handoff **`07c0969`**.

- [x] **Twilio trial dialect lab (2026-07-22):** Elastic SIP Trunk DID **`+15139279738`** → golden **1000** (inbound Peers gwid **40–47**, `dialect=strict-plus-e164`); outbound Peer **50** `sip:aelsbc.pstn.twilio.com:5060`. Inbound + direct Twilio egress audio OK. Outbound gwlist lab end-state **`1,20,50`** (Brindley first — Magrathea may not take intl on this account). UK habit `001…` → cell via Brindley OK; trombone DID via Brindley→Magrathea → **no answer** (trial/Twilio-side). Golden **`extensions.conf`** symlink to GenAst path fixed earlier same arc. **Live DB only** — no new git tips this slice.

- [x] **Toll fraud / velocity — V0 framing (2026-07-22):** Own track **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`** — direction of flow; phases **V0–V5**. **2026-07-23:** V1/V2 build plan fleshed (batch CDR, IRSF-only, fixture-first, `velocity_irsf`). **Next when prioritized:** V1 fixture + query → V2 scanner+notify.

- [x] **Toll fraud / velocity — V1+V2+V5 (2026-07-24):** Fixture + CSV import + `VelocityCdrQuery`; `pbx3:ops-velocity` → Gatekeeper `velocity_irsf`; V5 act (`active=NO` + clear CF + hangup + genAst) behind `PBX3_OPS_VELOCITY_ACT`. **Live golden:** notify **on**, act **off**, prefixes `00900`. Tips **pbx3api** **`afd56d0`**, **pbx3** **`9f5a7bf`**. Follow-ons: V3 templates; SPA “disabled by velocity”; optional ACT enable.

- [ ] **Toll fraud / velocity — standalone product (parked 2026-07-24):** Own **repo + installer** “just in case”; detect/notify portable to any Asterisk; **Go scanner** candidate (static binary); act via adapters (pbx3 reference). Do not fork this week. Spec § Future — **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`**.

- [ ] **Number dialect — paid Twilio + follow-ons:** Operator will sign up full Twilio; named Twilio Peer “recipe” (optional — today `strict-plus-e164`); US Egress `011:+` seed; Magrathea gwid **20** may still lack `dialect=uk-magrathea`; custom-dialect UI. Future product thread: global DID → EU CC on SBC (RTP bypass vs Asterisk/rtpengine stage). Spec: **`NUMBER_DIALECT_REQUIREMENTS.md`** · MkDocs **`fleet/number-dialect`**.

- [x] **Fleet Instances Egress badge (2026-07-22):** Gatekeeper probe → `GET /api/fleet/egress-qualify` (fleet.token); catalog `health.egress_*`; SPA Fleet Instances shows **Egress Avail/Unavail**. Ops-notify follow-ons (Egress mail + SPA badges) closed for now.

- [x] **Ops notify — Egress Unavail (2026-07-22):** Instance `pbx3:ops-egress-qualify` (hysteresis 2) → Gatekeeper `egress_unavail` down/cleared mail. Enable `PBX3_OPS_EGRESS_UNAVAIL_NOTIFY=true`. Spec: **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** · **`CONTROL_HOST.md`**.

- [x] **Fleet Egress R1+R2 (2026-07-22):** OpenSIPS OPTIONS from dispatcher → **200**; `qualify_frequency=30`; golden/bzy **Avail**. SPA: Trunks Latency + route **Egress Avail** badge via `fleet-posture.egress_qualify`; preflight **Egress qualify**. R3 EgressFailover/cagi still open. Spec: **`FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`**.

- [x] **Filament Backup “On S3?” + Magrathea cron (2026-07-22):** `sbc-backup-panel.sh list` joins local stamps to S3 prefixes; Filament **System → Backup** shows Yes/No. Live on VIP Magrathea. Cron `/etc/cron.d/pbx3sbc-backup` confirmed (`0 2 * * *` scheduled `--upload`).

- [x] **SBC HA — Phase D LE after promote (2026-07-22):** Promote runs `le-admin-cert.sh setup` on new active via SSH (`GATEKEEPER_EDGE_LE_EMAIL`, default on). `le-admin-cert` nginx keeps `/api/` on HTTP for warm-sync. Lab: companion LE live — `https://sbc.pbx3.com/admin/login` **200**. Fleet `POST /api/fleet/le-setup` also added (FPM/certbot flaky — promote uses SSH). Spec: **`SBC_HA_FAILOVER_REQUIREMENTS.md`** · **`CONTROL_HOST.md`**.

- [x] **SBC Filament Backup + Fleet warm sync (2026-07-21):** Filament **System → Backup** (VIP holder only; list local; optional S3 upload; no restore UI). Fleet **Edge HA → Sync now** (S3-mediated active backup → standby `--db-only`) + daily `pbx3-edge-warm-sync.timer`; Sync progress spinner. Companion warm-ready: fleet token, `log-ship.env`, AWS CLI, IAM `pbx3-sbc`; scripts `check-ha-standby-ready.sh` / `bootstrap-ha-standby-warm.sh`. Lab: Backup now + Sync now OK. Tips **pbx3** **`129ef40`**, **pbx3spa** **`d021f60`**, **pbx3sbc** **`9373d30`**, **pbx3sbc-admin** **`7dda7fb`**, **pbx3-docs** **`b9fb77f`**. Restore stays CLI (scratch runbook). Spec: **`SBC_BACKUP_RESTORE_REQUIREMENTS.md`**.

- [x] **SBC HA — Magrathea live pair + promote (2026-07-21):** Companion `i-00964a57ac65383d1` greenfield (VIP `advertised_address` = Magrathea EIP); warm `--db-only`; Fleet pair **`magrathea-lab`** (one pair at a time). Promote Magrathea→companion (~3 s EIP) and flip-back (~5 s); new calls OK. Soft-state: in-progress Magrathea PSTN / Asterisk-bridged calls can survive EIP move. Probe Healthy on VIP. Pair card: EIP `3.93.26.82` / `eipalloc-0814f5e931414fd2a`; A `i-078cca73d4a4106bb`; B `i-00964a57ac65383d1`.

- [x] **Fleet Edge HA panel — settings + one-pair CRUD (2026-07-21):** `ControlSettingsStore` SBC admin API URL (DB→env); `POST/DELETE /api/v1/edge-pairs`; SPA Add/Delete (hide Add when pair exists); no FO auto-seed. Live on control.

- [x] **SBC HA FO greenfield pair (2026-07-21):** Throwaway EC2 — FO1/FO2; drills done. **`fo-lab`** deleted from control after Magrathea pair. Spec: **`SBC_HA_FAILOVER_REQUIREMENTS.md`**.

- [x] **SBC admin greenfield installer hardening (2026-07-21):** Require `--server-name`; `APP_URL` from FQDN; optional `--letsencrypt --email`; Fail2ban+LE sudoers; idempotent Laravel migrations vs OpenSIPS pre-created sessions/cache; non-interactive composer root + DB port 3306 default; Filament **Certificates** (SPA layout kinship) + `le-admin-cert.sh` + progress spinner. Tips **pbx3sbc-admin** **`a0ded23`**, **pbx3sbc** **`c085b50`**, **pbx3-docs** **`25b3917`**.

- [x] **SBC HA — warm sync + promote drill (2026-07-21):** FO1→FO2 `--db-only` warm; fence + EIP → FO2; OPTIONS ~**6 s**; Phase D LE + `https://sbcfo.pbx3.com/admin/login`. MkDocs **`fleet/sbc-ha-promote.md`**.

- [x] **SBC HA — control-plane promote modes (2026-07-21):** Gatekeeper `edge_pairs` / SIP OPTIONS probe + timer; `edge_down`/`cleared` notify; `managed`\|`auto`; auto EIP promote on FO (~18 s wall); `POST /promote`; SPA **Edge HA**. IAM `pbx3-control-gatekeeper-fo-eip`. Default **Manual** + `GATEKEEPER_EDGE_AUTO_PROMOTE=false`. Spec: **`SBC_HA_FAILOVER_REQUIREMENTS.md`**.

- [x] **SBC HA — promoter SSH fence (2026-07-22):** Root cause was **`GATEKEEPER_EDGE_SSH_KEY` unset** on control. Installed `/etc/pbx3-gatekeeper/edge-ssh.pem` (www-data mode 600) + env. `EdgePairPromoter::fenceInstance` returns `fenced`/`fence_detail` (sudo -n stop opensips); SPA shows fence note. Lab: PHP fence companion OK. Spec: **`SBC_HA_FAILOVER_REQUIREMENTS.md`** · **`CONTROL_HOST.md`**.

- [x] **SBC scratch-box restore drill (2026-07-20):** amd64 `192.168.1.55` — install both repos → restore `20260720T172044Z` → OpenSIPS active + Filament Login 200; counts matched lab. Post-restore: align DB password + `advertised_address` + `www-data` home perms. Spec: **`SBC_BACKUP_RESTORE_REQUIREMENTS.md`**.

- [x] **SBC backup + restore scripts v1 (2026-07-20):** backup/upload/cron; `restore-sbc-backup.sh`; `fetch-latest-sbc-backup.sh`; S3 + scratch restore drill done.

- [x] **SBC SQLite + Litestream — dropped (2026-07-27):** Won’t do. Engine is MariaDB; Filament/S3 backup + warm sync are enough. Do not spike. Historical note: **`FLEET_TRUNK_PEERING_DECISION.md`** §6.0.

- [x] **SBC data & log aging WS0–WS4 (2026-07-20):** Lab live — purge + cron; Filament **Logs → Data retention**; MkDocs `fleet/sbc-data-retention.md`. Spec: **`pbx3-directory/docs/SBC_DATA_RETENTION_REQUIREMENTS.md`**.

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

- [x] **Peering — logical carrier Peers UX (attrs):** **`PEERING-PLAN.md` §0.1** + pbx3sbc-admin Peers form/table group by `carrier=` / `role=` in **`attrs`** (no OpenSIPS/schema change). Lab seed + Magrathea/Brindley backfill. Fail2ban auto-whitelist split out below.

- [ ] **SBC Fail2ban — inbound Peer auto-whitelist + ban notify (deferred until next carrier onboard):** (1) Auto-sync **carrier inbound Peer IPs** into Fail2ban whitelist on Peer save/delete — implement when onboarding the next carrier so it can be lab-tested live. (2) **Customer site** IPs remain **manual** whitelist (existing UI) — no site CRM. (3) **Ban events → email** via ops notify delivery when that track ships. Edge-authored (Rule 13). Spec: **`PEERING-PLAN.md`** §0.1 · **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** § Fail2ban.

- [x] **Fleet mode in pbx3spa (2026-07-13 → `main`):** **Enter Fleet / Exit Fleet** shell swap, `/fleet/*` guards, Instances / Tenants / **Jobs**, `FleetTokenGate`. **pbx3spa** **`ba31dd4`**, gatekeeper list API **pbx3** **`c047743`**. Branch **`fleetadmin` deleted**.

- [ ] **Instance shadowing (parked — framing locked 2026-07-21):** Paid SKU for customers who want min downtime: warm PBX twin + same promote mechanics as SBC edge HA (Manual/Auto, VIP/EIP, soft-state loss OK). Not default for every node. Implement after SBC HA is operational on real lab edge. Spec: **`pbx3-directory/docs/INSTANCE_SHADOWING_REQUIREMENTS.md`**. Related: **`SBC_HA_FAILOVER_REQUIREMENTS.md`**, egress availability.

- [x] **Ops failure notification — v1 probe + SMTP (2026-07-16):** Gatekeeper `bin/probe-fleet-instances.php` + systemd timer; SQLite `instance_health` (down after 2 misses); S3 `last_seen_at`; `Mailer`/`SmtpMailer`; `users.notify_failures` + SPA checkbox; `GATEKEEPER_OPS_NOTIFY_EMAIL`. Lifecycle maintenance/decommission mail. **Misconfig REGISTER:** `pbx3api` `pbx3:ops-register-loops` → Gatekeeper `POST /api/v1/ops-events`. Instance Asterisk F2B jail **off** (SIP ban on SBC); mail resolves shortuid→dialable. **Follow-ons:** move-job mail; Fail2ban Peer auto-whitelist / ban→email; SPA badges. Spec: **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`**.

- [x] **SPA Fleet Instances polish (2026-07-18):** Full copyable KSUID; probe RTT next to Active; health badges (Healthy ≤2m / Warning ≤5m / Degraded / Down / Probe paused for maintenance); manual Refresh. Gatekeeper measures RTT → SQLite `last_rtt_ms`; `GET /api/v1/catalog` overlays `health` (not S3). Branch **`instances-polish` → `main`**. Live on control (probe RTT ~60ms).

- [x] **SPA panel polish (2026-07-18):** DID list UID removed; extension SIP Registrar + Behaviour (CFIM/CFBS/ringdelay) + drop Common name; latency chip bands; Network searchable timezone. Log: **`pbx3spa/workingdocs/PANEL_POLISH_2026-07-18.md`**. Branch **`changes` → `main`** **`7dda918`**.

- [x] **pbx3sbc-admin SPA kinship polish (2026-07-18):** Topbar height/brand + Instance chip + Logged in as / Logout; Lucide sidebar icons; pill badges; icon-only Edit/Delete/View (+ Call Routes tooltips); Home / Home — FQDN; AccountWidget removed; ← list back links on edit/view/create; © Aelintra Telecom sidebar footer. Branch **`SBCpolish` → `main`** tip **`463431b`**. Live on **`sbc.pbx3.com/admin`**.

- [x] **Admin auto-logout (2026-07-19):** SPA + SBC admin idle logout, default **10 minutes**, configurable. SPA: `VITE_AUTO_LOGOUT_MINUTES` (build-time; absent → hardcoded 10 — see **`pbx3spa/workingdocs/DEV_ENVIRONMENT.md`** §7b). SBC: `PBX3_ADMIN_INACTIVITY_MINUTES` (runtime). Tips **pbx3spa** **`5c36ce2`**, **pbx3sbc-admin** **`2e56ae3`**. Live SBC: surgical copy of `config/panel.php` + `topbar-user.blade.php` (dirty tree — no wholesale `git pull`/reset); SSH key **`~/Documents/pemfiles/opensips.pem`**.

- [ ] **Log retention Phase 7 / SBC `acc` (superseded by broader review):** Planning moved to **`SBC_DATA_RETENTION_REQUIREMENTS.md`**. See open item **SBC data & log aging review**.

- [ ] **Downstream peer registration edge (future — not next):** Separate **registration-edge** SBC instance class + own OpenSIPS image; auth HoR on that edge; trusted SIP link into main **pbx3sbc**. Not bolted onto current SBC. Interim lab workaround (extension-like REGISTER via Asterisk) documented — not product path. Spec: **`pbx3-directory/docs/DOWNSTREAM_PEER_REGISTRATION_REQUIREMENTS.md`**.

- [x] **Log retention Phases 1–6 (2026-07-17):** Rotate/ship/lifecycle/siplog/SBC/control (1–4) on **`main`**; Phase 5 retention knobs + S3 archive list/download; Phase 6 Asterisk `cdr_sqlite3_custom` + `GET /cdr` + SPA `/cdr`. Lab: golden + bzy54n @ **pbx3api** **`6c28486`**. Spec: **`FLEET_LOG_RETENTION_REQUIREMENTS.md`**.

- [ ] **Fleet slug / org bucket naming (cosmetic — fix later):** Lab buckets `08jzwn-pbx3` (+ recordings) use first-node shortuid as stem; product should choose a **neutral fleet slug** at provision (`acme-pbx3`). No runtime impact. Design note: **`OPS_S3_RUNBOOK.md`** § Design note — fleet slug vs lab bucket name. Fold into onboard / S10.7 / create-fleet when that ships.

- [x] **S8.10 — interim gatekeeper auth harden (2026-07-10):** Production SPA must not bake `VITE_FLEET_GATEKEEPER_TOKEN`. Token from **sessionStorage** (Fleet tenants paste) or **DEV-only** Vite env. Gatekeeper README documents lab vs prod vs future control-plane login. Catalog reconcile: nodes/SBC aligned; added missing SBC domain **sandycroft** `vqcwd4.pbx3.com` setid 2.

- [x] **S8.10 — live panel moves + phone POC (2026-07-10):** **willand** (`0ggybk`) 08jzwn→bzy54n job `tmj_bf41c7b45dfc97d72135faf1`. **affcot** (`9wvvnb`) bzy54n→08jzwn job `tmj_7efdc9646309ff3641d21839` — Snom followed SBC remount (setid 3→2); dest commit/`genAst` ran. Preflight gap: willand needed SBC `domain` row before move (added setid 2 then cutover). Linphone 1102 flaky — parked. **Merged to `main`** same day.
- [x] **SBC HA requirements — VIP/EIP + warm standby (2026-07-20):** Locked **`pbx3-directory/docs/SBC_HA_FAILOVER_REQUIREMENTS.md`** (+ mermaid schematic). Option 3; ~15–20 min RTO; ~4 nines surface-dependent; SRV rejected as primary; usrloc sync deferred; Occam over seconds. **Implement later** (second member + promote drill — env TBD tomorrow; lean EC2). Cross-links §6 / backup / PEERING-PLAN.

- [x] **Edge portability scorecard (2026-07-20):** **`EDGE_PORTABILITY_SCORECARD.md`**. Adapter seam green; OpenSIPS vocab amber/red — **do not rename** for purity. Escape hatch: **peer/cascade** commercial SBC like Magrathea (not BYO-edge rewrite). Rule 7 link in **`DESIGN_RULES.md`**.

- [x] **SBC HA promote lab env decided (2026-07-21):** Minimal EC2 pair (real EIP). Greenfield FO1/FO2 installed — see open item **SBC HA — warm sync + promote drill**.

- [x] **Fleet Egress R1+R2 (2026-07-22):** see Open items above — R3 EgressFailover/cagi still open.

- [x] **Phase S8.10 — Fleet mobility scaffold (2026-07-10):** On **`movewizard`** then **`main`**: `tenant-move-job.v0.json`; gatekeeper presign + tenant-moves + phase runner; pbx3api `/api/fleet/*`; pbx3sbc-admin `/api/fleet` repoint; SPA Fleet tenants Move wizard + job view (**lab** — peer nav; product = Fleet **mode** in same SPA).

- [ ] **pbx3sbc — multi-tenant dispatcher reverse lookup:** Template + **`add-dispatcher.sh`** accept **`source_ip`** in dispatcher **`attrs`**. **Live:** golden **setid 2** (`54.236.153.81`), **bzy54n setid 3** (`98.82.174.36`); tenant domains on SBC. **Optional backfill:** hostname dispatcher rows (`sip:08jzwn.pbx3.com`) if needed. See **`opensips.cfg.template`** `route[GET_DOMAIN_FROM_SOURCE_IP]`.

- [ ] **Phase S8 — Fleet (optional polish):** **S8.1–S8.6 shipped and drill-validated** (affcot **08jzwn → bzy54n**). Remaining optional: LE Sync post-cutover; **`move-tenant.sh`** if catalog workflow preferred over **`register-tenant.sh`** for first-time tenants. See **`TENANT_MIGRATION_RUNBOOK.md`**.

- [x] **Tenant move — source wipe in the job (2026-07-23):** Full cascade via `TenantMobilityService::destroyTenantData` on fleet + SPA delete; Gatekeeper `awaiting_cleanup` → wipe + Commit (LE sync best-effort on dest + source). Drain: leave job page, reopen Fleet → **Jobs**. Lab: sandycroft round-trip OK. Tips **pbx3api** **`4930e2b`**, **pbx3** **`baf9040`**, **pbx3spa** **`edd270b`**. Runbook Phase 8 + MkDocs **`fleet/tenant-move`**.

- [x] **Phase S7 — PCI staging settled (docs 2026-07-14):** S7 = PCI-**shaped** baseline (dedicated private bucket, BPA, TLS, SSE-S3, gatekeeper presigns, non-attested wording); attested KMS/CloudTrail/Security Hub/QSA/PSP = **S7+**. Search stays SQLite on node; S3 = blobs only. **`d0801c5`**.

- [x] **Phase S7 — Recordings S3 offload (2026-07-14 evening):** Dedicated bucket **`08jzwn-pbx3-recordings`** (BPA/TLS/SSE-S3); gatekeeper **`POST /api/v1/s3/presign-recordings`**; pbx3api **`pbx3:recordings-s3-upload`** + `s3_key` + S3-only play proxy; SPA **Storage** column; `policy.json` + lifecycle `class=recording` 60d; retention keeps **`s3_only`** searchable; **S7.10** **`pbx3:recordings-reconcile`** sweeper (nightly 03:15). Live on control + golden. Tips: **pbx3** **`ed484f3`**, **pbx3api** **`6f46712`**, **pbx3spa** **`6e23fa3`**. Ops: **`OPS_S3_RUNBOOK.md`** §13. **Not** PCI-attested.

- [ ] **S7+ — Attested PCI / scale (deferred):** KMS CMK; CloudTrail→WORM audit bucket; Security Hub; QSA; PSP handoff; Athena/manifests. Do not start without customer ask. Design §6.2 / §7 S7+.

- [ ] **OSS org + repo registry:** Create GitHub org per **`OPEN_SOURCE_GITHUB_SETUP.md`** (e.g. `github.com/pbx3`). **Stay multi-repo** — transfer **`pbx3`**, **`pbx3api`**, **`pbx3spa`**, **`pbx3cagi`**, **`pbx3-docs`**. Maintain **`REPOS_AND_RELEASES.md`**. Interim docs repo already on **`aelintra/pbx3-docs`**. Update local clone remotes; keep **`pbx3-master/`** holding-folder layout.

- [x] **User guides — MkDocs site (`pbx3-docs`) seed (2026-07-15):** Holding-folder **`pbx3-docs/`** + GitHub **`aelintra/pbx3-docs`** → Pages **https://aelintra.github.io/pbx3-docs/**. Approved nav (Cloud/S3 + intro schematic); operator drafts for install/TLS/admin/fleet/cloud/troubleshoot (lab URLs). Content map updated. **Ongoing:** human review/edits; agent adds sections on request. Optional later: SBC / recordings chapters; move to OSS org. **`workingdocs/`** stay unpublished.

- [ ] **pbx3cagi refactor (under Ast config generator + cagi track):** Phase 0 harness **golden-signed-off** on **08jzwn**. Resume Phase **1.3 → 1.1 → 2.x** with generator work; run **`make test`** after each step. Contract: **`AST_CONFIG_GENERATOR_SUBPROJECT.md`** §5. Gate: **`REFACTOR_PLAN.md`**, **`TEST_HARNESS.md`**, **`TEST_RECIPE.md`**.

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

- [x] **Instance user privileges — P0–P4 (2026-07-22):** **`INSTANCE_USER_PRIVILEGES_REQUIREMENTS.md`**. Lab: sandycroft→bzy + joe; FormField create-user fix; orphan cleanup. Source wipe in move job done 2026-07-23.

- [x] **Login homing B′ thin slice (2026-07-23):** Compiled `catalog/tenant-home.json` (shortuid/cname → instance_id); Gatekeeper rebuild on register/move + `POST …/tenant-home/rebuild`; Mac `rebuild-tenant-home.sh` (macOS-safe); SPA three-door login with **Sign in to tenant first**; join to instance-index → Sanctum. Lab: published rollup (5 tenants); QA `vqcwd4` / `joe@gmail.com` → bzy tenant nav OK. Tips **pbx3** **`4d2f137`**, **pbx3spa** **`ffede89`**. Spec: **`INSTANCE_USER_PRIVILEGES_REQUIREMENTS.md`**. **Follow-up (done same evening):** Gatekeeper rsync’d to control + FPM reload; `POST /api/v1/catalog/tenant-home/rebuild` → **200**, 5 tenants, `updated_at=2026-07-24T01:05:56Z`. Three wrong-door UX stays without SSO (accepted).

- [ ] **User access privileges (SPA + API — P1–P3):** Phase 0 done (admin-or-nothing gate). Implement per **`INSTANCE_USER_PRIVILEGES_REQUIREMENTS.md`**. Do **not** implement SPA Phase F in isolation — ship **pbx3api** + **pbx3spa** together. Pattern: **`ADMIN_PANELS_AND_PERMISSIONS.md`**; **`AUTH_PATTERNS.md`**.

- [ ] **tt_help_core cleanup — unreferenced rows (final pass):** Reverse audit found **230** `tt_help_core` rows with no SPA field help wiring (**`pbx3spa/scripts/audit-unreferenced-help.mjs`** → **`pbx3spa/workingdocs/HELP_UNREFERENCED_IN_SPA.md`**). Review each: retire legacy-only keys (e.g. DHCP server, factory-reset wizards, BLF bulk editor) vs keep for future panels. Re-run script after SPA changes; prune or rewire as needed. Pair with forward audit **`audit-field-help.mjs`** for missing help on live fields.

- [ ] **SPA hygiene (deferred — after S8 / R1 / core panels):** No work until functionality complete; runs fine on golden/LAN today. Then: **(1)** route lazy-loading in **`router/index.js`**; **(2)** extract shared list/detail patterns when adding panels (avoid new 600+ line views). See **`pbx3spa/workingdocs/PROJECT_PLAN.md`** § Current state, **`PBX3SPA_CODEBASE_ANALYSIS.md`** § Phase H / H2.

- [ ] **SARK V6 migration routines (revisit, low priority — end of list):** Golden demo data still had tenant-scoped **`cluster`** on pkey (e.g. `affcot`) because **`sqlite_fixRi.sql`** was never applied; new SPA/API writes use shortuid, which broke joins (CoS on extensions). Shipped interim repair: **`sqlite_normalize_cluster_to_shortuid.sql`** (idempotent; **pbx3 0.0.3-20**). **Later revisit:** full **`db_legacy_sql`** path (`sqlite_create_legacy.sql`, **`sqlite_fixRi.sql`**, lineio, etc.) — ensure import always runs fixRi (or the normalize script), document operator steps, cover tables fixRi omits (`dateseg`, `holiday`, `page`, `users`, CoS junctions), and decide whether fixRi stays one-shot-only with normalize as the supported repair. Do not run stock fixRi on mixed DBs (NULLs shortuid rows). **FreePBX→pbx3 migrate:** separate future ETL (no shared components with this SARK path); defer requirements until after FreePBX-behind-SBC lab.

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
