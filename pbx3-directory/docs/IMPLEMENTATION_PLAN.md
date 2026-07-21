# Instance directory & S3 catalog — implementation plan

**Branch:** `directory` (pbx3, pbx3api, pbx3spa)  
**Read first:** `DESIGN_RULES.md` · **Layout:** `S3_LAYOUT_PROPOSAL.md` (improved v1) · **Schemas:** `../schema/` · **Review:** `ARCHITECTURE_REVIEW_SCORECARD.md` · **Grounding:** `ARCHITECTURE_PEER_REVIEW.md`

**Product model:** EC2-style fleet console — low-traffic admin; catalog changes rarely; **nodes never depend on S3/directory for calls.**

---

## Architecture decisions (committed)

| Decision | Choice | Notes |
|----------|--------|--------|
| **Phase 2 catalog** | **S3 JSON** (`catalog/instance-index.json`) | GET on login; no DB for picker v0. Human-facing `label` / tenant **shortuid** in paths; **KSUID** for instance `id` and `instances/` prefix. |
| **Bulk data** | **S3** (same org bucket) | Backups, recordings, share assets — not Postgres/Supabase blobs. |
| **Phase D central auth** | **Deferred** | Before building: **evaluate Supabase vs RDS** (and whether catalog moves off JSON). See ToDo § Product & auth. |
| **Nodes / telephony** | **No directory dependency** | `DESIGN_RULES.md` Rule 1 — unchanged. |
| **Solo / trial** | **No catalog required** | Rule 6 — one node = install + SPA login only; directory/S3 when fleet or backups opted in. |
| **Fleet edge** | **Replaceable SBC** via **`SbcFleetAdapter`**; SIP runtime API | Rules 7–8 — pbx3sbc default; catalog → SPA one-way. **`FLEET_TRUNK_PEERING_DECISION.md`** §2.4. |
| **Cloud / object store** | **S3-API portable** + **cloud/IaaS adapter** | **Rule 9** — not AWS-locked; MinIO/R2/etc. viable; onboard/rebuild IaaS behind adapter (AWS first). |

**Rejected for Phase 2:** Supabase/Postgres/RDS/DynamoDB as the catalog source of truth (unnecessary for rare reads of a small fleet; avoids running a DB before central auth is defined).

---

## Goals

| Track | Goal | v0 deliverable |
|-------|------|----------------|
| **A — Directory** | Central SPA picks instance from catalog | `catalog/instance-index.json` + picker UI |
| **B — S3 contract** | Documented keys + JSON schemas for ops/S3 | Schemas + v1 tree in repo |
| **C — Registrar** | One writer updates catalog + meta files | Script (manual invoke → install hook later) |
| **D — S3 backup upload** | Node backups land under `instances/…/backups/` | Async PUT after existing `/opt/pbx3/bkup` |
| **E — Recordings** | Operator find/play + S3 DR | **Phase R1** (local SPA/API) → **Phase S7** (S3 offload) |
| **F — Fleet lifecycle** | Low-friction instance (re)build + tenant move | **Phase S8** — **`NEW_INSTANCE_CHECKLIST.md`**, **`TENANT_MIGRATION_RUNBOOK.md`**, onboard hardening |
| **G — Fleet admin console** | Panel-first fleet-admin actions (not Mac CLI) | **Phase S10** — abilities-gated onboard / decommission / move ops / edge / reconcile |

---

## Current priority (2026-07-14)

Agreed product order — **pbx3cagi struct refactor deferred** until fleet + recordings have momentum. **S8.1–S8.10** scaffold + fleet login are largely on **`main`**; next fleet product slice is **S10** when chosen over S7/egress.

| Order | Phase | Focus |
|-------|-------|--------|
| **done** | **S8.1–S8.10** (core) | Checklist, onboard, preflight, tenant move tooling, Fleet mode + gatekeeper login |
| **1** | **S7** *or* **S10** | Recordings S3 offload **or** fleet admin panel actions (product pick) |
| **2** | **S10** (if not #1) | Abilities → catalog onboard/decommission → job/edge/reconcile — see § Phase S10 |
| **3** | **Egress availability** | **`FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`** (future) |
| **3b** | **SBC HA promote** | **`SBC_HA_FAILOVER_REQUIREMENTS.md`** (reqs locked 2026-07-20; implement later) |
| **—** | **pbx3cagi Phase 0** | **Built** on `main`; golden `make test` sign-off; Phase 1.3+ refactor when resumed |

See **`pbx3/workingdocs/TODO.md`** § suggested order.

## High value (in scope for schemas + v1 layout)

These are **specified now** in `schema/` and `S3_LAYOUT_PROPOSAL.md` § improved v1.

### Catalog (`catalog/instance-index.json`)

| Field | Required | Purpose |
|-------|----------|---------|
| `version`, `updated_at` | index | Staleness |
| `id`, `fqdn`, `api_base_url`, `label`, `status` | per row | Picker |
| `environment` | optional | prod/staging/lab |
| `notes`, `region`, `org_id` | optional | Ops |
| `package_version` | optional | Support |
| `last_seen_at` | optional | Fleet badge (manual or job later) |

Schema: `instance-record.v0.json` · example: `instance-index.json`

### Instance meta (`instances/{ksuid}/meta.json`)

`created_at`, `updated_at`, `status`, `environment`, `backup_latest_stamp`, optional `tenant_shortuids[]` — schema `instance-meta.v0.json`

### Tenant meta (`tenants/{shortuid}/meta.json`) — **required**

`instance_id`, `cname`, `fqdn`, `status`, `created_at`, `updated_at`, `moved_at`, `previous_instance_id` — schema `tenant-meta.v0.json`

### Backups (`backups/{backup_stamp}/`)

| File | Purpose |
|------|---------|
| `policy.json` | `maxage_days`, `glacier_after_days`, `legal_hold` — schema `retention-policy.v0.json` |
| `manifest.json` | scope, trigger, sha256, `contents_summary`, `restore_tested_at` — schema `backup-manifest.v0.json` |
| `backup.zip` | **Only** restore artifact |

`backup_stamp` = `20260517T153045Z` (UTC, sortable).

### Recordings

- Path: `media/{yyyy}/{mm}/{dd}/{call_id}.wav` (+ `.txt` sidecar)
- Filename includes **call_id** (tie to CDR / uniqueid on node)
- Document S3 object metadata: `tenant`, `call_id`, `duration` (set on PUT in implementation ToDo)

### Process (planned in phases below)

- **Registrar** — single script updates catalog + both meta files
- **Install hook** (later in phase C) — new node registers row idempotently by `globals.id`

---

## Implementation phases

### Phase 1 — Contract freeze (pbx3 only, no runtime code)

**Owner:** docs + schema PR on `directory`

- [x] `DESIGN_RULES.md`, `S3_LAYOUT_PROPOSAL.md` v1 tree
- [x] JSON Schemas: `instance-record`, `instance-meta`, `tenant-meta`, `backup-manifest`, `retention-policy`
- [x] `docs/V0_CONTRACT.md` — one-page pointer to schemas + required vs optional fields
- [x] `tools/validate-index.sh` — validate `instance-index.json` (jq + optional python jsonschema)

**Exit:** Example `instance-index.json` validates; team agrees backup = zip + manifest only.

---

### Phase 2 — Dev catalog URL (pbx3 + pbx3spa) — **S3 JSON (committed)**

**Owner:** pbx3-directory example + SPA env  
**Storage:** HTTPS URL to `catalog/instance-index.json` (static host or S3 object). **Not** Supabase/RDS for this phase.

- [ ] **Solo (Rule 6):** if `VITE_INSTANCE_DIRECTORY_URL` unset → no catalog fetch; login = email/password + API URL (optional `VITE_DEFAULT_API_BASE_URL`)
- [ ] If catalog has **one** row → auto-select, skip picker
- [ ] Host `catalog/instance-index.json` (dev/fleet only: static file in repo, or S3 test bucket)
- [ ] `pbx3spa`: `VITE_INSTANCE_DIRECTORY_URL` → fetch on login when set
- [ ] Instance picker UI: list `label`, `fqdn`, `status`, `environment`
- [ ] **Rule 3:** directory fetch failure → warning + manual `api_base_url` + **recent instances** (`localStorage`)
- [ ] **Refresh catalog** button (no polling)
- [ ] **Deep link** `?instance={ksuid}` (optional query preselect)
- [ ] **Maintenance:** allow open with confirm if `status === maintenance`
- [ ] Instance chip: label + fqdn + environment after connect

**Exit:** Operator picks `08jzwn` from JSON list; Sanctum login unchanged.

---

### Phase 3 — Registrar (pbx3 scripts)

**Owner:** `pbx3-directory/tools/` · **Docs:** `tools/README.md`

- [x] `register-instance.sh` — merges `catalog/instance-index.json` + `instances/{ksuid}/meta.json`
- [x] `register-tenant.sh` — writes `tenants/{shortuid}/meta.json`
- [x] `move-tenant.sh` — updates tenant meta + `moved_at` / `previous_instance_id`; does **not** move recordings prefix
- [x] Idempotent: same `globals.id` → update catalog row, no duplicate

**Exit:** Manual run on test node updates dev catalog consistently.

---

### Phase 4 — S3 backup packaging (pbx3 + pbx3api)

**Owner:** backup pipeline

- [x] After existing backup create: write `manifest.json` + upload `backup.zip` to `instances/{ksuid}/backups/{stamp}/`
- [x] Populate manifest: `pbx3_version`, `node_fqdn`, `trigger`, `sha256`, `contents_summary`
- [x] Update `instances/{ksuid}/meta.json` → `backup_latest_stamp`
- [x] Write `backups/policy.json` on first upload (defaults from org template)
- [x] **Async upload** — local `/opt/pbx3/bkup` remains source for UI until PUT succeeds (`dispatch()->afterResponse()`)

**Code:** `pbx3api` — `InstanceBackupDirectoryUpload`, `config/pbx3_directory.php`, disk `pbx3_org`; `php artisan pbx3:upload-backup`. **`pbx3-directory/tools/upload-instance-backup.sh`** for CLI retry without PHP.

**Deploy:** `composer install` on node (adds `league/flysystem-aws-s3-v3`); set `PBX3_ORG_BUCKET` + IAM (see `OPS_S3_RUNBOOK.md` §7).

**Exit:** One instance backup visible in S3 with valid manifest; restore still from local UI first.

---

### Phase 5 — Install registration (pbx3)

- [ ] `postinst` or `installer.sh` optional hook calls registrar (or prints exact command) when `globals.id` + org config present
- [ ] Document env vars: `PBX3_ORG_BUCKET`, `PBX3_ORG_ID`

**Exit:** New install can appear in catalog without hand-editing JSON.

---

## S3 program closeout (target: finish bulk S3 without Phase D auth)

**Goal:** Close the **S3-shaped** workstream — directory, instance backups, tenant recordings, ops tooling — so the team can treat “S3 v1” as done and park **Supabase/RDS / Phase D** until a separate auth project.

**Out of scope for this closeout:** central IdP, per-user catalog ACL, tenant-scoped backup zips to `tenants/…/backups/`, CloudFront phone images, EventBridge, Terraform, cross-region replication, GDPR export packages.

### Already done (golden reference)

| Area | Status |
|------|--------|
| Catalog + schemas + registrar | Phase 1–3 |
| Instance backup upload + manifest + `meta.json` | Phase 4 |
| Local retention option C (9 FIFO + cron) | pbx3api `119b1f7+` |
| S3 lifecycle `class=backup` (ops script, laptop) | Applied on `08jzwn-pbx3` |
| SPA backup columns (UTC + archive id) | pbx3spa |
| Central SPA hosting decision | GitHub Pages (`DESIGN_RULES.md`) |

### Exit criteria — “S3 v1 complete”

1. **Two instances** in `catalog/instance-index.json` with distinct buckets/roles (proves `OPS_S3_RUNBOOK.md` is repeatable).
2. **Backups:** operator can see **local + S3** archives; **restore or download** works when only S3 has the zip (presigned GET or rehydrate to `bkup/`).
3. **Recordings (S7 baseline):** at least one tenant on golden — async PUT to dedicated **`PBX3_RECORDINGS_BUCKET`** prefix `tenants/{shortuid}/recordings/media/…`; **playback** when local gone (presign/proxy); lifecycle/tag `class=recording`. PCI-**shaped** only (not attested) — see **`RECORDINGS_STORAGE_DESIGN.md`** §6.2.
4. **Ops:** lifecycle apply script reads **`maxage_days`** from `instances/{ksuid}/backups/policy.json` (and tenant `recordings/policy.json` when present), not a hard-coded `30` CLI arg only.
5. **Docs:** runbook covers **S3-compatible** endpoint (not AWS-only); deferred items listed explicitly below.

---

### Phase S5 — Backups complete (~1–2 weeks)

**Owner:** pbx3api + pbx3spa

| # | Task | Notes |
|---|------|--------|
| S5.1 | **API:** `GET /backups` merges local `pbx3bak.*.zip` + S3 prefixes under `instances/{ksuid}/backups/` (from manifest or listObjects) | De-dupe by `backup_stamp` / epoch; mark `source: local\|s3\|both` — **done** (`BackupIndexService`) |
| S5.2 | **SPA:** backup table shows S3-only rows (archive id, no local file); actions differ | **done** — archive download/restore when `!has_local && has_s3` |
| S5.3 | **Presigned GET** (or rehydrate job) for `backup.zip` when local missing | **done** — `GET backups/archive/{stamp}/download-url` |
| S5.4 | **Restore from S3:** optional `POST /backups/restore-from-archive` pulls zip to `bkup/` then existing restore path | **done** — `BackupArchiveService::rehydrateToLocal` + `restore_from_backup` |
| S5.5 | **`apply-backup-lifecycle-rule.sh`:** read `maxage_days` from bucket `policy.json` (instance path); fallback 30 | **done** — second arg `INSTANCE_KSUID` reads policy |

**Not required:** delete untagged pre-`119b1f7` backup objects (ops may `rm` prefix manually).

---

### Phase S6 — Fleet proof (~ops, light code)

| # | Task | Notes |
|---|------|--------|
| S6.1 | **Second node** — full runbook: bucket (or shared org bucket + second KSUID prefix), IAM role, `register-instance.sh`, Phase 4 smoke | **done** — **`INSTANCE_ONBOARDING.md`** (bzy54n); bucket/IAM detail in `OPS_S3_RUNBOOK.md` |
| S6.2 | **GitHub Pages** staging deploy + catalog CORS + API CORS for Pages origin | Closes hosting loop (`IMPLEMENTATION_PLAN` § SPA hosting) |
| S6.3 | *(Optional)* `last_seen_at` probe job updating catalog | Nice for SPA chips; **not** blocking S3 v1 exit |
| S6.4 | **Fleet onboard orchestrator** — one Mac command after AMI boot | **done** — `tools/onboard-fleet-instance.sh`; see § S6.4 |
| S6.5 | **Fleet unregister** — remove / decommission instance in catalog | **done** — `tools/unregister-instance.sh`; SPA hides `decommissioned` |

#### S6.4 — `onboard-fleet-instance.sh` (shipped)

**Problem:** Manual onboarding (IAM + SSH + registrar) is correct but heavy; many operators will stop at the runbook. **Goal:** After a **fleet-ready AMI** launch, operator runs **one idempotent command** on a Mac (or CI) with minimal flags.

**Prerequisites (not in the script):** PBX stack up on node (`/up` 200), `globals.id` set, Mac has IAM admin + SSH to instance.

**Operator input (minimal):**

- `--instance-id` and/or `--ssh user@host` (+ optional `--ssh-key`)
- `PBX3_ORG_BUCKET` (env or flag), `--region`
- Optional fleet defaults file `~/.pbx3/fleet.yaml`

**Discover from node (do not prompt for KSUID):** `shortuid`, `fqdn`, `globals.id` via SSH + sqlite.

**Pipeline (idempotent):**

| Step | Where | Reuse |
|------|--------|--------|
| Preflight | Mac + SSH | `aws sts`, SSH, `curl /up`, read globals |
| IAM | Mac | Policy from template `{{BUCKET}}` + `{{KSUID}}`; role `pbx3-node-{shortuid}`; profile; `associate-iam-instance-profile` |
| Catalog | Mac | `register-instance.sh` |
| Node join | SSH | `.env` `PBX3_ORG_BUCKET`, strip empty AWS keys, `config:clear`, optional `git pull`, S3 smoke |
| Verify | Mac | catalog instance count; optional backup upload if zip exists |

**Deliverables:**

| # | Artifact | Status |
|---|----------|--------|
| S6.4a | `tools/onboard-fleet-instance.sh` | done |
| S6.4b | `schema/pbx3-node-s3-writer.policy.json.tmpl` | done |
| S6.4c | `INSTANCE_ONBOARDING.md` § Automation + AMI checklist | done |
| S6.4d | `tools/README.md` — primary entry for “add node to fleet” | done |

**Out of scope v1:** DNS/Route53, security groups, full PBX install, Terraform (sibling later).

**AMI pairing:** Document “fleet-ready AMI” — packages + `/up` + globals; **no** `PBX3_ORG_BUCKET` until onboard script runs.

**Later:** `--hosted-zone`, registrar API on node (Phase 5), Terraform module mirroring same steps.

---

### Phase R1 — Call recordings management (local-first) (~2–3 weeks)

**Design (storage + search shape):** **`RECORDINGS_STORAGE_DESIGN.md`** — legacy recap, three-tier target (spool → local archive → S3), search strategy, phased R1 / R1.5 / S7 plan.

**Problem:** Capture and tenant config exist (`pbx3cagi` SetRecord, SPA tenant “Call recording” fields, files under `/opt/pbx3/media/recordings/…`) but operators have **no SPA panel** to search, listen, or download. Legacy **`sarkrecordings`** not ported; **no call-recordings API** in pbx3api (only IVR **`GreetingRecordController`**).

**Principle (Rule 1):** R1 works **without S3** — same as telephony. S3 offload is **Phase S7**, not a blocker for operator UX.

**Priority:** **#2** after **S8.1–S8.4** (fleet ops). Ship before or in parallel with **S7** upload work.

| # | Task | Repo | Notes |
|---|------|------|--------|
| R1.1 | **`GET /recordings`** — list/search by tenant, date range, caller/callee | pbx3api | Index from filesystem + filename conventions (epoch in path/name); tenant scope via auth |
| R1.2 | **`GET /recordings/{id}/stream`** (or `/download`) | pbx3api | Serve from local path when file exists |
| R1.3 | **SPA recordings panel** — port **`sarkrecordings`** | pbx3spa | List, filters, inline play/download; UTC display per **`DESIGN_RULES.md`** |
| R1.4 | **Nav + routes** | pbx3spa | Wire panel; help keys for search fields |
| R1.5 | **Golden smoke** | ops | Place test calls with recording enabled; verify list/play |
| R1.6 | **Optional:** reuse **`manageRecs.php`** logic or replace with API job for `recused` | pbx3 / pbx3api | Storage display on tenant panel already shows `recused` |

**Out of scope R1 v1:** bulk delete UI, legal hold, per-user listen permissions (permissions Phase 1+), MySQL `recordings` catalog table, S3 “archived” badge (S7.7).

**Exit criteria:**

- [ ] Operator finds and plays a recording from golden without SSH or legacy UI.
- [ ] API returns 404 cleanly when local file missing (S7 adds presigned fallback later).

---

### Phase S7 — Recordings S3 offload v1 (~2–3 weeks) — **PCI-shaped baseline**

**Design:** **`RECORDINGS_STORAGE_DESIGN.md`** §3.3, §4, §6.2–§6.3, §7 — dedicated bucket, presigned upload/playback, SQLite `s3_key`. **Settled 2026-07-14:** S7 = **DR + PCI-shaped store** (private bucket, BPA, TLS-only, SSE-S3, gatekeeper presigns, honest non-attested docs). **Not** in S7: KMS CMK, CloudTrail→WORM audit bucket, Security Hub, QSA, PSP payment handoff (**S7+**).

**Principle (Rule 1):** Calls and capture work **without S3**. Upload is **async** after the wav exists (R1.5 archive path is on `main`).

**IAM (supersedes older draft):** Do **not** re-open node `tenants/*` PutObject. Writers use **gatekeeper short-lived presigns** on **`PBX3_RECORDINGS_BUCKET`** only (§2.6.1 / Rule 9–12).

**Prereqs done:** R1 + R1.5. **Priority:** product pick vs S10 / egress.

| # | Task | Repo | Notes |
|---|------|------|--------|
| S7.1 | **Dedicated recordings bucket** | ops | `PBX3_RECORDINGS_BUCKET`; BPA; `aws:SecureTransport`; **SSE-S3**; never org/catalog bucket — **done** lab `08jzwn-pbx3-recordings` + **`OPS_S3_RUNBOOK.md`** §13 + `create-recordings-bucket.sh` (2026-07-14) |
| S7.2 | **Gatekeeper recordings presign** | control plane | PUT/GET scoped to `tenants/{hosted}/recordings/*` on recordings bucket — **`POST /api/v1/s3/presign-recordings`** |
| S7.3 | **Upload service + trigger** | pbx3api / cron | Presign → PUT; `PBX3_RECORDING_UPLOAD_ENABLED`; golden allowlist OK — **`pbx3:recordings-s3-upload`** |
| S7.4 | **`policy.json` + lifecycle tag** | pbx3api + tools | `maxage_days` from `recmaxage`; `class=recording` — **done** (upload tags + policy.json; `apply-recordings-lifecycle-rule.sh`) |
| S7.5 | **SQLite `s3_key` / `location`** | pbx3api | Set on upload; `s3_only` when local retention purges disk — **done** (retention keeps row searchable) |
| S7.6 | **Playback when S3-only** | pbx3api | Presigned GET or API proxy; search stays epoch/SQLite on node — **API proxies via gatekeeper GET** |
| S7.7 | **SPA “archived” badge** | pbx3spa | When `location === s3_only` — **Storage column** (Local / Local + S3 / S3 only) |
| S7.8 | **Local retention unchanged** | design | Hybrid like backup option C — S3 DR until lifecycle |
| S7.9 | **Ops wording** | docs | Runbook: private encrypted DR; **not PCI-attested** — **OPS_S3_RUNBOOK.md** §13 |
| S7.10 | **Reconciliation sweeper** | pbx3api | `pbx3:recordings-reconcile` — archive backfill + local/S3 drift repair; schedule 03:15 |

**Exit criteria:** golden async PUT; play after local age-off; dedicated bucket only; non-attested documented.

**Defer (S7+):** KMS CMK; CloudTrail → Object Lock audit bucket; Security Hub PCI; PSP strict handoff; Athena/manifests. See design §6.2 / §7 S7+.

**Related:** **`RECORDINGS_STORAGE_DESIGN.md`** (authoritative); R1/R1.5 shipped.

---

### Phase S8 — Fleet instance lifecycle & tenant mobility (~3–4 weeks)

**Problem (May 2026):** Fleet nodes are painful to (re)build: steps are split across **`INSTALL_SEQUENCE_UBUNTU.md`**, **`INSTANCE_ONBOARDING.md`**, and **`OPS_S3_RUNBOOK.md`**; rebuilds lose **EC2 IAM role** and **`pbx3api/.env` fleet block** (S3 backups vanish from panel while config looks fine). **Tenant move** is catalog-only today (`move-tenant.sh` updates S3 `tenants/{shortuid}/meta.json` only) — no integrated export/import, DNS cutover, dual-node LE sync, or SPA workflow.

**Fleet product goal:** Start/stop/rebuild instances and **move tenants between nodes** with minimal operator friction (AMI → onboard → healthy; tenant move → cutover → both nodes consistent).

**Principle:** Telephony still does not depend on S3 at runtime (Rule 1). Directory/S3 are for **ops, backups, recordings, and catalog** — but those paths must be **repeatable** without tribal knowledge.

| # | Task | Repo / owner | Notes |
|---|------|----------------|-------|
| **S8.1** | **`NEW_INSTANCE_CHECKLIST.md`** + **`REBUILD_INSTANCE_RUNBOOK.md`** + **`OPERATOR_MAC_SETUP.md`** | **pbx3-directory/docs** | Install → identity → IAM → `.env` → LE → backup/S3 smoke → catalog register; **rebuild** = S3 restore path; **Mac SSH/AWS** = operator guide for agents. |
| **S8.2** | **Fleet-ready AMI spec** | docs + ops | Packages + `/up` + `globals.id`; **no** `PBX3_ORG_BUCKET` until onboard; optional baked `scripts/fleet-node-preflight.sh`. Pair with **INSTANCE_ONBOARDING.md** § Fleet-ready AMI. |
| **S8.3** | **Harden `onboard-fleet-instance.sh`** | pbx3-directory/tools | Idempotent: IAM policy + role + **verify** `associate-iam-instance-profile`; write `.env` fleet block from template (strip empty AWS keys); run S3 list smoke; fail loudly on metadata 404. |
| **S8.4** | **Install / fleet health validator** | pbx3api | Extend `validate_install_health` (or `pbx3:fleet-preflight`): `globals.id`, `PBX3_ORG_BUCKET`, instance-profile creds, `Storage::disk('pbx3_org')->directories(instances/{ksuid}/backups)`; surfaced in installer or `GET /up` detail. |
| **S8.5** | **`TENANT_MIGRATION_RUNBOOK.md`** | pbx3-directory/docs | End-to-end: export tenant data → import on destination (preserve `cluster.id` KSUID) → DNS → **Certificates Sync** on dest + source → SPA **Commit** both → `move-tenant.sh` → optional recordings note. Cross-link **LETSENCRYPT_PER_TENANT_FQDN.md** §4.2 / **TLS_IMPLEMENTATION_STEPS.md** §4.2. |
| **S8.6** | **Tenant export/import tooling** | pbx3 + pbx3api | Inventory: `backupClusters.php` per-tenant mini-DBs, full backup restore, API gaps. Target: one command or API pair (`tenant:export` / `tenant:import`) for operator move; preserve object KSUIDs. |
| **S8.7** | **Instance stop/start runbook** | docs | EC2 stop/start vs decommission: catalog `status`, unregister vs maintenance, LE/DNS expectations, when to detach IAM. |
| **S8.8** | **Worked example + regression** | ops | Golden lab rebuilds validated (2026-07): **`REBUILD_INSTANCE_RUNBOOK.md`** path, `0.0.3-21`, preflight + SPA; tenant move smoke when S8.5–6 exist. |
| **S8.9** | **Self-service rebuild automation** | pbx3 + pbx3api + pbx3spa + ops | Design **`SELF_SERVICE_REBUILD_DESIGN.md`**: fleet AMI, first-boot S3 restore, orchestrator API, SPA wizard; node does restore, control plane does IAM/launch. |
| **S8.10** | **Tenant mobility — Fleet Console (panel-first)** | pbx3 + pbx3cagi + pbx3api + pbx3spa + **pbx3sbc** + control-plane | Design **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** (**§13** implementer map): **fleet requires SBC tier** (§2.2); cutover = SBC `domain.setid` repoint; **`Egress → SBC`** (Phase A); Fleet Console (**B**); control-plane + S3 gatekeeper (**B′**); move wizard + orchestrator (**C**). Direct-to-node = solo/Rule 6 only. |
| **S8.11** | **WebRTC edge normalization (WSS on SBC)** | **pbx3sbc** + pbx3 + pbx3api + pbx3spa + control-plane | Design: **`FLEET_TRUNK_PEERING_DECISION.md`** §6.1. Goal: SBC terminates WSS for **endpoint simplicity** (same VIP as desk phones); forward toward home instance; **RTP bypass** while backends are WebRTC-capable (PBX3 + last-gen SARK). Interim/beta: node `:8089`. |
| **S8.12** | **Fleet admin actions (panel-first)** | control-plane + pbx3spa (+ adapter) | **See Phase S10** — onboard / decommission / catalog edit / job control / reconcile / DID / fleet-user manage. Ability-gated; Mac scripts remain break-glass. |

**Out of scope S8 v1:** Terraform for full fleet; automatic DNS API (optional in S8.9 B6); SPA tenant-move wizard (S8.5/S8.6 docs + scripts first).

**Exit criteria:**

- [ ] Operator follows **`NEW_INSTANCE_CHECKLIST.md`** only — new fleet node shows S3 backups without ad-hoc certbot/IAM debugging.
- [ ] **`onboard-fleet-instance.sh`** fails fast if IAM role not attached (metadata 404 caught in preflight).
- [ ] **`TENANT_MIGRATION_RUNBOOK.md`** published; one tenant move validated on two-node fleet (data + catalog + LE).
- [ ] Rebuild golden from backup/AMI without losing backup panel S3 visibility (documented regression).

**Dependencies:** S5 backups (done), S6 onboard (done), LE Sync fix (**0.0.3-17**). Can run **in parallel** with Track B Phase 4 help QA.

---

### Phase W1 — WebRTC edge normalization (~2–4 weeks after UDP edge)

**Why:** Same stable SBC VIP for webphones as desk phones (endpoint setup / mobility). PBX3 and last-gen SARK already speak WSS/WebRTC — this is not protocol rescue. Closes the gap where webphones hit node `:8089` and do not follow SBC cutover.

**Non-goal (v1):** Full WebRTC feature platform; RTPEngine at edge; older non-WSS SARK browser webphone (needs media gateway — separate go/no-go).

| # | Task | Repo | Notes |
|---|------|------|-------|
| W1.1 | Add WSS/TLS listeners on SBC | pbx3sbc | `proto_wss` + TLS on **VIP** / stable edge FQDN (active–passive §6) |
| W1.2 | Registrar/NAT path for WebSocket clients | pbx3sbc | Handle `;transport=wss` contacts and registration lifecycle like UDP endpoints |
| W1.3 | Route WebRTC signaling to node backends | pbx3sbc | Preserve `domain` → `setid` mobility; no node-direct bypass in fleet mode |
| W1.4 | Keep RTP bypass for WSS-capable homes | pbx3sbc + product | Media stays endpoint ↔ home Asterisk (beta-proven). Media gateway only if older non-WSS backends get webphone |
| W1.5 | Provisioning/profile docs | docs + pbx3spa | Endpoint profile → SBC WSS URL; interim node `:8089` = beta/hybrid |
| W1.6 | Fleet preflight update | control-plane + pbx3api | “WebRTC edge ready” (SBC WSS + cert + routing) before claiming WebRTC mobility |

**Acceptance criteria:**

- [ ] WebRTC client registers to SBC WSS endpoint (not node endpoint) and makes/receives calls through fleet path.
- [ ] Tenant move via SBC repoint keeps WebRTC endpoint reachable without client reconfiguration.
- [ ] Operational docs include fallback/interim mode and explicit limitations.

---

### Phase S9 — Ops polish (when S5–S8 code exists)

| # | Task |
|---|------|
| S9.1 | Document **non-AWS** endpoint env for Flysystem (`AWS_ENDPOINT`, path-style) in `OPS_S3_RUNBOOK.md` |
| S9.2 | Optional object tags `org`, `instance_id`, `tenant` on PUT (in addition to `class`) |
| S9.3 | `postinst` registrar hook (Phase 5) |
| S9.4 | Mark `S3_LAYOUT_PROPOSAL.md` **implemented** sections vs **planned** in header |
| **S9.5** | **Snapshots SPA panel** | **pbx3spa** | **Done** — **`SnapshotsView`** + `/snapshots` nav; **`BackupView`** = archives only (local + S3). |
| **S9.6** | **Snapshot on Commit** | **pbx3api** | **Done** — after successful **`syscommands/commit`**, call **`create_new_snapshot()`** (failure logged; commit still 200). |
| **S9.7** | **Snapshot FIFO retention** | **pbx3api** | **Done** — **`SnapshotRetention`** keep newest **9**; env **`PBX3_SNAPSHOT_MAX_COUNT`**; on commit + `snapshots/new`; artisan **`pbx3:prune-snapshots`**. |

**Snapshots vs backups:** Snapshots = quick DB rollback around Commit; backups = full DR zip + S3. Do not merge panels.

---

### Phase S10 — Fleet admin actions (panel-first) (~3–5 weeks)

**Status:** Planned (2026-07-14). Wish-list packaged from Fleet Console product path after S8.10 shell + gatekeeper login.

**Problem:** S8.10 gave Fleet **mode** (Instances / Tenants / Jobs) and move jobs; ops still lands Mac IAM + `register-instance.sh` / `unregister-instance.sh` for node lifecycle. Product persona is a **fleet admin** — panel-driven, not CLI — and those powers must **never** leak to instance/tenant Sanctum `admin`.

**Goal:** Empower a signed-in **fleet admin** (gatekeeper identity + `fleet_*` abilities) to run the high-value fleet lifecycle actions from Fleet mode. Control plane (gatekeeper on `control.pbx3.com`) is the sole writer for catalog mutations and the sole caller of edge adapters / cloud onboard jobs. Browser never holds ops IAM.

**Portability (Rule 9):** Object-store access stays **S3-API shaped** (endpoint + credentials; not AWS-product assumptions). **S10.7** / S8.9 IaaS steps (attach role, launch AMI, etc.) go through a **cloud/fleet adapter** — AWS SDK is the first implementation, not a permanent coupling in domain code.

**Trust / jobs (Rules 10–14):** Fleet plane ≠ instance Sanctum; control plane fail-safe; browser never holds ops power; directory HoR / edge projection; destructive steps = durable gated jobs. Full text: **`DESIGN_RULES.md`** Parts C–D.

**Trust rule (settled):**

| Actor | May |
|-------|-----|
| **Fleet admin** (`fleet` / `fleet_*` on gatekeeper) | Onboard, decommission, move/job control, catalog edit, reconcile, DID assign, manage fleet users (by ability) |
| **Instance / tenant admin** (Sanctum on `:44300`) | Node panels only; optional “Enter Fleet” / deep-link if they also hold fleet credentials — **no** catalog mutate via node API |

**Ability sketch (gatekeeper users — no IdP required):**

| Ability | Example actions |
|---------|-----------------|
| `fleet_read` | Instances / tenants / jobs lists; health / preflight views |
| `fleet_instances` | Register (onboard catalog), decommission, metadata, maintenance / drain |
| `fleet_moves` | Move wizard; job cancel / retry / rollback |
| `fleet_edge` | DID assign; emergency repoint; S3↔SBC reconcile |
| `fleet_admin` | Fleet user manage + all of the above |

Mac CLI (`onboard-fleet-instance.sh`, `register-instance.sh`, `unregister-instance.sh`) remains **break-glass / lab**; product path is gatekeeper API + SPA.

| # | Task | Repo / owner | Notes |
|---|------|----------------|-------|
| **S10.1** | **Gatekeeper abilities** | gatekeeper + pbx3spa | **Done (2026-07-14):** Persist `abilities` on fleet users; login/`/me` return them; route checks (`fleet_read` / `fleet_instances` / `fleet_moves` / `fleet_admin`); SPA stores abilities, requires `fleet_read`, hides Move without `fleet_moves`. Break-glass = `fleet_admin`. |
| **S10.2** | **Instance lifecycle (catalog)** | gatekeeper + pbx3spa | **Done (`s102`→`main` 2026-07-14):** Register (+ `verify_up`), soft decommission, PATCH metadata/status; SPA Instances panel; `updated_by`. S10.2b IAM/.env later. |
| **S10.3** | **Move job control** | gatekeeper + pbx3spa | **Done (`s103`→`main` 2026-07-14):** abort / retry / rollback + `created_by` / `last_action_by`; SPA job actions. |
| **S10.4** | **Catalog integrity** | gatekeeper + pbx3sbc-admin + pbx3spa | **Done (`s104`):** reconcile + apply catalog→SBC for `setid_mismatch`. SPA copy: Instances = catalog only; Project ≠ undo. See gatekeeper README § Reconcile vs project. DID → **S10.5**. |
| **S10.5** | **Edge / DID actions** | gatekeeper + pbx3sbc-admin + pbx3spa | **Done (`s105`→`main` 2026-07-15):** DID path + residue — `provision-edge` / `provision-node`; SPA Provision edge + Register on SBC; `sbc_backend_uri`; Rule 13. |
| **S10.6** | **Fleet user manage** | gatekeeper + pbx3spa | **Done (2026-07-15):** Create/disable/enable; assign `fleet_*`; revoke sessions; SPA **Users** panel. Guards: no self-disable, cannot remove last active `fleet_admin`. |
| **S10.7** | **Orchestrated onboard / rebuild (optional)** | control-plane + SPA | **Parked (2026-07-15):** defer until cloud/IaaS vs S3-compatible posture is settled (Rule 9). **Interim equivalent:** agent-assisted Path (**Mode 4**) — document for operators in **`USER_GUIDES_MKDOCS_CONTENT_MAP.md`** row **28b**; implementer source **`SELF_SERVICE_REBUILD_DESIGN.md`** § Mode 4 + **`REBUILD_INSTANCE_RUNBOOK.md`** kickoff. Mac scripts remain. |
| **S10.8** | **Fleet entry polish (final)** | pbx3spa (+ gatekeeper auth UX) | **Done (2026-07-15):** Login **chooser** (Manage instance vs Fleet console); `/fleet` without Sanctum; Exit → instance if Sanctum else `/login`; Enter Fleet secondary; TokenGate kinship; Link setid demoted to Advanced. |

**v1 panel wish-list (shipped before expanding S10.7):** onboard (catalog register), decommission, move + job control, catalog edit/maintenance, reconcile/drift, DID assign, fleet user manage; **entry chooser = final polish (S10.8)**. **S10.7 parked** pending cloud-adapter discussion.

**Explicitly not fleet-admin (stay instance/tenant):** extension/trunk/IVR CRUD, local users, day-to-day Certificates LE UI, call-recording listen, Shorewall. Fleet may **trigger** post-move cert sync as a **job step**; cert panel remains node-local.

**Out of scope S10 v1:** Cookies/SSO IdP (`FLEET_AUTH_COOKIE_SSO.md`); Terraform fleet; baking gatekeeper tokens into SPA builds; co-hosting superadmin inside `pbx3sbc-admin`.

**Exit criteria:**

- [ ] Instance/tenant Sanctum admin **cannot** call register/decommission/move mutate APIs.
- [ ] Fleet admin with `fleet_instances` can register + decommission a lab node from Fleet mode without Mac registrar scripts.
- [ ] `fleet_moves` can complete move job control (retry/rollback) from Jobs UI.
- [ ] Abilities enforced on gatekeeper; SPA hides actions the session lacks.
- [ ] Audit log (or job trail) records who onboarded / decommissioned / moved.

**Dependencies:** S8.10 Fleet mode + gatekeeper login (done); control host catalog IAM (`CONTROL_HOST.md`). **S10.5** benefits from DID schema draft. **S10.7** shares engine with **S8.9**. Parallel-friendly with **S7** / egress availability once S10.1 lands.

**Related:** **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §2.5–2.6, §4, §13 · **`DESIGN_RULES.md` Rule 13** (standalone vs fleet authorship) · **`INSTANCE_ONBOARDING.md`** · **`FLEET_AUTH_COOKIE_SSO.md`** (abilities in-house) · **`SELF_SERVICE_REBUILD_DESIGN.md`** (S10.7 overlap).

---

### Explicitly deferred (post–S3 v1)

| Item | Why wait |
|------|----------|
| Supabase / RDS / Phase D central auth | Separate product decision |
| `last_seen_at` fleet badges | Monitoring track, not storage |
| `share/phone-images` + CloudFront | No telephony dependency |
| Tenant-scoped backup zip (`tenants/…/backups/`) | Instance backup covers DR v1 |
| EventBridge, Inventory, replication | Enterprise ops maturity |

---

### Suggested build order

```text
  S5 backups (done)  →  S6 onboard (done)
         │
         ├──→  S8.1–S8.4  fleet checklist + IAM/`.env` hardening     ← priority #1
         │
         ├──→  R1  recordings management (local API + SPA)           ← priority #2
         │
         ├──→  S7  recordings S3 offload (mirror S5; IAM w/ S8.3)   ← priority #3
         │
         └──→  S8.5–S8.6  tenant migration runbook + export/import  ← after S8.1–4 (+ R1/S7 as needed)
         │
         └──→  S8.9  self-service rebuild (AMI + orchestrator + SPA)  ← after S8.5–6 or parallel
         │
         └──→  S10  fleet admin actions (abilities + panel lifecycle)   ← after S8.10 auth; see § Phase S10

  pbx3cagi Phase 0 harness: built on main; golden sign-off; Phase 1.3+ refactor deferred
         │
         └──→  W1  WebRTC edge normalization (WSS→SIP on SBC)            ← after UDP edge + S8.10 path
```

**Next session pick:** product priority (**S7** / egress / Fleet login UI) or start **S10.1** (gatekeeper abilities) toward panel onboard/decommission. S8.1–S8.10 scaffold + fleet login are on **`main`**.

---

## ToDo backlog (deferred — not in v0 scope)

Use this as the **long-tail** queue. **Active S3 work** is tracked in **§ S3 program closeout** above. **Not** blocking instance picker.

### Backup retention (agreed option C — `DESIGN_RULES.md`)

**Policy:** **9** local FIFO (daily cron + on-demand share one pool) · **30 days** on S3 (lifecycle; archives survive local eviction).

- [x] **Local prune:** after backup create (SPA or `pbx3:backup-run`), keep newest 9 `pbx3bak.*.zip` — `LocalBackupRetention`; env `PBX3_BACKUP_LOCAL_MAX_COUNT=9`
- [x] **Daily cron** — `pbx3:backup-run --trigger=scheduled`; `pbx3api/scripts/cron.d/pbx3-backup.example` + Laravel schedule 02:00
- [x] **S3 lifecycle (ops):** `tools/apply-backup-lifecycle-rule.sh` — tag filter `class=backup`, 30 days; **`OPS_S3_RUNBOOK.md`**
- [x] **Do not** delete S3 when local FIFO evicts (option C — prune is local-only)
- [ ] **Later:** SPA/API “restore from archive” when zip exists on S3 only (presigned download)

**Phase 4 v0 (done):** upload after create. **Option C retention (done):** local FIFO + cron + ops lifecycle script (S3 expiry is AWS-side, not PHP delete).

### S3 & ops infrastructure

- [ ] Terraform/ops: S3 bucket per org — **manual steps:** **`OPS_S3_RUNBOOK.md`** (encryption SSE-S3, block public access, catalog prefix policy)
- [ ] S3 **Lifecycle** rules driven by `policy.json` (`maxage_days`, `glacier_after_days`) — **required for 30-day S3 retention**
- [ ] S3 **object tags**: `org`, `instance_id`, `tenant`, `class=backup|recording`
- [ ] S3 **EventBridge** on `backup.zip` `Complete` → SNS/email
- [ ] `ops/catalog-publish.log.jsonl` — audit who updated catalog
- [ ] Cross-region replication (DR)
- [ ] S3 Inventory + Athena (compliance/billing)

### Media & share

- [ ] `share/phone-images` + **CloudFront** OAC
- [ ] Phone image `manifest.json` automation (hash on publish)
- [ ] Recordings offload: node staging → async PUT `tenants/…/media/…`
- [ ] S3 object metadata on recordings (`tenant`, `call_id`, `duration`)
- [ ] Monthly `recordings/manifest-{yyyy}-{mm}.jsonl` (bulk search)
- [ ] Per-tenant KMS keys

### Fleet & monitoring

- [x] Scheduled job: probe each `api_base_url` → update `last_seen_at` in catalog (`bin/probe-fleet-instances.php` + systemd timer)
- [x] SPA fleet badges (warning/degraded) from `last_seen_at` (+ Gatekeeper `health` overlay / RTT)
- [ ] Optional `instances/{ksuid}/tls/{backup_stamp}.json` snapshot (cert SAN history)
- [x] **Ops failure notification (email v1)** — subscriptions + transition alerts on Gatekeeper; see **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** (SMTP `Mailer`; move-job / misconfig-REGISTER later)

### Product & auth

- [ ] **Before Phase D:** Evaluate **Supabase vs RDS** (vs DynamoDB on AWS) for **central identity + catalog ACL** — keep **S3 for bulk** either way; decide whether catalog stays JSON or migrates to SQL only when per-user instance lists are required
- [ ] Phase D — central auth + filter catalog by user/org (implementation after evaluation above)
- [ ] Tenant-scoped backup zip to `tenants/…/backups/`
- [ ] Tenant move orchestration (directory + LE sync on nodes)
- [ ] `tenants/{shortuid}/exports/` GDPR export packages
- [ ] Multiple directory API read replicas (only if static URL insufficient)

### SPA hosting (agreed)

- [x] **Decision:** production **pbx3spa** on **GitHub Pages**; instances **API-only** (`DESIGN_RULES.md` § Central SPA hosting)
- [ ] **GitHub Actions** — build `dist/` and deploy to Pages (staging + prod catalog URL in CI)
- [ ] **Custom domain** + catalog/API CORS for Pages origin (`OPS_S3_RUNBOOK.md` § 9)

### SPA polish (post picker)

- [x] **Backup list display** — ISO 8601 UTC + `backup_stamp` (S3 archive id); `pbx3bak.{epoch}.zip` as local file (`DESIGN_RULES.md` § time/display)
- [ ] “Index as of {updated_at}” banner when catalog stale
- [ ] Empty list vs fetch error vs ACL filtered — distinct UX
- [ ] Recording lists: ISO 8601 UTC display; epoch for search APIs (when S3 offload ships)

---

## Repo map

| Repo | Phase 1–2 | Phase 3–5 |
|------|-----------|-----------|
| **pbx3** (`pbx3-directory/`) | Schemas, docs, validate script, registrar | Install hook, backup manifest writer |
| **pbx3api** | — | Optional: backup-complete → S3 upload trigger |
| **pbx3spa** | Picker, Rule 3 fallbacks, env URL | Chip, maintenance confirm, deep link |

---

## Read order

1. `IMPLEMENTATION_PLAN.md` (this file)  
2. `DESIGN_RULES.md`  
3. `S3_LAYOUT_PROPOSAL.md`  
4. `schema/*.v0.json`  
5. `PLANNING_HANDOFF.md` (historical context + test node)

---

## Test node reference

| Field | Value |
|-------|--------|
| FQDN | `08jzwn.pbx3.com` |
| API | `https://08jzwn.pbx3.com:44300/api` |
| Tenants | `f34ck1.pbx3.com`, `5489nv.pbx3.com` |
| Package | `pbx3 0.0.3-10` |

Refresh `globals.id` from node: `sqlite3 /opt/pbx3/db/sqlite.db "SELECT id FROM globals;"`
