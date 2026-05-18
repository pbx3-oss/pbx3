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

The central SPA loads the **catalog** on login. Panels on a connected node may **read/write** tenant/instance prefixes via API (later) — not required for v0 picker.

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

## Changelog

| Date | Note |
|------|------|
| 2026-05 | Initial capture from operator layout sketch |
