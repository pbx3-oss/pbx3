# Fleet trunk and peering placement — architecture decision

**Status:** Locked (2026-07-09)  
**Audience:** Product, fleet implementers (pbx3, pbx3api, pbx3spa, pbx3cagi, pbx3sbc, control-plane)  
**Supersedes:** Ad-hoc “trunks on node vs SBC” discussion; aligns **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §3 with **`pbx3sbc/workingdocs/PEERING-PLAN.md`**.

---

## 1. Decision summary

| Deployment | Where carrier trunks live | Where phones register | Tenant move cutover |
|------------|---------------------------|------------------------|---------------------|
| **Fleet** (catalog + SBC tier) | **SBC only** (`pbx3sbc`, OpenSIPS `drouting`) | SBC (stable FQDN / pool) | SBC `domain.setid` repoint — **no carrier/DNS change** |
| **Solo / Rule 6** (no fleet SBC) | **Node** (today’s model) | Node FQDN | DNS + trunk alignment per **`TENANT_MIGRATION_RUNBOOK.md`** |

**Fleet rule:** Nodes are **not** carrier endpoints. Every fleet node has a fixed **`Egress`** trunk (and optional **`EgressFailover`**) to the SBC pool only. Carrier selection, DID mapping, LCR, and PSTN failover live on the **SBC**.

**Explicitly rejected for fleet:** Long-term hybrid (phones via SBC, carriers direct to node). That preserves migration friction, split cutover surfaces, and per-node public SIP exposure.

---

## 2. Rationale

### 2.1 Tenant mobility

Outbound routes store real trunk `pkey` values in `route.path1..path4`. Trunks are **instance-owned** and **excluded** from the tenant export mini-DB. After import, `path1='ael3'` dangles unless that trunk exists on the destination — invisible to a panel admin.

With SBC-fronted peering:

- Tenant miniDB carries **dialplan policy** (what may egress).
- **`path1`** is always **`Egress`** on fleet nodes (not operator-chosen).
- Move = data export/import + SBC repoint; **no trunk remap**, no virtual-trunk map table.

### 2.2 Single edge for signaling

Phones already register to the SBC (`tenant.pbx3.com` → SBC → node). Inbound carrier INVITEs naturally land on the same edge. Keeping trunks on nodes would require a second cutover (carrier IP / DID reprovision) on every move.

### 2.3 Acceptable tradeoff: SBC as PSTN choke point

Moving trunks to the SBC **does** concentrate PSTN failure domain on the edge tier. That is intentional for fleet product shape — the same tier that already owns phone registration. Mitigation is **redundant SBC instances + shared routing DB**, not distributing carriers back onto nodes.

**Principle (unchanged):** Runtime call path (phone → SBC → node → carrier) must survive control-plane or catalog outages. Management path (Fleet Console, S3 mutations) is best-effort for *changes*, not a runtime dependency for established calls.

### 2.4 Founding principle — replaceable edge; one-way catalog (Rules 7–8)

**`DESIGN_RULES.md`** Rules **7** and **8** are fleet founding constraints:

1. **SIP is the runtime API** — phones, carriers, and nodes integrate via standard SIP/RTP. The edge is a **discrete component** behind **`SbcFleetAdapter`**, not hard-wired to pbx3sbc/OpenSIPS internals.
2. **Fleet metadata feeds the SPA; not the reverse** — S3/catalog (`instance-index`, `meta.json`, optional `dids.json`) is an **ops signpost** for pickers and orchestration. Schemas hold **fleet facts**, not SPA routes, form keys, or panel layout. After instance select, panel truth is the **node API**.

**Swap story:** catalog intent (S3) → adapter projects to edge → SIP to nodes. Replace edge = new adapter implementation; nodes, tenant DB, and orchestrator job model unchanged.

**Customer-operated edge:** supported in principle — same adapter contract or documented manual projection; PBX3 nodes remain standard **`Egress`** downstream peers.

---

## 3. Layer ownership

| Layer | Owns | Does not own |
|-------|------|----------------|
| **SBC** (`pbx3sbc`) | Carrier gateways (trusted-peer IP ACL), **inbound DID delivery** (compiled → node/setid), outbound prefix → carrier, inbound `is_from_gw`, tenant `domain` → dispatcher `setid`; `uac_registrant` only when a carrier requires it | Tenant extensions, IVR, queues, per-tenant egress *policy*, **inroute regex behaviour** |
| **Node** (fleet instance) | Extensions, dialplan, CoS, route auth/CLID, **`Egress`** trunk to SBC | Carrier trunks, LCR, `path2`–`path4` failover to carriers |
| **Tenant miniDB** | Route `dialplan` patterns, **`inroutes.pkey`** (Asterisk regex/mask), auth PIN, CLID, active flags; `path1` = `Egress` | Carrier names, registration credentials, SBC delivery rows |
| **Fleet Console / control plane** | Orchestrates move, S3 catalog, `SbcFleetAdapter.repointTenant` | Per-call routing (never in hot path) |

### Call flows (fleet)

**Extension → extension (on-node or cross-tenant via SBC):**

```text
Phone → SBC (usrloc / dispatcher) → Node Asterisk → dialplan
```

**Extension → PSTN:**

```text
Phone → SBC → Node Asterisk
    → tenant route dialplan match + policy (auth, CoS, CLID)
    → seize Egress trunk → SBC
    → SBC: $rU length > 7 → do_routing("0") → carrier
```

**Inbound PSTN:**

```text
Carrier → SBC (is_from_gw — trusted peer IP)
    → SBC delivery lookup: DID → dispatcher setid (compiled projection)
    → Asterisk backend on that node
    → tenant inroutes: pkey regex match (block, singleton, or split range — one mechanism)
    → openroute / closeroute / IVR / extension (unchanged tenant logic)
```

Peering script detail: **`pbx3sbc/workingdocs/PEERING-PLAN.md`**.

---

## 4. Phase A — fleet `Egress` trunk (nodes)

Phase A ships **before** SBC peering Phases 1–4. Goal: every fleet node dials PSTN **only** via SBC, even if carrier selection on SBC is not live yet.

### 4.1 Instance trunks (fleet AMI / onboarding)

| Trunk `pkey` | Purpose | Cardinality |
|--------------|---------|-------------|
| **`Egress`** | Primary signalling peer to SBC pool | **1 per instance** (required on fleet nodes) |
| **`EgressFailover`** | Secondary SBC pool member | **0–1** (optional) |

**Properties (conceptual — align with existing trunk schema / generator):**

- **Peer URI:** SBC pool — **`_sip._udp.<pool-fqdn>`** SRV name (preferred) or explicit member URI for lab. From directory `sbc-fleet.sip_proxy_fqdn`.
- **Scope:** Instance-level, **not** tenant-scoped. Identical on every node in the fleet (template / onboarding seed).
- **Auth:** Typically IP-trust / no registration (node ↔ SBC is fleet-internal). Carrier registration is SBC-side only.
- **UFW / firewall:** Node accepts SIP **from SBC source IP(s) only** on fleet nodes (replaces `fqdninspect` STRING match for fleet posture).

### 4.2 Route model (fleet nodes)

| Field | Fleet behaviour |
|-------|-----------------|
| **`dialplan`** | Unchanged — primary egress *permission* filter |
| **`path1`** | Always **`Egress`** (hidden in SPA or implicit default) |
| **`path2`–`path4`** | Unused — carrier failover is SBC-side |
| **SPA trunk picker** | Hidden on fleet nodes; shown on solo (Rule 6) |

**pbx3cagi:** Load route policy (auth, etc.) from tenant DB; dial via `Egress` — **no trunk failover loop** on the node. See **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §11.3.

### 4.3 Fleet detection

Fleet vs solo behaviour is gated by instance posture (e.g. directory / fleet flag in instance meta, or presence of `Egress` trunk template). Solo installs keep today’s trunk picker and real carrier trunks on the node.

### 4.4 Phase A deliverables (checklist)

- [ ] Fleet AMI / **`NEW_INSTANCE_CHECKLIST.md`** / onboarding: seed `Egress` (+ optional `EgressFailover`).
- [ ] Generator / trunk templates for fleet peer URIs.
- [ ] **pbx3cagi:** `path1` → `Egress` convention; no multi-trunk failover on node.
- [ ] **pbx3spa / pbx3api:** fleet route panels — dialplan + policy; hide trunk paths.
- [ ] Move preflight (later Phase C): verify destination has `Egress`, not per-route trunk resolution.

---

## 5. SBC peering (carriers + DIDs)

Implementation follows **`pbx3sbc/workingdocs/PEERING-PLAN.md`** (Phases 0–6). This decision doc does not duplicate that plan; it **locks placement**:

| Concern | Owner |
|---------|--------|
| `dr_gateways`, `dr_rules`, `dbaliases`; `registrant` only if needed | **pbx3sbc** schema + `pbx3sbc-admin` CRUD |
| OpenSIPS route branches (`FROM_CARRIER`, `do_routing("0")`, etc.) | **pbx3sbc** `opensips.cfg.template` |
| Group IDs | Outbound = **0**, inbound DID = **1** |
| PSTN vs internal from Asterisk | `$rU` length **> 7** → carrier; **≤ 6** → endpoint path |

**Build order after Phase A Egress:**

1. Peering Phase 0 — tables + `drouting` module (no route change).
2. Phases 1–2 — outbound to carrier (+ failover).
3. Phases 3–5 — inbound carrier ID, **DID delivery projection** to backend setid.
4. Phase 6 — polish, `dr_groups` multi-tenant if needed.

**Validated baseline:** Inter-extension via SBC on **`sbc.pbx3.com`** (tenant **`dhbm8x`** → Golden **`08jzwn`**, 2026-07-08). Peering extends the same edge.

### 5.1 Operational caveats (locked)

#### Carrier authentication — trusted peer is the default

Most **Tier 2 and above** carriers use **IP-trusted peering**, not SIP registration:

- Carrier signalling IPs live in **`dr_gateways`**; inbound identification via **`is_from_gw(-1, "n")`**.
- Outbound is relay to the same gateway addresses — no REGISTER handshake.
- **`uac_registrant`** / **`registrant`** table is for the **minority** of carriers that require client registration. Implement the module and admin CRUD, but do **not** design the happy path around registration.
- **pbx3sbc-admin:** gateway CRUD is the primary carrier onboarding surface; registrant rows are an advanced/per-carrier option.

#### DID mapping — two layers; regex lives on the node

Inbound DID handling is **not** one problem solved in one place. Split **delivery** (which node receives the carrier INVITE) from **behaviour** (what Asterisk does with the call).

| Layer | Question | Mechanism | Authoring |
|-------|----------|-----------|-----------|
| **SBC** | Which **node/backend** gets this DID? | `dr_rules` (groupid **1**) — **compiled projection**, not hand-typed | Fleet orchestrator / reconcile job from catalog + `inroutes` |
| **Node (tenant)** | Where does the call **go** (ext, IVR, queue)? | **`inroutes.pkey`** — Asterisk-format **regex/mask** | Tenant admin (existing inbound-route panels) |

**On the node, one expression type covers everything.** `inroutes.pkey` is documented as *“inbound number, CLID or mask (in Asterisk format)”* — a **regex**, not a fixed contiguous block assumption. A tenant can define:

- a **block** (`_+441234567XXX`),
- a **singleton** (`_+441234567890`),
- or a **split / non-contiguous range** (multiple rows, or one pattern with alternation),

without a separate “singleton vs block” data model on Asterisk. That flexibility **stays on the node**; the SBC does not replicate dialplan semantics.

**SBC delivery projection (author once, derive):** see **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §11.9–§11.10.

- **Source of truth for behaviour:** tenant `inroutes` (regex `pkey` + `openroute`/`closeroute`/CLIP/transform).
- **Source of truth for homing:** S3 directory (`tenant → node` in `meta.json`; optional **`dids.json`** for reseller/trunker — see **`DID_ASSIGNMENT_DESIGN.md`**).
- **SBC rows are derived:** `DID → tenant → node → setid` — regenerated on **move**, never independently edited.

**Default SBC projection:** one `dr_rules` row per active inbound DID (full E.164 as prefix → tenant’s current `setid`). Longest-prefix with a full number is effectively exact match — works for scattered singletons without `alias_db`.

**Optional compression:** when reconcile detects a **contiguous** set of `inroutes` DIDs for one tenant, collapse to one prefix rule — an optimisation only, never assumed at design time.

**`alias_db`:** PEERING-PLAN fallback in OpenSIPS when `do_routing("1")` finds no match — not the primary fleet model. Do not force operators to maintain parallel prefix + alias inventories.

**Tenant move:** `inroutes` regex rows travel in the tenant miniDB; SBC delivery rows are **bulk-regenerated** to the new `setid` in the same job as `domain.setid`. No carrier reprovision.

#### Dispatcher source-IP lookup (noted)

`GET_DOMAIN_FROM_SOURCE_IP` fails when dispatcher rows use hostname instead of IP (seen on golden). **Fix before peering Phase 1:** store Asterisk **source IP** in dispatcher `attrs` (or DNS-aware lookup). Affects the “from Asterisk → PSTN” branch and multi-tenant outbound.

---

## 6. SBC high availability — fleet prerequisite

A single SBC is acceptable for **lab / golden validation**. **Production fleet** label requires:

| Requirement | Notes |
|-------------|--------|
| **Pool of identical SBC instances** | Same `pbx3sbc` image; shared or replicated MySQL routing DB; horizontal scale-out — no special “primary/secondary” roles in application logic |
| **DNS SRV pool (preferred)** | Phone-facing name resolves to **multiple SRV targets** (one per pool member). Most SIP phones support **multiple outbound proxy / path definitions** — provision primary + secondary SRV targets (or equivalent phone failover list) rather than a single hidden VIP |
| **Directory record** | `sbc-fleet` with `sip_proxy_fqdn` (SRV name), `admin_api_url`, `member_hosts` — see **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §4.1 |
| **Node `Egress` / `EgressFailover`** | Point at SRV name or two pool members — mirrors phone-side redundancy |

**Design intent:** Operate a **pool of interchangeable SBCs** behind SRV, not a bespoke active/passive pair. Floating IP remains a valid ops alternative but is **not** the preferred product direction.

**Not a blocker for:** Peering Phase 0–1 on single `sbc.pbx3.com`, Phase A Egress on golden/bzy54n.

**Is a blocker for:** “production fleet” SLA claims before SRV pool + ≥2 members are documented and tested.

### 6.1 WebRTC / WSS endpoints (fleet edge)

**Business driver:** Fleet product should support WebRTC client apps (browser or embedded) on the **same stable edge** as desk phones — not as a separate direct-to-node bypass.

**Status:** **Out of fleet v1** (UDP SIP soak, peering, Phase A Egress, move wizard). **Feasible on pbx3sbc** — separate track after UDP edge is proven. See **`pbx3sbc/docs/MASTER-PROJECT-PLAN.md`** §4 (TLS & WebRTC).

#### Today

| Layer | WebRTC / WSS |
|-------|----------------|
| **pbx3sbc** | **Not implemented** — `socket=udp:0.0.0.0:5060` only (`proto_udp.so`). No `proto_ws` / `proto_wss`, no TLS listener. |
| **Fleet node (Asterisk)** | **Implemented** — `transport-wss` on `:8089`; `pjsip_webrtc.tmpl` (`webrtc=yes`, DTLS, opus). |

WebRTC clients today register **directly to the node** (`wss://<node-fqdn>:8089/...`), not through the SBC.

#### Fleet tension

Fleet posture requires phones (and soft clients) to use the **stable SBC address** so tenant move = SBC repoint only. WebRTC hitting the **node** breaks that:

- Registrations and INVITEs bypass the SBC edge.
- Tenant move does **not** carry WebRTC clients with `domain.setid` repoint.
- Node firewall must admit **browser/WebRTC** sources as well as SBC — weakens “SBC-only SIP ingress.”

So **desk-phone fleet v1** and **WebRTC fleet** are not the same milestone.

#### Target architecture (v2 track)

```text
WebRTC app  →  wss://<sbc-pool-fqdn>  →  OpenSIPS (proto_wss + TLS)
                    →  usrloc / dispatcher  →  Asterisk backend (UDP/TCP)
                    →  media: see below
```

**Signaling (OpenSIPS — feasible):**

- `proto_wss` + TLS cert on SBC (LE on pool FQDN / SRV name).
- Extend registrar / `nathelper` / Contact handling for `;transport=wss` (same class of work as UDP NAT fixes).
- Same `domain` → `setid` mobility model as UDP endpoints.

**Media (harder than signaling):**

- SBC today is **RTP bypass** — media flows endpoint ↔ Asterisk; SBC handles signaling only.
- WebRTC uses **DTLS-SRTP + ICE**. Scenarios:
  - **WebRTC ↔ WebRTC** (app-to-app via PBX) — Asterisk may anchor; SBC may stay signaling-only if SDP/ICE paths are consistent.
  - **WebRTC ↔ PSTN or UDP desk phone** — often needs **media anchoring** (e.g. **RTPEngine** on the edge, or full media through Asterisk). **Decision deferred** until the target app media profile is known (codec, ICE, TURN use).

**TURN/STUN:** WebRTC apps often need **STUN/TURN** for NAT traversal. Clarify whether the app brings its own TURN, expects MSP-provided TURN, or relies on Asterisk/OpenSIPS. Not part of pbx3sbc v1.

#### Interim posture (lab / early rollout)

Until WSS lands on the SBC:

| Mode | Path | Mobility |
|------|------|----------|
| **Interim (hybrid)** | WebRTC → **node** `:8089` WSS; desk phones → **SBC** UDP | Desk phones mobile on move; **WebRTC not mobile** until WSS-on-SBC ships |
| **Target (fleet)** | All endpoints → **SBC** (UDP + WSS) | Full mobility on tenant move |

**Sales/engineering honesty:** onboard WebRTC on the **interim** path for pilot; contract fleet **move** and **single edge URL** for WebRTC as a **phase-2 deliverable** tied to the WSS track.

#### Implementation order (does not block v1)

```text
1. UDP edge stable     — soak, peering, Phase A (current plan)
2. TLS on SBC          — proto_tls / cert management (prerequisite for WSS)
3. WSS listener        — proto_wss, registrar paths for WebSocket clients
4. Media strategy      — RTPEngine vs Asterisk-only; per target app media profile
5. Provision template  — wss://<sbc-pool> for app; same SRV pool as desk phones
```

**Does not block:** SBC soak (UDP phones), peering Phases 0–4, Phase A Egress, move wizard v1 (UDP endpoints).

---

## 7. Solo / direct-to-node (Rule 6)

Per **`DESIGN_RULES.md`** Rule 6: single-box installs stay frictionless — no catalog, no SBC, no forced `Egress` abstraction.

- Real carrier trunks on the node.
- Route `path1`–`path4` and SPA trunk picker **unchanged**.
- Tenant migration (if ever needed) uses **`TENANT_MIGRATION_RUNBOOK.md`** — DNS cutover + trunk pkey alignment on destination.

Fleet features (Fleet Console, SBC repoint move wizard) are **opt-in** when org + directory + SBC are provisioned.

---

## 8. Break-glass and migration paths

| Scenario | Path |
|----------|------|
| **Fleet tenant move (happy path)** | Export/import + `SbcFleetAdapter.repointTenant` |
| **Fleet SBC down (calls in flight)** | Existing dialogs may complete; new registrations/PSTN need SBC — fail over to standby SBC / HA address |
| **Fleet SBC down (prolonged)** | Emergency: point carrier at node IP + temporary node trunks — **unsupported product path**, ops runbook only |
| **Non-SBC fleet member** | **`TENANT_MIGRATION_RUNBOOK.md`** (S8.5–S8.6) — DNS + manual catalog |

---

## 9. Implementation sequence (locked order)

```text
1. SBC soak          — more tenants/handsets on current edge (in progress)
2. Phase A           — Egress trunk on fleet nodes; SPA/cagi fleet route behaviour
3. SBC peering 0–4   — carrier outbound + inbound DID → backend (PEERING-PLAN)
4. B′ control plane  — gatekeeper, §2.6.1 IAM (done), Fleet Console shell
5. Phase C           — move wizard (SBC repoint + tenant export/import)
6. WebRTC / WSS      — §6.1; after UDP edge proven; interim = node :8089 for pilot fleets
```

**Deferred:** S7 recordings S3 until B′ gatekeeper. Solo trunk model unchanged throughout. **WebRTC fleet mobility** deferred to step 6 (interim hybrid supported).

---

## 10. Open items (not blocking this decision)

| Item | Owner | Note |
|------|--------|------|
| SBC SRV pool runbook | pbx3sbc fleet docs | **Direction locked:** SRV + identical pool; document record templates, weights, and phone provisioning examples |
| `GET_DOMAIN_FROM_SOURCE_IP` hostname gap | pbx3sbc | **Noted** — store Asterisk source IP in dispatcher `attrs`; gate for peering Phase 1 |
| **WebRTC / WSS on SBC** | pbx3sbc | §6.1 — `proto_wss` + TLS; media (RTPEngine?) TBD; **interim:** node `:8089` |
| WebRTC app profile | Product | Codecs, ICE, TURN — gates media design for §6.1 step 4 |
| Phone TLS termination | Product | SBC vs node — overlaps §6.1 TLS track |
| `sbc-fleet.v0.json` schema | pbx3-directory | Directory contract for adapter; `sip_proxy_fqdn` = SRV name |

---

## 11. References

| Document | Role |
|----------|------|
| **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §2–§3 | SBC-required fleet, egress model, Phase A scope |
| **`pbx3sbc/workingdocs/PEERING-PLAN.md`** | OpenSIPS `drouting` implementation phases |
| **`FLEET_SYSTEM_OVERVIEW.md`** | Stakeholder runtime vs management path |
| **`IMPLEMENTATION_PLAN.md`** § S8.10 | Program schedule |
| **`TENANT_MIGRATION_RUNBOOK.md`** | Direct-to-node / break-glass migration |
| **`DID_ASSIGNMENT_DESIGN.md`** | Mode A (inroutes-only) vs Mode B (central registry); S3 layout; projection |
| **`pbx3sbc/docs/MASTER-PROJECT-PLAN.md`** §4 | TLS & WebRTC on OpenSIPS (planned) |
| **`DESIGN_RULES.md`** Rule 6 | Solo frictionless path |
| **`DESIGN_RULES.md`** Rules 7–8 | Replaceable edge; catalog → SPA one-way |
| **`ARCHITECTURE_REVIEW_SCORECARD.md`** | Honest positioning, drills, red-team checklist |
| **`ARCHITECTURE_PEER_REVIEW.md`** | Full external challenge narrative (grounding) |

---

## 12. Change log

| Date | Change |
|------|--------|
| 2026-07-09 | §2.4 founding Rules 7–8 — replaceable edge; SIP runtime API; catalog → SPA one-way |
| 2026-07-09 | §6.1 WebRTC/WSS — out of v1; interim node :8089; target WSS on SBC |
| 2026-07-09 | DID: two-layer model — regex `inroutes` on node; SBC delivery projection only; per-DID default |
| 2026-07-09 | Caveats: trusted-peer default (not registration); SRV pool HA preference; dispatcher IP lookup noted |
| 2026-07-09 | Initial decision doc — fleet = SBC peering only; solo = node trunks; Phase A Egress spec; HA prerequisite |
