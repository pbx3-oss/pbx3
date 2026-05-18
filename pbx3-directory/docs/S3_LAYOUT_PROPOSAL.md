# S3 bucket layout — initial proposal (draft)

**Status:** Draft for review (branch **`directory`**). Not implemented.  
**Related:** `DESIGN_RULES.md` (directory signpost is **one small JSON**; this doc is **bulk object storage** for shared assets, recordings, backups).

**Rule 1 still applies:** PBX nodes make and take calls without S3. Upload/download to this bucket is **async ops/media** — never in the SIP/RTP path.

---

## Purpose split (do not conflate)

| Concern | What it is | v0 size |
|---------|------------|---------|
| **Directory / catalog** | `instance-index.json` — picker signpost (`api_base_url`, `fqdn`, `id`) | One small file, rare writes |
| **Share** | Phone images, other fleet-wide read-mostly assets | Large, CDN-friendly |
| **Tenants** | Per-tenant recordings + tenant-scoped backup payloads | Grows with CDR/media |
| **Instances** | Per-node (instance) backup snapshots | Grows with backup policy |

The central SPA loads the **catalog** on login (public HTTPS `GET` on `catalog/*` only — no AWS keys in the browser). Panels on a connected node may **read/write** tenant/instance prefixes via **instance API + IAM** (later) — not required for v0 picker.

**Ops how-to:** **`OPS_S3_RUNBOOK.md`** — bucket creation, prefix-scoped public policy, CORS, node IAM, Laravel Flysystem.

---

## Proposed tree (as suggested, normalized)

Bucket name: **`{org_shortuid}`** (MSP / customer org — **not** tenant `cluster.shortuid` unless one org = one tenant).

```text
s3://{org_shortuid}/
  catalog/
    instance-index.json          ← directory v0 (fleet signpost)

  share/
    PhoneImages/
      {manufacturer}/
        {model}/
          image.jpeg

  tenants/
    {tenant_shortuid}/             ← cluster.shortuid (e.g. f34ck1)
      meta.json                    ← optional: instance_id, cname, tenant fqdn
      recordings/
        info.json                  ← { "maxage": "30" } (days) — policy hint
        recordings.db              ← index (if used)
        media/
          {recording_id}.wav
          {recording_id}.txt       ← transcription
      backups/
        info.json
        {epochdate}/               ← UTC epoch or ISO date folder
          pbx3db                   ← sqlite unload / dump
          greetings/
          ldap/
          moh/
          voicemail/
          backup.zip

  instances/
    {instance_ksuid}/              ← globals.id (KSUID) — stable if fqdn changes
      meta.json                    ← fqdn, label, api_base_url (mirror catalog row)
      backups/
        info.json
        {epochdate}/
          pbx3db
          asteriskdb
          greetings/
          ldap/
          moh/
          voicemail/
          backup.zip
```

**Change from draft:** Under `instances/`, use **`{instance_ksuid}`** (not a second `shortuid` sibling next to `fqdn`). FQDN belongs in `meta.json` and in `catalog/instance-index.json`.

---

## Identifier mapping (PBX3 sqlite)

| S3 path segment | Source on node |
|-----------------|----------------|
| `{org_shortuid}` | Product/MSP bucket boundary (not in sqlite today — org provisioning) |
| `instances/{instance_ksuid}` | `globals.id` |
| Instance `meta.json` → `fqdn` | `globals.fqdn` |
| `tenants/{tenant_shortuid}` | `cluster.shortuid` (or `cluster.pkey` if same) |
| `meta.json` → `cname` | `cluster.fqdn` (tenant hostname) |
| `meta.json` → `instance_id` | `globals.id` (which node hosts tenant now) |

When a **tenant moves** to another node: update tenant `meta.json` + directory/catalog; **recordings** stay under `tenants/{tenant_shortuid}/`; instance backups remain under old/new `instances/{ksuid}/` respectively.

---

## `info.json` and retention

```json
{ "maxage": "30" }
```

Treat as **policy intent** (days) for lifecycle jobs. Prefer **S3 Lifecycle rules** (expire prefix after N days) driven by the same value ops sets in `info.json`. Document whether `maxage` is days, not minutes.

---

## Open decisions

| # | Question | Recommendation |
|---|----------|----------------|
| 1 | One bucket per org vs single fleet bucket | One bucket per **org** keeps ACL simple; single bucket + prefix if small fleet |
| 2 | `catalog/` vs bucket root | `catalog/instance-index.json` — clear separation from bulk data |
| 3 | Tenant backup vs instance backup | **Both:** tenant = portable tenant payload; instance = full node disaster recovery |
| 4 | `recordings.db` in S3 | OK if sync’d copy; **authoritative** for calls remains on node until archived |
| 5 | PhoneImages public read | `share/` + CloudFront optional; no impact on telephony |
| 6 | Versioning | S3 versioning on `backups/` only (see legacy note in `spin.sh`) — optional v1 |

---

## Gotchas

1. **Wrong `shortuid` level** — Tenant shortuid (`f34ck1`) ≠ org bucket name ≠ instance KSUID. Use KSUID under `instances/`.
2. **Duplicate paths** — Tenant backups and instance backups serve different restore stories; document which UI action writes where.
3. **Stale `instance_id` in tenant meta** — After tenant move, S3 path unchanged but `meta.json` must update.
4. **Directory vs `instances/.../meta.json`** — Same facts (`fqdn`, `api_base_url`) may exist twice; **catalog** is for SPA login; `meta.json` is for ops/automation at backup time. Prefer generating both from one registrar script.
5. **Calls without S3** — Node must run if bucket IAM denies; only backup/recordings features degrade.

---

## v0 minimal slice (directory work only)

For **Phase B** directory planning, implement only:

```text
s3://{org_shortuid}/catalog/instance-index.json
```

Everything else in this doc is **parallel track** (media, backup to S3) — do not block instance picker.

---

## Improved layout (v1) — visual reference

**Bucket:** `s3://{org_shortuid}-pbx3/` (one org / MSP customer; not tenant shortuid)

**Legend:** `()` = variable · `[ ]` = optional · `→` = written by registrar on provision/move

```text
s3://{org_shortuid}-pbx3/
│
├── catalog/                                    ← SPA login only (tiny, rare updates)
│   └── instance-index.json                     ← fleet signpost (all instances in org)
│
├── share/                                      ← public-read via CloudFront OAC (optional)
│   └── phone-images/
│       └── {manufacturer}/
│           └── {model}/
│               ├── image.jpg
│               └── manifest.json               ← sha256, updated_at
│
├── instances/
│   └── {instance_ksuid}/                       ← globals.id (stable)
│       ├── meta.json                           ← fqdn, api_base_url, label, status
│       └── backups/
│           ├── policy.json                     ← { "maxage_days": 30, "glacier_after_days": 7 }
│           └── {backup_stamp}/                 ← backup_stamp = 20260517T120000Z (UTC, sortable)
│               ├── manifest.json               ← schema_version, artifacts[], sha256
│               └── backup.zip                  ← single restore artifact (UI + DR)
│
└── tenants/
    └── {tenant_shortuid}/                      ← cluster.shortuid (stable across moves)
        ├── meta.json                           ← REQUIRED: instance_id, cname, fqdn, status
        ├── recordings/
        │   ├── policy.json                     ← { "maxage_days": 30 }
        │   ├── recordings.db                   ← snapshot upload only (not live over S3)
        │   └── media/
        │       └── {yyyy}/{mm}/{dd}/
        │           ├── {call_id}.wav
        │           └── {call_id}.txt           ← transcription sidecar (same call_id)
        └── backups/
            ├── policy.json
            └── {backup_stamp}/
                ├── manifest.json               ← scope: "tenant", lists contents
                └── backup.zip                  ← portable tenant payload (move/restore)
```

### Side-by-side: original sketch → v1

| Original | Improved v1 |
|----------|-------------|
| `Instances/{shortuid}` + `fqdn` siblings | `instances/{instance_ksuid}/` only; fqdn in `meta.json` |
| `instance-ksuid`, `cname` as loose files | `tenants/.../meta.json` with all tenant fields |
| `info.json` `{ "maxage": "30" }` | `policy.json` with `maxage_days` (integer) + S3 Lifecycle |
| `{epochdate}/` + zip + exploded folders | `{backup_stamp}/` + **manifest.json** + **backup.zip** only |
| `media/recording.wav` flat | `media/{yyyy}/{mm}/{dd}/{call_id}.wav` |
| Directory mixed into tree | **`catalog/instance-index.json`** isolated at top |

### Example paths (test node)

Org bucket `acme-pbx3`, instance KSUID `2abc…`, tenant `f34ck1`:

```text
s3://acme-pbx3/catalog/instance-index.json

s3://acme-pbx3/instances/2abc…/meta.json
s3://acme-pbx3/instances/2abc…/backups/20260517T153045Z/manifest.json
s3://acme-pbx3/instances/2abc…/backups/20260517T153045Z/backup.zip

s3://acme-pbx3/tenants/f34ck1/meta.json
s3://acme-pbx3/tenants/f34ck1/recordings/media/2026/05/17/call-01K…/.wav
s3://acme-pbx3/tenants/f34ck1/backups/20260517T153045Z/backup.zip
```

### `instance-index.json` (catalog)

Schema: `schema/instance-record.v0.json` · example: `schema/instance-index.v0.json`

```json
{
  "version": 1,
  "updated_at": "2026-05-17T15:30:00Z",
  "instances": [
    {
      "id": "2abc…",
      "fqdn": "08jzwn.pbx3.com",
      "api_base_url": "https://08jzwn.pbx3.com:44300/api",
      "label": "08jzwn",
      "status": "active",
      "environment": "production",
      "region": "us-east-1",
      "notes": "Acme primary",
      "package_version": "pbx3 0.0.3-10",
      "last_seen_at": "2026-05-17T15:00:00Z"
    }
  ]
}
```

### `instances/{ksuid}/meta.json`

Schema: `schema/instance-meta.v0.json`

### `tenants/{shortuid}/meta.json` (required)

Schema: `schema/tenant-meta.v0.json` — must include `instance_id`, `cname`, `moved_at` after tenant move.

### `policy.json`

Schema: `schema/retention-policy.v0.json`

```json
{
  "maxage_days": 30,
  "glacier_after_days": 7,
  "legal_hold": false
}
```

### `manifest.json` (per backup folder)

Schema: `schema/backup-manifest.v0.json`

```json
{
  "schema_version": 1,
  "created_at": "2026-05-17T15:30:45Z",
  "scope": "instance",
  "trigger": "manual",
  "instance_id": "2abc…",
  "tenant_shortuid": null,
  "node_fqdn": "08jzwn.pbx3.com",
  "pbx3_version": "pbx3 0.0.3-10",
  "contents_summary": { "tenant_count": 2, "sqlite_bytes": 5242880 },
  "artifacts": [
    { "name": "backup.zip", "sha256": "…", "bytes": 104857600 }
  ]
}
```

### Recordings object keys

`media/{yyyy}/{mm}/{dd}/{call_id}.wav` — `call_id` matches CDR / Asterisk uniqueid on node. Optional S3 metadata on PUT: `x-amz-meta-tenant`, `x-amz-meta-call-id`, `x-amz-meta-duration` (implementation in **IMPLEMENTATION_PLAN.md** ToDo).

### Data flow (ASCII)

```text
  [Operator SPA] ──GET──► catalog/instance-index.json
        │
        │ pick instance → Sanctum on node :44300 (unchanged)
        ▼
  [PBX node] ──async PUT──► instances/{ksuid}/backups/…
              ──async PUT──► tenants/{shortuid}/recordings/media/…
              (calls do NOT wait on S3)
```

---

## Changelog

| Date | Note |
|------|------|
| 2026-05 | Initial capture from operator layout sketch |
| 2026-05 | Added improved v1 layout (manifest, policy.json, partitioned media) |
| 2026-05 | High-value fields + schemas; see **IMPLEMENTATION_PLAN.md** |
| 2026-05 | **OPS_S3_RUNBOOK.md** — bucket, catalog policy, CORS, IAM |
