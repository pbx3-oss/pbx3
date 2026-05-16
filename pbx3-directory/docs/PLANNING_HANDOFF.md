# Instance directory — planning handoff (session end 2026-05-17)

**AI: start here** for Model B / central admin / instance directory work.

**Product direction:** `pbx3spa/workingdocs/CENTRAL_ADMIN_DIRECTION.md`  
**SPA handoff (broader):** `pbx3spa/workingdocs/SESSION_HANDOFF.md`  
**Per-instance TLS (done):** `pbx3/workingdocs/TLS_AND_CERTIFICATES.md`

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
| `schema/instance-index.v0.json` | Example index (includes test node `08jzwn`) |
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

## 4. Planning phases (suggested order)

### Phase A — Agree v0 contract (no code)

- [ ] Confirm **required fields** on `instance-record.v0.json` (enough for picker + `baseUrl`).
- [ ] Decide **storage**: S3 object only vs S3 + thin read API vs DB later.
- [ ] Decide **who writes** records: install hook, manual ops, central registrar, CI.
- [ ] Decide **ACL model**: directory row includes `org_id` vs auth service returns allowed `instance_id[]`.
- [ ] Map **registration**: how `globals.id` + `globals.fqdn` on first install become a directory row (idempotent).
- [ ] Document **tenant move** (future): directory updates `api_base_url` / FQDN hints; node runs LE sync (see `LETSENCRYPT_PER_TENANT_FQDN.md` §8).

**Deliverable:** `docs/V0_CONTRACT.md` (or update `OVERVIEW.md` § Open questions with decisions).

### Phase B — Dev directory feed

- [ ] Publish **dev index** (static file URL, or S3 bucket `pbx3-directory-dev`).
- [ ] Add second instance row when a second test node exists.
- [ ] Optional: script `tools/validate-index.sh` (ajv against schema).

**Deliverable:** URL the SPA can `GET` in dev (`VITE_INSTANCE_DIRECTORY_URL`).

### Phase C — SPA instance picker (minimal)

- [ ] After login (or before instance API login): fetch directory → list **label** + **fqdn**.
- [ ] On select: set `baseUrl` from `api_base_url`; persist in sessionStorage.
- [ ] Keep **advanced override** for engineering (see `DEV_ENVIRONMENT.md`).
- [ ] Top bar **Instance** chip shows directory **label** / **fqdn** (already have `globalsFqdn` from connected instance).

**Deliverable:** PR in **pbx3spa** only; still uses per-instance Sanctum until Phase D.

### Phase D — Auth (later)

- [ ] Central identity + “instances you may access” (may duplicate ACL filter).
- [ ] Preserve **`AUTH_PATTERNS.md`** contract: Bearer + **whoami** shape on instance API.

**Deliverable:** separate auth design doc; do not block Phase C on full central auth.

### Phase E — Ops / monitoring (later)

- [ ] Central monitoring reads directory, polls instance health or cert expiry via existing API.
- [ ] Tenant migration orchestration uses directory for source/target URLs.

---

## 5. Open questions (track decisions here)

| # | Question | Notes |
|---|----------|--------|
| 1 | **S3 layout** | Single `instance-index.json` vs sharded by org? Version field + `updated_at`? |
| 2 | **HTTPS for directory** | CloudFront + S3? Signed URLs? |
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

1. This file  
2. `CENTRAL_ADMIN_DIRECTION.md`  
3. `OVERVIEW.md`  
4. `schema/instance-record.v0.json` + `instance-index.v0.json`  
5. `AUTH_PATTERNS.md` (§4 federated)  
6. `pbx3spa/workingdocs/DEV_ENVIRONMENT.md` (API URL today)

**Branches:** **`main`** only (all three repos).
