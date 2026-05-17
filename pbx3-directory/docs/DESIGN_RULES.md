# Instance directory — design rules (non-negotiable)

**Status:** Agreed before implementation on branch **`directory`** (2026-05).  
**Applies to:** `pbx3-directory`, **pbx3spa** (picker UX), any future central auth/gateway. **Does not** change runtime requirements on **pbx3** / **pbx3api** / Asterisk on each node.

**Related:** `PLANNING_HANDOFF.md`, `CENTRAL_ADMIN_DIRECTION.md`, `OVERVIEW.md`.

---

## Product mental model — EC2 fleet console

**One line:** A **fleet console** for PBX nodes — like **EC2**: see instances, monitor them, open one; each node keeps its own admin security and keeps carrying calls if the console is away.

The directory is **not** a telephony control plane. It is where operators **see** the fleet and **choose** which node to administer. Each instance remains a sovereign cell (like an AWS account or a single EC2 “world” on a host): local DB, Asterisk, LE, firewall, and **its own admin security**.

### EC2 ↔ PBX3 mapping

| EC2 / AWS console | PBX3 (Model B) |
|-------------------|----------------|
| EC2 console / resource list | Central **pbx3spa** + **instance directory** |
| Each EC2 instance (workload on a host) | One **PBX node** (`pbx3` + `pbx3api` + Asterisk) |
| Instance runs if console/Organizations API is down | **Calls work** if directory / central SPA unavailable (Rules 1, 5) |
| CloudWatch metrics, alarms, status checks | **Later (optional):** fleet badges; v0 = open instance and use panels |
| **IAM in that AWS account** | **Security on the node** — Sanctum, users, `whoami` on `:44300/api` |
| Organizations account picker | Directory rows: `label`, `fqdn`, `api_base_url`, `org_id` |
| “Open this account” / switch role | User picks instance → SPA sets `baseUrl` → panels as today |
| Console URL + account credentials (break-glass) | Direct `api_base_url` / dev override when directory fetch fails (Rule 3) |

### Telemetry: keep it on the node (v0)

Admin UIs are **low traffic**; PBX fleets are **steady-state** for long periods. The directory changes **rarely** (new node, retire node, URL fix).

| v0 | Later (optional) |
|----|------------------|
| Directory row = **label**, **fqdn**, **api_base_url**, **id**, **status** | Summary health on list (poll nodes) |
| Fetch index **on login** (+ manual “Refresh list”) | Continuous fleet dashboards |
| All real detail after connect — certificates, logs, Asterisk | Cache hints in directory JSON |

Do not build live telemetry into the catalog for v0.

### Security: IAM per account, not one global gate

- **Today:** Only **instance IAM** — Sanctum login and abilities on that node’s API.
- **Later (optional):** Central IdP answers “who is this person?”; **each node** still decides what they may do (like **SSO into AWS**, then **IAM in that account**).
- Directory ACL (Phase D) filters **which instances appear in the picker** for MSP/superuser views — **discovery**, not replacement for node credentials unless explicitly designed later.

### Do / don’t (stay EC2-like)

| Do | Don’t |
|----|--------|
| List instances; show summary health when available | Put SIP/RTP or dialplan through directory |
| On select, all admin traffic to that node’s `api_base_url` | Require directory for node boot, `commit`, or calls |
| **Later:** optional fleet poll for list badges | Treat directory as sole security boundary for everyone |
| Stable row `id` (`globals.id`); URL can change with ops | Copy full logs/metrics into S3 index as source of truth |

### Gotchas (EC2 analogy)

1. **Stale signpost** — Directory URL wrong but node still serving calls (like wrong Route53/console tag). Need `updated_at`, health probe, decommissioned `status`.
2. **Invisible new instance** — Node live before directory row exists (like instance running before it appears in Resource Groups). Need registration/onboarding path.
3. **Two permission systems** — Removed on node but still on directory row (or reverse). Deprovision playbook must cover both until single IdP owns access.
4. **Empty list ≠ broken** — Distinguish “directory down”, “you have zero instances”, and “ACL filtered everything out”.
5. **Discovery vs secrecy** — Console lists accounts you can access; break-glass URL is policy for support, not accidental removal (Rule 3 vs Rule 4).

PBX3 directory follows the **console + per-cell IAM** pattern, not a **single gateway proxy** for all admin traffic.

### v0 delivery — keep it boring

**Workload:** A few operators, a few logins per day, catalog changes **infrequently**. Do not design for heavy traffic or sub-minute global consistency.

**v0 catalog:**

1. One file — `instance-index.json` (see `schema/`).
2. One HTTPS URL — static host, S3, or S3 + CDN (**CDN optional**, not required day one).
3. SPA **GET on login** (+ optional “Refresh list”) — not polling.
4. Fields enough to pick a node: `id`, `label`, `fqdn`, `api_base_url`, `status`.
5. **Writes** — manual edit or script when a node is provisioned/decommissioned; idempotent by `globals.id`.

**Explicitly defer (until a real requirement):**

- Multiple directory API replicas / load-balanced readers  
- Read replicas, geo-redundant catalog DB  
- Live fleet health in the index  
- Aggressive cache invalidation and thundering-herd tuning  

**If you add CDN later:** Long TTL is fine; after a rare publish, invalidate once or bump `version` in JSON. Stale list for an hour is acceptable for admin pickers.

**Naming:** “**Directory catalog**” vs “**PBX node**” — do not mix in runbooks.

#### v0 gotchas (only what matters at low scale)

| Gotcha | Mitigation |
|--------|------------|
| Node live, not in JSON yet | Registration step when node is built |
| Wrong `api_base_url` in JSON | `updated_at` / `version`; fix file; break-glass direct URL |
| Directory URL down | Rule 3 — manual `api_base_url`, recent instances |
| Two people edit JSON | Single owner or small script; git-review the index |

#### Later (optional) — HA readers / CDN / fleet badges

See git history or ops runbooks if traffic or MSP scale demands it. PBX **nodes** stay unchanged; only how the SPA loads the map gets fancier.

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
