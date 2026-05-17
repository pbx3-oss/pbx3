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
| CloudWatch metrics, alarms, status checks | Fleet view: directory + **poll** each `api_base_url` for health/errors (Phase E) |
| **IAM in that AWS account** | **Security on the node** — Sanctum, users, `whoami` on `:44300/api` |
| Organizations account picker | Directory rows: `label`, `fqdn`, `api_base_url`, `org_id` |
| “Open this account” / switch role | User picks instance → SPA sets `baseUrl` → panels as today |
| Console URL + account credentials (break-glass) | Direct `api_base_url` / dev override when directory fetch fails (Rule 3) |

### Telemetry: list vs drill-down (EC2-style)

| Layer | What it holds | Staleness |
|-------|----------------|-----------|
| **Directory row** (optional) | `status`, `updated_at`, last probe OK, cert expiry **hint**, alarm count **hint** | May be stale — treat as signpost |
| **After user opens instance** | Logs, Asterisk, certificates, tenants, commit — **authoritative on node API** | Live (same as instance detail page in EC2 console) |

Prefer **live read from the connected node** for detail; use **async fleet poll** only for list badges. Do not replicate full telemetry into the directory (classic “stale console” failure mode).

### Security: IAM per account, not one global gate

- **Today:** Only **instance IAM** — Sanctum login and abilities on that node’s API.
- **Later (optional):** Central IdP answers “who is this person?”; **each node** still decides what they may do (like **SSO into AWS**, then **IAM in that account**).
- Directory ACL (Phase D) filters **which instances appear in the picker** for MSP/superuser views — **discovery**, not replacement for node credentials unless explicitly designed later.

### Do / don’t (stay EC2-like)

| Do | Don’t |
|----|--------|
| List instances; show summary health when available | Put SIP/RTP or dialplan through directory |
| On select, all admin traffic to that node’s `api_base_url` | Require directory for node boot, `commit`, or calls |
| Fleet monitoring walks directory, polls nodes **best-effort** | Treat directory as sole security boundary for everyone |
| Stable row `id` (`globals.id`); URL can change with ops | Copy full logs/metrics into S3 index as source of truth |

### Gotchas (EC2 analogy)

1. **Stale signpost** — Directory URL wrong but node still serving calls (like wrong Route53/console tag). Need `updated_at`, health probe, decommissioned `status`.
2. **Invisible new instance** — Node live before directory row exists (like instance running before it appears in Resource Groups). Need registration/onboarding path.
3. **Two permission systems** — Removed on node but still on directory row (or reverse). Deprovision playbook must cover both until single IdP owns access.
4. **Empty list ≠ broken** — Distinguish “directory down”, “you have zero instances”, and “ACL filtered everything out”.
5. **Discovery vs secrecy** — Console lists accounts you can access; break-glass URL is policy for support, not accidental removal (Rule 3 vs Rule 4).

### How other federated systems align

| Pattern | Federation | Workloads if catalog down | Auth |
|---------|------------|---------------------------|------|
| **AWS Console + Organizations** | Account list | EC2 in account still runs | **IAM per account** |
| **GCP / Azure** | Project/subscription picker | Resources keep running | **IAM on resource** |
| **Kubernetes contexts** | kubeconfig | Clusters autonomous | **Per-cluster credentials** |
| **Grafana orgs** | Org + datasource list | Metrics backends independent | **Per-org roles** |
| **Okta app portal** | App tiles | Apps up; portal is convenience | **Per-app federation** |

PBX3 directory follows the **console + per-cell IAM** pattern, not a **single gateway proxy** for all admin traffic.

### Directory service topology — datastore + identical read fronts

**Separate layer from PBX nodes.** The **directory** itself may be:

```
                    ┌─────────────┐     ┌─────────────┐
   SPA / ops ──────►│  Reader A   │     │  Reader B   │  (stateless, identical)
                    └──────┬──────┘     └──────┬──────┘
                           │                   │
                           └─────────┬─────────┘
                                     ▼
                           ┌─────────────────┐
                           │   Datastore     │  (S3 object, DB, etc.)
                           │ instance-index  │
                           └─────────────────┘
```

It does not matter which reader serves `GET /instances` — all return the same catalog **for a given datastore version**. PBX **nodes** are *not* these readers; they never call this layer for calls (Rule 1).

**Good fit:** Read-heavy signpost; v0 static JSON on S3 + CloudFront is already “one logical store, many edge caches.”

#### Gotchas — HA read replicas (directory only)

| # | Gotcha | What goes wrong | Mitigation |
|---|--------|-----------------|------------|
| 1 | **Replica ≠ fresh** | All readers healthy but datastore/CDN serves **stale** index; every replica agrees on wrong data | Short CDN TTL; `ETag` / `version` / `generated_at` in JSON; SPA shows “index as of …” |
| 2 | **LB “healthy” liar** | Reader passes TCP health check but cannot reach S3/DB | Deep health: reader verifies datastore read (or fails out of pool) |
| 3 | **Thundering herd** | Fleet refresh at top of hour hits all readers → datastore | Cache at reader; `If-None-Match`; rate limit; single regional cache layer |
| 4 | **Writes are the hard part** | N identical readers + **multiple writers** (install hooks, ops, CI) → lost updates, split index | **Single writer path** or conditional writes (ETag), idempotent registration by `globals.id` |
| 5 | **Read-after-write** | Register new node → immediate picker fetch → row missing on all readers | Writer returns only after commit; or client retry; or “pending” until visible |
| 6 | **ACL on each reader** | Replica pool without shared auth config → inconsistent filtered lists | Same JWT validation keys; or filter in SPA after fetch of signed index |
| 7 | **Confusing two “instances”** | Team mixes up **directory reader** vs **PBX node** in runbooks | Naming: “directory API” / “catalog” vs “PBX instance” / “node” |
| 8 | **False confidence** | “Directory is HA” so ops neglect **PBX node** health | Rule 5: directory SLA ≠ node SLA; probe `api_base_url` per row |
| 9 | **Break-glass unchanged** | All readers down → Rule 3 still required | SPA manual `api_base_url`; cached last index optional |
| 10 | **Geo replication lag** | Multi-region readers, single-region datastore (or vice versa) | Prefer one primary store; readers regional with same source; document RPO |

#### Writes vs reads (design early)

| Pattern | Reads | Writes | Notes |
|---------|-------|--------|-------|
| **S3 + CloudFront (v0)** | Many edges, one object | Rare human/CI `PUT` | Simplest HA reads; invalidate cache on publish |
| **DB primary + read replicas** | `SELECT` on replicas | `INSERT/UPDATE` on primary | Replica lag = gotcha #1 |
| **Leader-elected writer** | All readers read snapshot | One job owns writes | Good for registration automation |

**Do not** require sticky sessions on directory readers for the SPA (stateless `GET`). **Do** require **idempotent** node registration (`id` = `globals.id`).

#### How others do “identical fronts, one store”

| System | Store | Identical fronts | Caveat |
|--------|-------|------------------|--------|
| **S3 + CloudFront** | Object | Edge POPs | Eventual consistency + cache TTL |
| **RDS read replicas** | Postgres | App servers | Replication lag |
| **DynamoDB / DAX** | Table | Many Lambdas/APIs | Consistency model per read |
| **etcd + many apiservers** | Raft log | Kube apiservers | Strong consistency; ops complexity |
| **Git-backed config** | Repo | Many pull agents | Not instant; version by commit |

For PBX3 v0, **S3 index + CDN** is enough for “doesn’t matter which edge”; add explicit **API readers** later only if you need ACL at fetch time or write APIs.

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
