# Instance directory — overview (v0 stub)

**Mental model:** EC2 fleet console — low-traffic admin signpost; each node manages its own security. **v0:** one JSON file, fetch on login. See **`DESIGN_RULES.md`**.

## Problem

PBX3 is a **federation of instances**. Operators should not type `https://host:44300/api` at login. They should pick an **instance** from a list scoped to their organisation/service.

## Solution shape

1. **Directory** — one rarely updated **`instance-index.json`** at one HTTPS URL (any S3-compatible bucket; CDN optional).
2. **Central auth** — later; v0 uses per-node Sanctum after pick.
3. **pbx3spa** — hosted **once** on **GitHub Pages** (production); on login, `GET` directory → picker → set `baseUrl` from `api_base_url` (break-glass if fetch fails). **Not** installed on each PBX instance.

```text
  Central SPA                    Directory (S3/API)
       |                                |
       |  list instances (filtered)     |
       |------------------------------->|
       |<-------------------------------|
       |                                |
       |  POST .../auth/login           |
       |------------------------------->|  (central — TBD)
       |                                |
       |  API calls                     |
       |------------------------------->|  PBX instance :44300
```

## Instance record (v0)

See **`../schema/instance-record.v0.json`** and **`../schema/instance-index.json`** (S3: `catalog/instance-index.json`).

Required fields for SPA v0:

- `id` — stable instance identifier
- `fqdn` — public hostname
- `api_base_url` — full API prefix including `/api`
- `label` — UI display string

## Open questions (to resolve before build)

| Topic | Options |
|--------|---------|
| **Storage** | S3 only vs S3 + caching API vs DB |
| **Who writes records** | Provisioner on install, central registrar, manual |
| **ACL** | Directory embeds `allowed_orgs[]` vs auth service returns allowed ids |
| **Health** | Inline `status` vs separate monitoring pipeline |
| **Sync with node** | How `globals.id` / `globals.fqdn` register on first boot |

## Relationship to per-node TLS

Directory stores **`api_base_url`** and **`fqdn`**; **certificate issuance** remains on the node (pbx3 LE scripts, `tls-active.json`). Central UI may **display** cert expiry from instance API (`GET /certificates/letsencrypt`) after connect — not from directory alone.

## Next steps (LE merged 2026-05-17)

See **`PLANNING_HANDOFF.md`** for phased checklist (A–E).

1. Agree v0 schema with test instance **`08jzwn.pbx3.com`** (refresh `globals.id` on node).
2. Publish dev index (S3 or static URL).
3. SPA: instance picker + `VITE_INSTANCE_DIRECTORY_URL` for dev.
4. Central auth design doc (separate; do not block picker on full auth).
