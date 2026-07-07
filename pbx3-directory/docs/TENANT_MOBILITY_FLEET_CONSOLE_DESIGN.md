# Tenant mobility — Fleet Console design (S8.10)

**Status:** Design draft (2026-07-07). **§13** = implementer execution map.
**Audience:** Product, implementers (pbx3api, pbx3spa, pbx3-directory, control-plane service, pbx3sbc).
**New here?** Read **`FLEET_SYSTEM_OVERVIEW.md`** first — plain-language, diagram-led introduction to the fleet for non-implementers.
**Depends on:** **S8.5** (`TENANT_MIGRATION_RUNBOOK.md`), **S8.6** (`tenant:export` / `tenant:import`, shipped `main`), **Central admin Model B** (`CENTRAL_ADMIN_DIRECTION.md`).
**Key enabler:** **pbx3sbc** (OpenSIPS SIP edge, sibling repo `pbx3-master/pbx3sbc`) — when the fleet is SBC-fronted, tenant cutover is an SBC routing-table change, **not a DNS change**. See §2.1.
**Supersedes for product path:** operator CLI runbook remains the **support/engineering** reference; this doc defines the **panel-first** experience.

---

## 1. Why this doc

S8.5–S8.6 proved tenant migration **works** (affcot `08jzwn → bzy54n`, 2026-07). It did **not** produce a procedure a **PBX fleet admin** can run. Target persona: **Windows-style admin — technical but panel-driven, not CLI**. Most SARK-lineage customer admins fit this profile.

**Product significance:** decoupling **extension number** (what the phone user sees) from **SIP identity** is a core PBX3 pillar. It makes a tenant *portable* across fleet nodes — the answer to Asterisk's chronic load-balancing / re-homing pain. Tenant mobility is therefore a **headline feature**, not an ops footnote, and it deserves a first-class UI.

**Decision (2026-07-07):** Tenant move lives in the **Fleet Console only** (central admin, Model B). Per-node SPA gets a "Manage in Fleet Admin" link when a directory is configured; it does **not** host the move workflow. **Fleet deployments require an SBC tier** (§2.2) — one or more identical pbx3sbc instances; direct-to-node is solo/Rule 6 only.

**Implementers:** start at **§13** (read order, MVP scope, first PRs, contracts to draft).

---

## 2. Principles

| # | Principle |
|---|-----------|
| 1 | **Panels, not CLI.** The happy path is a wizard + job view. CLI (`tenant:export`/`import`, `move-tenant.sh`) is the escape hatch for support. |
| 2 | **Browser never touches SSH / AWS root / DNS APIs directly.** A server-side orchestrator with ops identity coordinates nodes; the SPA drives a job. |
| 3 | **S3 is the transfer pipe, not the operator's laptop.** Export uploads to a staging prefix; destination pulls it. No `scp`, no Mac-in-the-middle on the happy path. |
| 4 | **Preflight before anything destructive.** Red/green readiness (versions, fleet Egress trunk, SBC dispatcher health; `fqdninspect`/DNS only for direct fleets) gates the Start button. |
| 5 | **Human gates are first-class UI.** Irreversible source-delete and (solo/direct fleet only) DNS cutover are explicit confirm steps with exact values shown. Fleet cutover via SBC is automated. |
| 6 | **Rollback always visible.** The job shows whether abort is safe (pre source-delete) and what rollback requires. |
| 7 | **Idempotent, resumable job.** Re-open the job after a browser close; retry a failed phase without corrupting catalog or double-importing. |
| 8 | **Runtime never depends on S3 (Rule 1).** Mobility uses directory/S3 for *ops*; calls run on the node regardless. |

---

## 2.1 SBC-fronted routing — the cutover pivot (key)

**pbx3sbc** already exists (OpenSIPS edge, MySQL-driven routing, admin panel `pbx3sbc-admin` Laravel+Filament, dispatcher health checks, RTP bypass). When phones register **to the SBC** instead of directly to a node, the SBC — not DNS — decides which node serves a tenant. This changes tenant mobility more than any other factor.

### Routing model (as built)

| Table | Maps | On tenant move |
|-------|------|----------------|
| `domain` | tenant domain → `setid` | **change this row** (`setid` → destination node's set) |
| `dispatcher` | `setid` → Asterisk backend URI(s), health-checked | unchanged if one set per node already exists |
| `location` (usrloc) | registered endpoint contact, **domain-aware** | unchanged — endpoint domain doesn't change, so registrations stay valid |

**Recommended fleet convention:** **one dispatcher `setid` per node** (its backend URI + health check). Each tenant domain points at the set of its current host node. Moving a tenant = repoint that one `domain.setid` and reload.

### What this removes from the move

- **No DNS change for phones.** Phones always target the SBC (stable FQDN/IP). Tenant FQDN → node mapping lives in the SBC DB, not public DNS. → **`awaiting_dns` gate deleted** for SBC fleets; replaced by an automated `sbc_repoint` step.
- **Instant, reversible cutover.** One-row `domain.setid` update + `opensipsctl fifo cfg_reload` (or dispatcher reload). Rollback = flip the row back. Seconds, not TTL waits.
- **Edge protection centralizes.** The node `fqdninspect` SIP-STRING obscurity layer is superseded — the SBC does scanner/door-knock/domain-validation; nodes restrict SIP to the **SBC source IP(s)** (simpler and stronger than FQDN string match).
- **TLS surface shrinks.** Phone-facing SIP TLS can terminate at the SBC (one cert surface), reducing per-node per-tenant LE churn. Node↔SBC and API TLS still apply. (Decide separately — see open questions.)

### What it does NOT change

- **Tenant data still moves.** The SBC routes *signaling only*; the tenant's extensions/routes/IVRs live on the node. `tenant:export` / `tenant:import` (Phase C) are unchanged.
- **In-flight calls.** Established dialogs are pinned to the old node via `record_route`; they drain naturally. New INVITEs/REGISTERs follow the new `setid` after reload. A forced re-REGISTER (or accepting one re-registration interval) closes the gap — see open questions.

### The move primitives already exist

`scripts/add-domain.sh` (`domain → setid`), `scripts/add-dispatcher.sh` (`setid → backend`), live `cfg_reload`, and the `pbx3sbc-admin` CRUD API. The Fleet Console orchestrator drives the **repoint** via that surface rather than SSH/DNS.

### Two fleet postures

| Posture | Phones point at | Tenant cutover | Node edge/DNS work |
|---------|-----------------|----------------|--------------------|
| **SBC-fronted** (target) | SBC | SBC `domain.setid` repoint (automated, instant) | None per move |
| **Direct-to-node** (today, S8.5–S8.6) | tenant FQDN → node IP | DNS A-record change (human gate, TTL wait) | `fqdninspect`, per-node LE |

The wizard should **detect posture from the directory** and present the right cutover step. **Fleet deployments require SBC** (§2.2); direct-to-node remains supported for **solo / kick-the-tyres** only (`DESIGN_RULES.md` Rule 6).

### 2.2 Fleet model decision — SBC is required (settled 2026-07-07)

**Decision:** A fleet of PBX3 nodes **requires** one or more **identical SBC instances** (pbx3sbc) in front of the node tier. This is not optional polish for tenant mobility — it is a **structural prerequisite** of the fleet product model.

**Rationale (product + ops):**

| Need | Without SBC | With SBC tier |
|------|-------------|---------------|
| Tenant mobility | DNS cutover per move; TTL; human gates | `domain.setid` repoint; seconds; panel-automated |
| Load balancing / growth | Sticky tenants; painful re-homing | Move tenant data + repoint; phones unchanged |
| Edge security | Per-node `fqdninspect`, STRING rules, scan exposure | Centralized domain validation, door-knock, scanner drops |
| Phone provisioning | Per-tenant DNS → node IP | One stable SBC address (or SRV pool) for all phones |
| Outbound | Per-node carrier trunks; collision on move | `Egress → SBC`; carrier/LCR at edge (optional) |
| TLS | Per-node per-tenant LE churn | Phone TLS at SBC (one cert surface — TBD) |

**Multi-SBC:** Production fleets will run **≥2 identical SBCs** for redundancy. OpenSIPS is stateless at the edge (signaling only; RTP bypass); horizontal scale and failover are design goals of pbx3sbc. Exact HA topology (DNS SRV / round-robin, anycast, active-passive pair) is a **fleet infra prerequisite** — see §2.3 — not part of the move wizard itself.

**What stays direct-to-node:** Single-box evaluation, lab, and **Rule 6** solo installs — no catalog, no SBC, admin on node URL. Fleet features (Fleet Console, tenant move wizard, catalog) are **opt-in** when `org` + directory + SBC are provisioned.

**Implications for this design:**

- Phase A fleet track: **one `Egress` trunk per node** (fleet AMI); E.164 → SBC in dial/AGI (§3) — not four-name virtual trunks.
- Move wizard **cutover** for fleet = automated `sbc_repoint`; DNS gate removed from fleet happy path.
- Directory schema gains **SBC fleet records** (admin API URL, per-node dispatcher `setid`) — see §5.1.
- S8.5–S8.6 direct-to-node runbook remains the **support path** for non-SBC and break-glass.

### 2.3 SBC fleet prerequisite (HA + provisioning)

Before tenant mobility is shippable as a fleet product, operators provision:

1. **≥1 SBC** (≥2 for production) from identical pbx3sbc images; shared MySQL routing DB (or replicated).
2. **Per fleet node:** one dispatcher `setid` → `sip:{node-private-or-public-ip}:5060` (health-checked).
3. **Per tenant domain:** `domain` row → current host node's `setid`.
4. **Per fleet node:** instance trunks `Egress` (+ optional `EgressFailover`) → SBC pool; **UFW** (or successor): SIP **5060/tcp+udp from SBC IP(s) only** — no `fqdninspect` / Shorewall STRING match on fleet nodes.
5. **Phone provisioning template:** registrar/proxy = SBC address (stable); tenant domain in AoR unchanged on move.

HA mechanism (SRV, floating IP, etc.) is **TBD in pbx3sbc fleet docs** — out of scope for S8.10 wizard, but blocks "production fleet" label until defined.

### 2.4 SBC platform — continue pbx3sbc (settled 2026-07-07)

**Decision:** The fleet edge tier is **pbx3sbc** (OpenSIPS + MySQL routing + `pbx3sbc-admin`). Do **not** switch to raw Kamailio or adopt dSIPRouter for v1. Revisit only if a **revisit trigger** below fires.

**Context:** pbx3sbc is already a working minimum on test rigs — domain validation, dispatcher to Asterisk backends, endpoint location (usrloc), NAT traversal, scanner drops, RTP bypass. It is primitive vs commercial SBCs but satisfies the **fleet SBC contract** (§2.1). Carrier/peering (OpenSIPS `drouting`) is planned in pbx3sbc **`PEERING-PLAN.md`** but not yet implemented.

#### Options considered

| Option | Role | Fit for PBX3 fleet |
|--------|------|-------------------|
| **pbx3sbc** (OpenSIPS) ✓ | Thin PBX3-shaped edge; `domain` → `setid` → `dispatcher` | **Best** — move = `domain.setid` repoint; admin API exists; peering plan in-repo |
| **Raw Kamailio** | Same class as OpenSIPS (programmable proxy) | **Poor** — rewrite with no product gain; still no Fleet integration or admin |
| **dSIPRouter** | Productized Kamailio + RTPEngine + carrier GUI | **Mixed** — faster carrier/LCR UI, but second admin universe and foreign data model; integration tax on tenant move |
| **Commercial appliance** (AudioCodes, etc.) | Enterprise SBC | **Poor** for software product — cost, closed APIs, overkill for signaling-only edge |

**Why not Kamailio:** OpenSIPS and Kamailio solve the same problem with different syntax. Switching is a **near-complete rewrite** of routing, NAT, and admin — not a shortcut to "commercial grade."

**Why not dSIPRouter (for now):** Strong when **carrier interconnect** is the product center. PBX3 fleet needs a **narrow edge** (stable phone address + tenant-domain → node + optional egress). dSIPRouter would split the Windows-admin experience (Fleet Console vs dSIPRouter UI) unless heavily bridged. Revisit if **peering** on OpenSIPS stalls or carrier ops becomes the dominant surface.

#### Fleet SBC v1 scope (in / out)

**In scope (pbx3sbc):**

- Domain → dispatcher-set → health-checked Asterisk backend(s)
- Registration proxy; endpoint location for Asterisk→phone signaling
- NAT traversal; basic scanner / door-knock protection
- RTP bypass (signaling only at edge)
- **≥2 SBC instances** + shared/replicated routing DB (HA — topology TBD)
- `pbx3sbc-admin` domain + dispatcher CRUD (seed of edge admin)
- **Peering Phase 0–1** per `PEERING-PLAN.md` when egress is needed (Asterisk → SBC → carrier; inbound carrier → DID → backend)

**Explicitly out of scope v1** (do not chase commercial parity):

- Media anchoring / transcoding / RTPEngine at edge (RTP stays direct)
- Billing, rate decks, wholesale LCR product
- Lawful intercept, recording at edge
- WebRTC gateway, MS Teams SBC, etc.

#### `SbcFleetAdapter` — integration contract (de-risk swap later)

Fleet Console orchestrator talks to the edge through a **small adapter interface**, not OpenSIPS specifics. First implementation: **pbx3sbc** via `pbx3sbc-admin` API (or thin wrapper). A future dSIPRouter or other backend could implement the same contract without rewriting the move wizard.

| Method | Purpose |
|--------|---------|
| `preflight(tenantDomain, destInstanceId)` | Dest dispatcher set exists and healthy; domain row exists |
| `repointTenant(tenantDomain, destDispatcherSetId)` | Cutover — update routing so tenant domain → dest node |
| `rollbackRepoint(tenantDomain, previousSetId)` | Instant rollback before source cleanup |
| `registerNode(instanceId, backendSipUri)` | Provision/update dispatcher set for a fleet node |
| `health()` | Edge pool reachable; DB OK |

Move job **`cutover`** step calls `repointTenant` only; catalog `tenant-meta.instance_id` and SBC routing must **both** succeed in one transaction or the job fails (§4.1).

#### Revisit triggers (when to re-open platform choice)

| Trigger | Likely direction |
|---------|------------------|
| **Peering** on OpenSIPS `drouting` fails a **time-boxed** sprint | Hire OpenSIPS depth or evaluate dSIPRouter for carrier layer |
| **RTP/NAT unsolvable at fleet scale** | Evaluate **dSIPRouter** (+ RTPEngine) per §11.5 |
| **HA / security** cannot reach production bar with available effort | Evaluate managed edge or dSIPRouter ops model |
| **Carrier ops** becomes primary product (many trunks, LCR GUI, rate decks) | dSIPRouter or commercial may win |
| Fleet Console **must not** own any edge config | Accept split admin → dSIPRouter native UI |

Until a trigger fires: **invest in pbx3sbc** (HA doc, peering Phase 0, adapter API on `pbx3sbc-admin`), not a platform migration.

### 2.5 Superadmin homing — separate control-plane app (leaning, 2026-07-07)

**Question:** where does fleet **superadmin** functionality live? (`CENTRAL_ADMIN_DIRECTION` §4 already names *"Superuser / MSP — one login, many instances"*.)

**Superadmin is a distinct plane, not a bigger tenant admin:**

| | Tenant/operator admin | Superadmin (fleet) |
|---|---|---|
| Scope | one tenant on one node | whole fleet |
| System of record | node sqlite via `:44300` | **S3 directory + edge routing** |
| Worst-case mistake | breaks one tenant | strands/moves many tenants; repoints the edge |
| Needs | CRUD panels | CRUD **+ durable jobs + credentials + adapters + ACL tier** |

**Ruled out:** SPA-only (browser can't hold secrets / run jobs / write S3); a "primary node" `pbx3api` (breaks shared-nothing, SPOF snowflake); inside tenant `pbx3api` (fleet-destroying power in the tenant trust tier).

**Decision (leaning): a dedicated fleet control-plane service** — Laravel+Filament, own origin + own auth, owning **S3 directory (home of record) + orchestrator (queues) + adapters** (`S3DirectoryAdapter`, `SbcFleetAdapter`, `NodeApiAdapter`). This is the `pbx3-directory` stub becoming a real service.

**Do NOT home superadmin inside `pbx3sbc-admin`.** Tempting (already Laravel+Filament, already owns SBC MySQL), but it **couples the control plane to the edge platform and spends the dSIPRouter escape hatch**:

- dSIPRouter is a **Kamailio** product with its **own admin GUI + REST API + data model**. Swapping to it swaps the whole edge admin universe.
- If superadmin lives *inside* `pbx3sbc-admin`, an edge swap drags the orchestrator/wizard/directory with it → **rewrite the control plane**.
- If superadmin is **separate, calling through `SbcFleetAdapter` (§2.4)**, the edge is a replaceable implementation → adopting dSIPRouter = write a `DsipRouterAdapter` + projector, swap the binding, control plane untouched.

**The seam is only load-bearing if:**
1. **Adapter speaks *intent*, not schema** — `repointTenant` / `setDidDelivery` / `dispatcherMembership`, never raw `INSERT INTO dr_rules`. Leaked OpenSIPS schema = fake abstraction.
2. **S3 is home of record; edge is a projection (§11.10)** — swapping edge = new projector (S3 → new platform) + new adapter; the platform-neutral source of truth stays put. **The edge becomes disposable, not merely swappable.**

**Role of `pbx3sbc-admin` under this decision:** stays a **thin local edge admin / break-glass tool for the SBC only**, *behind* the adapter — it does **not** grow into the fleet console.

**Settled on merit (survives independent scrutiny — follows from prior commitments, not from a stated preference):** the control plane is a **separate service/backend + trust tier**, sits on the **caller side** of `SbcFleetAdapter`, and **must fail safe**. This rests on three preference-independent arguments: (1) **trust boundary** — fleet-destroying power must not share an app/token tier with tenant operators (multi-tenant security, not aesthetics); (2) **fail-safe is a `DESIGN_RULES` rule** — nodes + SBC keep routing if the console is down; superadmin is never a runtime dependency of a call; (3) **S3 home-of-record + adapter seam (§11.10)** — the orchestrator must not live inside a target it orchestrates. The security boundary lives in the **backend + auth tier**, *not* in the number of visible UIs.

**Genuinely open (taste / product calls — do not over-anchor):**
- **UI presentation** — one unified operator shell (role-gated superadmin panels, single padlock) vs two visibly separate apps. **Either satisfies the trust boundary** as long as the *backend* control plane + auth tier is separate. Weak lean: two apps; low confidence.
- **Identity model** — shared central IdP with operators (SSO, ACL-scoped) vs wholly separate superadmin credentials (§5 leaves open).

**When the alternative wins (honest caveat):** small/static fleet + single-person ops + dSIPRouter genuinely off the table → role-gated panels in one app is a defensible ship-faster call; the separate-*service* discipline still matters most for the backend/trust tier.

#### 2.5.1 Physical deployment — ops note (2026-07-07)

**Settled:** control plane is **not** on the SBC (`pbx3sbc-admin` stays edge-only; §2.5). **Open:** which **host** runs the separate service — an ops choice, not an architectural gate.

**Either suffices:** a **small EC2** in the fleet VPC **or** a **local VM** (dev Mac / lab hypervisor). The service is **low-traffic management** (infrequent catalog writes, move jobs, presigns) and **fail-safe** — calls continue if it is down; worst case is no move/onboard until it returns. HA (second instance, queue failover) can wait.

| Requirement | Implication |
|-------------|-------------|
| S3 gatekeeper writes (`catalog/*`, `tenants/*/meta.json`, presigns) | AWS credentials with org/fleet IAM (see below) |
| `NodeApiAdapter` | Outbound HTTPS to every fleet node `:44300` |
| `SbcFleetAdapter` | Outbound HTTPS to `pbx3sbc-admin` API |
| Durable jobs (move orchestrator) | Persistent host + small DB/queue — not serverless-first for v1 |

| Option | Fit | Notes |
|--------|-----|-------|
| **Small EC2** (e.g. `t3.small` / `t4g.small`) | **Production fleet** (lean) | **Instance role** for S3 — no long-lived keys; same network neighborhood as nodes + SBC; natural when fleet is already AWS-hosted |
| **Local VM / dev host** | **B′/C build + lab** | Static IAM in `.env` or shared ops profile; must reach node + SBC APIs over VPN/internet; fine for golden validation before committing to a hosted box |

**Not on the table:** co-hosting fleet superadmin **inside** the SBC stack (see §2.5). The SBC is an **API client** of the control plane, not its home.

**§6** orchestrator endpoints run on this same host; no separate “orchestrator box” in v1.

### 2.6 S3 gatekeeper — org-level security domain (2026-07-07)

**Observation:** S3 is **not owned by any instance or tenant**. It is **org/fleet infrastructure** — shared bucket, stable prefixes (`catalog/`, `instances/{ksuid}/`, `tenants/{shortuid}/`), cross-cutting metadata (instance index, tenant homing, DID inventory, export staging). Instances and tenants each have **their own security subsystems** (Sanctum on `:44300`, local users, Shorewall). S3 needs a **third**, quite separate security arrangement — and that points to a **separate service** (whatever it is written in).

**Three trust domains (not two):**

| Domain | Owns | Security today | Problem |
|--------|------|----------------|---------|
| **Tenant** | dialplan, extensions, `inroutes` behaviour | node sqlite + tenant-scoped API abilities | Correct — sovereign per tenant on a node |
| **Instance** | Asterisk, LE, firewall, local admin users | Sanctum + `whoami` on `:44300` | Correct — EC2-like per-cell IAM (`DESIGN_RULES`) |
| **Org / fleet (S3)** | catalog, homing, DID inventory, cross-tenant ops, export staging | **Split and incomplete** — Mac ops IAM + per-node instance profile + registrar shell scripts | **No owner**; no unified policy engine or audit |

`DESIGN_RULES` maps console vs instance IAM well, but S3 is a **shared asset with no cell boundary**. Parking fleet security inside a node API or tenant API would let one cell's compromise affect org-wide data.

**Current patchwork (honest):**

- **Mac operator** — broad IAM for `catalog/*`, `instances/*`, `tenants/*` via registrar scripts (`register-instance.sh`, `move-tenant.sh`). Works for v0; not a product security model.
- **Node instance profile** — scoped template (`pbx3-node-s3-writer.policy.json.tmpl`) for `instances/{ksuid}/*` **and** `tenants/*`. The `tenants/*` grant is **too wide**: any node can write any tenant prefix. A compromised node could corrupt another tenant's `meta.json` or recordings path. Evidence the model is unfinished.
- **SPA** — read-only `GET` on public `catalog/` (v0); no S3 write (correct).

**S3 gatekeeper — role of the fleet control plane:**

The control-plane service (§2.5) is not only "superadmin UI + move wizard." Its core job includes being the **authoritative gatekeeper for org S3 mutations**:

| Responsibility | Gatekeeper | Node (tightened IAM) |
|----------------|------------|----------------------|
| `catalog/instance-index.json` read | public or authenticated GET | no write |
| `catalog/*`, `tenants/*/meta.json`, `tenants/*/dids.json` write | **gatekeeper only** | no write |
| Tenant move / DID assign / onboard | gatekeeper orchestrates + audits | receives node-local steps via API |
| Export staging (`tenants/.../staging/`) | gatekeeper issues paths or presigned URLs | read/write **own** staging keys only |
| Backups `instances/{ksuid}/backups/` | optional presigned PUT from gatekeeper | **or** direct IAM — **own ksuid prefix only** |
| Recordings `tenants/{shortuid}/recordings/` | presigned PUT scoped to tenants **this node hosts** | no blanket `tenants/*` write |

**Fail-safe (Rule 1 preserved):** gatekeeper down → **calls continue**; nodes can still upload backups/recordings via **tight, prefix-scoped IAM** (or cached presigned URLs). Gatekeeper is required for **catalog mutations** (move, onboard, DID assign) — acceptable; those are infrequent ops, not runtime telephony.

**Convergence with §2.5:** the separate control-plane service and the S3 gatekeeper are **the same thing**, not two apps. Superadmin panels, move orchestrator, `SbcFleetAdapter`, and S3 policy engine share one backend + one fleet identity. This is an **independent** argument for a separate service — not UI taste, not dSIPRouter optionality, not superadmin blast radius alone.

**Follow-ups:** (a) tighten node IAM — see **§2.6.1** (concrete gap + migration); (b) `S3Gatekeeper` adapter in control plane (wraps AWS SDK / registrar logic); (c) audit log for every catalog mutation; (d) migrate Mac registrar scripts into gatekeeper API (scripts become thin CLI clients).

#### 2.6.1 Node IAM tightening — `tenants/*` gap (action item)

**The vulnerability (today):** `pbx3-node-s3-writer.policy.json.tmpl` grants every fleet node:

```json
"Resource": [
  "arn:aws:s3:::__BUCKET__/instances/__INSTANCE_KSUID__/*",
  "arn:aws:s3:::__BUCKET__/tenants/*"
]
```

and `ListBucket` on prefix `tenants/*`. **Any compromised node can read/write any tenant prefix** in the org bucket — including another tenant's `meta.json` (fleet homing), `dids.json` (§11.10), recordings, backups, and migration staging. This contradicts the EC2-like per-cell model (`DESIGN_RULES`) and is the clearest evidence that org S3 needs its own security owner (§2.6).

**What nodes actually need (by prefix):**

| S3 prefix | Writer today | Writer target | Notes |
|-----------|--------------|---------------|-------|
| `catalog/*` | Mac ops only | **gatekeeper only** | SPA read-only GET (v0) |
| `instances/{own_ksuid}/backups/*` | node (Flysystem) | **node** (direct IAM) | Already correct scope; `InstanceBackupDirectoryUpload` |
| `tenants/{shortuid}/meta.json`, `dids.json` | Mac ops / registrar | **gatekeeper only** | Tenant homing + DID inventory — never on node role |
| `tenants/{shortuid}/migration/{job_id}/*` | (planned §7) | **gatekeeper-issued presign** or orchestrator-mediated | Source PUT + dest GET for move staging |
| `tenants/{shortuid}/recordings/*` | (future S7/R1) | **presigned PUT** scoped to hosted tenants | Not blanket `tenants/*` on node role |

**v1 interim fix (ship before or with Phase B′):** drop `tenants/*` from the node policy entirely. Nodes retain **only** `instances/{own_ksuid}/*` (+ `ListBucket` on that prefix). This is safe **today** because live code paths write backups under `instances/` only (`pbx3api` `InstanceBackupDirectoryUpload`, `pbx3:upload-backup`). Recordings offload and tenant-export→S3 staging are not production yet — they should land with presigns, not by re-opening `tenants/*`.

**Target model (when recordings + move staging ship):**

```text
Node needs bulk write to tenants/{shortuid}/…
  → node asks gatekeeper (or orchestrator): "presign PUT for tenant T, path P"
  → gatekeeper checks: tenant T is hosted on this instance (catalog meta.instance_id)
  → returns short-TTL presigned URL(s)
  → node uploads async (Rule 1 — no call-path dependency)
```

For **migration staging**, the orchestrator (gatekeeper) issues presigns to **source** (export zip PUT) and **dest** (GET/import) — nodes never hold fleet-wide tenant write keys.

**Alternative (heavier, defer):** dynamic IAM policy on the instance role, updated by gatekeeper on tenant move/onboard to list only `tenants/{shortuid}/recordings/*` for hosted shortuids. Possible but operationally brittle (IAM propagation lag, move race). **Presigned URLs are the default path.**

**Artifacts to change:**

| Artifact | Change |
|----------|--------|
| `schema/pbx3-node-s3-writer.policy.json.tmpl` | Remove `tenants/*` from List + Write; document presign path for future tenant bulk |
| `docs/OPS_S3_RUNBOOK.md` §7.1 | Match tightened policy; note gatekeeper owns `tenants/*` |
| `tools/onboard-fleet-instance.sh` | Attach tightened policy on new nodes |
| `FleetPreflightService` (`pbx3:fleet-preflight`) | Optional check: node role **must not** have `tenants/*` write (negative test) |
| Control plane (Phase B′) | `POST /s3/presign` (recordings, staging); audit log |
| Existing fleet nodes | Ops runbook: replace attached IAM policy; verify backup smoke still passes |

**Migration (existing nodes):** update IAM policy in place (same role name); re-run backup smoke (`aws s3 cp` to `instances/{ksuid}/backups/_iam-test.txt`). No node reboot required. **Do not** remove `tenants/*` until recordings upload path uses presigns — but **do** remove it now if recordings S3 is not enabled (current golden state).

**Fail-safe preserved:** tightened node IAM does **not** block calls or local backups. S3 backup upload continues under `instances/{own_ksuid}/`. Gatekeeper down blocks catalog mutations and presign issuance for *new* recordings/staging — acceptable for infrequent ops; local disk remains authoritative until upload succeeds.

**Gotcha cross-ref:** see §11 #21.

---

## 3. Outbound routing — fleet vs solo (Phase A)

### Problem today (blocks tenant move on direct fleets)

Outbound routes store **real trunk `pkey` strings** in `route.path1..path4`. Trunks are **instance-owned** and **excluded** from the tenant export mini-DB. After import, `path1='ael3'` dangles unless that trunk exists on the destination — a failure a panel admin cannot diagnose.

### Fleet model (SBC egress) — trunks question largely goes away

With **pbx3sbc as the fleet edge** (§2.2–§2.4), instances are **not** carrier endpoints. They have **one signalling peer to the neighborhood SBC** (optionally **one failover** peer to a secondary SBC). Carrier trunks, LCR, prefix rules, and PSTN failover live on the **SBC** (`PEERING-PLAN.md` / `drouting`).

**Routing rule at the node (conceptual):**

```text
extension dials digits
    → match tenant route dialplan (egress filter — intl codes, domestic, etc.)
    → if permitted: seize Egress trunk (→ SBC)
    → else: no route / deny
internal extension-to-extension  →  tenant dialplan (unchanged; no egress)
```

Aligns with pbx3sbc peering design: once on `Egress`, PSTN handling and carrier selection are **SBC-side**. The node does not choose carrier trunks or `path2`–`path4` failover.

| Layer | Owns | Fleet instance has |
|-------|------|-------------------|
| **SBC** | Carriers, DIDs, LCR, outbound prefix→gateway, inbound carrier→tenant | — |
| **Node (instance)** | Extensions, IVR, queues, tenant policy | **1× `Egress`** (+ optional **1× `EgressFailover`**) → SBC URI |
| **Tenant miniDB** | Dialplan match, CoS, auth PIN, CLID policy | Routes that **match** digits; **path** is always `Egress` (implicit or literal) |

**Tenant move:** export/import unchanged. Every fleet node already has the same `Egress` trunk (fleet AMI / onboarding). **No trunk remap, no virtual-trunk map table, no per-move trunk preflight** — only SBC `domain.setid` repoint.

### Routes stay — trunk choice goes

**Outbound `route` rows are not going away.** They remain the **main local filter** for what is allowed to gain egress to the SBC. The node decides *whether* a dialled string may leave the tenant; the SBC decides *how* it leaves (carrier, LCR, failover).

```text
Extension dials digits
    → Asterisk dialplan matches tenant route (dialplan pattern)   ← still here
    → route policy: auth, CoS, CLID, active                      ← still here
    → if matched and permitted: seize Egress (→ SBC)             ← path fixed; no trunk picker
    → SBC: prefix / carrier / failover                           ← not in tenant DB
```

**Examples of what routes still govern (per tenant):**

- Which **international dial codes** are permitted (`_011.`, country-prefix patterns, etc.)
- Domestic vs mobile vs premium-rate patterns (separate route rows, same egress)
- **Auth** (PIN required for certain prefixes)
- **CLID** presentation before handoff to SBC
- **Active** / inactive route rows (soft deny without deleting pattern)

Different tenants on the same node can have **different egress filters** while sharing the same physical `Egress` trunk — e.g. tenant A allows `+44…`, tenant B does not. That policy travels in the tenant miniDB on move; no trunk alignment needed.

**What changes in the route model (fleet):**

| Column / UX | Fleet behaviour |
|-------------|-----------------|
| **`path1`** | Always **`Egress`** (implicit default or hidden field) — not operator-chosen |
| **`path2`–`path4`** | **Unused** for fleet — carrier failover is SBC-side |
| **Trunk picker in SPA** | **Removed** on fleet nodes |
| **`dialplan`** | **Unchanged** — primary egress gate |
| **`auth`, CLID, `active`, etc.** | **Unchanged** |

**What moves to the SBC (not in tenant routes):** carrier selection, PSTN prefix→gateway rules, trunk registration, outbound failover between carriers.

### Phase A scope — fleet (SBC) track (primary)

1. **Fleet AMI / node onboarding:** pre-provision instance trunks `Egress` (+ optional `EgressFailover`) → SBC pool URI(s). Identical on every node; not tenant-scoped.
2. **Generator + pbx3cagi:** route policy in AGI (auth, etc.); **no trunk failover loop** — AGI returns to Asterisk to dial via `Egress` trunk peer (§11.3). Dialplan match unchanged.
3. **SPA/API:** fleet outbound route panels **keep dialplan + policy fields**; **remove trunk/path pickers** (`path1` hidden or fixed to `Egress`). Solo nodes keep today's behaviour.
4. **Migration preflight:** fleet move checks **node has Egress trunk** (fleet template), not per-route trunk resolution. Tenant route rows import as-is.

No `vtrunk_map` table required for fleet.

### Phase A scope — solo / direct track (Rule 6)

Non-SBC installs keep today's model until needed:

- Real trunks on node; route `path1`–`path4` as today, **or**
- Four-name virtual trunks (`Primary`, …) + instance map if direct fleet without SBC is ever required.

Tenant move on **direct-to-node** (S8.5–S8.6 runbook) still needs trunk pkey alignment or virtual names — **not** the fleet product path.

### Implementation note

`pbx3cagi` today loads `path1..path4` from `Route` per dialplan key (`sqlite_create_tenant.sql`). Fleet work: **`path1` → `Egress` by convention**; strip path UI in SPA; route **dialplan remains the egress filter**. Carrier/LCR complexity belongs on the SBC (`PEERING-PLAN.md`), not in fewer route rows.

> **Fleet Phase A:** provision `Egress` once per node; fix route path to egress; **keep route dialplan as tenant policy filter**. Tenant mobility: no trunk remap on move.

---

## 4. Fleet Console shell (Phase B)

Depends on **Central admin Model B** instance directory (`CENTRAL_ADMIN_DIRECTION.md` §3). Move is a cross-node action, so a fleet-wide view is a hard prerequisite.

- **Fleet → Instances** — list from directory (`instance-index.json` / API): label, fqdn, status, version.
- **Fleet → Tenants** — fleet-wide tenant list assembled from catalog `tenants/{shortuid}/meta.json` (current `instance_id`, fqdn, status). This is the launch point for **[Move tenant…]**.
- Per-node SPA tenant panel shows **"Manage in Fleet Admin"** when `VITE_INSTANCE_DIRECTORY_URL` is set; no move UI on the node.

### 4.1 Directory schema additions (fleet + SBC)

Fleet Console and the move orchestrator need SBC metadata in the directory (alongside instance and tenant catalog rows):

**`sbc-fleet` record (v0 sketch)** — one per org / edge pool:

| Field | Purpose |
|-------|---------|
| `id` | Stable SBC pool id |
| `sip_proxy_fqdn` | Phone-facing address (or SRV name) |
| `admin_api_url` | `pbx3sbc-admin` API base for repoint CRUD |
| `member_hosts` | List of SBC instance FQDNs/IPs (HA pool) |
| `status` | active / maintenance |

**`instance-record` extension:**

| Field | Purpose |
|-------|---------|
| `sbc_dispatcher_setid` | This node's `setid` in the SBC `dispatcher` table — target for `domain.setid` on move |

**`tenant-meta` extension (optional):**

| Field | Purpose |
|-------|---------|
| `sbc_domain` | Tenant SIP domain as registered in SBC `domain` table (usually = `fqdn`) |

**Source of truth for cutover (settled §10):** **S3 directory** owns `tenant→node` (`meta.json.instance_id`) and `DID→tenant` (`dids.json`, §11.10). **SBC DB is a compiled projection** — the orchestrator writes S3 first, then calls `SbcFleetAdapter` to project (`domain.setid`, `dr_rules`). On move, **both** S3 `instance_id` update and SBC repoint must succeed in one job transaction or the job fails + rolls back (§11 #2). Reconcile job flags drift.

---

## 5. Move wizard + job (Phase C)

### Wizard steps (admin-facing)

```text
[Move tenant]
 1. Pick tenant           (fleet tenant list → affcot @ 08jzwn)
 2. Pick destination      (fleet instance list → bzy54n)  [only shows eligible nodes]
 3. Preflight (auto)      ── must be all-green to continue
 4. Options              (include on-node recordings? maintenance quiesce?)
 5. Review & Start        (shows what runs vs what you must do)
 → Job view
```

### Preflight checks (the hero screen)

| Check | Green condition | Fails loud when |
|-------|-----------------|-----------------|
| Destination version | ≥ source pbx3 / pbx3api | dest on older deb (e.g. 0.0.3-10) |
| Destination health | `pbx3:fleet-preflight` green | onboard/IAM/.env drift |
| Same SIP domain | `globals.domain` match | mismatched domains |
| **Fleet Egress trunk** | dest has `Egress` (+ optional failover) → SBC | missing fleet template trunks |
| Tenant name/shortuid | no collision on dest (or `--replace` chosen) | existing row |
| **SBC reachability** (SBC fleet) | dest node's dispatcher `setid` exists + healthy; SBC can reach dest backend | no set for dest / dispatcher DOWN |
| **Node S3 IAM** (fleet) | instance role has `instances/{ksuid}/*` only — **no** `tenants/*` write (§2.6.1) | over-broad policy on source/dest |
| `fqdninspect` (direct fleet only) | dest `YES` (if fleet uses SIP STRING match) | `NO` → phones won't register |
| DNS ownership (direct fleet only) | admin can update `{tenant}.fqdn` A record | (informational; gated later) |

### Job state machine

```text
pending
  → preflight            (green gate)
  → exporting            (source: tenant:export [+recordings] → S3 staging)
  → transferring         (dest pulls from S3 staging prefix)
  → importing            (dest: tenant:import [--replace])
  → configuring          (dest: Commit / genAst + reload; verify symlinks)
  → cutover              (SBC fleet: sbc_repoint domain.setid → dest set + reload   [automated]
                          direct fleet: awaiting_dns HUMAN gate — A record → dest IP)
  → awaiting_certs       (edge/node Certificates Sync as posture requires)
  → verifying            (registration + test call confirmation)
  → catalog              (move-tenant.sh equivalent: meta.json instance_id → dest)
  → awaiting_cleanup     (HUMAN gate: delete tenant on source — IRREVERSIBLE)
  → completed | failed | aborted
```

- **`cutover` is posture-aware** (§2.1). **SBC fleet:** orchestrator updates `domain.setid` on the SBC and reloads — automated, sub-second, reversible; no human gate. **Direct fleet:** `awaiting_dns` human gate with exact record + expected IP + `dig` check.
- Each node-side step is an **authenticated API call** the orchestrator makes (not SSH). Node exposes export/import/commit/cert-sync; the SBC exposes repoint via `pbx3sbc-admin` API or `add-domain.sh` + `cfg_reload`.
- **Rollback boundary:** anything before `awaiting_cleanup` is safe to abort. SBC fleet rollback = flip `domain.setid` back (seconds). Direct fleet = revert DNS (TTL wait). After source delete, rollback = re-import from the staging zip (retained N days).
- **In-flight calls at cutover (SBC):** established dialogs drain on the old node (record-route pinned); new registrations/calls follow the new set. Optionally trigger re-REGISTER to shorten the window (open question).

### S3 staging path

```
tenants/{shortuid}/migration/{job_id}/pbx3tenant.{shortuid}.{epoch}.zip
tenants/{shortuid}/migration/{job_id}/job.json          (state, for resume/audit)
```

Recordings under `tenants/{shortuid}/recordings/` are **unchanged** by a move (catalog pointer only). On-node wav bundling stays opt-in (`--include-recordings`).

---

## 6. Orchestrator (server-side)

Start **thin**; it can later merge with the S8.9 rebuild orchestrator (`SELF_SERVICE_REBUILD_DESIGN.md`).

- **Home (settled §2.5):** **fleet control-plane service** — separate deployable (grown from `pbx3-directory` stub / Laravel+Filament stack like `pbx3sbc-admin`). **Not** a fleet namespace inside tenant `pbx3api`. Owns **S3 gatekeeper** (§2.6), job queue, and adapters. Holds fleet ops identity for catalog writes; calls node APIs via `NodeApiAdapter`. **Physical host:** small EC2 or local VM — see **§2.5.1** (ops choice; not on SBC).
- **Endpoints (sketch — implement in control plane):**
  - `POST /fleet/tenant-moves` → `{tenant, source_instance, dest_instance, options}` → `job_id`
  - `GET /fleet/tenant-moves/{id}` → state + per-phase status + next human action
  - `POST /fleet/tenant-moves/{id}/advance` (confirm a human gate) / `/retry` / `/abort`
  - `POST /s3/presign` → scoped PUT/GET for node bulk (§2.6.1) — Phase B′+
- **Node contract:** node APIs must expose export→S3, import←S3, commit, cert-sync, preflight as **authenticated HTTP actions** (§13.3). Today these exist as **artisan CLI only** (`tenant:export` / `tenant:import`, `pbx3:fleet-preflight`) — wrapping behind API is a **prerequisite for Phase C**.
- **SBC contract (SBC fleet):** cutover via **`SbcFleetAdapter`** (§2.4) — first implementation calls `pbx3sbc-admin` API (`repointTenant`, `preflight`, `rollbackRepoint`). Escape hatch: `add-domain.sh` + `opensipsctl fifo cfg_reload`. Directory carries SBC `admin_api_url` + per-node `sbc_dispatcher_setid`. **Adapter backend API may need to be built** on pbx3sbc-admin (§13.3).
- **Never on node:** IAM association with ops admin creds; DNS registrar admin; catalog / `tenants/*/meta.json` writes. Those are control-plane or explicit human steps.

---

## 7. DNS & certs

- **SBC fleet (target): DNS is a non-event.** Phone-facing DNS points at the SBC and never changes on a move; cutover is the SBC `domain.setid` repoint (§2.1). Public per-tenant A records are not required for phone routing.
- **Direct fleet (no SBC):** DNS cutover remains. **Phase D, optional:** Route53 integration to auto-apply the A record at `awaiting_dns`. Otherwise wizard shows the exact record + expected IP, offers a `dig` check, requires **"I've updated DNS"** confirmation.
- **Certs:**
  - *Direct fleet:* destination **Certificates → Sync** (tenant FQDN into SANs) at cutover; source Sync at cleanup. Node LE scripts unchanged (Option A already shipped).
  - *SBC fleet:* phone-facing SIP TLS can terminate at the SBC (one cert surface), largely removing per-node per-tenant LE churn. Node↔SBC and API TLS still apply. **Not yet decided** — see open questions.

---

## 8. Build order & sequencing

| Phase | Deliverable | Repos | Rough size |
|-------|-------------|-------|-----------|
| **A** | Fleet egress: `Egress` trunk per node (AMI); E.164→SBC in generator/AGI; simplify route SPA (no trunk picker) | pbx3, pbx3cagi, pbx3api, pbx3spa | smaller than virtual-trunk map |
| **B** | Fleet Console shell: instance picker (directory) + fleet tenant list | pbx3spa (+ directory read) | ~1 wk |
| **B′** | **Fleet control-plane service scaffold (§2.5–2.6):** own origin + fleet auth; **S3 gatekeeper** (`S3DirectoryAdapter` + sole writer for `catalog/*`, `tenants/*/meta.json`); adopt registrar logic behind an API; **node IAM tighten** (§2.6.1 — drop `tenants/*` from `pbx3-node-s3-writer.policy.json.tmpl`, update runbook + onboard) | new service (grown from `pbx3-directory` stub / `pbx3sbc-admin` stack) + `pbx3-directory/schema` | medium |
| **C** | Move wizard + orchestrator job API + S3 staging transfer + preflight; `SbcFleetAdapter` + `NodeApiAdapter` | control-plane service, pbx3spa | larger |
| **D** | DNS (Route53) + deeper cert automation | control-plane service | optional |

**Order rule:** **A before C** (fleet nodes must have Egress + E.164 rule before moves are safe). B before/with C. **B′ is the home for C's orchestrator** — stand up the control-plane/gatekeeper shell before wiring the move job; the reconcile/drift job (§11.10) and **node-IAM tightening (§2.6.1)** also live here. **§2.6.1 v1 interim** (drop `tenants/*` from node policy) can land **early** — safe before B′ ships because backups already use `instances/{ksuid}` only. D last (direct fleets only).

**SBC-fronted fleet (default per §2.2):** Phase A = `Egress → SBC` per node; Phase C `cutover` = automated SBC repoint; Phase D (DNS) not on critical path. **§2.3 SBC HA + provisioning** is a fleet-infra gate before "production fleet" label.

### Relationship to R1 (recordings)

Independent — can run in parallel:
- R1 = local-disk recordings list/play on one node; no fleet dependency.
- Mobility = fleet egress + Fleet Console UI; no recordings dependency (S3 recordings prefix already stays put on move).

If a single implementer must sequence: **Phase A first** (also improves daily outbound-route UX), then R1 can slot alongside A/B since it's single-node pbx3api + SPA.

---

## 9. Out of scope (v1)

- SPA-driven EC2 lifecycle (that's S8.9 rebuild orchestrator; may share the job engine later).
- Automatic DNS for non-Route53 registrars.
- Copying S3 recordings prefix on move (unchanged by design).
- Tenant-owned (BYOC) trunks — later `owner = HOST|TENANT` phase.
- Terraform / multi-cloud fleet provisioning.

---

## 10. Open questions

1. **Cutover call-drain:** ~~force re-REGISTER vs wait~~ — **Settled (§11.1):** accept registration lag as fact; short reg interval (e.g. **5 min**) ameliorates; wizard documents drain + keep source until verified. Optional force re-REGISTER remains nice-to-have.
3. **SBC HA topology:** DNS SRV vs round-robin vs anycast vs active-passive — document in pbx3sbc fleet guide; blocks production fleet label.
4. **TLS at edge:** terminate phone SIP-TLS at the SBC (one cert surface) vs keep per-node per-tenant LE? Interacts with `LETSENCRYPT_PER_TENANT_FQDN.md` Option A already shipped. (Gotcha #9 — API/admin TLS stays per-node regardless.)
5. **SBC vs node filter boundary:** node route denies by pattern (e.g. intl codes); SBC may apply additional carrier/LCR rules — document who wins on overlap.
7. **Fleet service auth (mechanism):** trust tier is settled (§2.6 — org/fleet identity, separate from tenant/instance), but the **mechanism** by which the control plane authenticates to node APIs **and** the SBC admin API (dedicated service token vs admin bearer) is open. Must not break `AUTH_PATTERNS.md` whoami contract.
8. **DID assignment/inventory authoring (§11.9):** tenant panel ("claim a DID") vs fleet DID-inventory panel (MSP number management) vs both. Delivery row is derived either way; this is *where ownership is entered*.
9. **Superadmin UI presentation (§2.5):** one unified operator shell (role-gated) vs two visibly separate apps. Backend separation settled; UI is taste. Weak lean: two apps.
10. **Superadmin identity model (§2.5):** shared central IdP with operators (SSO, ACL-scoped) vs wholly separate superadmin credentials.

### Settled (no longer open)

- **SBC required for fleet** — one or more identical SBCs; direct-to-node = solo/Rule 6 only (§2.2).
- **SBC platform** — continue **pbx3sbc**; not Kamailio rewrite or dSIPRouter for v1; `SbcFleetAdapter` contract (§2.4).
- **Phase A fleet** — one `Egress` (+ optional failover) per node; E.164 → SBC; no virtual-trunk map (§3).
- **Cutover for fleet** — SBC `domain.setid` repoint; no DNS gate on happy path.
- **SBC routing source of truth** (was Q2) — **directory (S3) owns `tenant→node` and `DID→tenant`; SBC DB is a compiled projection** (§11.10). Console never treats the SBC as home of record; consistency via re-projection + reconcile job.
- **Orchestrator / control-plane home** (was Q6) — **separate fleet control-plane service** (§2.5), not a fleet namespace inside tenant `pbx3api`. Also the **S3 gatekeeper** (§2.6).
- **Fleet trust tier** — **three domains: tenant / instance / org-fleet (S3)** (§2.6); org-fleet security is its own subsystem, owned by the control plane.
- **Node IAM `tenants/*` gap** — v1 interim: drop blanket `tenants/*` from node instance profile (§2.6.1); safe now; future bulk via gatekeeper presigns.
- **Gotchas 1–5** — registration drain (5 min reg helps); standardized trunk pkeys on takeover; AGI defers dial to Asterisk (no path failover); node firewall = SBC IP(s) only on 5060 (UFW, retire Shorewall STRING match); RTP stays on Asterisk (dsiprouter revisit if media becomes unsolvable).

---

## 11. Architectural gotchas (review 2026-07-07)

Likely trip points when implementing SBC-fronted fleet + tenant mobility. Severity: **H** high (blocks or data loss), **M** medium (ops pain / subtle bugs), **L** lower (planning / polish).

### Decisions on gotchas 1–5 (2026-07-07)

| # | Decision |
|---|----------|
| **1** | **Registration lag is a fact** after SBC repoint — not eliminable. **Mitigation:** short phone registration interval (e.g. **5 minutes**) reduces worst-case window; move wizard still documents in-flight call drain and defers source delete until verified. |
| **2** | **Standardize fleet trunk `pkey` names** (`Egress`, optional `EgressFailover`). On legacy **data takeover** / tenant import to a fleet node, **insert normalized values** into `route.path1` (and clear `path2`–`path4`) as part of migration — not a manual operator step. |
| **3** | **`pbx3cagi` outbound changes.** AGI **no longer implements trunk failover** (path rotation loop becomes redundant). After route policy (auth, etc.), AGI **returns control to Asterisk** to place the outbound dial via the standard trunk/Egress peer — simpler and consistent with "Asterisk handles the dial." |
| **4** | **Node edge firewall:** no SIP URI / packet inspection (`fqdninspect` / `pbx3_inline_fqdn` retired on fleet nodes). Allow **SIP UDP/TCP 5060 only from SBC IP address(es)**. **Shorewall is EOL** — fleet template moves to **UFW** (or equivalent). Skip `update-fqdn-inline.sh` on fleet `tenant:import`. |
| **5** | **RTP bypass stays** — Asterisk handles media/NAT (keeps load off SBC). Follow proxy NAT docs per node; fleet AMI bakes PJSIP NAT policy. If RTP/NAT becomes unsolvable at scale → **revisit trigger for dSIPRouter** (RTPEngine path), not a v1 blocker. |
| **6** | **RTP-from-anywhere is accepted and largely unavoidable.** With RTP bypass, media is phone ↔ Asterisk and phones roam behind arbitrary NAT IPs — **RTP cannot be IP-whitelisted like SIP-from-SBC**. **Risk is low** because SIP is gated to the SBC (no signaling foothold ⇒ attacker can't learn live RTP ports or beat `strictrtp`), `direct_media=no` anchors media, and `rtp_symmetric=yes` is set. Residual = **blind UDP flood DoS** on the RTP range. **Mitigations (not blockers):** (1) make **`strictrtp=yes` explicit** in `rtp.conf`; (2) **per-source rate-limit** RTP UDP range in node firewall (UFW/nftables `limit`); (3) **tighten RTP range** to real capacity (currently 10000–20000); (4) **SRTP** (`media_encryption=sdes`, already stubbed in `pjsip_phone.tmpl`) as future escalation for media integrity/confidentiality. |
| **7** | **Fleet node SIP firewall = "5060 from SBC IP(s)" + `fqdninspect=NO` — two actions, not one toggle.** The `fqdninspect` panel toggle only controls the **`pbx3_inline_fqdn` STRING-match** include; turning it off falls back to the base **`pbx3_rules`** which admit SIP 5060 (UDP+TCP) only from **`net:$LAN`**. So: **(a)** set `fqdninspect=NO` (drops STRING layer); **(b)** ensure 5060 accepts the **SBC IP(s)** — either the SBC is inside `$LAN` (same-LAN physical model ⇒ genuinely "done" with just the toggle) or add an explicit ACCEPT / set `$LAN` = SBC IP(s). **Cover transports the SBC uses:** UDP 5060 and/or TCP 5060, plus TCP 5061 if node↔SBC is TLS. **RTP (10000–20000) is a separate path** (§11.6) — scoped to phones, not the SBC. On the **UFW migration (§11.4)** this becomes one clean rule ("allow 5060 from SBC IP(s)") and the STRING machinery disappears entirely. |

### Cutover and registration

| # | Gotcha | Sev | Mitigation |
|---|--------|-----|------------|
| 1 | **SBC `domain.setid` repoint is instant; registrations are not.** | **H** | **Decided §11.1:** fact; 5 min reg interval; wizard drain + delayed source delete. |
| 2 | **Dual write: SBC DB + catalog `meta.json`.** If orchestrator updates one and fails the other → split brain (console says node B, SBC still sends to A). | **H** | Single job transaction: SBC repoint + catalog only commit together; rollback on partial failure (§4.1). |
| 3 | **Every tenant `cluster.fqdn` needs an SBC `domain` row** before phones work — not just instance/node records. Moving tenant updates `setid`; **creating** tenant on a node must also register domain on SBC. | **M** | Fleet onboarding checklist: tenant create → SBC `add-domain.sh` (or admin API). Automate from Fleet Console later. |

### RTP, NAT, and media (RTP bypass)

| # | Gotcha | Sev | Mitigation |
|---|--------|-----|------------|
| 4 | **RTP bypasses the SBC** — media phone ↔ Asterisk. | **H** | **Decided §11.5:** Asterisk owns RTP/NAT; AMI template + proxy NAT docs; dSIPRouter if revisit trigger fires. |
| 5 | **Outbound signaling hairpin:** extension call may traverse **Phone → SBC → Asterisk → Egress trunk → SBC → carrier** (two SBC legs on signaling). Latency and dialog/Record-Route edge cases possible. | **M** | Accept for v1; later optimize (private VPC path node→SBC, or internal dispatcher URI). Test hold/transfer/bye on outbound PSTN. |
| 6 | **RTP must stay open to roaming phones** — can't IP-whitelist like SIP. | **L** | **Decided §11.6:** low risk (SIP gated + `strictrtp` + `direct_media=no`); residual = blind UDP flood. Mitigate: explicit `strictrtp=yes`, per-source rate-limit RTP range, tighten range, SRTP later. |

### Node edge vs SBC edge

| # | Gotcha | Sev | Mitigation |
|---|--------|-----|------------|
| 7 | **`tenant:import` runs `update-fqdn-inline.sh`**; base `pbx3_rules` admit 5060 from `$LAN` only, so the `fqdninspect` toggle alone doesn't admit an off-LAN SBC. | **H** | **Decided §11.4 + §11.7:** two actions — `fqdninspect=NO` **and** 5060 from SBC IP(s) (same-LAN SBC ⇒ toggle suffices); skip `update-fqdn-inline.sh` on fleet import; UFW = one "5060 from SBC" rule. |
| 8 | **Inbound PSTN mobility gap (expanded §11.8).** Phones + outbound are mobile via SBC; **inbound DID delivery is not** until the SBC owns DID→node routing. `inroutes` logic moves with the tenant, but carrier delivery stays pinned to the source node's instance trunks. Hybrid state also forces the node firewall to admit **both** SBC and carrier IPs (breaks #7's SBC-only rule). | **H** | **SBC inbound peering (`PEERING-PLAN` §7) is a prerequisite for *complete* mobility.** Until then, advertise moves as "phones/extensions/outbound/internal mobile; inbound PSTN needs carrier DID re-point." Keep carrier `type=identify` rules on node during hybrid. |
| 9 | **API / admin TLS** still per-node (`:44300`). SBC-fronted phones ≠ SBC-fronted admin. LE per-tenant on node may still matter for API until edge TLS decided. | **M** | Separate "phone TLS at SBC" from "API TLS on node" in runbooks; open question §10. |

### Routes, trunks, and pbx3cagi (today's code)

| # | Gotcha | Sev | Mitigation |
|---|--------|-----|------------|
| 10 | **`path1` must equal trunk `pkey` exactly.** | **H** | **Decided §11.2:** fleet-standard names; rewrite on data takeover / import. |
| 11 | **Legacy `path2`–`path4` + AGI failover loop.** | **H** | **Decided §11.2–3:** normalize paths on takeover; remove failover loop — AGI hands dial to Asterisk. |
| 12 | **`strategy=balance` rotates across path slots** — meaningless with one egress trunk; odd behaviour if path2–4 are stale. | **M** | Default hunt for fleet; clear path2–4 on fleet nodes. |
| 13 | **Peering not built on pbx3sbc yet** — Egress trunk lands on SBC but **carrier selection / inbound DDI from carriers** is still design (`PEERING-PLAN.md`). Fleet egress story is incomplete until Phase 0. | **H** | Sequence: peering Phase 0 before selling "SBC owns PSTN"; until then scope fleet moves as **extension + internal** validation. |

### Tenant export / data

| # | Gotcha | Sev | Mitigation |
|---|--------|-----|------------|
| 14 | **Laravel `users` (admin login) not in tenant export** — instance-scoped. Tenant move does not migrate SPA operators for that tenant. | **M** | Document; instance admins unchanged; tenant-scoped users (future) need export row. |
| 15 | **Route filter policy moves; instance `Egress` trunk does not** — correct by design, but **preflight must verify dest has `Egress`**, not that routes reference valid trunks. | **M** | Already in §3 Phase A; enforce in wizard. |

### SBC platform

| # | Gotcha | Sev | Mitigation |
|---|--------|-----|------------|
| 16 | **Shared MySQL routing DB** across SBC pool — HA depends on DB replication/failover; edge is only as good as DB availability. | **H** | §2.3 HA doc: DB + ≥2 SBCs; rehearse failover. **Rebuildable from S3 (§11.10):** SBC MySQL is a projection of the directory home-of-record, so DB loss = re-project, not data loss. |
| 17 | **`pbx3sbc-admin` vs Fleet Console** — two UIs until adapter ships; manual `domain`/`dispatcher` edits can drift from catalog. | **M** | **Decided §2.5:** `pbx3sbc-admin` = thin local/break-glass edge admin **behind** the adapter; control plane is **sole writer** for moves via `SbcFleetAdapter`. Manual edits = break-glass only; reconcile job (S3 ≡ SBC, §11.10) flags drift. |
| 18 | **Dispatcher health marks node down** — during move, if dest node fails health check, SBC won't send traffic even after repoint. | **M** | Preflight (`SbcFleetAdapter.preflight`, §2.4): dest dispatcher **UP**; move only when `pbx3:fleet-preflight` green. |

### Filter boundary (node vs SBC)

| # | Gotcha | Sev | Mitigation |
|---|--------|-----|------------|
| 19 | **Deny on node vs deny on SBC:** tenant route can forbid `+44…` but SBC might still accept and route a misdial if another path injects the call. Clarify trust boundary. | **M** | Policy: **node is authoritative** for tenant permission; SBC never bypasses Asterisk for tenant calls. Document for peering. |
| 20 | **Emergency numbers (`cluster.emergency`)** may bypass normal routes — ensure they still egress correctly via Egress/SBC and are not blocked by intl filters. | **M** | Regression test 999/112/911 per tenant after fleet template change. |

### S3 / org security

| # | Gotcha | Sev | Mitigation |
|---|--------|-----|------------|
| 21 | **Node IAM grants blanket `tenants/*` write** — any compromised node can corrupt another tenant's `meta.json`, `dids.json`, recordings, or staging. | **H** | **§2.6.1:** v1 interim = drop `tenants/*` from node policy (safe now — backups use `instances/{ksuid}` only); future bulk = gatekeeper presigns scoped to hosted tenants; gatekeeper sole writer for catalog + tenant meta. |

### 11.8 Inbound PSTN mobility — the hard half (expanded 2026-07-07)

Outbound and inbound are **not symmetric** under the SBC model. Outbound is easy (node initiates → `Egress` → SBC). **Inbound is the gating problem** because the carrier chooses where to deliver a DID, and today that's the **node's public IP** via instance-owned trunks (`pjsip_trunk_trusted.tmpl` `type=identify match=$host`; `sndreg` registers the node to the carrier).

**Key fact:** `inroutes` **is** in the tenant export (`TenantMobilityService::TENANT_DATA_TABLES`), so DID→destination **logic** travels to the destination node. But the **carrier delivery** of that DID does not (trunks are instance-owned, excluded from export). Result after a move: node B knows the DID routing; the call still arrives at node A. **Inbound logic is mobile; inbound delivery is not.**

**Mobility matrix:**

| Element | Moves on tenant move? | Mechanism |
|---------|----------------------|-----------|
| Extensions, IVR, queues, CoS | Yes | tenant miniDB |
| Phone registration target | Yes | SBC `domain.setid` repoint |
| Outbound PSTN | Yes | `Egress` trunk (fleet-standard) → SBC |
| Inbound DID **logic** (`inroutes`) | Yes | tenant miniDB |
| Inbound DID **delivery** | **No (until SBC owns it)** | carrier → node IP; needs SBC `dr_rules` DID→setid |

**Transition states:**

```text
State 0 — direct (today): phones + carriers → node. Move = DNS + carrier DID re-point.
State 1 — HYBRID: phones → SBC (mobile); carriers → node IP (NOT mobile).
          Firewall must admit BOTH SBC IPs and carrier IPs on 5060.
State 2 — target: phones AND inbound DID via SBC (dr_rules DID→dispatcher setid).
          Move = SBC table changes only; node firewall = SBC-only (#7 realized).
```

**Hybrid-state gotchas:**

1. **Firewall can't be SBC-only** — must also admit carrier source IPs for inbound (partially defeats §11.7). Node stays SIP-exposed to carrier IPs.
2. **Inbound PSTN not mobile** — move strands DIDs on source node. Wizard must gate: *"inbound PSTN follows only after carrier DID re-point / SBC inbound peering."*
3. **Carrier registration is per-node** (`sndreg`/`uac_registrant`) — moves to SBC only in State 2.
4. **Preserve carrier `type=identify` rules** on the node during hybrid — don't strip them when moving phone endpoints behind the SBC.

**Conclusion / sequencing:** **SBC inbound peering (`PEERING-PLAN` §7: DID prefix → dispatcher setid) is a prerequisite for *complete* fleet mobility**, not an optional later phase. Once shipped, inbound repoint = same one-row change as `domain.setid`, and node firewall can finally be SBC-only. Until then, ship and **advertise** fleet moves honestly: phones + extensions + outbound + internal are mobile in seconds; **inbound PSTN needs a carrier/DID step** for DID-heavy tenants.

### 11.9 DID homing — "author once, derive the SBC row" (design note 2026-07-07)

**Tension:** For inbound mobility (§11.8) the SBC must know **DID → node**. But the DID number is **already** recorded tenant-side (`inroutes.pkey`, with behavior: `openroute`/`closeroute`, `swoclip`, `inprefix`, `transform`, CLID). Recording it again on the SBC feels like double-entry.

**Resolution — one number, two *facts*:**

| Fact | Home | Changes when |
|------|------|--------------|
| DID **behavior** (→ ext/IVR, open/closed, CLIP, transform) | Tenant `inroutes` | Tenant admin edits routing |
| DID **delivery** (→ which node/setid) | SBC `dr_rules` | Tenant **moves** |

The SBC needs only delivery, and **delivery is derivable**, not independent data:

```text
DID → tenant   (assignment; rarely changes)
tenant → node  (catalog meta.json; changes on move)
──────────────────────────────────────────────
DID → node     (SBC dr_rules; REGENERATED on move, never hand-typed)
```

**Principle:** **Author a DID once; project the SBC delivery row.** No human types a DID into the SBC — the move job that flips `domain.setid` also regenerates the tenant's DID rules → new setid. Same pattern as phone `domain.setid`. Double *storage*, single *authoring point*.

**Derivation source (the real choice):**

| Option | Source of "DID belongs to tenant T" | Trade-off |
|--------|-------------------------------------|-----------|
| **A — `inroutes` as source** (first cut) | Tenant `inroutes.pkey` | Single authoring point (existing tenant panel); **no DID inventory model** (spare numbers, carrier of record) |
| **B — Fleet DID inventory in the S3 directory** (MSP-grade) | Directory JSON (see §11.10): `number, carrier, tenant, status` — **no new database**, reuses the catalog that already homes `tenant → node` | Models number lifecycle; validates `inroutes` ("can't route a DID you don't own"); one small file to add |

**Lean:** ship **A** with peering inbound; move to **B** when MSP number management demands it. Both preserve author-once/derive. **B does not require a new datastore** — the S3 directory already exists and already holds the other half of the derivation (§11.10).

**Dispersed DIDs — the common case (not the exception):**

Many fleet tenants are geographically dispersed enterprises: DIDs span multiple area codes and carriers, **not** one or two contiguous blocks. Prefix-group compression is an **optional optimisation** when a tenant happens to have a contiguous range — not the default model.

| Model | When | SBC rows per tenant |
|-------|------|---------------------|
| **Per-DID delivery** (default) | Scattered area codes, mixed carriers | 1 row per active `inroutes` DID |
| **Prefix block** (optional) | Contiguous allocation (e.g. `+441234567___`) | 1 row per block; fleet may auto-detect and collapse |
| **alias_db** (one-off) | PEERING-PLAN fallback for numbers outside `dr_rules` | 1 alias per DID |

**Default projection:** fleet reads the tenant's active `inroutes` DIDs and writes **one `dr_rules` row per DID** (full E.164 as prefix → tenant's current dispatcher `setid`). Longest-prefix match with a full number is effectively exact match. On **move**, the job **bulk-regenerates** the tenant's full DID set → new `setid` — same transaction as `domain.setid`, just N rows instead of 1.

**Scale:** drouting is built for large prefix tables; tens–hundreds of DIDs per tenant and thousands fleet-wide is routine. Row count is a reason to automate projection and reconcile, not to avoid per-DID homing.

**Implications for fleet DID inventory (option B):** dispersed allocations make a **flat DID list** (`number → tenant → node`) the natural MSP model anyway — there is little to gain from prefix grouping. Option B may arrive sooner for DID-heavy fleets than for tenants with tidy blocks.

**Supporting details:**
- **Prefix blocks** — fleet may optionally collapse contiguous `inroutes` DIDs into one `dr_rules` prefix rule when detected; never required; never assumed at design time.
- **Reconcile/drift job** (fleet): every active `inroutes` DID has exactly one SBC delivery row → tenant's current node; flag orphans both directions. **More important** with per-DID rows (N per tenant) than with block rules.

**Open question (product/persona, not technical):** where is DID **assignment/inventory** authored — tenant panel ("claim a DID"), fleet DID-inventory panel (MSP number management), or both (claim from a fleet-assigned pool)? See §10.

### 11.10 DID homing in the S3 directory — the catalog already owns half of it (design note 2026-07-07)

**The realisation:** the S3 directory **already** resolves `tenant → node`. `tenants/{tenant_shortuid}/meta.json.instance_id` is the authoritative homing record, written by `move-tenant.sh` on every move (`tenant-meta.v0.json`). The directory is *already* the fleet source of truth for where a tenant lives — half of `DID → node` is done. All that's missing is `DID → tenant`, and that belongs in the same directory.

```text
DID → tenant   ← ADD to S3 directory (dids)      ─┐
tenant → node  ← ALREADY in S3 (meta.instance_id) ─┤→ compile → SBC dr_rules
                                                    ─┘  (projection, never authored on SBC)
```

**Why this dissolves the "record twice" tension cleanly:**
- The DID **home of record** = the S3 directory (fleet-owned, survives node loss/rebuild, already backed up, already the move pivot).
- The SBC `dr_rules` = a **compiled projection** of the directory. Rebuildable from S3 at any time; if the SBC MySQL is lost, re-project from the catalog.
- Tenant `inroutes` stays **behavior-only** (what the DID does once it lands). It is *validated against* the directory, not the source of homing.
- **`inroutes` DID logic already travels in the tenant export** (§11.8) — so behavior moves with the tenant miniDB; the directory move flips homing; the SBC projection follows. All three stay consistent because there is exactly one authoring point per fact.

**This is exactly "option B" — but with no new datastore.** §11.9 option B assumed a "new directory/SBC table." It isn't new: it's a JSON object in the catalog we already operate, following the established directory pattern (small authored records + a compiled index, like `tenants/*/meta.json` rolled into `catalog/instance-index.json`).

**Proposed layout (mirrors existing conventions):**

| Object | Role | Written by |
|--------|------|------------|
| `tenants/{tenant_shortuid}/dids.json` | **Authored** per-tenant DID inventory (flat list; scattered area codes fine) | registrar / DID-assign panel |
| `catalog/did-index.json` *(optional rollup)* | **Compiled** fleet-wide `DID → tenant → node` for one-GET SBC projection + reconcile | registrar on assign/move |

`dids.json` sits next to `meta.json` under the tenant's **stable** prefix (unchanged across moves), so DID ownership survives moves exactly like recordings do. A flat list suits dispersed enterprises (§11.9) — no prefix assumption.

**`dids.json` sketch (needs a `did-inventory.v0.json` schema):**

```json
{
  "tenant_shortuid": "f34ck1",
  "updated_at": "2026-07-07T17:30:00Z",
  "dids": [
    { "e164": "+442071234567", "carrier": "gamma", "status": "active" },
    { "e164": "+441611234567", "carrier": "gamma", "status": "active" },
    { "e164": "+12125550100",  "carrier": "bandwidth", "status": "active" }
  ]
}
```

**Rule 1 preserved:** the directory is ops metadata (async), never in the SIP/RTP path. Calls route from the SBC's **MySQL** `dr_rules` (fast, local); S3 is the *authoring + compile* source, projected to MySQL out-of-band — same posture as `catalog/instance-index.json` feeding the SPA, never the live call.

**Move flow becomes one coherent pivot:**
1. `move-tenant.sh` updates `meta.json.instance_id` *(already happens)*.
2. Orchestrator re-reads the tenant's `dids.json` + new `instance_id` → **re-projects** that tenant's `dr_rules` → new dispatcher `setid`.
3. SBC `domain.setid` repoint (phones) + DID re-projection (inbound PSTN) happen in the **same job** — the directory is the single pivot for both.

**Payoffs:**
- **No double authoring** — DID home is the directory; SBC and (optionally) tenant `inroutes` validate against it.
- **No new database** — reuses S3 catalog + registrar tooling + backup story.
- **Disaster-resilient** — SBC routing tables are rebuildable from S3; node loss doesn't lose DID ownership.
- **Dispersed-friendly** — flat per-tenant list; prefix compression stays optional (§11.9).

**Follow-ups:** (a) add `schema/did-inventory.v0.json`; (b) extend registrar with `assign-did.sh` / `release-did.sh` (+ `move-tenant.sh` already covers the node pivot); (c) build the S3 → SBC `dr_rules` projector (part of `SbcFleetAdapter`); (d) reconcile job asserts directory `dids` ≡ SBC `dr_rules` ≡ (optionally) tenant `inroutes`.

**Open question (unchanged, now sharper):** the *authoring UI* for `dids.json` — tenant panel, fleet DID-inventory panel, or both — is still a product/persona call (§10). The **home of record** is settled: the S3 directory.

---

## 13. Implementer readiness

**Purpose:** what an agent or developer needs to **start work** without re-deriving architecture. This doc is the **design + decision record**; §13 is the **execution map**.

### 13.1 Read order (by task)

| Task | Read first | Then |
|------|------------|------|
| **Any mobility work** | This doc §1–2, §8 build order | `TENANT_MIGRATION_RUNBOOK.md` (CLI golden path) |
| **Phase A — Egress + AGI** | §3, §11 #2–3, #10–12 | `pbx3cagi` route loop; `pjsip_trunk_*.tmpl`; `TRUNK_ROUTE_MULTITENANCY.md` |
| **§2.6.1 — IAM tighten** | §2.6.1 | `schema/pbx3-node-s3-writer.policy.json.tmpl`, `OPS_S3_RUNBOOK.md` §7 |
| **Phase B — Fleet shell** | §4, `CENTRAL_ADMIN_DIRECTION.md` | `pbx3spa` instance picker; `schema/instance-index.json` |
| **Phase B′ — Control plane** | §2.5–2.6, **§2.5.1** (hosting), §6 | `pbx3-directory/tools/` (registrar scripts to adopt); `DESIGN_RULES.md` |
| **Phase C — Move wizard** | §5–6, §13.2–13.4 | `TenantMobilityService.php`; `FleetPreflightService.php`; §13.3 contracts |
| **SBC / peering** | §2.1–2.4, §11.8 | `pbx3sbc/` `PEERING-PLAN.md`, `routing-logic.md` |
| **Inbound DID mobility** | §11.8–11.10 | Deferred for v1 MVP (§13.4) |

### 13.2 v1 MVP scope (what “done” means first)

**In scope for first shippable fleet move (panel):**

- SBC-fronted fleet; phones + extensions + outbound + internal routing mobile on move
- Wizard + job view; preflight gates; human gate on source delete
- S3 staging transfer (no Mac-in-the-middle)
- Cutover = SBC `domain.setid` repoint + catalog `meta.json.instance_id` (atomic job)
- CLI runbook remains escape hatch

**Explicitly deferred (do not block v1 MVP on these):**

- **Inbound PSTN mobility** — carrier DID delivery; needs SBC peering Phase 0 (§11.8, #13)
- **`dids.json` / fleet DID inventory** — schema + UI (§11.9–11.10); reconcile job
- **SBC HA production topology** — lab can use single SBC (§10 Q3)
- **Route53 / Phase D** — DNS automation for direct fleet only
- **Recordings S3 presign path** — unless `--include-recordings` on export is in scope for v1
- **Full reconcile** S3 ≡ SBC ≡ `inroutes` — ship after move path works

**Golden acceptance path (manual or panel):** reproduce **affcot / tenant shortuid** move **08jzwn → bzy54n** per `TENANT_MIGRATION_RUNBOOK.md`, then via panel with same outcome: tenant on dest, SBC repoints, catalog updated, source deleted after verify, test call succeeds.

### 13.3 Contracts to draft before Phase C

These do **not** exist yet; draft in `pbx3-directory/schema/` (or OpenAPI on control-plane repo) **before** wiring the move wizard.

| Contract | Owner | Status | Notes |
|----------|-------|--------|-------|
| **`sbc-fleet.v0.json`** | directory schema | **TODO** | §4.1 fields: `sip_proxy_fqdn`, `admin_api_url`, `member_hosts` |
| **`instance-record` + `sbc_dispatcher_setid`** | directory schema | **TODO** | Extend `instance-record.v0.json` |
| **`did-inventory.v0.json`** | directory schema | **TODO** | §11.10 `tenants/{shortuid}/dids.json` |
| **`tenant-move-job.v0.json`** | control plane | **TODO** | Job state + `tenants/{shortuid}/migration/{job_id}/job.json` |
| **Node mobility HTTP API** | pbx3api | **TODO** | Wrap `TenantMobilityService` — see §13.3.1 |
| **`SbcFleetAdapter` HTTP API** | pbx3sbc-admin | **TODO** | §2.4 methods; may not exist beyond Filament CRUD today |
| **Fleet→node auth** | control plane + pbx3api | **OPEN §10 Q7** | Service token vs admin bearer; must not break `whoami` |

#### 13.3.1 Node mobility API (sketch — pbx3api)

Orchestrator calls **source** and **dest** `api_base_url` with fleet credentials:

| Method | Path | Maps to |
|--------|------|---------|
| `POST` | `/api/fleet/tenants/{tenant}/export` | `tenant:export` → S3 staging key (or presigned PUT) |
| `POST` | `/api/fleet/tenants/import` | `tenant:import` ← staging zip |
| `POST` | `/api/fleet/commit` | Asterisk regen + reload |
| `POST` | `/api/fleet/certificates/sync` | LE SAN sync for tenant FQDN |
| `GET` | `/api/fleet/preflight` | `pbx3:fleet-preflight` |

**Existing code:** `pbx3api/app/Services/Tenant/TenantMobilityService.php`, `FleetPreflightService.php`; CLI in `pbx3api/routes/console.php`.

### 13.4 First PR checklist (by phase)

| Phase | First PR(s) | Done when |
|-------|-------------|-----------|
| **A** | Fleet AMI: `Egress` trunk template; `path1` normalization on fleet import | Outbound PSTN via SBC from fleet node; route SPA hides trunk picker on fleet |
| **A** | `pbx3cagi`: remove path failover loop; dial via `Egress` | AGI defers outbound dial to Asterisk (§11.3) |
| **§2.6.1** | Tighten `pbx3-node-s3-writer.policy.json.tmpl`; sync `OPS_S3_RUNBOOK` §7 | Node role has `instances/{ksuid}/*` only; backup smoke passes |
| **B** | Fleet tenant list from `tenants/*/meta.json` in SPA or control-plane read API | Operator sees tenant @ instance; "Move" disabled until C |
| **B′** | Control-plane repo scaffold: Laravel app, fleet auth stub, `POST` registrar-equivalent for `register-instance` / `move-tenant` | Mac scripts optional; gatekeeper writes catalog |
| **B′** | `sbc-fleet.v0.json` + extend `instance-record.v0.json` | Schemas validate; example in `schema/` |
| **C** | Node mobility HTTP API (§13.3.1) + `tenant-move-job.v0.json` | Orchestrator can export/import without SSH |
| **C** | `SbcFleetAdapter` + pbx3sbc-admin repoint endpoints | `repointTenant` + rollback tested on lab SBC |
| **C** | Move wizard UI + job state machine (§5) | Golden path (§13.2) via panel |

### 13.5 Repo map (where code lives today)

| Component | Location | Notes |
|-----------|----------|-------|
| Tenant export/import logic | `pbx3api/app/Services/Tenant/TenantMobilityService.php` | CLI works; HTTP wrapper needed |
| Fleet preflight | `pbx3api/app/Services/Directory/FleetPreflightService.php` | `php artisan pbx3:fleet-preflight` |
| Instance backup → S3 | `pbx3api/app/Services/Directory/InstanceBackupDirectoryUpload.php` | `instances/{ksuid}/backups/` only |
| Registrar / catalog scripts | `pbx3-directory/tools/` | Adopt into control-plane API (B′) |
| Directory schemas | `pbx3-directory/schema/` | v0 catalog; extensions in §13.3 |
| SBC edge | `pbx3sbc/` (sibling repo) | OpenSIPS + `pbx3sbc-admin`; `PEERING-PLAN.md` |
| Control-plane service | **Not started** | `pbx3-directory/README.md` = stub only |
| Fleet Console UI | `pbx3spa` | Model B picker; move wizard = Phase C |
| AGI outbound | `pbx3cagi/.../pbx3cagi.c` | Path loop §11.3 |

### 13.6 Document hygiene

When implementing, keep these sections aligned:

- **§6** orchestrator home = control-plane service (not pbx3api namespace)
- **§4.1** / **§10** — S3 owns truth; SBC projects
- **§8** build order — B′ before C
- **`IMPLEMENTATION_PLAN.md`** S8.10 row — one-line pointer to this doc + §13

---

## 14. References

### Design & runbooks

- **`TENANT_MIGRATION_RUNBOOK.md`** — CLI/support path (Phases 0–8), troubleshooting; **golden test** 08jzwn → bzy54n.
- **`pbx3spa/workingdocs/TRUNK_ROUTE_MULTITENANCY.md`** — trunk ownership, virtual trunks, migration mechanics (policy source of truth).
- **`pbx3spa/workingdocs/CENTRAL_ADMIN_DIRECTION.md`** — Model B, instance directory (Fleet Console dependency).
- **`SELF_SERVICE_REBUILD_DESIGN.md`** — S8.9 rebuild orchestrator + job state machine (sibling; possible shared engine).
- **`LETSENCRYPT_PER_TENANT_FQDN.md`** §4.2 / **`TLS_IMPLEMENTATION_STEPS.md`** §4.2 — cert sync on move.
- **`IMPLEMENTATION_PLAN.md`** § Phase S8 — fleet lifecycle plan (S8.10 row for this design).
- **`DESIGN_RULES.md`** — Rule 1 (fail-safe), EC2 fleet model, solo Rule 6.
- **`OPS_S3_RUNBOOK.md`** §7 — node IAM; **must align with §2.6.1** (tightened policy).
- **`S3_LAYOUT_PROPOSAL.md`** — bucket tree, identifier mapping.

### Implementation entry points (code)

- **`pbx3api/app/Services/Tenant/TenantMobilityService.php`** — `tenant:export` / `tenant:import` (S8.6).
- **`pbx3api/app/Services/Directory/FleetPreflightService.php`** — `pbx3:fleet-preflight` (S8.4).
- **`pbx3api/routes/console.php`** — artisan commands (mobility + preflight).
- **`pbx3-directory/tools/`** — `register-instance.sh`, `register-tenant.sh`, `move-tenant.sh`, `onboard-fleet-instance.sh`.
- **`pbx3-directory/schema/`** — `tenant-meta.v0.json`, `instance-record.v0.json`, `pbx3-node-s3-writer.policy.json.tmpl`.
- **`pbx3cagi/.../pbx3cagi.c`** — outbound route / path loop (Phase A).
- **pbx3sbc** (sibling repo `pbx3-master/pbx3sbc`) — `docs/PROJECT-CONTEXT.md`, `docs/architecture/routing-logic.md`, `workingdocs/PEERING-PLAN.md`, `scripts/add-domain.sh` / `add-dispatcher.sh`; admin **`pbx3sbc-admin`** (behind `SbcFleetAdapter`, §2.5).
