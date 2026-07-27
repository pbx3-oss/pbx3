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
| Fleet / S3 catalog / onboard | **pbx3-directory/docs/FLEET_SYSTEM_OVERVIEW.md** (stakeholder intro) → **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** (S8.10, §2.5 one SPA / two modes + control plane, §13 implementer map) → **IMPLEMENTATION_PLAN.md** § **S8** → **`OPERATOR_MAC_SETUP.md`** (Mac SSH + AWS CLI) → **REBUILD_INSTANCE_RUNBOOK.md** → **`SELF_SERVICE_REBUILD_DESIGN.md`** (S8.9 + **Mode 4 agent-assisted**) → **NEW_INSTANCE_CHECKLIST.md** → **INSTANCE_ONBOARDING.md** → **OPS_S3_RUNBOOK.md**; tools **`onboard-fleet-instance.sh`**, **`fetch-latest-instance-backup.sh`** |
| **Asterisk after Egress / genAst** | **`OPS_ASTERISK_AFTER_EGRESS_GENAST.md`** — full restart vs pjsip reload |
| **Ast config generator + CAGI cleanup** | **`AST_CONFIG_GENERATOR_SUBPROJECT.md`** (one track: staging/overlay + GenAst↔CAGI contract) → **pbx3cagi**/workingdocs/**`REFACTOR_PLAN.md`** → **`TEST_RECIPE.md`** |
| **Time-based routing (day-parts)** | **`TIME_BASED_ROUTING_REQUIREMENTS.md`** — requirements draft; implement after §8 lock; before CAGI Phase 4 |
| **Tenant short dial (cross-tenant)** | **`TENANT_SHORT_DIAL_REQUIREMENTS.md`** — per-tenant dial alias; SBC miss→dispatcher locked; implement after remaining §8 |
| **Call / SIP testing (SIPp)** | **`CALL_TYPE_INVENTORY.md`** (full map) → **`CALL_TEST_STRATEGY.md`** → **`TEST_CADENCE.md`** · **`CRITICAL_PATH_TEST_PACK.md`** Pack B · CAGI L0 **`TEST_RECIPE.md`** |
| **Fleet mode UX** (future) | **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §2.5, §4 — one SPA, two modes; separate control-plane API; lab peer-nav → mode swap |
| **Failover + shadowing** (parked) | Edge HA: **`SBC_HA_FAILOVER_REQUIREMENTS.md`**. Instance shadow SKU framing: **`INSTANCE_SHADOWING_REQUIREMENTS.md`** (same mechanics, paid twin) |
| **Fleet egress lab rollback** (2026-07-09) | **`FLEET_EGRESS_LAB_ROLLBACK.md`** — git tags, revert steps, SBC/golden/SPA recovery |
| **SBC HA (VIP/EIP promote)** | **`SBC_HA_FAILOVER_REQUIREMENTS.md`** — requirements locked; implement later |
| **Edge portability (Rule 7 debt)** | **`EDGE_PORTABILITY_SCORECARD.md`** — adapter vs OpenSIPS vocabulary leaks |
| **Fleet Egress availability** | **`FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`** — R1+R2 shipped; R3 EgressFailover/cagi parked |
| **Ops failure notification** | **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** — probe+SMTP + lifecycle + misconfig + move-job + Fail2ban ban + **Egress Unavail** shipped; SPA badges later |
| **Toll fraud / velocity** | **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`** — V1–V5 fleshed (fixture-first, batch CDR, `active=NO` act); competitive notes |
| **PSTN number dialects** | **`NUMBER_DIALECT_REQUIREMENTS.md`** → MkDocs **`fleet/number-dialect`** → Peer dialect + OpenSIPS `DIALECT_*`; node Egress transform = DNID/`+CC` by serving country |

| **Log retention / SIP capture** | **`FLEET_LOG_RETENTION_REQUIREMENTS.md`** — Phases 1–6 done; **`SBC_DATA_RETENTION_REQUIREMENTS.md`** — aging WS0–WS4 **done** (lab); **`SBC_BACKUP_RESTORE_REQUIREMENTS.md`** — SBC DR **v1 done** (scripts + scratch drill + MkDocs) |
| **Downstream peer REGISTER (future)** | **`DOWNSTREAM_PEER_REGISTRATION_REQUIREMENTS.md`** — separate registration-edge instance class; no shared OpenSIPS image; interim Asterisk-proxied workaround only |
| **Agent-assisted fleet rebuild** | **`REBUILD_INSTANCE_RUNBOOK.md`** (kickoff prompt) → **`SELF_SERVICE_REBUILD_DESIGN.md`** § Mode 4 → **`OPERATOR_MAC_SETUP.md`** |
| Call recordings | **`RECORDINGS_STORAGE_DESIGN.md`** → **`IMPLEMENTATION_PLAN.md`** § **R1** (done) / **R1.5** / **S7** |
| SPA GitHub Pages (S6.2) | **pbx3-directory/docs/OPS_S3_RUNBOOK.md** § 9; **pbx3spa** `.env.production` / CI; verify S3 + **each node API CORS** for Pages origin |

**Source of truth:** Schema and code. Verify against pbx3 db_sql and code when changing behaviour; workingdocs may be outdated.

---

## Next agent session notes (2026-07-27 — L1 pack 11/11 session end)

**Branches:** **pbx3** + **pbx3cagi** + **pbx3spa** on **`main`** (commit this close; not pushed unless asked). Tips: pbx3 this tip; pbx3cagi **`a7cdeed`** (OutVoip); spa handoff this close. Magrathea VIP **`3.93.26.82`** (companion **stopped**). **bzy54n stopped**. SIPp host **`98.93.98.162`**.

### Shipped
- **L1 pack 11/11 green:** prior nine + **`in-queue-cancel-vm`** (agent 486→failover→VM) + **`out-busy-or-reject`** (Local→486→PostDial). Catcher **`uas-486`**.
- Earlier same day: `feat-master-closed`, `in-cfim-external`, `out-egress-ok`, **SIPP_MAIN**, OutVoip `description` fix.
- Holiday L1 deferred until day-parts.

### Golden / operator follow-up
- Peer gwid **99** = SIPp EIP only. Velocity notify-on / ACT-off.
- OutVoip fix live on golden agi-bin (hot install); commit tip **`a7cdeed`**.

### Resume
- Lock dial-alias §8 (digit plan, CLID, trust) — not CAGI Phase 4.
- Pack: `ssh -i …/pbx3test.pem ubuntu@98.93.98.162 'cd ~/call-tests && ./run-pack.sh'`

---

## Next agent session notes (2026-07-27 — L1 grow outbound + OutVoip fix) — historical

**Branches:** **pbx3** + **pbx3cagi** on **`main`**. Tips: pbx3 **`b7cedac`**, pbx3cagi **`a7cdeed`**. Magrathea VIP **`3.93.26.82`**. SIPp **`98.93.98.162`**.

### Shipped
- L1 pack 9/9: master-closed / CFIM-external / out-egress-ok + SIPP_MAIN + OutVoip fix.

### Resume
- Superseded by L1 pack 11/11 block above.

---

## Next agent session notes (2026-07-27 — L1 +302/multi-tenant + dial-alias reqs) — historical

**Branches:** **pbx3** on **`main`** (pushed). Tips: pbx3 **`16a34b4`**, pbx3api **`106ee6b`**, pbx3cagi **`9e4bfa9`**, pbx3spa **`187742b`**, pbx3sbc-admin **`d8ea56e`**. Magrathea VIP **`3.93.26.82`** (companion **stopped**). **bzy54n stopped**. SIPp host **`98.93.98.162`**.

### Shipped
- **L1 pack growth:** `phone-302-local` + `in-multi-tenant-a-b`. Full pack green on EC2 (6 ids).
- **Requirements:** **`TENANT_SHORT_DIAL_REQUIREMENTS.md`** — dial alias; usrloc miss→dispatcher locked.

### Resume
- Superseded by L1 grow outbound + OutVoip block above.

---

## Next agent session notes (2026-07-27 — L1 pack + SIPp EC2) — historical

**Branches:** **pbx3** (+ spa handoff) on **`main`**. Tips: pbx3 **`c23863b`**, pbx3api **`106ee6b`**, pbx3cagi **`9e4bfa9`**, pbx3spa **`187742b`**, pbx3sbc-admin **`d8ea56e`**. Magrathea VIP **`3.93.26.82`** (companion **stopped**). **bzy54n stopped**.

### Shipped
- **SIPp catcher tenant** on golden: `sipp` / `pb0wsk.pbx3.com`, exts 2000/2001, Q2060; Twilio DID `+15139279738` → 2000; SBC domain + aliases + `domain_reload`.
- **L1 pack v1:** `run-pack.sh` + `lab-state.sh` + catcher register/answer — open / CFIM / closed / queue **green**.
- **Off-box lab host** `98.93.98.162` — `sip-tester`, `~/call-tests`, Peer gwid **99** → EIP only. Pack green from Mac via SSH.
- Docs: **`SIPP_LAB_HOST.md`**, call-tests README, strategy Step 3 note.

### Golden / operator follow-up
- **Never** Peer the office IP as carrier (gwid 99 on Mac IP broke phones — “No inbound route”).
- Phone **302** divert still untested as pack scenario (Snom attempt blocked by Peer issue).
- Velocity still notify-on / ACT-off. Magrathea HA standby off until restarted.

### Resume
- Superseded by L1 +302/multi-tenant + dial-alias block above.

---

## Next agent session notes (2026-07-27 — SIPp in-open-ext green) — historical

**Branches:** **pbx3** + **pbx3api** + **pbx3cagi** + **pbx3spa** + **pbx3sbc-admin** on **`main`**. Tips: pbx3 **`976fbd6`**, pbx3api **`106ee6b`**, pbx3cagi **`9e4bfa9`**, pbx3spa **`f87a783`**, pbx3sbc-admin **`d8ea56e`**. Magrathea VIP **`3.93.26.82`**.

### Shipped
- **Call tests:** `workingdocs/call-tests/` + **`CALL_TYPE_INVENTORY.md`** (majors/shortcodes + U/H). **`in-open-ext`** full green (Mac SIPp → VIP → DID → 1000; Snom always-auto-answer; BYE needs scenario `rrs="true"`).
- **Inbound Route +E.164 pkey** — api + spa; golden hot-file deploy (repo tree still has overlay drift vs origin).
- **SBC-admin** numeric next-gwid (deploy VIP Filament when convenient).

### Golden / operator follow-up
- Temp Peer **gwid 99** `sipp-lab` / `74.83.26.203` — superseded (moved to EC2 EIP).
- DID openroute may still point at **1000** (was ring group) — restore if desired.
- Snom lab phone in **always auto-answer**; `extalert` does **not** apply on ring-group dial.
- Velocity still notify-on / ACT-off. Agent Mac SIPp/SSH often needs sandbox-off approval.

### Resume
- Superseded by L1 pack + EC2 block above.

---

## Next agent session notes (2026-07-26 — close: call test is next) — historical

**Branches:** **pbx3** + **pbx3api** + **pbx3cagi** + **pbx3spa** on **`main`**. Tips: pbx3 **`976fbd6`**, pbx3api **`2c429ab`**, pbx3cagi **`9e4bfa9`**, pbx3spa **`6c31fe7`**. Magrathea VIP **`3.93.26.82`**.

### Shipped (this session, docs)
- **Time-based routing** requirements — **`TIME_BASED_ROUTING_REQUIREMENTS.md`** (day-parts + profiles; Phase 4 parked).
- **Call / SIP test strategy** — **`CALL_TEST_STRATEGY.md`** on `main`; TODO #1.
- Operator close: **system largely built; proper pathway/load testing is next** (not more edge features first).

### Golden / operator follow-up
- Lab still on cagi **3.2** wrap; velocity notify-on / ACT-off.

### Resume
- **Start here:** call-test Step 1 — SIPp + green `in-open-ext` on golden — **`CALL_TEST_STRATEGY.md`**.
- Later: time-based §8 / product crumbs. Do **not** open CAGI Phase 4 first.

---

## Next agent session notes (2026-07-26 — call-test strategy) — historical

**Branches:** **pbx3** + **pbx3api** + **pbx3cagi** + **pbx3spa** on **`main`**. Tips: pbx3 **`976fbd6`**, pbx3api **`2c429ab`**, pbx3cagi **`9e4bfa9`**, pbx3spa **`c2d2e2b`**. Magrathea VIP **`3.93.26.82`**.

### Shipped
- **Docs:** **`CALL_TEST_STRATEGY.md`** — L0 CAGI harness / L1 SIPp pathways / L2 soak / L3 PSTN manual; scenario inventory; build order (first green `in-open-ext`).
- Pointers in **`TEST_CADENCE.md`** + Pack B row in **`CRITICAL_PATH_TEST_PACK.md`**.
- **TODO:** call-test open item + suggested-next #1.
- No runtime code; no SIPp scenarios yet.

### Golden / operator follow-up
- Velocity still notify-on / ACT-off.

### Resume
- Implement call-test Step 1 (SIPp + `in-open-ext` on golden), or product crumbs / time-based §8 — **`TODO.md`**.
- Do **not** start CAGI Phase 4 ahead of schedule track.

---

## Next agent session notes (2026-07-26 — time-based routing requirements) — historical

**Branches:** **pbx3** + **pbx3api** + **pbx3cagi** + **pbx3spa** on **`main`**. Tips: pbx3 **`976fbd6`**, pbx3api **`2c429ab`**, pbx3cagi **`9e4bfa9`**, pbx3spa **`c2d2e2b`**. Magrathea VIP **`3.93.26.82`**.

### Shipped
- **Docs:** **`TIME_BASED_ROUTING_REQUIREMENTS.md`** — day-parts + route profiles; cron precompute kept; FreePBX TC chains deferred; SARK convert + CAGI dual-read; delivery slices A–E; open **§8 Q1–Q7**.
- **Parked:** pbx3cagi **Phase 4** domain splits until schedule/CheckState contract stable.
- No runtime/code change this session (lab still on cagi **3.2** wrap tip).

### Golden / operator follow-up
- Velocity still notify-on / ACT-off.

### Resume
- Lock **§8** on time-based routing when ready to implement; or product crumbs (D WSS / Twilio / drain / velocity V3) — **`TODO.md`**.
- Do **not** start CAGI Phase 4 ahead of the schedule track.

---

## Next agent session notes (2026-07-26 — cagi thread-s + 3.2 AGI wrap) — historical

**Branches:** **pbx3** + **pbx3api** + **pbx3cagi** + **pbx3spa** on **`main`**. Tips: pbx3 **`976fbd6`**, pbx3api **`2c429ab`**, pbx3cagi **`9e4bfa9`**, pbx3spa **`568c604`**. Magrathea VIP **`3.93.26.82`**.

### Shipped
- **Emergency roll back point** (pre E/G dial-locus) — **`AST_CONFIG_GENERATOR_SUBPROJECT.md` §5.5** (paired tips; not CAGI alone).
- **pbx3cagi** Phase 3 follow-on: thread `agi_session_t *s` into helpers — PR **#1** merged (`thread-s-helpers`).
- **pbx3cagi** Phase **3.2** thin AGI wrap (`agi_wrap.c`/`h`) — PR **#2** merged → tip **`9e4bfa9`**. Debug/Init/ListGetVal still raw `AGITool_*`.
- **Lab:** golden + **bzy54n** on wrap build (md5 `8837a592…`). Operator: calls + local CF / diverted OK.

### Golden / operator follow-up
- Velocity still notify-on / ACT-off.
- Phase 4 (domain splits / named feature codes) not started.

### Resume
- Optional **Phase 4** — **`pbx3cagi/workingdocs/REFACTOR_PLAN.md`**.
- Or product: D WSS / Twilio / drain / velocity V3 — **`TODO.md`**.

---

## Next agent session notes (2026-07-26 — emergency rollback pin + bzy cagi parity) — historical

**Branches:** **pbx3** + **pbx3api** + **pbx3cagi** + **pbx3spa** on **`main`**. Tips: pbx3 **`976fbd6`**, pbx3api **`2c429ab`**, pbx3cagi **`c4b06bd`**, pbx3spa **`a58c183`**. Magrathea VIP **`3.93.26.82`**.

### Shipped
- **Docs:** **Emergency roll back point** for pre–E/G dial-locus — **`AST_CONFIG_GENERATOR_SUBPROJECT.md` §5.5** (pbx3cagi **`fd9b146`** + pbx3 **`4d862e0`**; alt fleet pin pbx3 **`1ea1210`**). Paired GenAst+CAGI only — not CAGI alone.
- **Ops:** **bzy54n** cagi built/installed to match golden **`c4b06bd`** (`pbx3cagi.arm64` md5 `45a18cb5…`; bak `…20260726193238`).
- Clarified: struct refactor (1.3–3.1) did not change dialplan contract; E/G did. Optional polish (thread `s` / 3.2 / Phase 4) left alone.

### Golden / operator follow-up
- Operator running live tests as-is (both nodes on cagi tip).
- Velocity still notify-on / ACT-off.

### Resume
- Await operator test results; then product (D WSS / Twilio / drain / velocity V3) or optional cagi polish — **`TODO.md`**.

---

## Next agent session notes (2026-07-25 — pbx3cagi Phase 1.3–3.1 + golden QA) — historical

**Branches:** **pbx3** + **pbx3api** + **pbx3cagi** + **pbx3spa** on **`main`**. Tips: pbx3 **`976fbd6`**, pbx3api **`2c429ab`**, pbx3cagi **`c4b06bd`**, pbx3spa **`38333ca`**. Magrathea VIP **`3.93.26.82`**.

### Shipped
- **pbx3cagi refactor** on **`main`**: 1.3 dead code → 1.1 structs → 2.1 command table → 2.2 `agi_sqlite` → 2.3 `agi_init_call_context` → 3.1 `agi_session_t` + drop name macros. Commits **`670c02f`…`c4b06bd`**.
- Offline **`make test`** 7/7 throughout. **`cagi.c`** left alone (LGPL; thin used surface).
- **Golden:** deploy key for private repo; pull/build/install **`c4b06bd`** → `/usr/share/asterisk/agi-bin/pbx3cagi.arm64` (bak `…20260725224240`). Operator: **simple calls + CFIM OK**.

### Golden / operator follow-up
- **bzy54n** cagi may still lag — same pull/`make`/install when ready.
- Velocity still notify-on / ACT-off.
- GenAst A–H already on `main` + both nodes from prior session.

### Resume
- Product: deferred D WebRTC WSS lab, Twilio paid dialect, drain affordance, velocity V3 — **`TODO.md`**.
- Or cagi: thread `s` into helpers / Phase 4 — **`pbx3cagi/workingdocs/REFACTOR_PLAN.md`**.

---

## Next agent session notes (2026-07-25 — graph MCP + class `.php` layout) — historical

**Branches:** **pbx3** + **pbx3api** + **pbx3cagi** on **`genast-hermit`** (pushed; **not** merged to `main`). SPA overlay on **`main`**. Golden still G+H hot. Tips: pbx3 **`976fbd6`**, pbx3api **`2c429ab`**, pbx3cagi **`b9dd195`**, pbx3spa **`3528e71`**. Magrathea VIP **`3.93.26.82`**.

### Shipped
- **code-review-graph MCP:** fixed (`~/.cursor/mcp.json` → `/opt/homebrew/bin/uvx` + PATH/HOME); auth + full builds for pbx3/api/spa/cagi.
- **Graph review** of hermit vs `main`: no merge-blockers; GenClass was invisible until layout fix.
- **PHP classes:** content in `*.php`; extensionless names are **symlinks** for `config.php`. Graph now indexes GenClass (~29 nodes). Hot-patch **`GenClass.php`**, do not clobber the symlink.
- **TODO:** open item to drop symlink workaround (full `.php` requires).

### Golden / operator follow-up
- When rolling this pbx3 tip: preserve extensionless → `.php` symlinks under `php/classes/`.
- bzy may still lag hermit (C2+/G/H).
- Velocity still notify-on / ACT-off.

### Resume
1. **Merge `genast-hermit` → `main`** (pbx3 + pbx3api + pbx3cagi) — or roll bzy.
2. Optional: D WebRTC live WSS lab; PHP class path cleanup (TODO).
3. Not first: Twilio paid / velocity ACT / SSO / cagi struct 1.3+.

## Next agent session notes (2026-07-25 — GenAst hermit G+H lab OK) — historical

**Branches:** **pbx3** + **pbx3api** + **pbx3cagi** on **`genast-hermit`** (pushed; **not** merged to `main`). SPA overlay on **`main`**. Golden: G LepDial + H trunk/queue/park overlays hot; migrations applied. Tips: pbx3 **`976fbd6`**, pbx3api **`2c429ab`**, pbx3cagi **`b9dd195`**, pbx3spa **`51b0fa3`**. Magrathea VIP **`3.93.26.82`**.

### Shipped
- **G:** LepDial PreDial → `Dial(${PBX3_DIAL})` → PostDial; ANSWER/CANCEL skip second AGI (dead-AGI cold start). Golden lab: answer, cancel→VM, timeout→VM, AstDB CFIM, SIP DIVERT.
- **H:** Trunk/queue/park C2 — always tmpl + DB overlay (`trunks.pjsip_overlay`, `queue.queue_overlay`, `cluster.park_overlay`); SPA admin fields on Trunk/Queue/Tenant (park = Tenant → Parking). Golden migrate + legacy freeze rm + Commit OK.
- Docs: **`AST_CONFIG_GENERATOR_SUBPROJECT.md`** §0 Phase G locked + Phase H.

### Golden / operator follow-up
- SPA: Trunk/Queue overlay visible; park overlay on **Tenant** edit (no Parks panel).
- bzy may still lag hermit (C2+/G/H).
- Velocity still notify-on / ACT-off.
- SSH: instances `pbx3test.pem`; SBC `opensips.pem`.
- Graph MCP was unavailable mid-session — fixed later same day.

### Resume
- Superseded by **graph MCP + class `.php`** block above.

## Next agent session notes (2026-07-25 — GenAst hermit A–F; E lab OK) — historical

**Branches:** **pbx3** + **pbx3api** + **pbx3cagi** on **`genast-hermit`** (pushed; **not** merged to `main`). SPA overlay on **`main`**. Golden hot: GenClass/Helper/cagi/tmpls; migrate `pjsip_overlay` on 08jzwn. Tips (session end): pbx3 **`e3e02ec`**, pbx3api **`177a28b`**, pbx3cagi **`e3d8522`**, pbx3spa **`3c05adb`**. Magrathea VIP **`3.93.26.82`**.

### Shipped
- **C2:** DB `pjsip_overlay` + SPA admin field; Commit prefers DB over file; golden set/clear/Commit OK.
- **D:** WebRTC tmpl+overlay (same as phones); live WSS lab deferred.
- **E:** `Q*` → short AGI PrepDial(queue) → `Dial(${PBX3_DIAL})`; golden **Q1060** OK. Deploy **cagi before** GenAst Commit.
- **F:** `PBX3_SBC_EGRESS_HOST` for outbound_proxy; `$clstkey`→`park-{tenant}` before `$clst`; webrtc parkinglot aligned.
- Phase E design locked in **`AST_CONFIG_GENERATOR_SUBPROJECT.md` §0**.

### Golden / operator follow-up
- Commit after F deploy so ready phones pick up `$clstkey` / SBC host (if env set).
- Deferred: WebRTC REGISTER via instance `:8089` (SG + browser client).
- bzy may still need C2 migrate + hermit hot-patch if not done.
- Velocity still notify-on / ACT-off.
- SSH: instances `pbx3test.pem`; SBC `opensips.pem`.

### Resume
- Superseded by **2026-07-25** G+H block above.

## Next agent session notes (2026-07-25 — GenAst hermit-crab A–C lab OK) — historical

**Branches:** **pbx3** + **pbx3api** on **`genast-hermit`** (pushed; **not** merged to `main`). Live hot-patched on **08jzwn** + **bzy54n**. Tips: pbx3 **`976fbd6`**, pbx3api **`89052ac`**. Old stash on `genast-phone-overlay` superseded. Magrathea VIP **`3.93.26.82`**.

### Shipped
- Hermit-crab plan solidified in **`AST_CONFIG_GENERATOR_SUBPROJECT.md` §0** (characterize → `$row` → G2 file overlay → **C2 DB overlay** next).
- **A:** `genast-normalize.php` + `genast-characterize.sh` + `workingdocs/genast-characterize/`.
- **B:** `genExtensionsEndpoints` `$row` → `$applrow` (no tenant shadow).
- **C:** Phone tmpl always + thin overlay; **key merge** (replace if present, add if absent); pbx3api deletes `*_phone.overlay.conf`.
- **Lab:** legacy `*_phone.conf` removed; Commit OK; calls OK; golden overlay `fkdd5d` → `qualify_frequency=60` live in Asterisk.
- **C2 locked (docs only):** extension DB column (e.g. `pjsip_overlay`); SPA on extension edit for visibility; backup/move; not full stanza.

### Golden / operator follow-up
- Nodes on hermit code; file overlay still works until C2. Example overlay: `/opt/pbx3/etc/asterisk/endpoints/fkdd5d_phone.overlay.conf`.
- SSH: instances `pbx3test.pem`; SBC `opensips.pem`.
- Velocity still notify-on / ACT-off on golden.

### Resume
- Superseded by **2026-07-25** A–F block above.

## Next agent session notes (2026-07-24 — GenAst challenger review parked) — historical

**Branches:** **pbx3** / **pbx3api** / **pbx3spa** on **`main`** (this commit = docs). Feature branch **`genast-phone-overlay`** exists with **WIP in `git stash`** (premature G2 HelperClass — not merged). Velocity code already on **`main`** earlier today. Live Magrathea VIP **`3.93.26.82`**.

### Shipped (this session — docs only)
- **GenAst challenger review** in **`AST_CONFIG_GENERATOR_SUBPROJECT.md` §0** + Cursor plan **`~/.cursor/plans/genast_challenger_review_0db5c469.plan.md`**.
- **Locked phones (G2):** always `pjsip_phone.tmpl` + **required** thin hand `*_phone.overlay.conf` (append pre-xlate). Reject copy-once freeze.
- **Locked dialplan:** GenAst = routing stubs; CAGI = Dial engine; one Dial authority (remove GenAst fleet `Q{ext}` Dial fork). **`$row` shadow bug** in `genExtensionsEndpoints` appl loop (~990).
- Premature G2 code started then **stashed** — restore with care after plan review.

### Earlier same day (already on main — context)
- Velocity V1–V2+V5 on golden (notify on, **ACT off**). Standalone velocity product parked.

### Golden / operator follow-up
- No new operator deploy from this session.
- SSH: instances `pbx3test.pem`; SBC `opensips.pem`.

### Resume
- Superseded by **2026-07-25** hermit-crab block above.

## Next agent session notes (2026-07-23 — velocity plan + Gatekeeper + generator framing) — historical

**Branches:** all **`main`** (then). Velocity requirements fleshed; Gatekeeper tenant-home live; generator track framed. **Superseded** for generator by **2026-07-24** block above; velocity **code** shipped later (see TODO).

---

## Next agent session notes (2026-07-23 — login-homing B′) — historical

**Branches:** all **`main`** (pushed). Tips were **pbx3** **`4d2f137`**, **pbx3spa** **`ffede89`**. Superseded by velocity/Gatekeeper/generator block above (Gatekeeper deploy completed same evening).

### Shipped
- **B′ customer login:** SPA **Sign in to tenant** → `tenant-home.json` + instance-index → Sanctum.
- Catalog rollup writer + Mac `rebuild-tenant-home.sh`; lab QA `vqcwd4` / joe → bzy.

### Resume
- See block above.

---

## Next agent session notes (2026-07-23 — fleet phone dial / SBC AoR) — historical

**Branches:** all **`main`**. Tips **pbx3cagi** **`fd9b146`** (1.0.0-6), **pbx3** **`1ea1210`**, **pbx3sbc** **`4509b5d`**. Live Magrathea VIP **`3.93.26.82`**.

### Shipped
- **Multi-tenant-on-one-node SIP dial:** Asterisk→SBC must keep tenant domain in RURI (`sip:shortuid@tenant.fqdn`) + phone `outbound_proxy` → SBC; OpenSIPS from-Asterisk FQDN RURI → usrloc (not dispatcher hairpin).
- **Fleet-gated** so singleton stays `Dial(PJSIP/shortuid)` / no SBC proxy (`PBX3_FLEET_MODE` / Egress).
- **Lab:** golden 4 regs / two tenants both ways + ring groups (Q dial); recording still Queue no-args AGI. Rolled **08jzwn** + **bzy54n** (refresh staged `endpoints/*_phone.conf` before Commit when tmpl changes).
- Earlier same day (prior session arc): **source wipe in move job** done — see TODO.

### Golden / operator follow-up
- Nodes already patched this session; future tmpl rolls: **delete/refresh staged phone instances** then Commit.
- SSH: instances `pbx3test.pem`; SBC `opensips.pem`.

### Resume
- Superseded by **velocity / Gatekeeper / generator** block above.

---

## Next agent session notes (2026-07-22 — instance user privileges P1–P4) — historical

**Branches:** all **`main`**. Privileges P1–P4 + portable users; sandycroft→bzy lab. **Superseded** by 2026-07-23 blocks.

### Resume
- See **2026-07-23 login-homing B′** block above.

---

## Next agent session notes (2026-07-22 — Twilio dialect lab) — historical

**Branches:** all **`main`**. Code tips unchanged this slice: **pbx3sbc** **`3404608`**, **pbx3sbc-admin** **`c623d0c`**, **pbx3-docs** **`12f32e3`**, spa **`07c0969`**, api **`5426f58`**. Handoff commit on **pbx3** after this block. Live Magrathea VIP **`3.93.26.82`** / companion **`3.80.2.11`**.

### Shipped (lab / ops — not new package tips)
- **Twilio trial trunk:** DID **`+15139279738`** → golden **1000** (`dhbm8x`); inbound Peers **40–47** `dialect=strict-plus-e164`; outbound Peer **50** `aelsbc.pstn.twilio.com`; Magrathea rule prefix digit form for UK DID; golden inroutes `+E.164`.
- **Audio OK:** Twilio inbound; Twilio direct egress (when Peer 50 was first). Cell via Brindley with UK `001…` OK.
- **Outbound gwlist end-state:** **`1,20,50`** (Brindley → Magrathea → Twilio). Magrathea first rejected for intl on this account; Brindley exits to Magrathea upstream.
- **Trombone DID** (out Brindley → Magrathea → Twilio DID): Brindley shows progress, **no answer** — treat as trial/Twilio-side; abandoned.
- **Architecture (discussed, not built):** global local DIDs → EU contact centre can be SBC-only for signaling/dialects; **RTP bypass** may still need Asterisk or rtpengine stage — test later. Dialects/DID management is the reusable foundation.

### Golden / operator follow-up
- Pair **`magrathea-lab`**: VIP Magrathea `i-078cca73d4a4106bb` / `3.93.26.82`; companion `i-00964a57ac65383d1` (`3.80.2.11`). SSH SBC `opensips.pem`; golden `pbx3test.pem` @ `08jzwn.pbx3.com`.
- Magrathea gwid **20** attrs may still lack `dialect=uk-magrathea` (Twilio 50 has dialect).
- Untracked: `pbx3sbc-admin/scripts/sbcfo-greenfield-remote.sh`. Surgical deploy only on live SBC admin trees.

### Resume
- Superseded by privileges block above.

### Resume
1. **Toll fraud / velocity** — V0 framing done; next **V1** CDR / **V2** detect+notify when prioritized (`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`), or parked shadowing/Litestream.
2. Or **paid Twilio** + named dialect recipe / US Egress `011:+`.
3. Fail2ban Peer auto-whitelist on next carrier onboard.

---

## Next agent session notes (2026-07-22 — PSTN number dialects) — historical

**Tips were:** pbx3 dialects **`0e764c1`** / handoff **`f36db55`**, sbc **`3404608`**, sbc-admin **`c623d0c`**, docs **`12f32e3`**. Superseded by Twilio lab block above.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-22 — Egress qualify + ops notify) — historical

**Tips were:** pbx3 **`d377631`**, spa **`8b9fc83`**, api **`5426f58`**, sbc **`b6135b2`**, sbc-admin **`69e1893`**. Superseded.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-21 — Filament Backup + Fleet warm sync) — historical

**Branches:** **pbx3** **`129ef40`**, **pbx3spa** **`d021f60`**, **pbx3sbc** **`9373d30`**, **pbx3sbc-admin** **`7dda7fb`**, **pbx3-docs** **`b9fb77f`**. Live on Magrathea / companion / control.

### Shipped
- **Filament Backup** (VIP holder only via IMDS public IPv4): create + list local zips; optional S3 upload; **no restore UI**. Helper `sbc-backup-panel.sh` + sudoers.
- **Fleet warm sync:** `POST …/edge-pairs/{id}/warm-sync` — active `/api/fleet/backup` → S3 → standby `/api/fleet/warm-pull` (`--db-only`); `last_warm_sync_*` on pair; daily `pbx3-edge-warm-sync.timer`. SPA Sync now + comfort spinner/elapsed.
- **Standby bootstrap:** companion needed fleet token, `log-ship.env`, AWS CLI, IAM `pbx3-sbc`. Scripts `check-ha-standby-ready.sh` / `bootstrap-ha-standby-warm.sh`; Phase A checklist in MkDocs.
- Lab: Backup now + Sync now OK; cold restore remains CLI scratch runbook (`fleet/sbc-backup-restore.md`).

### Golden / operator follow-up
- Pair **`magrathea-lab`**: Magrathea active (`i-078cca73d4a4106bb`); companion (`i-00964a57ac65383d1`) — public IP via `aws ec2 describe-instances` (`opensips.pem`).
- Optional: Filament “On S3?” column; confirm Magrathea backup cron installed.
- Restore UI deferred; Litestream/shadowing parked.

### Resume
1. **Promoter SSH fence** reliability (`fenced: false` often) before Auto promote.
2. Or Phase D LE / egress OPTIONS / ops-notify polish.
3. Optional Backup list S3 badge + Magrathea cron check.

---

## Next agent session notes (2026-07-21 — Magrathea live HA promote) — historical

**Branch was:** superseded by Filament Backup + Fleet warm sync block above. Tips were pbx3 **`3a9dbb2`**, spa **`acfb13b`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-21 — HA FO greenfield + SBC Certificates/LE) — historical

**Branch was:** superseded by Magrathea live HA block above. Tips were sbc-admin **`a0ded23`**, sbc **`c085b50`**, docs **`25b3917`**, pbx3 **`1630137`**, spa **`a21a439`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-20 — SBC HA requirements + portability) — historical

**Branch was:** superseded by block above. Tips were pbx3 **`a5e19d4`**, sbc **`994eb68`**, spa **`a3dc665`**, docs **`7873efe`**, sbc-admin **`467ac63`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-20 — SBC backup/restore v1 + scratch drill) — historical

**Branch was:** superseded by block above. Tips were pbx3 **`9cc0d11`**, sbc **`0a326d0`**, docs **`7873efe`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-20 — SBC data aging complete + backup/restore stub) — historical

**Branch was:** superseded by block above. Tips were sbc-admin **`82641ad`**, pbx3 **`5471d9c`**, sbc **`a5d62c4`**, docs **`553c8e7`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-20 — SPA/SBC brand + Fail2ban log + SBC aging review) — historical

**Branch was:** superseded by blocks above. Tips were spa **`858c084`**, sbc-admin **`0210d10`**, sbc **`7311b2e`**, pbx3 **`b511d59`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-19 — auto-logout + downstream peer REGISTER reqs) — historical

**Branch was:** superseded by block above. Tips were **pbx3spa** **`1868242`**, **pbx3sbc-admin** **`2e56ae3`**, **pbx3** **`af70342`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-18 — SBC admin SPA kinship polish) — historical

**Branch was:** superseded by blocks above. Tips were **pbx3sbc-admin** **`463431b`**, **pbx3spa** **`0f9fd65`**, **pbx3** **`1acfec4`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-18 — Instances polish + SPA panel polish) — historical

**Branch was:** superseded by blocks above. Tips were **pbx3** **`b5fee3e`**, **pbx3spa** **`changes`/`6b15302`** (later merged to **`7dda918`**).

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-17 — log retention Phases 5–6) — historical

**Branch was `main`:** superseded by block above. Tips were **pbx3** **`7c9f8d4`**, **pbx3api** **`6c28486`**, **pbx3spa** **`a9ce18c`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-17 — log retention Phases 1–4) — historical

**Branch was `logs`:** merged to **`main`** earlier same day. Superseded by Phases 5–6 block above.

### Shipped (summary)
- Phases 1–4: instance ship, siplog fleet-off, SBC + control ship, lifecycle — ops smoke done; merged **`logs`→`main`**.

### Resume
- See block above.

---

## Next agent session notes (2026-07-16 — REGISTER-loop lab + Asterisk F2B off) — historical

**Branch:** **`main`** — superseded by block above. Tips were **pbx3** **`59b5dc5`**, **pbx3api** **`16fba66`**, **pbx3spa** **`305faec`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-16 — ops notify live + REGISTER loops) — historical

**Branch:** **`main`** — superseded by block above. Tips were **pbx3** **`8622fd8`**, **pbx3api** **`4b2aa99`**, **pbx3spa** **`aa8b22a`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-16 — docs: What is PBX3 + ops notify plan) — historical

**Branch:** **`main`** — superseded by block above. Tips were **pbx3** **`0aac37b`**, **pbx3spa** **`cf64ea7`**, **pbx3-docs** **`e76c451`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-15 — pbx3-docs MkDocs live) — historical

**Branch:** **`main`** — superseded by block above. Tips were **pbx3** **`1d8316a`**, **pbx3spa** **`d4d3e71`**, **pbx3-docs** **`2a37a00`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-15 — S10.8 login chooser complete) — historical

**Branch:** **`main`** — superseded by block above (docs session). Tips were **pbx3** **`6f4facd`**, **pbx3spa** **`54cced4`** / **`59225b9`**.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-15 — S10.5 DID catalog + project; edge residue paused) — historical

**Branch:** **`s105`** — superseded by block above (residue shipped + merged).

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-14 — S10.4 catalog ↔ SBC reconcile) — historical

**Branch:** **`main`** — **pbx3** **`96e432e`**, **pbx3sbc-admin** **`2d232f8`**, **pbx3spa** **`15c5090`**. Superseded by block above.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-14 — S10.1–S10.3 fleet panel path) — historical

**Branch:** **`main`** — **pbx3** **`4498a4c`**, **pbx3spa** **`18f957d`**. Superseded by block above.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-14 — S7 recordings S3 + S7.10 sweeper) — historical

**Branch:** **`main`** — **pbx3** **`ed484f3`**, **pbx3api** **`6f46712`**, **pbx3spa** **`6e23fa3`**. Superseded by block above.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-14 — S10, design rules, S7 PCI baseline) — historical

**Branch:** **`main`** — docs tip before evening S7 implement. Superseded by later blocks.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-14 — LE, control, fleet auth, Pack A) — historical

**Branch:** **`main`** — morning tip before pm docs arc. SBC LE, control host, fleet auth, Pack A, identity stance — see **`3bc815f`** handoff commit / TODO [x] items.

### Resume (superseded)
See block above.

---

## Next agent session notes (2026-07-13 — Peers carrier UX + SBC admin nav) — historical

## Next agent session notes (2026-07-13 — Brindley lab + peering address model) — historical

**Branch:** live lab on SBC/golden; docs updated in tree (commit when asked). Prior tip: **2026-07-11 S9 + Phase 5**.

### Shipped / validated (lab)

- **Carrier REGISTER:** `uac_auth` + `uac_registrant` + admin **Peering → Registrations**; Brindley lab REGISTER OK.
- **DID `01924910444` → golden 1000:** SBC alias + golden `inroutes`; hairpin fixed (rdonly inroute); operator **Commit** published rdonly/genAst. Demo trunks cleaned to **Egress** only.
- **Docs:** **`PEERING-PLAN.md` §0.1** — DNS outbound / IP inbound (Magrathea pattern); no ITSP profiles. **`FLEET_TRUNK_PEERING_DECISION.md` §4.3.1** — solo vs fleet trunk panel. Brindley Peer gwid 30 flipped to FQDN.

### Golden / operator follow-up

- Peering UX polish for logical carrier = FQDN + IP set — **done** later same day (carrier attrs UX).

### Resume

1. Twilio/second carrier with §0.1 address split; Phase 2 failover when ready.
2. Fleet mode / Egress availability deferred.

---

## Next agent session notes (2026-07-11 — S9 snapshots + peering Phase 5) — historical

**Branch:** **`main`** — **pbx3** **`3705b8b`**, **pbx3api** **`d8c560c`**, **pbx3spa** **`103ab34`**, **pbx3sbc** **`05ea925`**, **pbx3sbc-admin** **`2df6a60`**. Golden API on **`d8c560c`**. SBC config applied + Phase 5 call validated.

### Shipped

- **S9.5–S9.7 snapshots:** Commit → `create_new_snapshot()` + FIFO (`PBX3_SNAPSHOT_MAX_COUNT`); SPA **`/snapshots`** panel; Backup archives-only. Golden Commit snap confirmed.
- **Peering Phase 5 `alias_db`:** SBC `FROM_CARRIER` fallthrough; admin **DID aliases**; Magrathea DID lab call via alias path; Phase 4 prefix restored. Lab alias row left for `01924918076` → `dhbm8x.pbx3.com`.

### Golden / operator follow-up

- None pending. **Phase 2 outbound failover** waits on second SIP provider (user returning when acquired).

### Resume

1. **Peering Phase 2** when second carrier ready — or **Fleet mode** shell / **S7** / ops note by priority.
2. Egress availability, failover+shadowing, cagi remain deferred.

**SPA dev:** **`https://08jzwn.pbx3.com:44300/api`** · **bzy54n:** **`https://bzy54n.pbx3.com:44300/api`** · **SBC admin:** **`http://sbc.pbx3.com/admin`** · **Gatekeeper:** **`http://127.0.0.1:8090`**

---

## Next agent session notes (2026-07-11 — Fleet UI home + SBC stylesync) — historical

**Branch:** **`main`** — tips superseded by **S9 + Phase 5** block above (sbc-admin now **`2df6a60`**, spa **`103ab34`**, api **`d8c560c`**).

### Resume — historical

See **2026-07-11 — S9 snapshots + peering Phase 5** block above.

---

## Next agent session notes (2026-07-10 — S8.10 day complete) — historical

**Branch:** **`main`** — **pbx3** **`9e00e30`**, **pbx3api** **`0fb0019`**, **pbx3spa** **`089477b`**, **pbx3sbc-admin** **`6036bcb`**. Superseded by **2026-07-11** block above (sbc-admin now **`624b0f3`**).

### Resume — historical

See **2026-07-11** block above.

---

## Next agent session notes (2026-07-10 — S8.10 merged to main) — historical

**Branch:** **`main`** merge tips before final handoff bump. Superseded by **day complete** block above (nodes pulled; tips `9e00e30` / `089477b`).

### Resume — historical

See **S8.10 day complete** block above.

---

## Next agent session notes (2026-07-10 — S8.10 live moves + phone POC) — historical

**Branch:** **`movewizard`** — willand + affcot phone POC. Superseded by merge to **`main`** above.

### Resume — historical

See **S8.10 merged to main** block above.

---

## Next agent session notes (2026-07-10 — S8.10 movewizard scaffold) — historical

**Branch:** **`movewizard`** — scaffold + Hosted on column. Superseded same day by live moves + phone POC above.

### Resume — historical

See **S8.10 live moves** block above.

---

## Next agent session notes (2026-07-10 — pbx3 0.0.3-25 on fleet) — historical

**Branch:** **`main`** — **pbx3** **`1bed066`** (**0.0.3-25**), **pbx3sbc** **`b914e1c`**, **pbx3sbc-admin** **`138d65d`**. Superseded same day by **`movewizard`** S8.10 scaffold.

### Shipped

- **pbx3 0.0.3-25** built, pushed (**`1bed066`**), installed on **08jzwn** + **bzy54n** — Egress identify + `endpoint=` + username-first identifier order (no longer hot-patch-only).
- Earlier same day: SBC peering Phases 3–4 lab green (Magrathea DID, hangup, Active Calls) — see historical block below.

### Golden / operator follow-up

- **After egress template / `genAst.sh`:** **`systemctl restart asterisk`** (not **`pjsip reload` alone**).
- **SBC admin:** **`http://sbc.pbx3.com/admin`**.

### Resume — historical

See **S8.10 movewizard** block above.

**SPA dev:** **`https://08jzwn.pbx3.com:44300/api`** · **affcot:** **`https://bzy54n.pbx3.com:44300/api`** · **SBC admin:** **`http://sbc.pbx3.com/admin`**

---

## Next agent session notes (2026-07-10 — SBC peering Phases 3–4 lab green) — historical

**Branch:** **`main`** — **pbx3** **`3af4519`**, **pbx3sbc** **`b914e1c`**, **pbx3sbc-admin** **`138d65d`**. Superseded later same day by **0.0.3-25** install (**`1bed066`**).

### Shipped (live lab)

| Area | Notes |
|------|--------|
| **Inbound Magrathea** | DID **`01924918076`** → golden **1000** (dhbm8x); CLI **`+44…`** (no CNAM — normal UK PSTN) |
| **Hangup** | Both directions after **`record_route()`** on **`FROM_CARRIER`** (**`60253f0`**) |
| **Active Calls** | Two dialogs per call after **`create_dialog()`** on peering paths (**`b914e1c`**) |
| **Internal dials** | Broke when golden was in **`dr_gateways`** + **`is_from_gw`** → **`FROM_CARRIER`**; fixed by skipping carrier path when **`CHECK_IS_FROM_ASTERISK`** |
| **Egress identify** | **`type=identify`** + **`endpoint=`** (Asterisk 20) + **`username,ip,anonymous`**; **`privileged=NO`** → Ingress. Packaged as **0.0.3-25**. |
| **Admin UI** | Peering **Peers** + **Number routes** (name-first, not raw gwid) **`138d65d`** on **`http://sbc.pbx3.com/admin`** |
| **Outbound** | Still **ael.vcloudpbx.com** gwid **1**; Magrathea IPs gwid **3–9, 11**; golden gwid **10** |

### Resume — historical

Identify deb shipped; see block above for current resume.

**SPA dev:** **`https://08jzwn.pbx3.com:44300/api`** · **affcot:** **`https://bzy54n.pbx3.com:44300/api`** · **SBC admin:** **`http://sbc.pbx3.com/admin`**

---

## Next agent session notes (2026-07-09 — Phase A egress validated both nodes; bzy54n phone + PSTN) — historical

**Branch:** **`fleet-phase-a`** / **`main`** (superseded 2026-07-10 — peering 3–4 done; repos on **`main`**).

**Rollback:** **`FLEET_EGRESS_LAB_ROLLBACK.md`** — tags `rollback/*-20260709`, `fleet-*-lab-validated-20260709`.

### Shipped (live lab) — historical

| Area | Notes |
|------|--------|
| **SBC peering Phase 0–2** | **`dr_*`** seeded; carrier **gwid 1** (ael); golden PSTN outbound validated |
| **08jzwn / bzy54n** | Phase A egress; Linphone + Snom/Yealink via SBC |
| **Phone types (lab)** | **Snom**, **Yealink**, **Linphone** |

### Resume — historical

Peering Phases 3–4 + merge **`fleet-phase-a`** completed 2026-07-10. See block above.

**SPA dev:** **`https://08jzwn.pbx3.com:44300/api`** · **SBC admin:** **`http://sbc.pbx3.com/admin`**

---

## Next agent session notes (2026-07-09 — fleet egress PSTN lab validated + pushed) — historical

**Branch:** **`fleet-phase-a`** in **pbx3** (**`117340f`**), **pbx3spa** (**`c27e6d5`**), **pbx3api**, **pbx3cagi**. **`main`** in **pbx3sbc** (**`8c702fb`** — peering egress + ACK fix).

**Rollback:** **`FLEET_EGRESS_LAB_ROLLBACK.md`** — tags `rollback/*-20260709` and `fleet-*-lab-validated-20260709` on GitHub; revert/redeploy steps if issues found later.

### Shipped

| Area | Notes |
|------|--------|
| **Phase A (08jzwn + bzy54n)** | Egress trunk seed, **`PBX3_FLEET_MODE`** / **`PBX3_SBC_EGRESS_HOST`**, **pbx3cagi 1.0.0-4**, **`pbx3:fleet-preflight`** all green |
| **pbx3 `67d2376`** | **`pjsip_trunk_egress.tmpl`** — outbound-only Egress (no `identify` on SBC IP); fixes relayed phone REGISTER collision. Hot-patched on both nodes |
| **SBC soak** | Golden + SBC reboot; registrations + extension calls OK. Live OpenSIPS + fail2ban whitelist persisted |
| **pbx3sbc-admin `4282261`** | Filament **`->profile()`** for password change; deployed on **`sbc.pbx3.com`** |

**Test carrier:** Operator has a relay carrier for PSTN lab tests (may need **registrant** or trusted peer) — exercise in peering Phase 0–2, not this session.

### Golden / operator follow-up

- Nodes run **hot-patches** for egress PJSIP template — merge **`fleet-phase-a` → `main`** and install **pbx3** deb when convenient.
- **SBC peering not live:** no **`dr_*`** data; live **`opensips.cfg`** lacks **`do_routing`** branches (template on **`main`** has them). Next: Phase 0 schema + carrier seed + template reload.
- **Egress PJSIP** shows **Unavailable** on golden — OPTIONS qualify to SBC fails; outbound uses **`Dial(PJSIP/num@Egress)`** via **pbx3cagi** fleet mode. Optional: **`qualify_frequency=0`** on egress template.
- **pbx3cagi** on golden: canonical repo **`~/Git/pbx3cagi`** (duplicate dirs removed).

### Resume

1. **SBC peering Phase 0–2** — test carrier (trusted peer + registration if needed); golden outbound → SBC → PSTN relay.
2. **Merge `fleet-phase-a` → `main`** across fleet repos; deb install on nodes.
3. **pbx3sbc-admin** — Carrier Peers + Inbound DIDs CRUD when peering tables exist (**`PEERING-PLAN.md`** §16).

**SPA dev:** **`https://08jzwn.pbx3.com:44300/api`** · **SBC admin:** **`http://sbc.pbx3.com/admin`**

---

## Next agent session notes (2026-07-09, session end — fleet-egress merged; nodes + SBC pulled) — historical

**Branch:** **`main`** in **pbx3**, **pbx3api**, **pbx3spa**, **pbx3cagi**, **pbx3sbc** ( **`fleet-egress`** merged and branch may be deleted when convenient).

### Shipped

| Repo | Commit | Notes |
|------|--------|--------|
| **pbx3** | **`9a25470`** | `seed-fleet-egress-trunk.sh`, gatekeeper scaffold, `sbc-fleet.v0.json`, onboard fleet `.env` hooks |
| **pbx3api** | **`2e25076`** | `FleetPostureService`, `GET /fleet-posture`, route normalization, Egress preflight check |
| **pbx3spa** | **`308af87`** | Fleet nav, `FleetTenantsView` stub, hide route trunk picker in fleet mode |
| **pbx3cagi** | **`9fe15e2`** | Fleet mode: dial **`Egress`** only (no path failover loop) |
| **pbx3sbc** | **`d84c192`** | Dispatcher `source_ip` attrs, drouting peering route blocks, soak endpoint reference doc |

**Deploy:** **`fleet-egress` → `main`** pushed on all five repos. **Pulled on instances:** **08jzwn** + **bzy54n** `/opt/pbx3api` → **`2e25076`**; **sbc** (`3.93.26.82`) `/home/ubuntu/pbx3sbc` → **`d84c192`** (SSH: **`opensips.pem`**, not **`pbx3test.pem`**).

### Golden / operator follow-up

- **`pbx3:fleet-preflight`** on both nodes: all green except **`[FAIL] Egress trunk`** — run **`seed-fleet-egress-trunk.sh`** (script not on node yet; SCP from Mac or clone **`pbx3`** tools path).
- Set **`PBX3_FLEET_MODE=true`** and **`PBX3_SBC_EGRESS_HOST=sbc.pbx3.com`** in **`/opt/pbx3api/.env`**; **`php artisan config:clear`**.
- Rebuild/install **pbx3cagi** deb on nodes for fleet AGI behaviour (**`9fe15e2`**).
- **SBC:** git updated; OpenSIPS **not** reloaded from template this session — live config still hot-patched from **`8174dfe`** era.
- Backfill dispatcher **`attrs`** with Asterisk source IP for hostname rows (multi-tenant **`GET_DOMAIN_FROM_SOURCE_IP`**).

### Resume

1. **Deploy Phase A on golden** — egress seed + fleet `.env` + **pbx3cagi** deb → preflight all green.
2. **SBC** — apply template reload + dispatcher attrs backfill; continue soak per **`SBC_SOAK_ENDPOINT_REFERENCE.md`**.
3. **Carrier peering** path per **`PEERING-PLAN.md`** (template blocks on `main`; not exercised live).

**SPA dev:** **`https://08jzwn.pbx3.com:44300/api`** at login (local **`pbx3spa`** on **`main`** for fleet UI).

---

## Next agent session notes (2026-07-08, session end — pbx3sbc inter-extension calling) — historical

**Branch:** **`main`** in **pbx3sbc** (**`8174dfe`** pushed); **pbx3sbc-admin** **`205e1a2`** (MI `ds_reload`; from prior session). **pbx3**, **pbx3api**, **pbx3spa**, **pbx3cagi** unchanged.

### Shipped

| Repo | Commit | Notes |
|------|--------|--------|
| **pbx3sbc** | **`8174dfe`** | Inter-extension calling via SBC: INVITE NAT routing (`COALESCE(received, contact)`), Yealink 401/407 auth relay (`force_rport`, defer outbound `create_dialog`), Snom `line=` URI param preservation (`GET_ENDPOINT_URI_PARAMS`), single-tenant dispatcher hostname fallback |

**Live:** **`sbc.pbx3.com`** (`3.93.26.82`) — config patched in place + OpenSIPS restarted. Tenant **`dhbm8x.pbx3.com`** → Golden **`08jzwn.pbx3.com`**. **Validated:** Snom 1000 ↔ Yealinks 1001/1002 all directions.

### Golden / operator follow-up

- Live **`/etc/opensips/opensips.cfg`** was hot-patched on the server; future installs should use template from **`8174dfe`** (not ad-hoc Python patches).
- **`GET_DOMAIN_FROM_SOURCE_IP`** still fails when dispatcher uses hostname (`sip:08jzwn.pbx3.com`) — single-tenant fallback works; multi-tenant needs IP in dispatcher attrs or DNS-aware reverse lookup.
- **UFW** on SBC had restrictive SIP rules — opened `5060/udp`+`tcp` during session; confirm installer defaults.
- **PSTN/carrier peering** path not exercised this session (extension-to-extension only).

### Resume

1. **SBC soak** — more tenants/handsets; watch for new vendor SIP quirks (Yealink `:5060` in URI, Snom `line=`).
2. **SBC peering** — outbound carrier path per **`pbx3sbc/workingdocs/PEERING-PLAN.md`**.
3. Then **Phase A** Egress on nodes (fleet plan unchanged).

**SBC test:** phones → **`dhbm8x.pbx3.com`** → **`sbc.pbx3.com`** → Golden **`08jzwn.pbx3.com`**.

---

## Next agent session notes (2026-07-07, session end — §2.6.1 node IAM tighten; S7 deferred) — historical

**Branch:** **`main`** in **pbx3**, **pbx3api**, **pbx3spa**, **pbx3cagi**.

### Shipped

| Repo | Commit | Notes |
|------|--------|--------|
| **pbx3** | **`a4628fe`** | §2.6.1 — node S3 writer policy drops blanket `tenants/*` (template + golden/bzy54n JSON); `OPS_S3_RUNBOOK.md` §3.1/§7.1; `apply-node-s3-writer-policy.sh` auto-prunes at 5-version IAM limit; recordings bucket naming clarification (`RECORDINGS_STORAGE_DESIGN.md` §6.3); TODO (S7 deferred) |
| **pbx3api** | **`34d8bd8`** | `FleetPreflightService` — new **`S3 tenants/* denied`** deny-probe check |

**IAM applied live:** golden policy **v6**, bzy54n **v2** — nodes now `instances/{own_ksuid}/*` only. Smoke on both: backup PUT **PASS**, `tenants/*` PUT **DENIED**. `pbx3:fleet-preflight` **all green** on both nodes (git pull done, config cleared).

### Decisions this session

- **S7 (recordings S3) deferred** — R1.5 local tier proves the operator path; building upload/presign now = work twice (needs the B′ gatekeeper). Revisit after B′.
- **S8.10 panel tenant moves = priority** (stakeholder weight). Path: **§2.6.1 done** → **SBC standup** (image tested) → **Phase A** Egress → **B/B′** control plane + gatekeeper → **C** move wizard.
- **Gatekeeper** lives in the **fleet control-plane service** (Phase B′), on its own host (small EC2 or lab VM) — **not** on a node or the SBC.
- **Bucket naming:** `08jzwn-pbx3` is the **fleet slug** (first node stood up), not instance-owned; one recordings bucket per fleet, keyed by tenant.

### Golden / operator follow-up

- **bzy54n:** now on **pbx3 0.0.3-23** (R1.5 parity; smoke-tested — offload/list/play/retention OK).
- Node IAM policies tightened in place (same role/policy names) — no reboot; backups unaffected.

### Resume

1. **SBC standup** — bring up `pbx3sbc` image on golden fleet; validate phone→SBC→node and node→Egress→SBC→carrier (gate for Phase A). See `pbx3sbc/workingdocs/PEERING-PLAN.md`.
2. **Phase A** — per-node `Egress` trunk (fleet AMI) + AGI path simplification.
3. Then **B/B′** control plane + gatekeeper → **C** move wizard.

**SPA dev:** **`https://08jzwn.pbx3.com:44300/api`** at login.

---

## Next agent session notes (2026-07-07, session end — R1.5 recordings local archive shipped) — historical

**Branch:** **`main`** in **pbx3**, **pbx3api**, **pbx3spa**, **pbx3cagi**.

### Shipped

| Repo | Commit | Notes |
|------|--------|--------|
| **pbx3api** | **`27ff302`…`f5237de`** | R1.5: offload, retention, reconcile, SQLite index, cron examples; archive perms fix (`852b034`); installer drops backup + recordings cron |
| **pbx3** | **`ac2d90a`/`a8c9cb2`/`efdc78a`** | `recordings` table + migration SQL; postinst applies on upgrade; legacy recording cron retired; **`pbx3 0.0.3-23`** deb built on golden |

**Golden validated:** tenant **dhbm8x** — offload → archive, list/play from SQLite index; retention age-out + grace purge smoke-tested. **bzy54n:** R1.5 parity (6 recordings offloaded); still on **0.0.3-22** deb (SQL seeded manually).

**Cron (both nodes):** `/etc/cron.d/pbx3-recordings` (offload */10, retain 02:30); `/etc/cron.d/pbx3-backup` (daily 02:00). Prior backups were SPA-manual only.

### Golden / operator follow-up

- **08jzwn:** **pbx3 0.0.3-23** installed; **pbx3api** on **`main`** (`f5237de`).
- **bzy54n:** upgrade to **`pbx3_0.0.3-23_all.deb`** when convenient (functionally at R1.5).
- **apt upgrade over SSH:** use `DEBIAN_FRONTEND=noninteractive` + `-o Dpkg::Options::="--force-confold"` for `/etc/cron.d/pbx3` (live edits vs package).
- **`rec_mount`:** deferred (on-prem SAN/EFS — not fleet canonical).

### Resume

1. **S7** — recordings S3 offload (needs gatekeeper presigns + **`PBX3_RECORDINGS_BUCKET`**).
2. Optional parallel: **§2.6.1** IAM tighten.
3. **bzy54n** — install **0.0.3-23** deb.

**SPA dev:** **`https://08jzwn.pbx3.com:44300/api`** at login.

---

## Next agent session notes (2026-07-07, session end — R1 recordings shipped) — historical

**Branch:** **`main`** in **pbx3**, **pbx3api**, **pbx3spa**, **pbx3cagi**. **`r1`** merged to **`main`** in **pbx3api** + **pbx3spa**; local **`r1`** branches may be deleted.

### Shipped

| Repo | Commit | Notes |
|------|--------|--------|
| **pbx3api** | **`4f52853`** | R1 API: `RecordingController`, `RecordingIndexService`, `/recordings` routes; spool disk `PBX3_RECORDINGS_ROOT` |
| **pbx3spa** | **`ea0fefc`** | Recordings panel, nav, tenant-name filters, play/download |
| **pbx3** | **`b90e93f`…`4f19530`** | **`RECORDINGS_STORAGE_DESIGN.md`** — three-tier storage, SQLite index, ageing, dedicated S3 bucket, PCI + third-party PSP handoff |

**Golden validated:** tenant **duns** — list, play, download from **`https://08jzwn.pbx3.com:44300/api`**. SPA runs locally against golden.

### Golden / operator follow-up

- **08jzwn** `/opt/pbx3api` on **`main`** (`git pull` done; php-fpm reloaded).
- Recordings read spool: **`/var/spool/asterisk/monitor/{tenant_shortuid}/`** (not `/opt/pbx3/media/recordings` until R1.5).

### Resume

1. **R1.5** — local archive offload + `recordings` SQLite table (**`RECORDINGS_STORAGE_DESIGN.md`** §7).
2. Optional parallel: **§2.6.1** IAM tighten (drop `tenants/*` on node policy).
3. **S7** after R1.5 + gatekeeper presigns (dedicated recordings bucket).

**SPA dev:** **`https://08jzwn.pbx3.com:44300/api`** at login.

---

## Next agent session notes (2026-07-07, session end — fleet mobility design) — historical

### Shipped (docs)

| Doc | Purpose |
|-----|---------|
| **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** | S8.10 panel-first tenant move: SBC-required fleet, Egress, control-plane + **S3 gatekeeper**, DID homing in S3, gotchas, **§13** implementer map |
| **`FLEET_SYSTEM_OVERVIEW.md`** | Stakeholder intro — Instance / Tenant / SBC / S3 responsibilities (slides source later) |
| **`IMPLEMENTATION_PLAN.md`** | S8.10 row + control-plane / B′ |
| **`pbx3-directory/README.md`** | Pointer to overview |

**Key decisions (settled in design):** fleet requires **SBC tier**; cutover = **`domain.setid`** repoint; **S3** owns tenant homing + DID inventory; **separate control-plane service** (not pbx3api namespace); **`tenants/*` node IAM** too broad — tighten per §2.6.1.

### Fleet state (unchanged)

**08jzwn** + **bzy54n** on **`main`**; **affcot** on **bzy54n**; **pbx3 0.0.3-22** / **pbx3cagi 1.0.0-3**.

### Resume

1. **R1** — call recordings (still priority #1 per TODO).
2. **S8.10 build** when ready — start **§2.6.1** IAM or **Phase A** (Egress + AGI); read **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §13 before **B′/C**.
3. Stakeholder **slides** — derive from **`FLEET_SYSTEM_OVERVIEW.md`**.

---

## Next agent session notes (2026-07-07, session end) — historical

**Branch:** **`main`** in **pbx3**, **pbx3api**, **pbx3spa**, **pbx3cagi**. **`s8-tenant-move`** merged and deleted.

### Shipped / fleet state

| Item | Notes |
|------|--------|
| **pbx3 `main`** | **`e4f9a88`** — **`pbx3_0.0.3-22_all.deb`** + postinst **runLinker**; runbook firewall/symlink |
| **pbx3api `main`** | **`a7cb907`** — tenant import hardening; auto **`update-fqdn-inline`** |
| **pbx3cagi `main`** | **`bf8774e`** — **1.0.0-3** sailhpe **`_all.deb`** packaging |
| **Fleet** | **08jzwn** + **bzy54n** API on **`main`**; **affcot** on **bzy54n**; packages installed |

### Fleet reference

| | **08jzwn** (golden) | **bzy54n** |
|--|--|--|
| FQDN | `08jzwn.pbx3.com` | `bzy54n.pbx3.com` |
| KSUID | `3DmAsxePTWQZgynBYXE8obIRqEE` | `3E3gAOVGBhvc6vEPTBIYCBPycIk` |
| Tenants | default, duns, sandycroft, willand | cluster1 (`wfh69h`), **affcot** (`9wvvnb`) |

### Operator notes

- Node API updates: **`cd /opt/pbx3api && git pull origin main && composer install --no-dev`** — do not **`scp`** hotfixes.
- Golden git push needs Mac/credentials; **`.deb`** artifacts committed from builder like prior releases.
- **`fqdninspect=YES`** on nodes using SIP STRING match on 5060.

### Resume

1. **R1** — call recordings API + SPA panel.

**SPA dev:** **`https://08jzwn.pbx3.com:44300/api`** · affcot: **`https://bzy54n.pbx3.com:44300/api`**.

**Open items:** **`TODO.md`**. **SPA:** **`pbx3spa/workingdocs/SESSION_HANDOFF.md`**.

---

## Next agent session notes (2026-07-06, session end — tenant migration drill)

**Branch:** **`main`** — **pbx3cagi** **`bf8774e`** (1.0.0-3 packaging). **pbx3** + **pbx3api** — **`s8-tenant-move`** (pending merge to **`main`**). **pbx3spa** — **`main`** (handoff only).

### Shipped / validated

| Item | Notes |
|------|--------|
| **S8.5–S8.6 drill** | **affcot** `9wvvnb` golden → **bzy54n**; DNS; UDP register + calls; golden cleanup; S3 **`tenants/9wvvnb/meta.json`** |
| **pbx3api `s8-tenant-move`** | `TenantMobilityService` import fixes; auto **`update-fqdn-inline`** after import |
| **pbx3 `s8-tenant-move`** | **`TENANT_MIGRATION_RUNBOOK.md`** firewall/symlink; postinst **runLinker**; **0.0.3-22** changelog |
| **pbx3cagi `main`** | **1.0.0-3** sailhpe-style **`_all.deb`** (pre-staged amd64+arm64, no compile in debuild) |

### Fleet reference

| | **08jzwn** (golden) | **bzy54n** |
|--|--|--|
| FQDN | `08jzwn.pbx3.com` | `bzy54n.pbx3.com` |
| KSUID | `3DmAsxePTWQZgynBYXE8obIRqEE` | `3E3gAOVGBhvc6vEPTBIYCBPycIk` |
| Tenants | default, duns, sandycroft, willand | cluster1 (`wfh69h`), **affcot** (`9wvvnb`) |

### Golden / operator follow-up

- Merge **`s8-tenant-move`** → **`main`**; build/install **`pbx3 0.0.3-22`**, **`pbx3cagi 1.0.0-3`** on fleet nodes as needed.
- LE Sync optional (UDP drill skipped TLS).
- **`fqdninspect=YES`** on nodes using SIP STRING match on 5060.

### Resume

1. Merge **`s8-tenant-move`** and deploy package bumps to fleet.
2. **R1** — call recordings API + SPA panel.

**SPA dev:** **`https://08jzwn.pbx3.com:44300/api`** or proxy **bzy54n** for affcot testing.

**Open items:** **`TODO.md`**. **SPA:** **`pbx3spa/workingdocs/SESSION_HANDOFF.md`**.

---

## Next agent session notes (2026-07-06, session end — snapshots backlog)

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
