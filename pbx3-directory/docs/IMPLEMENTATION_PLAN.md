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

- [ ] After existing backup create: write `manifest.json` + upload `backup.zip` to `instances/{ksuid}/backups/{stamp}/`
- [ ] Populate manifest: `pbx3_version`, `node_fqdn`, `trigger`, `sha256`, `contents_summary`
- [ ] Update `instances/{ksuid}/meta.json` → `backup_latest_stamp`
- [ ] Write `backups/policy.json` on first upload (defaults from org template)
- [ ] **Async upload** — local `/opt/pbx3/bkup` remains source for UI until PUT succeeds

**Exit:** One instance backup visible in S3 with valid manifest; restore still from local UI first.

---

### Phase 5 — Install registration (pbx3)

- [ ] `postinst` or `installer.sh` optional hook calls registrar (or prints exact command) when `globals.id` + org config present
- [ ] Document env vars: `PBX3_ORG_BUCKET`, `PBX3_ORG_ID`

**Exit:** New install can appear in catalog without hand-editing JSON.

---

## ToDo backlog (deferred — not in v0 scope)

Use this as the product/engineering queue after Phase 2–4. **Not** blocking instance picker.

### S3 & ops infrastructure

- [ ] Terraform/ops: S3 bucket per org — **manual steps:** **`OPS_S3_RUNBOOK.md`** (encryption SSE-S3, block public access, catalog prefix policy)
- [ ] S3 **Lifecycle** rules driven by `policy.json` (`maxage_days`, `glacier_after_days`)
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

### SPA polish (post picker)

- [ ] “Index as of {updated_at}” banner when catalog stale
- [ ] Empty list vs fetch error vs ACL filtered — distinct UX

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
