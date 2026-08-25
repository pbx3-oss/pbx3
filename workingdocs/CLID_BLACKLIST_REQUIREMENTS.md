# Tenant CLID blacklist — requirements (greenfield)

**Status:** Direction locked **2026-08-24** (not implemented).  
**Repos when built:** **pbx3** (schema + GenAst/CAGI enforce) · **pbx3api** · **pbx3spa** · optional later feature-code path.  
**Not** a SARK port. SARK had a stub `clid_blacklist` table (`cluster`-scoped) that **never shipped in production use** — do **not** ETL-migrate it; greenfield only.

---

## 1. One-line purpose

Let a **tenant** block inbound calls from selected calling-line IDs (CLIDs), without making that block global across other tenants on the same instance, and without letting arbitrary desk phones mutate the list.

---

## 2. Why not “just a feature key”

Many competitors expose a star-code / feature key so **any** phone user can blacklist the last/current caller. That is easy and abusive (prank blocks, no audit, no tenant policy).

**PBX3 preference:** treat blacklist as a **policy object** — managed with **identity + privilege**, same class as CoS / inbound routing — not as an unauthenticated phone gesture.

---

## 3. Locks

| # | Lock |
|---|------|
| **B0** | **Tenant-scoped only.** Rows belong to one `cluster` / shortuid. Tenant A may block `+441234…`; tenant B may still accept it. Never instance-global. |
| **B1** | **Greenfield.** Ignore SARK `clid_blacklist` for migrate (drop from ETL `TABLE_MAP` when convenient). No heritage UI parity obligation. |
| **B2** | **Mutate requires auth.** v1: **SPA (Sanctum)** with an explicit ability (tenant admin / privileged instance user for that tenant). No open “any extension” feature key in v1. |
| **B3** | **Optional later — authenticated phone path only.** If a desk feature code is added, it must require a **privilege** (e.g. CoS / extension flag “may manage CLID blacklist”) **and** a second factor suitable for the channel (PIN / agent login / confirm tone) — not bare `*xx`. Park until product asks. |
| **B4** | **Enforce in the call path for that tenant** (inbound before ring/IVR). Miss = fail open or closed is an implementer decision documented at build time; default lean **fail open** (don’t drop calls if DB/lookup broken) unless security review says otherwise. |
| **B5** | **Audit.** Who added/removed which CLID, when (API user id / z_updater). Phone path later must stamp actor extension. |
| **B6** | **Not host firewall.** Unrelated to UFW / Shorewall / `shorewall_*` IP lists. |

---

## 4. v1 shape (product)

| Surface | Behaviour |
|---------|-----------|
| **SPA** | Tenant-scoped list: CLID (normalized), optional note, action (v1: **Hangup** / reject only unless product expands), add/edit/delete |
| **API** | CRUD under tenant auth; uniqueness **(cluster, clid)** |
| **Dialplan / CAGI** | On inbound for tenant T, if CLID matches list → apply action (no ring) |
| **Normalization** | Store/compare in one wire-ish form (align with number-wire / inbound presentation); document exact match vs suffix rules at implement time |
| **Permissions** | Wire to instance user privileges — **tenant** role may manage own tenant’s list; not trunks/System. See **`INSTANCE_USER_PRIVILEGES_REQUIREMENTS.md`** |

**Out of v1:** anonymous feature key; fleet-global blocklist; carrier/SBC-level CLID filter (different layer).

---

## 5. Open at implement time (not blocking the lock)

- Exact match vs national/E.164 normalize / “last N digits”.
- Anonymous / withheld CLI handling (never match vs explicit “block unknown”).
- Action set beyond Hangup (busy, greeting, voicemail).
- Whether Commit is required (likely **live or light reload** — blacklist should not wait on full GenAst if avoidable; decide with AstDB vs SQLite lookup).

---

## 6. Non-goals

- Porting unfinished SARK panel behaviour.
- Letting every phone user blacklist without privilege.
- Confusing with Fail2ban / UFW IP bans or SBC door-knock.

---

## 7. When scheduled

Add schema + API + SPA + inbound check; update **`TODO.md`** / legacy backlog as greenfield (not “sarkipblacklist port”). ETL: drop `clid_blacklist` from migrate map as hygiene.
