# Database: pbx3 schema vs pbx3api expectations

**Purpose:** Compare pbx3 SQLite schema (instance + tenant + Laravel tables) with what pbx3api (Laravel API) expects. No action required where the API already tolerates or documents the variance.

---

## 1. Laravel / auth tables (instance DB)

**Source (pbx3):** `sqlite_create_laravel.sql`  
**Source (API):** `database/migrations/` (users, cache, jobs, personal_access_tokens, replace_user_role_with_abilities)

| Table | Variance | Notes |
|-------|----------|--------|
| **users** | None (pbx3 is superset) | pbx3 has `cluster`, `endpoint`, `role` in addition to API columns. API User model fillable: name, email, password, abilities, endpoint. pbx3 has all of these; `role` is deprecated, kept for legacy. |
| **password_reset_tokens** | None | Match. |
| **sessions** | None | pbx3 uses varchar for payload; API migration uses longText. SQLite treats both as TEXT. |
| **cache** / **cache_locks** | None | Match. |
| **jobs** / **job_batches** / **failed_jobs** | None | Match (type differences are SQLite-compatible). |
| **personal_access_tokens** | None | Match. |

**Conclusion:** Laravel tables are aligned. pbx3 schema is a superset for `users`; no missing columns for the API.

---

## 2. Instance tables (globals, tt_help_core)

**Source (pbx3):** `sqlite_create_instance.sql`  
**API:** `Sysglobal` model → table `globals`, primary key `pkey`.

| Item | Variance | Notes |
|------|----------|--------|
| **globals column names** | Case | Instance schema uses **lowercase** (e.g. `fqdn`, `bindaddr`). Legacy schema uses UPPERCASE. API Sysglobal guards many names in UPPERCASE; SQLite is case-insensitive for column access, so both work. |
| **globals columns** | API guards non-existent columns | Sysglobal `$guarded` lists columns (e.g. ASTDLIM, ATTEMPTRESTART, CDR) that are **not** in instance `globals`. They may exist in legacy or elsewhere. No schema change required; guarded only affects mass assignment. |
| **shortuid** | Missing in instance globals | Instance `globals` has no `shortuid` column. Tenant tables and legacy have it. Not used by API for globals. |
| **tt_help_core** | Not used by API migrations | API has no migration for this; pbx3 owns it. No conflict. |

**Conclusion:** No blocking variance. API works with instance globals; case and extra guarded names are safe.

---

## 3. Tenant tables (cluster, ipphone, etc.)

**Source (pbx3):** `sqlite_create_tenant.sql`  
**API:** Models Tenant (cluster), Extension (ipphone), and others.

| Table / model | Variance | Notes |
|---------------|----------|--------|
| **cluster** (Tenant) | Primary key | Schema: `id` PRIMARY KEY, `pkey` NOT NULL (no UNIQUE). API uses `primaryKey = 'pkey'`. If `pkey` is not unique, find-by-pkey could be ambiguous. In practice tenants use unique pkeys. |
| **ipphone** (Extension) | **provision**, **provisionwith**, **sndcreds**, **last_provisioned_at**, **first_provisioned_at** | Tenant schema includes them for **phone provision** (Phase A). Older DBs: **`apply-sqlite-add-provision-columns.sh`** (postinst). |
| **IPphoneCOSopen** / **IPphoneCOSclosed** | pbx3 uses `ipphone_pkey` / `cos_pkey` | Schema and API both use these names. No variance. |
| Other tenant tables (agent, appl, cos, route, queue, etc.) | Not fully compared | API models reference same table names; column names in schema are lowercase. Any mismatch would surface at runtime. |

**Conclusion:** Provision columns on **ipphone** are product HoR for Phase A (not dead). SPA/API may still need to expose **Reset Once** / Last provisioned (Phase B).

---

## 4. Summary

- **Laravel / auth:** No variances that affect the API; pbx3 Laravel schema matches or is a superset.
- **Instance globals:** No blocking variances; case and guarded columns are acceptable.
- **Tenant ipphone:** `provision` / `provisionwith` / `sndcreds` / `last_provisioned_at` / `first_provisioned_at` are on the tenant schema (apply script for upgrades).

If you add new API endpoints or models that depend on columns not present in the pbx3 schema (instance or tenant), add those columns to the corresponding pbx3 SQL files and document here.
