# Instance directory — planning handoff (session end 2026-05-17)

**AI: start here** for Model B / central admin / instance directory work.

**Implementation plan (active):** **`IMPLEMENTATION_PLAN.md`** — phases 1–5 + ToDo backlog.  
**Design rules:** **`DESIGN_RULES.md`**  
**S3 layout:** **`S3_LAYOUT_PROPOSAL.md`**  
**Product direction:** `pbx3spa/workingdocs/CENTRAL_ADMIN_DIRECTION.md`  
**SPA handoff:** `pbx3spa/workingdocs/SESSION_HANDOFF.md`  
**Per-instance TLS (done):** `pbx3/workingdocs/TLS_AND_CERTIFICATES.md`

**Branch:** **`directory`** (all three repos).

---

## 1. What we finished this session (LE / TLS)

Merged to **`main`** in **pbx3**, **pbx3api**, **pbx3spa**. Remote **`certificates`** branches deleted.

### Test node (`08jzwn.pbx3.com`)

| Item | State |
|------|--------|
| **pbx3 package** | `0.0.3-9` |
| **pbx3api** | `main` @ `bd1c2d4` (incl. fast `tls-active.json` read) |
| **LE cert** | Multi-SAN: `08jzwn.pbx3.com`, `f34ck1.pbx3.com`, `5489nv.pbx3.com` |
| **Renew** | `certbot renew --dry-run` succeeded |
| **Panel** | Sync with tenant list works (after API + script fixes) |
| **Dev pattern** | Mac **pbx3spa** + `https://<fqdn>:44300/api` — **no SPA on node** |

### Operator flow (validated)

1. Create tenant → FQDN = `{shortuid}.{globals.domain}` (e.g. `5489nv.pbx3.com`).
2. DNS A record for tenant FQDN → node public IP.
3. **Certificates → Sync with tenant list** (not “Get certificate” if LE already exists).
4. Confirm `cat /opt/pbx3/etc/identity/tls-active.json` → `cert_sans` lists all names.
5. Login from local SPA with `https://<tenant-fqdn>:44300/api`.

### Key fixes shipped on `main`

| Area | Fix |
|------|-----|
| **pbx3** | `le_run_script` uses **bash**; `apply-active-cert.sh` portable SAN parse; postinst builds **idpwgen** on target host |
| **pbx3api** | Sync orders SANs with **le-domain** first; GET reads **tls-active.json** before heavy syshelper chain |
| **pbx3spa** | Tenant create sends **0/1** for integer flags (`lterm`, `play_*`); Certificates Sync + cert covers |

### `:44300` behaviour (do not confuse with directory work)

- Nginx serves **pbx3api** only (`/opt/pbx3api/public`).
- **`https://<fqdn>:44300/`** → Laravel welcome page (expected).
- **`https://<fqdn>:44300/api`** → API (Sanctum login, panels).
- Central SPA will **not** be deployed per node in Model B.

---

## 2. Why directory is next

**Agreed model:** **Model B** — one central **pbx3spa**; operators pick an **instance** from a **directory**, not a raw API URL field.

**LE on each node** is no longer blocking: instances expose a stable **`api_base_url`** and tenant FQDNs; directory stores **which instances exist** and **who may access them**.

---

## 3. Stub assets (v0)

| Path | Purpose |
|------|---------|
| `schema/instance-record.v0.json` | JSON Schema for one instance row |
| `schema/instance-index.json` | Example index (includes test node `08jzwn`; same S3 key) |
| `docs/OVERVIEW.md` | Architecture sketch + open questions |

**Example record (align with live test node when planning):**

```json
{
  "id": "<globals.id KSUID from node>",
  "fqdn": "08jzwn.pbx3.com",
  "api_base_url": "https://08jzwn.pbx3.com:44300/api",
  "label": "08jzwn",
  "status": "active",
  "org_id": "example-org"
}
```

Refresh **`id`** from `sqlite3 /opt/pbx3/db/sqlite.db "SELECT id FROM globals;"` on the node.

---

## 4. Planning phases

**Superseded by **`IMPLEMENTATION_PLAN.md`** (phases 1–5 + ToDo backlog).** Summary:

| Phase | Focus |
|-------|--------|
| **1** | Schemas + validate script (done in repo) |
| **2** | Dev catalog URL + SPA picker + Rule 3 fallbacks |
| **3** | Registrar scripts (catalog + meta.json) |
| **4** | S3 backup zip + manifest upload (async) |
| **5** | Install registration hook |

Deferred work (CDN, fleet health poll, central auth, recordings offload, etc.) → **IMPLEMENTATION_PLAN.md** § ToDo backlog.

---

## 5. Open questions (track decisions here)

| # | Question | Notes |
|---|----------|--------|
| 1 | **S3 layout** | **Directory v0:** `catalog/instance-index.json` per org bucket. **Bulk layout** (share, tenants, backups): see **`S3_LAYOUT_PROPOSAL.md`**. |
| 2 | **HTTPS for directory** | **Committed Phase 2:** `catalog/instance-index.json` on S3 or static HTTPS. **Not** Supabase/RDS until Phase D evaluation. |
| 3 | **Instance `id`** | Must match `globals.id` (KSUID) or separate directory UUID? |
| 4 | **Multi-tenant FQDN in directory** | Directory is **instance-level** only; tenant FQDNs stay on node DB |
| 5 | **Stale records** | `status: decommissioned` vs delete; who cleans up |
| 6 | **Break-glass** | Direct API URL for support — keep in dev login only? |
| 7 | **Repo split** | Keep stub in **pbx3** repo vs new `pbx3-directory` repo when code appears |

---

## 6. Out of scope for directory v0

- Replacing per-node **pbx3** / **pbx3api** install.
- Wildcard DNS or DNS-01 LE (still HTTP-01 per FQDN on node).
- Hosting **pbx3spa** on each PBX (`:44300`).
- Full **tenant move** automation (directory enables it later).

### LE follow-on still on node (not directory)

- **Firewall** `update-fqdn-inline` + Shorewall per tenant FQDN when `fqdninspect` ON (`TLS_IMPLEMENTATION_STEPS.md` Step 1.2–1.3).
- Optional: remove committed **`pbx3_*.deb`** binaries from **pbx3** git history on a hygiene pass.

---

## 7. Reference instance (test server)

Use this node as the **golden example** when validating schema and SPA picker.

| Field | Value (verify on box) |
|-------|------------------------|
| **FQDN** | `08jzwn.pbx3.com` |
| **API** | `https://08jzwn.pbx3.com:44300/api` |
| **Tenants** | e.g. `f34ck1.pbx3.com`, `5489nv.pbx3.com` |
| **Package** | `pbx3` 0.0.3-9 |
| **git pull** | `sudo -u www-data -H bash -c 'cd /opt/pbx3api && git pull origin main'` |

**Server git:** use **www-data** for `/opt/pbx3api` pulls (not `sudo git` — dubious ownership).

---

## 8. Read order for next session

1. **`IMPLEMENTATION_PLAN.md`**  
2. **`DESIGN_RULES.md`**  
3. **`S3_LAYOUT_PROPOSAL.md`** · **`OPS_S3_RUNBOOK.md`** (bucket setup)  
4. This file (historical context)  
5. `CENTRAL_ADMIN_DIRECTION.md` · `OVERVIEW.md`  
6. `schema/*.v0.json` · `AUTH_PATTERNS.md` · `DEV_ENVIRONMENT.md`

**Branches:** **`directory`** (all three repos).
