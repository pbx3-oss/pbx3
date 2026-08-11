# PBX3 ToDo list

**Last updated:** 2026-08-11 (pbx3 `0.0.5-5` SIP debug rolled fleet-wide)  
**Branch:** Product repos **`main`**. Private session state: **`~/GiT/pbx3-ops`** (**`TODO_OPS.md`** for tip/lab gossip). SPA via **`npm run dev`**.  

### Suggested “what next?” order

0. **Customer migrate ETL v2 — more fixture tests** — offline migrate + optional lab load; CDR→sipplabs when ready (private **`aelintra/sark-to-pbx3`**). Tip/host gossip: **`~/GiT/pbx3-ops/TODO_OPS.md`**.  
1. ~~**Workingdocs hygiene**~~ — **done** (session handoffs in **`aelintra/pbx3-ops`**; product stubs remain).  
2. ~~**Apache-2.0 `LICENSE` files**~~ — **done** (clean Apache-2.0 on product repos; see open-item note).  
3. ~~**Strip customer-migrate tooling from pbx3**~~ — **done** (private ETL owns migrate; package keeps shortuid normalize only).  
4. **First out triage** — **`FIRST_OUT_CHECKLIST.md`** (must-fix F1–F5 vs nice N* vs parked).  
4a. ~~**Pre-release safety debt (go/no-go)**~~ — **code + tests + golden go-smoke done** (`PRE_RELEASE_SAFETY_DEBT.md` 1–16). ChanSpy desk + sipplab feature pack **U**; golden dial + SPA login + DID `441924910444` green (2026-08-09). Bzy smoke optional.  
4b. ~~**Tenant delete data integrity**~~ — **T1–T5 done** (`TENANT_DELETE_DATA_INTEGRITY.md`). Lab green **`TENANT_WIPE_AND_EXT_LEN_LAB.md`** §1 (2026-08-10). Remaining optional: T6 DID policy, T7 Class B, T8 FK.  
4c. ~~**Enforce tenant `ext_len`**~~ — **done** (`TENANT_SHORT_DIAL_REQUIREMENTS.md` §3.8 / Q15). Tip-deploy + lab green **`TENANT_WIPE_AND_EXT_LEN_LAB.md`** §2 (2026-08-10).  
4d. ~~**Fleet trunk Create vs Edit**~~ — **done** (`FLEET_TRUNK_PEERING_DECISION.md` §4.3.1): hide/403 Create on fleet; keep Edit for Egress mangle.  
5. **Lab deployment (when scheduled)** — **`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`**: LAN Lab T4; prefer **3 VMs** for two homes (Mag+GK+Garage / Ast1 / Ast2); optional public-carrier pilot = **chunked RTP DNAT** before rtpengine. OSS gates cleared.  
5a. **Toliman vanity shortuid (`kildare`)** — hold; preferred path delete/recreate (opaque suid) after tenant move exercise — see **TODO_OPS**.  
5b. **Instance Name → SBC Peer label sync** (optional) — Fleet Name PATCH does not update Magrathea Peer description today.  
6. **pbx3api `.deb`** — versioned package for `/opt/pbx3api` (Ubuntu/Debian long-haul; apt parity with pbx3/cagi). Clone-at-tag OK until then.  
7. **New instance / package install** — fleet packages **pbx3 `0.0.5-5`** / **pbx3cagi `1.0.0-18`** (SIP debug + SITE_DIAL hairpin; rolled 2026-08-11). Tip-deploy **pbx3api** SIP debug + TrunkController lab-wide; optional full API checkout align. Ops: **`TODO_OPS.md`**.  
8. **Toll fraud / velocity — remainder** — V1/V2/V5 shipped (env-only IRSF burst + notify + optional act); finish product: **V3** fleet rule template, **V4** audience, SPA surface, more detectors. Spec: **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`**. Design still thin for V3+ — lock before build.  
8a. **Product crumbs** (optional) — paid Twilio **lab green** (inbound+outbound); remaining: named Peer recipe / O4 US seed / drain / custom-dialect UI.  
9. **Multi-AZ lab** — instances in **different AZs** (WebRTC / RTP proof).  
10. **pbx3cagi Phase 4** (parked; day-parts merged — unblocked when wanted).  
11. **Velocity standalone SKU** (parked — after in-tree remainder or instead) — own repo/installer; see requirements § Future.  
12. **Instance shadowing** / S10.7 / S8.9 (parked).  
13. **AMI wallboard** (parked).  
14. **Fleet node health ≠ Asterisk** (parked — also **N3** on first-out checklist).  
15. **Control plane duplex / HA** (parked).  
16. **Fleet auth cookie/SSO (blocked)**.  
17. **TOTP 2FA — Fleet Gatekeeper G5** (optional — require for `fleet_admin`; G1–G4 shipped).  
18. **S7+** attested PCI — customer ask.  
19. **SBC Track A / STIR Twilio lab** — **`SBC_PRODUCT_TRACKS.md`**.  
20. **Grafana / door-knock geo** (parked).  
21. **Pre-first-release — SPA bundle diet** (parked — **N1**).  
22. **Lab / demo DB anonymize** (parked — **F5** if external demo).  
23. **Provisioning (home listener + edge proxy)** — direction **2026-08-10**: SARK lift on home + nginx Host→home proxy (stable A; no DNS on move). Spec: **`PROVISIONING_SERVER_REQUIREMENTS.md`**. Schedule when prioritized; TLS §0 cross-link when shipping.  
23a. **UA → `devicemodel` sidekick** (parked) — **`EXTENSION_PHONE_IMAGE_FROM_UA_REQUIREMENTS.md`** (implement A–D when scheduled; images = E).  
24. **SPA list action icons component** (parked).  
25. **Number wire Phase 2 / D2–D4** (parked).  
26. **Seed outbound US dialplan string (O4)** — optional; UK `_0XXX. _00XX.` shipped (#4c).  
27. **Instance API digest deepen** (optional).  
28. **Device templates** — seed lean + nav done; prune existing DBs / drop routes residual.  
29. **OSS org + repo transfer** — after Apache `LICENSE` + migrate extract/strip (**done**).  
30. **Optional SBC media plane / rtpengine** (parked) — only on LAN-edge / Track A / Peer trigger; see try-it doc Appendix A.  
31. **Incident notify (parked)** — tenant callout teams → ConfBridge + optional SMS; SARK `mcstcaller` heritage. Spec: **`INCIDENT_NOTIFY_REQUIREMENTS.md`**. Est. **~5–7 d** v1 (voice MVP **~4–5 d**). Not first-out.  
32. ~~**Instance SIP logging**~~ — **done** (A–G on **`main`**; **pbx3 `0.0.5-5`** on golden/bzy/Toliman; API tip; S3 **`sip-text`** ship confirmed). Spec: **`HOME_SIP_LOGGING_REQUIREMENTS.md`**.  

**SIPp lab work** (pack teardown, traffic profiles, soak) lives in **[aelintra/sipplabs](https://github.com/aelintra/sipplabs)** `workingdocs/TODO.md` — not here.

---

## Open items

- [x] **Pre-release safety debt 1–16 (2026-08-09):** Code + tests in product repos. ChanSpy desk + unattended shortcode pack green. Checklist: **`PRE_RELEASE_SAFETY_DEBT.md`**.

- [x] **Pre-release go smoke — golden (2026-08-09):** Dial + SPA login + fleet DID `441924910444` (Peer SIPp → Magrathea → `dhbm8x`/`1000`). Bzy optional.
- [x] **Tenant delete data integrity T1–T5 (2026-08-10):** Wipe-preflight; mesh prune; park cleanup; `pbx3:tenant-orphan-audit`; `pbx3:tenant-wipe-list-check`. Spec: **`TENANT_DELETE_DATA_INTEGRITY.md`**. Lab: **`TENANT_WIPE_AND_EXT_LEN_LAB.md`** §1. Open later: **T6** DID policy, **T7** Class B, **T8** FK.

- [x] **Enforce tenant `ext_len` (2026-08-10 #4c):** Default **3**, max **5**, allowed **2–5**; no mixed-length extension pkeys. GenAst PrefixDial fixed remainder; OutRoute/sysglobal seed min match `> ext_len`; UK seed `_0XXX. _00XX.`. Spec: **`TENANT_SHORT_DIAL_REQUIREMENTS.md`** §3.8 / Q15. Lab: **`TENANT_WIPE_AND_EXT_LEN_LAB.md`** §2.

- [x] **Fleet trunk Create vs Edit (2026-08-10):** No Create on fleet (SPA hide + API 403); Edit kept for Egress mangle. Solo unchanged. Lock: **`FLEET_TRUNK_PEERING_DECISION.md`** §4.3.1.

- [x] **Workingdocs hygiene — product vs agent session (done 2026-08-09):** Curate in-repo; quarantine session handoffs. Private **`aelintra/pbx3-ops`**. **Light peel same day:** research/audits/tippy lab → **`pbx3-ops/devdocs/`**; active requirements stay in product. Cross-link: **`OPEN_SOURCE_GITHUB_SETUP.md`** · **`workingdocs/README.md`**.

- [x] **Apache-2.0 `LICENSE` on product repos (suggested #2, done 2026-08-09):** Clean Apache License 2.0 root `LICENSE` on **`pbx3`**, **`pbx3api`**, **`pbx3spa`**, **`pbx3cagi`**, **`pbx3sbc`**, **`pbx3sbc-admin`** (removed mistaken httpd subcomponents appendix). Packaging: `debian/copyright` / composer / `package.json` license fields. Copyright owner **Aelintra Telecom Limited**. See **`OPEN_SOURCE_GITHUB_SETUP.md`**.

- [x] **Customer migrate ETL → separate Aelintra repo (2026-08-08/09):** Private **`aelintra/sark-to-pbx3`**. **v2 offline** (`bin/migrate-offline.py`) is primary; v1 on-host for parity. Fixtures: `~/GiT/nonGitStuff/sark-backups/<site>/`. **Next:** more v2 fixture tests; then product **strip** (#3). Lab/tip detail: **`~/GiT/pbx3-ops/TODO_OPS.md`**.

- [x] **Strip customer-migrate tooling from pbx3 (suggested #3, done 2026-08-09):** Removed stock migrate entrypoints; kept idempotent **`sqlite_normalize_cluster_to_shortuid.sql`**. Private ETL owns migrate SQL/PHP. Heritage strings scrubbed 2026-08-09.

- [ ] **Lab deployment — quick LAN fleet (requirements locked 2026-08-08; box/RTP stance 2026-08-10):** Primary project: curious user + **VM manager** → **Ubuntu/Debian** VMs → **T4**. Prefer **3 boxes** for two homes (Magrathea+GK+Garage / Ast1 / Ast2). Optional LAN+public carrier: **chunked RTP port-forwards** before Appendix A rtpengine. SPA prefer **LAN static**. Tailor + Appendix B. Cloud **T2**/AMI = follow-on. Spec: **`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`**. Implement D1+ when scheduled.

- [x] **#4b/#4c lab procedures on golden (2026-08-10):** **`TENANT_WIPE_AND_EXT_LEN_LAB.md`** §1–§2 green (same-home prune; ext_len API + GenAst `_81XXX`).

- [ ] **pbx3api `.deb` (open 2026-08-08):** Versioned Debian package installing under **`/opt/pbx3api`**, preserving `.env` on upgrade, wiring nginx/php-fpm via existing installer semantics. Ubuntu/Debian long-haul; apt parity with **pbx3** / **pbx3cagi**. Until shipped: clone-at-tag (public org) or current tip deploy. Repo: **pbx3api**. See try-it packaging § **`FLEET_TRYIT_DEPLOYMENT_REQUIREMENTS.md`**.

- [x] **Roll API tip — Sanctum TOTP to fleet nodes (2026-08-08):** Done on lab fleet. Tip/host detail: **`~/GiT/pbx3-ops/TODO_OPS.md`**.

- [x] **Tenant FQDN DNS + instance-only LE — SBC fleet (2026-08-06):** No tenant public **A** records; SPA → instance DNS; SIP domain → OpenSIPS setid. **Lock:** **`TLS_AND_CERTIFICATES.md` §0**. Option A multi-SAN remains solo/direct only.

- [ ] **Fleet SPA — edge host health scrape (parked 2026-07-30):** Multi-edge load/mem/disk (and later door-knock country rollups) via Gatekeeper ← edge summary cron → S3 HoR → Fleet overlay. **Not** browser→SBC polling; **not** on-SBC heatmaps. Checklist in **`pbx3sbc-admin/workingdocs/HOME_SYSTEM_AND_FLEET_SCRAPE.md`**.

- [ ] **Door-knock geo heat / map (parked 2026-07-30):** Do **not** geolocate on every Home poll on the SBC. Prefer Fleet scrape path above. Edge keeps single-row geo on Door-knock View only.

- [ ] **Grafana / Homer — fleet view only, unmodified (parked 2026-07-30):** Stance locked. **SBC Home = Filament** (in-box). **Grafana** (and Homer if ever) = optional **fleet / multi-instance** observability later — operator-installed **unmodified** OSS (AGPL); no fork, no bundling into product installer, no on-licensing end users. If a use case needs modifying Grafana/Homer, **don’t do that use case**. Not next.

- [ ] **Pre-first-release — SPA production bundle diet (parked 2026-08-03):** Do **before first product release**, not now. Prefer: (1) **dynamic `import()` of line-test + JsSIP** only when Line test opens; (2) **route-level code-split** for heavy views; (3) optional split of `marked`/`dompurify` off the critical path. Repo: **pbx3spa**.

- [ ] **Lab / demo SQLite anonymize (parked 2026-08-03):** Lab test DBs may still carry site-derived surnames / friendly labels. Prefer a **one-shot idempotent SQL + short runbook** before wider demos. Keep dial plans / shortuids functional. Not urgent for closed lab.

- [ ] **Provisioning — home listener + edge proxy (direction 2026-08-10):** Preferred: lift/polish SARK provision routines on the **home**; fleet **nginx** routes by tenant Host/SNI to current home; proxy has stable **A**; tenant move = remap only (no DNS). Secrets stay on `ipphone`. Spec: **`PROVISIONING_SERVER_REQUIREMENTS.md`**. Not scheduled to build yet; update **`TLS_AND_CERTIFICATES.md` §0** (provision A→proxy exception) when shipping.

- [ ] **Device table — lean done in seed; residual (2026-08-06):** Seed keepers + prune SQL landed; SPA **Devices** removed from System nav. **Still open:** drop Devices routes/views entirely; Snom/Grandstream pkey gap; optional later packaged JSON keepers. Provision templates still relevant when **#23** builds.

- [ ] **Extension phone image / UA model harvest (parked 2026-08-09):** Sidekick design locked — edge `GET /fleet/registrations` + home `harvest-devicemodel` soft-fills `ipphone.devicemodel`. Spec: **`EXTENSION_PHONE_IMAGE_FROM_UA_REQUIREMENTS.md`**. Assets: **`~/GiT/nonGitStuff/phoneimages/`** (sailpbx zip URL dead); slice E = SPA + model→filename map.

- [ ] **SPA list action icons — shared component (parked 2026-08-03):** Extract small **`ListEditIcon` / `ListDeleteIcon`** (or combined row-actions) in **pbx3spa** and reuse everywhere. Not urgent polish.

- [ ] **Multi-AZ fleet lab (open 2026-08-03):** Need instances in **different AZs** for WebRTC / RTP proof. Notes: **`WEBRTC_WSS_LAB.md`** Next.

- [ ] **`ipphone.desc` vs `description` — clarify / rename (parked 2026-07-29):** Schema has both; SPA/GenAst roles misaligned. Proper fix later — do not drive-by.

- [ ] **SBC Track A lab — third-party PBX (± FreePBX) behind SBC (2026-07-28):** Prove REGISTER / calls via Magrathea or scratch pbx3sbc. Capture recipe / gaps — **`SBC_PRODUCT_TRACKS.md`** Track A. Foreign-PBX→pbx3 data migrate is a separate ETL later.

- [ ] **pbx3cagi Phase 4 — domain file splits (parked 2026-07-26):** Day-parts / CheckState **merged to `main`** — Phase 4 unblocked when scheduled. Spec: **`REFACTOR_PLAN.md`**.

- [ ] **Control plane duplex / HA (parked, pre-live 2026-07-27):** Gatekeeper is a single host — ops SPOF. Call plane fail-safe by design. Do **not** home on SBC. Spec seed: **`CONTROL_HOST.md`** · **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §2.5 fail-safe.

- [ ] **Fleet instance health includes Asterisk (parked, pre-live 2026-07-27):** Gatekeeper node badge uses HTTP **`/up`** only. Extend probe for call-plane liveness before production. Do not block dial-alias.

- [ ] **AMI wallboard feed (side gig, parked 2026-07-27):** Feed-only live board when demand appears — separate small track.

- [ ] **Drain affordance — tenant-scoped “up calls” + wipe-when-drained (nice-to-have, parked 2026-07-23):** Not built. Best-effort AMI overlay on move jobs.

- [ ] **Toll fraud / velocity — remainder (promoted 2026-08-10):** **Shipped:** V1 CDR fixture/query, V2 IRSF burst → Gatekeeper `velocity_irsf`, V5 `active=NO` act (`pbx3:ops-velocity`; env flags; not SPA; off on golden today). **Still to do (requirements-thin — design before build):** **V3** fleet-wide rule template (N/T/Q/prefixes without per-node `.env`); **V4** tenant-admin audience if wanted; SPA enable/status + “disabled by velocity” badge; more detectors (CFIM, off-hours, short-call, dormant, concurrency, …); ops enable + `schedule:run` when ready. Spec: **`pbx3-directory/docs/FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`**. Research: **`TELEPHONE_FRAUD_RESEARCH.md`**.

- [ ] **Toll fraud / velocity — standalone SKU (parked 2026-07-24):** Own **repo + installer** later (Go extract sketch). Spec § Future — same requirements doc. Do not block in-tree remainder (#8).

- [ ] **Number dialect — paid Twilio + follow-ons:** Paid Elastic SIP **lab green** (Toliman↔Twilio both ways; SBC Route-strip + public From/PAI host; Egress CLIP update without `default` tenant). Still open: named Twilio Peer recipe; product **O4** US seed; custom-dialect UI. Spec: **`NUMBER_DIALECT_REQUIREMENTS.md`** · wire: **`EGRESS_PLUS_E164_WIRE.md`**. CLI stays as-stored (no CLIP mangle).

- [ ] **Number wire Phase 2 / D2–D4 (parked 2026-08-06):** Phase 1 = node Mangle (**D1 = C** locked). Do not strip node Mangle until Phase-2 gate. Specs: **`NUMBER_WIRE_POLICY.md`**, **`NUMBER_WIRE_STANDARD_DRAFT.md`**.

- [ ] **Seed outbound US dialplan string (O4) (optional):** UK `_0XXX. _00XX.` shipped with **`SEED_OUTBOUND_ON_TENANT_CREATE.md`** (#4c). US seed string when wanted.

- [ ] **Incident notify (parked 2026-08-11):** Tenant callout → ConfBridge + optional SMS. Spec: **`INCIDENT_NOTIFY_REQUIREMENTS.md`**. Est. ~5–7 d v1.

- [x] **Instance SIP logging (2026-08-11):** Session-armed SIP text (PJSIP-filtered) + JSONL; SPA arm/disarm; S3 **`sip-text` / `sip-pcap`**. Package **`0.0.5-5`** rolled golden/bzy/Toliman; API tip; S3 sip-text ship green. Spec: **`HOME_SIP_LOGGING_REQUIREMENTS.md`**.

- [ ] **Fleet auth — cookie sessions / SSO (deferred — settled stance 2026-07-14):** Try-it-out auth is enough. Design: **`FLEET_AUTH_COOKIE_SSO.md`**.

- [x] **TOTP 2FA — SBC Filament (2026-08-07):** Lab green Magrathea; **`main`**. Spec: **`pbx3sbc-admin/workingdocs/TOTP_2FA_SBC.md`**.

- [x] **TOTP 2FA — instance SPA / Sanctum (2026-08-07):** Opt-in MFA on **`main`**. Spec: **`TOTP_2FA_REQUIREMENTS.md`**.

- [x] **TOTP 2FA — Fleet Gatekeeper G1–G4 (2026-08-07):** Lab green. Spec: **`FLEET_GATEKEEPER_TOTP_REQUIREMENTS.md`**. G5 optional later.

- [ ] **Phase S10 — remaining:** **S10.7**/S10.2b orchestrated IAM onboard/rebuild — **parked**. Mode 4 + Mac scripts stay. Plan: **`IMPLEMENTATION_PLAN.md`** § Phase S10.

- [ ] **S10.7 — Orchestrated onboard / rebuild (parked 2026-07-15):** Interim: agent-assisted Mode 4. Design: **`SELF_SERVICE_REBUILD_DESIGN.md`**.

- [ ] **SBC Fail2ban — inbound Peer auto-whitelist + ban notify (deferred until next carrier onboard):** Edge-authored (Rule 13). Spec: **`PEERING-PLAN.md`** §0.1 · **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** § Fail2ban.

- [ ] **Instance shadowing (parked — framing locked 2026-07-21):** Spec: **`pbx3-directory/docs/INSTANCE_SHADOWING_REQUIREMENTS.md`**.

- [ ] **Downstream peer registration edge (future — not next):** Spec: **`pbx3-directory/docs/DOWNSTREAM_PEER_REGISTRATION_REQUIREMENTS.md`**.

- [ ] **Fleet slug / org bucket naming (cosmetic — fix later):** Product should choose a **neutral fleet slug** at provision. Design note: **`OPS_S3_RUNBOOK.md`**.

- [ ] **Phase S8 — Fleet (optional polish):** **S8.1–S8.6 shipped**. Remaining optional: LE Sync post-cutover; **`move-tenant.sh`**. See **`TENANT_MIGRATION_RUNBOOK.md`**.

- [ ] **S7+ — Attested PCI / scale (deferred):** Do not start without customer ask.

- [ ] **OSS org + repo registry:** Create GitHub org per **`OPEN_SOURCE_GITHUB_SETUP.md`**. **Prerequisites:** hygiene (**done**) → Apache-2.0 `LICENSE` (**done**) → migrate extract (**done**) → strip migrate from pbx3 (**done**). Ready for org transfer when scheduled.

- [ ] **pbx3cagi refactor (under Ast config generator + cagi track):** Resume Phase **1.3 → 1.1 → 2.x**; **`make test`**. Contract: **`AST_CONFIG_GENERATOR_SUBPROJECT.md`** §5.

- [ ] **Golden `pkey='default'` layout (investigate, low priority):** Does SPA tenant-create-only provisioning ever skip creating `default`?

- [ ] **pbx3api astamis `PJSIPShowEndpoint/{id}`:** Singular action not whitelisted — fix when implementing live endpoint query.

- [ ] **LDAP — overall strategy deferred:** Parking all LDAP work until a design is chosen.

- [ ] **LDAP: LDAPHelperClass reads from `globals` but instance `globals` has no LDAP columns.** Fold into LDAP strategy when picked up.

- [ ] **pjsipuser for extensions:** Address pjsipuser handling for extensions as needed.

- [ ] **Extensions edit panel — Runtime section (re-examine):** Deferred until phones are registered on a test instance.

- [ ] **Inbound route panels — SWOCLIP (re-examine):** Confirm field placement / create-edit parity.

- [ ] **pbx3cagi — `maxin` / `maxout` call counters:** Fix concurrent-call limit enforcement.

- [ ] **SPA session timeout (Instance Globals `sessiontimout`):** Implement client-side idle/session expiry. See **`pbx3spa/workingdocs/AUTH_PATTERNS.md`**.

- [ ] **tt_help_core cleanup — unreferenced rows (final pass):** Review unreferenced help keys; prune or rewire.

- [ ] **SPA hygiene (deferred — after S8 / R1 / core panels):** Route lazy-loading + shared list/detail patterns later.

- [ ] **Customer migrate routines (revisit, low priority — end of list):** Normalize/repair remains in pbx3; ETL is private under Aelintra. FreePBX migrate separate later.

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
