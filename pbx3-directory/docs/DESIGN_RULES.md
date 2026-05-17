# Instance directory — design rules (non-negotiable)

**Status:** Agreed before implementation on branch **`directory`** (2026-05).  
**Applies to:** `pbx3-directory`, **pbx3spa** (picker UX), any future central auth/gateway. **Does not** change runtime requirements on **pbx3** / **pbx3api** / Asterisk on each node.

**Related:** `PLANNING_HANDOFF.md`, `CENTRAL_ADMIN_DIRECTION.md`, `OVERVIEW.md`.

---

## Rule 1 — Nodes never depend on the directory for telephony

PBX nodes must **always** be able to make and receive calls when the directory is down, unreachable, misconfigured, or empty.

| Must remain true | Must never happen |
|------------------|-------------------|
| Asterisk runs from local config + **instance** sqlite | Directory in the SIP/RTP path |
| Phones register to the node FQDN / tenant FQDN on that host | “Directory unavailable” blocks calls |
| **pbx3api** on `:44300` serves instance API without calling directory | Node boot or `commit` requires directory |
| LE, firewall, tenant DB are node-local | Central service is a hard dependency for media/signaling |

**Implication:** No directory callbacks from **pbx3**, **pbx3api**, or Asterisk. Directory is **not** part of the real-time telephony control plane.

---

## Rule 2 — The directory is a signpost for humans

The directory is an **operator map**: which instances exist, how to reach their admin API (`api_base_url`), and (later) who may see which row.

| Directory is | Directory is not |
|--------------|------------------|
| A curated index for the central SPA | Source of truth for extensions, routes, or dialplan |
| Metadata for pickers, monitoring, orchestration | Required for call routing between tenants |
| Eventually ACL-filtered for MSP/superuser views | A replacement for per-instance **Sanctum** / **whoami** on the node API |

**Implication:** After the user picks an instance, **all panel work** uses that node’s **`api_base_url`** and existing instance auth — same as today.

---

## Rule 3 — Directory unavailable must not block instance access

**Normal path:** User signs in (central or local SPA) → sees **allowed instances** from the directory → picks one → admin UI connects to that node.

**Degraded path:** If the directory fetch fails (timeout, 404, corrupt JSON, S3 outage):

- User **must still** be able to open admin for any instance she has **security clearance** for.
- Mechanisms (product may combine):
  - **Direct instance login** — enter or select a known `api_base_url` (engineering / break-glass; see `DEV_ENVIRONMENT.md`).
  - **Recently used instances** — from browser storage (no directory round-trip).
  - **Bookmarked instance URL** — deep link with instance id/fqdn when central auth exists later.

Directory failure surfaces as **UX degradation** (no picker list, warning banner), **not** a hard login failure for users who can reach a node.

| Acceptable | Not acceptable |
|------------|----------------|
| “Directory unavailable — pick an instance manually or try again” | “Cannot log in — directory down” |
| Empty picker + override field | SPA refuses to call any `api_base_url` |
| Cached last-good index (optional, stale OK with warning) | Node rejects API because directory did not approve |

**Implication for Phase C (SPA):** `GET` directory is **best-effort**; instance **Sanctum** login against chosen `baseUrl` is **required** and must work with zero directory response.

---

## Rule 4 — Security clearance is enforced on the instance (and later centrally)

**Today:** Clearance = successful **Sanctum** login + **whoami** / admin abilities on **that** node’s API.

**Future:** Central identity may **filter** directory rows (ACL) and/or issue tokens — but **Rule 3** still applies: a user with credentials for `https://node.example:44300/api` can administer that node even if the directory omits or hides it (support break-glass must remain policy-controlled, not accidentally removed).

**Implication:** Directory ACL is **advisory for discovery**, not the only gate — unless product explicitly adds “directory-only discovery” for standard users while preserving break-glass for support roles.

---

## Rule 5 — Directory outage does not change node SLA

Monitoring and ops should treat directory availability separately from **instance health**. An instance can be **fully operational** while the directory is **offline**.

**Implication:** Health checks for “can this PBX carry traffic?” target the **node**, not the directory service.

---

## Summary (one line each)

1. **Calls work without directory.**  
2. **Directory = human signpost, not call path.**  
3. **Directory down → can still log into permitted nodes.**  
4. **Auth/clearance on instance API (central ACL filters the map later).**  
5. **Directory SLA ≠ node SLA.**

---

## Checklist for designs and PRs

Before merging directory-related work, confirm:

- [ ] No new **pbx3** / **pbx3api** dependency on directory at request or boot time.
- [ ] SPA instance picker treats directory `GET` as optional; manual / cached instance entry still works.
- [ ] No user-facing path where directory failure equals total admin lockout (except “no credentials for any node”).
- [ ] Docs and diagrams show directory **beside** nodes, not **in front of** SIP/RTP.

---

## Phase mapping

| Phase | How these rules apply |
|-------|------------------------|
| **A — Contract** | Schema is instance metadata only; no “required_for_calls” flags. |
| **B — Dev feed** | Static URL; nodes unaffected if URL wrong. |
| **C — SPA picker** | Implement Rule 3 explicitly (override + error state). |
| **D — Central auth** | ACL filters directory view; Rule 4 + break-glass documented. |
| **E — Orchestration** | Tenant move uses directory for **ops** URLs; nodes run local LE/sync scripts. |
