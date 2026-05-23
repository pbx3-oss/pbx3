# Instance directory & S3 catalog — implementation plan

**Branch:** `directory` (pbx3, pbx3api, pbx3spa)  
**Read first:** `DESIGN_RULES.md` · **Layout:** `S3_LAYOUT_PROPOSAL.md` (improved v1) · **Schemas:** `../schema/`

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

**Rejected for Phase 2:** Supabase/Postgres/RDS/DynamoDB as the catalog source of truth (unnecessary for rare reads of a small fleet; avoids running a DB before central auth is defined).

---

## Goals

| Track | Goal | v0 deliverable |
|-------|------|----------------|
| **A — Directory** | Central SPA picks instance from catalog | `catalog/instance-index.json` + picker UI |
| **B — S3 contract** | Documented keys + JSON schemas for ops/S3 | Schemas + v1 tree in repo |
| **C — Registrar** | One writer updates catalog + meta files | Script (manual invoke → install hook later) |
| **D — S3 backup upload** | Node backups land under `instances/…/backups/` | Async PUT after existing `/opt/pbx3/bkup` |
| **E+** | Recordings, CDN, fleet health, central auth | **ToDo** (below) |

---

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
3. **Recordings:** at least one tenant on golden — finished call recording **async PUT** to `tenants/{shortuid}/recordings/media/{yyyy}/{mm}/{dd}/{call_id}.wav`; **playback** works from S3 when local file is gone (presigned or API proxy); lifecycle/tag `class=recording` aligned with `policy.json`.
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

### Phase S7 — Recordings offload v1 (~2–3 weeks)

**Principle (Rule 1):** Calls and recording capture work **without S3**. Upload is **async** after the wav exists on disk (mirror `InstanceBackupDirectoryUpload`).

**On-node today:** tenant `rec_final_dest`, `rec_age` / `recmaxage` (days), spool under `/opt/pbx3/media/recordings/…` and Asterisk monitor paths — see `sqlite_create_tenant.sql`.

| # | Task | Repo | Notes |
|---|------|------|--------|
| S7.1 | **`InstanceRecordingDirectoryUpload`** (or shared `OrgObjectUpload` base) | pbx3api | PUT `tenants/{shortuid}/recordings/media/{y}/{m}/{d}/{call_id}.wav`; optional `.txt` sidecar |
| S7.2 | **Trigger** — after recording finalized or nightly scan of age-eligible files | pbx3api / cron | Config: `PBX3_RECORDING_UPLOAD_ENABLED`, tenant allowlist for golden |
| S7.3 | **`tenants/…/recordings/policy.json`** on first upload (`maxage_days` from tenant `recmaxage` or default) | pbx3api | Schema `retention-policy.v0.json` |
| S7.4 | **S3 tag** `class=recording` + lifecycle rule (extend ops script or sibling `apply-recording-lifecycle-rule.sh`) | pbx3-directory/tools | Same pattern as backups; **do not** expire `meta.json` / catalog |
| S7.5 | **IAM** — node role `PutObject` on `tenants/{hosted-tenant}/recordings/*` for tenants on that instance | ops | Per-node policy like backups |
| S7.6 | **API playback** — `GET /recordings/{id}/play` returns presigned URL or streams via API when file only on S3 | pbx3api | CDR/search still uses **epoch** on node DB |
| S7.7 | **SPA** — recording list shows UTC; badge “archived” if S3-only | pbx3spa | ISO display per `DESIGN_RULES.md` |
| S7.8 | **Local retention unchanged** — `rec_age` still deletes from disk; S3 holds DR copy until lifecycle | design | Hybrid like backup option C |

**Defer past S7:** `recordings.db` snapshot to S3, monthly `manifest-{yyyy}-{mm}.jsonl`, bulk Athena search, tenant backup zip under `tenants/…/backups/`.

---

### Phase S8 — Ops polish (when S5–S7 code exists)

| # | Task |
|---|------|
| S8.1 | Document **non-AWS** endpoint env for Flysystem (`AWS_ENDPOINT`, path-style) in `OPS_S3_RUNBOOK.md` |
| S8.2 | Optional object tags `org`, `instance_id`, `tenant` on PUT (in addition to `class`) |
| S8.3 | `postinst` registrar hook (Phase 5) |
| S8.4 | Mark `S3_LAYOUT_PROPOSAL.md` **implemented** sections vs **planned** in header |

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
  S5 backups complete  →  S6.1 manual onboard (done)  →  S6.4 onboard script  →  S6.2 Pages
         │                         │                              │
         └─────────────────────────┴──────────────────────────────┴──→  S7 recordings  →  S8 polish
                           S3 v1 exit review
```

**Next session pick:** **S6.2** (GitHub Pages) or **S7** (recordings). S6.1 + S6.4 fleet onboard validated.

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

- [ ] Scheduled job: probe each `api_base_url` → update `last_seen_at` in catalog
- [ ] SPA fleet badges (warning/degraded) from `last_seen_at`
- [ ] Optional `instances/{ksuid}/tls/{backup_stamp}.json` snapshot (cert SAN history)

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
