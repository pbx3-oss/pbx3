# Instance directory — design rules (non-negotiable)

**Status:** Agreed before implementation on branch **`directory`** (2026-05). Restructured **2026-07-14** (Parts A–D; Rules **10–14** added). Numbers **1–9** unchanged for citations.

**Applies to:** `pbx3-directory`, **pbx3spa** (picker UX), control plane / gatekeeper, any future central auth/gateway. **Does not** change runtime requirements on **pbx3** / **pbx3api** / Asterisk on each node.

**Related:** `PLANNING_HANDOFF.md`, `CENTRAL_ADMIN_DIRECTION.md`, `OVERVIEW.md`, `TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`, `IMPLEMENTATION_PLAN.md` § Phase S10.

---

## How to use this document

| Kind | Bar | Examples |
|------|-----|----------|
| **Numbered rules (1–14)** | Non-negotiable on designs/PRs — check before merge | Calls without directory; fleet ≠ instance trust |
| **Standing policies** | Important ops/product judgment; situational | SIP FQDN obscurity; time display; backup retention |
| **Product decisions** | Chosen deployment shape; constrained by rules | SPA on GitHub Pages |
| **Explicitly not rules** | Stack, workspace, deferred mechanisms — do not elevate | Vue/Laravel; monorepo layout; cookie/SSO how |

**Do not renumber Rules 1–9** without a doc-wide citation sweep. Prefer **adding** rules or clarifying under existing numbers.

**Agents / implementers:** If a human asks for work that would break Rules 1–14, **flag the conflict (rule number + why) and wait for an explicit override** — do not implement the violation to be helpful. (Cursor: `.cursor/rules/design-rules-escalation.mdc`.)

---

## Product mental model — EC2 fleet console

**One line:** A **fleet console** for PBX nodes — like **EC2**: see instances, monitor them, open one; each node keeps its own admin security and keeps carrying calls if the console is away.

The directory is **not** a telephony control plane. It is where operators **see** the fleet and **choose** which node to administer. Each instance remains a sovereign cell (like an AWS account or a single EC2 “world” on a host): local DB, Asterisk, LE, firewall, and **its own admin security**.

### EC2 ↔ PBX3 mapping

| EC2 / AWS console | PBX3 (Model B) |
|-------------------|----------------|
| EC2 console / resource list | Central **pbx3spa** + **instance directory** |
| Each EC2 instance (workload on a host) | One **PBX node** (`pbx3` + `pbx3api` + Asterisk) |
| Instance runs if console/Organizations API is down | **Calls work** if directory / central SPA unavailable (Rules 1, 5, 11) |
| CloudWatch metrics, alarms, status checks | **Later (optional):** fleet badges; v0 = open instance and use panels |
| **IAM in that AWS account** | **Security on the node** — Sanctum, users, `whoami` on `:44300/api` (Rule 4). Fleet ops = Rule 10 |
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

- **Today:** Only **instance IAM** — Sanctum login and abilities on that node’s API (Rule 4).
- **Fleet plane:** Separate gatekeeper identity + `fleet_*` abilities (Rule 10).
- **Later (optional):** Central IdP answers “who is this person?”; **each node** still decides what they may do (like **SSO into AWS**, then **IAM in that account**). Cookie/SSO *mechanism* is deferred — see **Explicitly not rules**.
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
3. **Two permission systems** — Removed on node but still on directory row (or reverse). Deprovision playbook must cover both until single IdP owns access. Fleet vs instance is a **third** plane (Rule 10).
4. **Empty list ≠ broken** — Distinguish “directory down”, “you have zero instances”, and “ACL filtered everything out”.
5. **Discovery vs secrecy** — Console lists accounts you can access; break-glass URL is policy for support, not accidental removal (Rule 3 vs Rule 4). See also **Standing policies → SIP FQDN obscurity**.

PBX3 directory follows the **console + per-cell IAM** pattern, not a **single gateway proxy** for all admin traffic.

### v0 delivery — keep it boring

**Workload:** A few operators, a few logins per day, catalog changes **infrequently**. Do not design for heavy traffic or sub-minute global consistency.

**v0 catalog:**

1. One file — `instance-index.json` (see `schema/`).
2. One HTTPS URL — static host, S3, or S3 + CDN (**CDN optional**, not required day one).
3. SPA **GET on login** (+ optional “Refresh list”) — not polling.
4. Fields enough to pick a node: `id`, `label`, `fqdn`, `api_base_url`, `status`.
5. **Writes** — manual edit or script when a node is provisioned/decommissioned; idempotent by `globals.id` (product path → gatekeeper; Rule 10 / Phase S10).

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

# Numbered rules

## Part A — Telephony autonomy

### Rule 1 — Nodes never depend on the directory for telephony

PBX nodes must **always** be able to make and receive calls when the directory is down, unreachable, misconfigured, or empty.

| Must remain true | Must never happen |
|------------------|-------------------|
| Asterisk runs from local config + **instance** sqlite | Directory in the SIP/RTP path |
| Phones register to the node FQDN / tenant FQDN on that host | “Directory unavailable” blocks calls |
| **pbx3api** on `:44300` serves instance API without calling directory | Node boot or `commit` requires directory |
| LE, firewall, tenant DB are node-local | Central service is a hard dependency for media/signaling |

**Implication:** No directory callbacks from **pbx3**, **pbx3api**, or Asterisk. Directory is **not** part of the real-time telephony control plane.

**See also:** Rule **11** (ops fail-safe: moves/onboard may wait; calls must not). Local-first recordings/backups (Standing policies) apply the same idea to media/DR.

---

### Rule 5 — Directory outage does not change node SLA

Monitoring and ops should treat directory availability separately from **instance health**. An instance can be **fully operational** while the directory is **offline**.

**Implication:** Health checks for “can this PBX carry traffic?” target the **node**, not the directory service.

---

### Rule 6 — Solo / “kick the tyres” must stay frictionless

A new operator running **one** PBX to evaluate the product must **not** need S3, a fleet catalog, registrar scripts, central admin hosting, or cloning **`pbx3-directory`** tooling.

| Required for minimal trial | **Not** required for minimal trial |
|----------------------------|-------------------------------------|
| **pbx3** + **pbx3api** on the node | S3 bucket or `catalog/instance-index.json` |
| Admin UI (**pbx3spa**) + Sanctum login | Multi-instance picker |
| Reachable `api_base_url` (or same-origin admin) | Phase D central auth |
| | Org backup upload to S3 (Phase 4+) |

**Product paths (same SPA, no second app):**

1. **Solo default** — `VITE_INSTANCE_DIRECTORY_URL` unset → skip catalog; email/password + API URL (or build-time `VITE_DEFAULT_API_BASE_URL`).
2. **Single catalog row** — if directory is configured and `instances.length === 1`, auto-select; no picker step.
3. **Model A** — SPA on the node hostname; derive API from same origin (optional nginx co-host on `:44300`).
4. **Fleet later** — enable directory URL when the operator has **two or more** instances or opts into MSP console.

**Implication:** Directory and S3 are **opt-in scale features**, not gates on first boot, LE, `commit`, or calls. Install docs for solo: one URL + credentials; fleet catalog is an appendix.

---

## Part B — Directory & clearance

### Rule 2 — The directory is a signpost for humans

The directory is an **operator map**: which instances exist, how to reach their admin API (`api_base_url`), and (later) who may see which row.

| Directory is | Directory is not |
|--------------|------------------|
| A curated index for the central SPA | Source of truth for extensions, routes, or dialplan |
| Metadata for pickers, monitoring, orchestration | Required for call routing between tenants |
| Eventually ACL-filtered for MSP/superuser views | A replacement for per-instance **Sanctum** / **whoami** on the node API |

**Implication:** After the user picks an instance, **all panel work** uses that node’s **`api_base_url`** and existing instance auth — same as today.

---

### Rule 3 — Directory unavailable must not block instance access

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

### Rule 4 — Security clearance is enforced on the instance (and later centrally)

**Today:** Clearance = successful **Sanctum** login + **whoami** / admin abilities on **that** node’s API.

**Future:** Central identity may **filter** directory rows (ACL) and/or issue tokens — but **Rule 3** still applies: a user with credentials for `https://node.example:44300/api` can administer that node even if the directory omits or hides it (support break-glass must remain policy-controlled, not accidentally removed).

**Implication:** Directory ACL is **advisory for discovery**, not the only gate — unless product explicitly adds “directory-only discovery” for standard users while preserving break-glass for support roles.

**Fleet plane is separate:** Do **not** stretch instance Sanctum `admin` into catalog mutate / move / onboard. Fleet clearance = Rule **10**.

---

## Part C — Replaceable backends (adapters)

### Rule 7 — Replaceable edge; SIP is the runtime API

The fleet **edge** (SBC / session border) is a **discrete, swappable component**. **pbx3sbc** is the **default** implementation, not the abstraction.

| Layer | Contract | Replaceable? |
|-------|----------|--------------|
| **Runtime (calls)** | **SIP** — REGISTER, INVITE, RTP between endpoints, edge, nodes, carriers | Universal; no PBX3-proprietary wire protocol |
| **Fleet edge (signaling)** | Stable phone/carrier address; `tenant domain` → backend node | **Yes** — via **`SbcFleetAdapter`** (see **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §2.4) |
| **Fleet intent (ops)** | S3 directory — homing, DID assignment, instance index | Edge-agnostic JSON; projected to edge DB (Rule 13) |
| **Nodes** | Standard downstream SIP peer (`Egress` → edge URI) | Any edge that accepts that pattern |

**Default implementation:** **pbx3sbc** (OpenSIPS). **Alternatives:** another SBC product, customer-operated edge, or dSIPRouter — implement the same **adapter contract**, not OpenSIPS table names in the orchestrator.

**Adapter surface (minimum):** `preflight`, `repointTenant`, `projectTenantDids` (or bulk projector), `registerNode`, `health`, `rollbackRepoint`. Move wizard and nodes call the **adapter**, never `opensipsctl` or `dr_rules` directly.

**Anti-patterns (do not ship):**

- Fleet Console or control plane **inside** `pbx3sbc-admin` (couples orchestrator to one edge).
- OpenSIPS-specific schema as **home of record** for tenant homing (use S3 directory; edge DB is **compiled projection** — Rule 13).
- Node dialplan, AGI, or trunk generator assuming **one vendor’s** edge config format.

**Implication:** Swapping edge = new adapter + projector from catalog → edge config. **Nodes and move orchestration stay unchanged.**

**Same pattern:** Rule **9** applies the adapter idea to **cloud / object store** backends.

---

### Rule 8 — Fleet metadata feeds the SPA; not the reverse

Catalog and fleet structures exist to **inform** operators and the central SPA. They must **not** be shaped by SPA internals, and the **runtime fleet must not depend** on SPA-specific metadata.

| Direction | Allowed | Forbidden |
|-----------|---------|-----------|
| **Fleet → SPA** | S3 `catalog/*`, `tenants/*/meta.json`, optional `dids.json` → instance picker, fleet badges, “Manage in Fleet Admin” links | — |
| **SPA → fleet** | User **actions** (start move, assign DID) via **control-plane API** with fleet schemas | SPA routes, Vue form keys, panel layout, or `localStorage` shape **defining** S3 schema or edge config |
| **Node → SPA** | After instance select, **all panel data** from that node’s **`api_base_url`** (Sanctum) | Node sqlite or API reading SPA build artifacts |

**SIP remains the primary integration API** for telephony. S3/catalog is **ops metadata** (async, human/orchestrator oriented) — same posture as Rule 1: feeds the console, never the media/signaling path.

**Schema rule:** `schema/*.v0.json` describe **fleet and ops facts** (`instance_id`, `fqdn`, `e164`, `status`) — not SPA field names, help pkeys, or nav groups. If the SPA needs a display label, **derive** it in the SPA from fleet fields; do not add `spa_nav_label` to catalog rows.

**Implication:** A different admin UI (or no central SPA) can consume the same S3 layout. Retiring or rewriting **pbx3spa** does not require rewriting fleet catalog or edge routing.

---

### Rule 9 — Cloud provider portability; object store via interface

**Observation (2026-07-14):** Lab and first fleets may run on **AWS**, but product must **not** become tightly coupled to AWS as a vendor. Many clouds and on-prem products offer **S3-compatible object storage** (MinIO, Cloudflare R2, Backblaze B2, Wasabi, Ceph RGW, etc.). Compute / IAM / instance lifecycle differ more widely — those interactions must also sit behind a seam, not leak into SPA, node panels, or gatekeeper business logic.

**Object store (primary):** Treat the org bucket as an **S3 API** surface — keys, GET/PUT/LIST, presigns, optional lifecycle tags — not as “AWS S3 the product.”

| Layer | Owns | Must not |
|-------|------|----------|
| **App / control plane** | Key layout (`catalog/`, `instances/…`, `tenants/…`), Laravel `pbx3_org` (or equivalent) disk, catalog schemas, gatekeeper write APIs | Hard-code AWS console URLs, account-specific ARN shapes, or `us-east-1` assumptions in product paths |
| **Storage adapter** | Endpoint, credentials, path-style vs virtual-host, region/signing quirks | Change key layout per vendor |
| **Ops scripts** | Provider-specific IAM/lifecycle until rewritten | Become the only way product code talks to the bucket |

**Compute / IAM (secondary — Phase S8.9 / S10.7):** Actions such as “attach instance profile”, “launch AMI”, “associate role” are **not** universal. Encapsulate behind a **cloud/fleet adapter** (name optional: `CloudFleetAdapter`, `IaaSAdapter`) with intent-level methods. First implementation may use the AWS SDK; a second provider or bare-metal path implements the same contract (or documents “unsupported”). SPA and move wizard call **gatekeeper → adapter**, never AWS APIs directly (Rule 12).

**Anti-patterns (do not ship):**

- Gatekeeper / SPA / `pbx3api` importing AWS SDK types into domain services (except inside an adapter package).
- Env vars or docs that assume **only** AWS role ARNs with no equivalent for “static keys + custom endpoint” (already needed for MinIO-class labs).
- Catalog or job JSON that records AWS-only fields as home of record (`i-0abc…` as sole identity) — EC2 instance id may be **ops metadata**; fleet identity remains **`globals.id` (KSUID)** + FQDN.

**Implication:** Switching object-store vendor = new **storage** config (and maybe ops runbook). Switching IaaS for onboard/rebuild = new **cloud adapter** implementation. **Directory layout, move jobs, and SBC adapter stay unchanged.** Sibling of Rule 7 (replaceable edge): replaceable **cloud backend**.

**Related:** Product decisions → SPA hosting § Storage portability · **`OPS_S3_RUNBOOK.md`** · **`IMPLEMENTATION_PLAN.md`** S9.1 · Phase **S10** / **S8.9**.

---

## Part D — Fleet control plane

### Rule 10 — Split trust: fleet plane ≠ instance/tenant plane

Fleet-destroying and catalog-mutating actions must not share the instance/tenant admin token tier.

| Actor | Identity | May |
|-------|----------|-----|
| **Instance / tenant admin** | Sanctum on `:44300`; `admin` / panel abilities | Node panels (extensions, trunks, LE UI, etc.) |
| **Fleet admin** | Gatekeeper; `fleet` / `fleet_*` abilities | Onboard, decommission, move, DID assign, catalog write, reconcile, fleet user manage (by ability) |

**Must never happen:** instance API exposes register-instance / decommission / tenant-move mutate for ordinary Sanctum `admin`; Fleet mode actions callable without fleet identity.

**Implication:** One SPA, two modes, two APIs (`CENTRAL_ADMIN_DIRECTION.md`, mobility §2.5). Having both credentials still means **one mode at a time**. Phase **S10** implements ability gating. See **`FLEET_AUTH_COOKIE_SSO.md`** for identity stance (abilities in-house; big IdP optional later).

---

### Rule 11 — Control plane fail-safe; mutations are optional

When the control plane (gatekeeper), org bucket, or orchestrator is down:

| Must continue | May wait / fail loudly |
|---------------|------------------------|
| Calls, REGISTER, local admin on nodes | Tenant move, catalog onboard/decommission, DID assign, rebuild jobs |
| Node backup upload via **tight prefix IAM** (or cached presigns) where already configured | New catalog publishes that need gatekeeper write |

**Implication:** Console can be red while phones are green. Same spirit as Rule 1 applied to **ops**. Do not make telephony wait on job queues.

---

### Rule 12 — Browser never holds ops power

The SPA must not hold SSH, cloud root, registrar Mac IAM, or long-lived break-glass keys as the product path.

| Does | Does not |
|------|----------|
| Drive **durable jobs** and gatekeeper APIs with a **fleet** session | Call AWS/IaaS APIs, `opensipsctl`, or node SSH from the browser |
| Use server-side orchestrator + adapters (Rules 7, 9) | Embed ops secrets in SPA builds (`VITE_*` bake of gatekeeper tokens — forbidden for production) |

**Implication:** Break-glass paste remains an **ops** escape hatch (collapsed UI); product happy path is email/password fleet session → job. Matches mobility design: “browser never touches SSH / AWS root / DNS APIs directly.”

---

### Rule 13 — One home of record; edges are projections

**Home of record (HoR)** for fleet ops facts lives in the **directory / org object store** (catalog, `tenants/*/meta.json`, DID inventory). Edge databases (SBC MySQL/SQLite, etc.) are **compiled projections**.

| Owner | Examples |
|-------|----------|
| **HoR (S3 / gatekeeper writes)** | Tenant → `instance_id`; DID → tenant; instance index row |
| **Projection (edge)** | `domain.setid`, `dr_rules`, dispatcher membership |

**Reconcile** flags drift and (when authorized) re-projects **from** catalog **to** edge — not the reverse as product path. Manual Filament edits on the SBC are **break-glass**; expect reconcile to notice.

**Implication:** Move cutover updates HoR and projection in one job (or fails/rolls back). Do not invent a second HoR in OpenSIPS tables. Ties Rules 7 + 8.

---

### Rule 14 — Destructive fleet steps are gated and durable

Onboard IAM join, decommission, tenant move cutover, source cleanup, DID reassign, and rebuild must run as **durable jobs** (or equivalent auditable server workflows), not a single long browser POST with no resume.

| Required | Forbidden as product path |
|----------|---------------------------|
| Preflight gates before destructive phases | Fire-and-forget cutover with no job record |
| Human gates where agreed (e.g. source delete after verify) | Silent delete of live tenant or node row |
| Retry / rollback paths where defined | Orphaned half-moves with no job state |

**Implication:** Job view + audit trail (“who started this”) are part of the product, not optional polish. Phase S8.10 job shape + Phase S10 job control.

---

# Standing policies (not numbered rules)

Important, but situational — do not treat as the same bar as Rules 1–14.

## SIP FQDN obscurity vs public catalog

**Context (legacy PBX3 posture):** For many deployments, **SIP ingress security** has relied on **packet inspection** of inbound INVITEs — Shorewall INLINE rules when **`globals.fqdninspect`** is YES match the expected hostname in the SIP payload (e.g. `sip:<fqdn>` on UDP/TCP **5060**). Operators have **not generally published** those dialable FQDNs; a passive observer could still learn names from **SIP on the wire** or from **DNS** (LE, phones), but the names were not advertised in marketing or public indexes.

**This is a different layer from API security.** Sanctum on `:44300` protects **admin panels**. SIP URI inspection protects **telephony ingress**. A world-readable **`catalog/instance-index.json`** can weaken the **obscurity** leg of SIP defense without breaking Sanctum or `fqdninspect` themselves — it makes correct INVITE targets **cheaper to discover** (scrape JSON) than PCAP or blind scanning.

| Layer | What leaks | Public catalog impact |
|-------|------------|------------------------|
| Admin API | `api_base_url`, instance `fqdn` | Low for auth — still need credentials |
| SIP ingress | Tenant / node FQDNs in INVITE **Request-URI** / **To** | **Higher** — attacker learns strings to satisfy inspection |

**Agreed policy:**

1. **v0 dev / golden** — public `catalog/*` prefix is acceptable with eyes open when FQDNs are already in DNS for LE and phones.
2. **Production fleets that depend on SIP URI checking** — treat public catalog as **convenience vs obscurity** trade-off; prefer **Phase D private catalog** (auth before `GET`, or signed URLs) before MSP / multi-customer launch.
3. **Minimize public index content** — use opaque **`id`**, human **`label`** (“Golden”), **`status`**; avoid enumerating every **tenant** `{shortuid}.{apex}` in a world-readable file if those names are SIP inspection targets. Instance **`fqdn`** / **`api_base_url`** may still be required for the admin picker after connect.
4. **Do not conflate** “directory down” (Rule 3) with “hide SIP names” — break-glass **manual `api_base_url`** remains for operators who already know the node; that path does not require publishing names to the internet.
5. **Registrar / onboarding** — document which FQDNs are written to catalog vs kept node-local only.

**References:** **`pbx3/workingdocs/LETSENCRYPT_PER_TENANT_FQDN.md`** § `fqdninspect`; **`OPS_S3_RUNBOOK.md`** § 5.3 (confidentiality); **`IMPLEMENTATION_PLAN.md`** Phase D (private catalog + ACL).

---

## Time identifiers and display (agreed 2026-05)

**UX rule:** *Don’t make me think* — operators see **one consistent time format** in admin UIs. Storage and search may use other forms; **display** does not.

### Split: machine vs human

| Layer | Format | Use |
|-------|--------|-----|
| **Query / range search** | **Unix epoch** (integer seconds) | SQL `BETWEEN`, CDR/recording indexes, legacy behaviour |
| **Operator display** | **ISO 8601 UTC** (e.g. `2026-05-20T00:24:23Z`) | SPA tables, panels, messages — same everywhere |
| **S3 backup folder** | **Compact UTC stamp** `YYYYMMDDThhmmssZ` (e.g. `20260520T002423Z`) | Sortable prefix; equals epoch from `pbx3bak.{epoch}.zip` |
| **Local backup file** | `pbx3bak.{epoch}.zip` | Unchanged on disk; restore/download API |

**Principle:** Epoch (or datetime derived from epoch) is authoritative for **logic**. ISO 8601 UTC is authoritative for **what humans read**. Do not show raw epoch in primary UI columns.

### Backups

- **SPA / API list:** Primary column = **Created (UTC)** (`created_at` ISO). Secondary = **Archive ID** (`backup_stamp`, matches S3 prefix). **Local file** = `pbx3bak.{epoch}.zip` (technical; used for actions).
- **S3:** Keep `instances/{ksuid}/backups/{backup_stamp}/backup.zip` + `manifest.json` (`created_at` ISO).
- Operators comparing UI ↔ S3 console use **Archive ID**, not the zip filename.

### Backup retention (agreed — option C)

**Legacy Sark:** daily cron + on-demand backups in one pool; **max 9** local copies; new backup deletes the oldest (10th) locally.

**PBX3 (option C — implemented):**

| Layer | Policy | Enforcement |
|-------|--------|-------------|
| **Local** `/opt/pbx3/bkup/` | **Keep 9** newest `pbx3bak.*.zip` (FIFO) | `LocalBackupRetention` after SPA create or `pbx3:backup-run`; **do not** delete S3 |
| **S3** `instances/{ksuid}/backups/` | **30 days** archive | Ops: `apply-backup-lifecycle-rule.sh` on tag `class=backup` (upload sets tag); `policy.json` documents `maxage_days: 30` |

**Relationship (option C — hybrid):**

- Local = **fast restore** window (9 generations on disk).
- S3 = **longer DR window** (30 days); may still hold backups that were **evicted locally** until lifecycle expires.
- **Not lockstep on count:** local may have 9 while S3 has more stamps (up to 30 days of history).
- **Not lockstep on delete:** local manual delete does **not** remove S3 (unchanged until lifecycle or explicit ops).
- **Cron:** `pbx3:backup-run --trigger=scheduled` (see `pbx3api/scripts/cron.d/pbx3-backup.example`).

**Config knobs:** `PBX3_BACKUP_LOCAL_MAX_COUNT=9`, `PBX3_BACKUP_MAXAGE_DAYS=30` (`pbx3api` `config/pbx3_directory.php`).

**Future (backlog):** restore/download from S3 when local zip is gone (presigned GET or rehydrate to `bkup/`).

### Recordings (S3 offload — Phase S7 in `IMPLEMENTATION_PLAN.md`)

- **Rule 1:** Recording capture and playback on disk work **without S3**; upload is **async** after the wav exists locally.
- **Search on node:** Keep **epoch** (or DB datetime from epoch) for `BETWEEN` — authoritative index stays on node until a later manifest track.
- **S3 layout:** `tenants/{tenant_shortuid}/recordings/media/{yyyy}/{mm}/{dd}/{call_id}.wav` (+ optional `.txt`); `policy.json` + tag `class=recording` for lifecycle.
- **Retention hybrid:** Node `rec_age` / `recmaxage` evicts local files; S3 holds DR copy until lifecycle (same spirit as backup option C).
- **SPA:** Show ISO 8601 UTC for call time; epoch stays internal; “archived” when object is S3-only.

### Checklist (time/display)

- [ ] New admin lists use **ISO 8601 UTC** for primary time, not locale-only strings alone.
- [ ] S3/console identifiers (`backup_stamp`) exposed in UI where off-box copy exists.
- [ ] Recording search APIs continue to accept **epoch** ranges.

---

# Product decisions (not numbered rules)

Chosen deployment shapes — constrained by the rules above, but not themselves Rules.

## SPA hosting — GitHub Pages (central)

**Decision:** Production **pbx3spa** is hosted **once**, on **GitHub Pages** (custom domain when ready). It is **not** deployed onto PBX **instances** in production.

### Topology

```text
  GitHub Pages (one SPA origin, e.g. app.example.com)
       │
       ├── GET catalog/instance-index.json  (HTTPS — any S3-compatible bucket)
       │
       └── per instance: POST/GET https://{fqdn}:44300/api  (pbx3api only on node)
```

| Component | Where it lives | Notes |
|-----------|----------------|--------|
| **pbx3spa** | **GitHub Pages** (+ optional custom domain) | Static `dist/`; deploy via GitHub Actions |
| **pbx3api** | **Each instance** (`/opt/pbx3api`) | Sanctum, backups, telephony admin API |
| **Directory + backups** | **Org bucket** (S3-compatible API) | Layout in `S3_LAYOUT_PROPOSAL.md`; Rule 9 |

### Why GitHub Pages (vs CDN on AWS vs per-node nginx)

- **Convenience:** CI build → publish; free HTTPS; no VM to patch for static files.
- **No AWS lock-in for the UI:** Fleet storage may use AWS today, **MinIO, R2, B2, Wasabi**, etc. tomorrow — standard S3 API + Flysystem / AWS CLI toolkit (Rule 9).
- **Matches EC2-console model:** One fleet UI; nodes stay API-only (Rules 1, 5).

**Golden node exception:** Installing or nginx-serving **pbx3spa on a test instance** is an **expedient** for TLS/nginx validation only — **not** the production pattern. Do not bake SPA into instance AMIs or fleet install.

### Cross-origin requirements (production)

The SPA origin (e.g. `https://yourorg.github.io` or `https://app.example.com`) differs from each `api_base_url` and usually from the catalog bucket host. Plan for:

1. **Catalog bucket CORS** — allow SPA origin on `GET`/`HEAD` for `catalog/*` (see **`OPS_S3_RUNBOOK.md`** § CORS).
2. **Each instance API** — allow SPA origin + `Authorization` header for API calls (Bearer token after login; configure per node or via install template).
3. **Build-time env** — `VITE_INSTANCE_DIRECTORY_URL` is baked at build; use separate builds or CI vars for staging vs production catalog URLs. Local dev may use Vite `/dev-catalog` proxy (no bucket CORS).

### Storage portability (directory / backups) — see **Rule 9**

- **Application code** uses S3-shaped keys and Laravel `pbx3_org` disk (endpoint + bucket env) — vendor via config, not code forks.
- **Ops scripts** (`register-instance.sh`, `apply-backup-lifecycle-rule.sh`, etc.) may use AWS CLI today; lifecycle/IAM details vary by provider — rewrite ops steps, not app layout.
- **SPA hosting** is independent of bucket vendor.

### Phased rollout

| Phase | SPA | Catalog / backups |
|-------|-----|-------------------|
| **Now** | Local `npm run dev` (+ proxy) | Golden bucket on AWS (reference) |
| **Next** | GitHub Pages staging + custom domain | Same or any S3-compatible endpoint |
| **Production** | GitHub Pages production URL | Per-org bucket; registrar + node IAM unchanged |

### Checklist (SPA hosting PRs)

- [ ] No requirement to install **pbx3spa** on fleet instances in production docs or packages.
- [ ] Pages deploy docs or workflow live in **pbx3spa** repo (when implemented).
- [ ] Runbook lists SPA origin in catalog CORS and node API CORS checklist.
- [ ] Solo path (Rule 6) still works with no catalog URL.

---

# Explicitly not rules

Do **not** elevate these to numbered Rules. They are preferences, workspace facts, or deferred mechanisms.

| Topic | Stance |
|-------|--------|
| **SPA / API frameworks** (Vue, Laravel, Filament) | Current stack. Adapters and schemas outlive UI frameworks (Rules 7–8). |
| **Multi-repo / `pbx3-master` holding folder** | Operator clone layout. Irrelevant to customer deploy or a future monorepo. |
| **Cookie sessions / SSO / IdP product** | Deferred until same-site Fleet UI or customer SSO ask. **Abilities** (`fleet_*`) stay in-house (Rule 10). See **`FLEET_AUTH_COOKIE_SSO.md`**. |
| **“Always use AWS CLI in scripts”** | Lab convenience; product path is adapters (Rule 9). |

---

## Summary (one line each)

**Part A — Autonomy**

1. **Calls work without directory.**  
5. **Directory SLA ≠ node SLA.**  
6. **One box to try it → no S3/catalog required.**  

**Part B — Directory**

2. **Directory = human signpost, not call path.**  
3. **Directory down → can still log into permitted nodes.**  
4. **Auth/clearance on instance API (central ACL filters the map later).**  

**Part C — Adapters**

7. **Edge is replaceable; SIP is the wire API; adapter not OpenSIPS.**  
8. **Catalog feeds SPA; SPA does not define fleet schema.**  
9. **Cloud is replaceable; object store is S3-API shaped; IaaS behind an adapter — not AWS-locked.**  

**Part D — Fleet control plane**

10. **Fleet plane ≠ instance/tenant plane; `fleet_*` only for catalog/move/onboard.**  
11. **Control plane down → calls continue; mutations may wait.**  
12. **Browser never holds ops IAM/SSH; SPA drives jobs.**  
13. **Directory is HoR; edge DBs are projections.**  
14. **Destructive fleet steps are gated, durable jobs with audit.**  

---

## Checklist for designs and PRs

Before merging directory / fleet / control-plane work, confirm:

**Autonomy (A)**

- [ ] No new **pbx3** / **pbx3api** dependency on directory at request or boot time (Rule 1).
- [ ] Docs and diagrams show directory **beside** nodes, not **in front of** SIP/RTP (Rules 1, 5).
- [ ] Solo path works with **no** `VITE_INSTANCE_DIRECTORY_URL`; single-row catalog auto-selects without picker (Rule 6).
- [ ] Install/quick-start docs do not require S3 or directory setup for a single-node trial (Rule 6).

**Directory (B)**

- [ ] SPA instance picker treats directory `GET` as optional; manual / cached instance entry still works (Rule 3).
- [ ] No user-facing path where directory failure equals total admin lockout (except “no credentials for any node”) (Rules 3–4).

**Adapters (C)**

- [ ] Edge changes go through **`SbcFleetAdapter`** (or documented break-glass); orchestrator does not embed OpenSIPS specifics (Rule 7).
- [ ] S3/catalog schemas hold **fleet ops facts** only — no SPA-specific fields (Rule 8).
- [ ] Object-store and IaaS/IAM calls sit behind config + **adapters** (Rule 9); no new AWS-only hardwiring in domain or SPA code.

**Fleet control plane (D)**

- [ ] Catalog mutate / move / onboard / decommission require **fleet** identity + appropriate `fleet_*` — not instance Sanctum `admin` (Rule 10).
- [ ] Control-plane outage does not block calls; jobs fail safe (Rule 11).
- [ ] SPA does not hold ops cloud/SSH credentials; production builds do not bake gatekeeper tokens (Rule 12).
- [ ] Edge config treated as **projection** of directory HoR; reconcile direction documented (Rule 13).
- [ ] Destructive fleet actions are **jobs** (preflight, gates, retry/rollback, audit) (Rule 14).

**Product decisions**

- [ ] Production SPA hosting documented as **GitHub Pages** (central); instances **API-only**.

---

## Phase mapping

| Phase | How these rules apply |
|-------|------------------------|
| **A — Contract** | Schema is instance metadata only; no “required_for_calls” flags. |
| **B — Dev feed** | Static URL; nodes unaffected if URL wrong. |
| **C — SPA picker** | Rules 3 + 6: optional catalog, solo + single-row paths, override + error state. |
| **D — Central auth** | ACL filters directory view; Rule 4 + break-glass; **SIP FQDN obscurity** policy — prefer private catalog when `fqdninspect` matters. |
| **E — Orchestration** | Tenant move uses directory for **ops** URLs; nodes run local LE/sync scripts; Rule 14 jobs. |
| **S8 — Fleet edge** | Rules 7 + 8 + 13: **`SbcFleetAdapter`**; S3 intent → edge projection; catalog → SPA one-way. See **`FLEET_TRUNK_PEERING_DECISION.md`** §2.4. |
| **S10 / S8.9** | Rules 9–14: cloud adapter; fleet trust split; fail-safe control plane; browser powerless; HoR; durable jobs. **`IMPLEMENTATION_PLAN.md`** § Phase S10. |
