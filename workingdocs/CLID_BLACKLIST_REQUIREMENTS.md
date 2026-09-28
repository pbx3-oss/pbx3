# Tenant CLID blacklist — requirements (greenfield)

**Status:** **Phase 1 shipped** (schema + API + SPA + CAGI enforce). **Phase 1 is sufficient** for product use (SPA admin CRUD). **Phase 2** (feature code → email request → admin approve) is an **optional upgrade only** — **parked**, not scheduled; revisit only if customers ask for desk-side “report caller” workflow.  
**Repos:** **pbx3** (schema) · **pbx3api** · **pbx3spa** · **pbx3cagi** (enforce).  
**Not** a previous-PBX port. previous PBX had a stub `clid_blacklist` table (`cluster`-scoped) that **never shipped in production use** — do **not** ETL-migrate it; greenfield only.

---

## 1. One-line purpose

Let a **tenant** block inbound calls from selected calling-line IDs (CLIDs), without making that block global across other tenants on the same instance, and without letting arbitrary desk phones mutate the list.

---

## 2. Why not “just a feature key”

Many competitors expose a star-code / feature key so **any** phone user can blacklist the last/current caller. That is easy and abusive (prank blocks, no audit, no tenant policy).

**PBX3 preference:** treat blacklist as a **policy object** — managed with **identity + privilege**, same class as inbound routing — not as an unauthenticated phone gesture.

---

## 3. Locks

| # | Lock |
|---|------|
| **B0** | **Tenant-scoped only.** Rows belong to one `cluster` / shortuid. Tenant A may block `+441234…`; tenant B may still accept it. Never instance-global. |
| **B1** | **Greenfield.** Ignore previous PBX `clid_blacklist` for migrate (dropped from ETL map). No heritage UI parity obligation. |
| **B2** | **Mutate requires auth.** v1: **SPA (Sanctum)** with tenant/admin ability for that cluster. No open “any extension” feature key in Phase 1. |
| **B3** | **Phase 2 (optional) — request only from phone.** If ever built: feature code **submits a block request** (not apply the block). Email to tenant `emailalert` (and/or scoped tenant admins). **SPA approval required** before a row appears in `clid_block`. Rate-limit per extension; withheld CLI = no-op. **Not required** for v1 completeness. |
| **B4** | **Enforce in the call path for that tenant** (inbound before ring/IVR). **Fail open** if DB/lookup broken or CLID empty/short. |
| **B5** | **Audit.** API sets `z_updater` to Sanctum user email on create/update. Phase 2 requests stamp requesting extension + approver. |
| **B6** | **Not host firewall.** Unrelated to UFW / Shorewall / `shorewall_*` IP lists. |

---

## 4. Phases

### Phase 1 — **shipped**

| Surface | Behaviour |
|---------|-----------|
| **Schema** | Tenant table `clid_block`: `pkey` = digits-only CLID, unique `(cluster, pkey)`; `action` = `hangup`; `active` YES/NO |
| **SPA** | **Inbound → Blocked caller IDs** — list / create / edit / delete (tenant-scoped) |
| **API** | `GET/POST/PUT/DELETE /api/clidblocks` under cluster scope |
| **CAGI** | `Ingress()` — after CLIP normalize, before ring: match active row → `Hangup` |
| **Normalization** | **Digits-only exact match** (6–32 digits). Admin enters the same digit form as CDR (e.g. `441924918076` or `01924918076`). Non-digits stripped on save. |
| **Commit** | **Not required** — live SQLite read on each inbound call |

**Out of Phase 1:** feature codes, email, request queue, anonymous CLI row type.

### Phase 2 — **optional upgrade (parked)**

| Surface | Behaviour |
|---------|-----------|
| **Feature code** | Desk user reports last/current caller → creates **`clid_block_request`** (pending), sends email |
| **Email** | To tenant `cluster.emailalert` and/or portable tenant admins — link to SPA request inbox |
| **SPA** | Approve → insert `clid_block`; Deny → audit only |
| **CAGI** | Unchanged until approve (no direct block from phone) |

Sketch table **`clid_block_request`**: `cluster`, normalized `clid`, `requested_by_ext`, timestamps, `status` (pending/approved/denied), reviewer.

---

## 5. Open at implement time (Phase 2+)

- National vs E.164 aliasing (e.g. `0…` ↔ `44…`) beyond exact digits match.
- Explicit “block withheld/unknown” row type.
- Actions beyond Hangup (busy, greeting, voicemail).

---

## 6. Non-goals

- Porting unfinished previous PBX panel behaviour.
- Letting every phone user blacklist without admin approval.
- Confusing with Fail2ban / UFW IP bans or SBC door-knock.

---

## 7. References

- Product TODO: **`pbx3/workingdocs/TODO.md`**
- CAGI scenario: **`pbx3cagi/.../tests/scenarios/clid-block-reject`**
- Migration SQL: **`pbx3/pbx3-1/opt/pbx3/db/db_sql/sqlite_add_clid_block.sql`**
