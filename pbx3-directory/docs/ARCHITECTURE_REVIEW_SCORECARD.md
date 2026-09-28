# PBX3 fleet — architecture review scorecard

**Status:** Living document — re-score after major drills or phase completions.  
**Audience:** Product, architects, ops leads — honest architecture drills and rule enforcement (not competitive marketing).  
**First review:** 2026-07-09  
**Related:** `FLEET_SYSTEM_OVERVIEW.md` · `DESIGN_RULES.md` · `FLEET_TRUNK_PEERING_DECISION.md` · `TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md` · `IMPLEMENTATION_PLAN.md`

---

## One-line verdict

PBX3 fleet is **telco-style federation** (sovereign nodes + replaceable SIP edge + async ops catalog), **not** a monolith multi-tenant cloud PBX. That is the **right trade for MSP mobility and blast-radius control**; it is the **wrong trade** if the primary goal is minimum infra cost per seat on a single shared box.

**Use this doc to:** (1) run repeatable drills with numbers, (2) block designs that violate founding rules, (3) track dimension scores honestly.

**Private competitive narrative** (OSS-excluded): `~/GiT/pbx3-ops/devdocs/oss-move/competitive/ARCHITECTURE_PEER_REVIEW.md`.

---

## 1. What we are (industry label)

| Label | Fit |
|-------|-----|
| **OpenSIPS/Kamailio farm + Asterisk workers** | **Primary cousin** — domain homing, dispatcher, drouting, SBC choke point |
| **EC2-cell / cell-based SaaS** | **Management model** — fleet console discovers cells; each cell owns IAM and runtime |
| **Monolith multi-tenant hosted PBX** | **Explicit non-goal** for fleet product (shared-box density) |
| **CPaaS** | **Different category** — API control plane; compare only for SIP trunking / ops automation rows |

---

## 2. Dimension scorecard

**Scale:** 1 = weak vs peers · 3 = acceptable for target ICP · 5 = industry-leading for MSP fleet PBX  
**As of 2026-07-09** — subjective but grounded in committed design + known gaps. Update after drills.

| Dimension | Score | Target | Notes (honest) |
|-----------|:-----:|:------:|----------------|
| Call path independent of control plane | **5** | 5 | Rules 1, 5, 7 — **genuine strength**; many SMB products fail here |
| Tenant mobility without phone reprovision (fleet) | **4** | 5 | SBC repoint is sound; **move wizard + miniDB** not yet proven at scale |
| Blast radius / per-tenant isolation | **5** | 5 | Sovereign nodes + tenant DB — **strong** vs monolith |
| Solo / trial friction (Rule 6) | **5** | 5 | One box, no S3 — **better than** most “cloud only” PBX |
| Edge replaceability (`SbcFleetAdapter`) | **4** | 5 | **Designed well**; only one adapter impl exists today |
| Catalog → SPA one-way (Rule 8) | **4** | 5 | Principle locked; **enforce in every schema/PR review** |
| Operator platform (SSO, fleet admin, jobs) | **2** | 4 | Phase D/B′ **deferred** — runtime ahead of console |
| Fleet observability / SRE | **1** | 3 | v0 = no live health in catalog; **EC2 without CloudWatch** |
| S3 / catalog consistency at scale | **2** | 4 | Fine at low churn; **gatekeeper not built** — biggest scale seam |
| PSTN path efficiency (fleet double-hop) | **3** | 3 | Acceptable trade for mobility; **measure latency**, don’t assume |
| WebRTC / modern endpoint story | **1** | 3 | Phase W1 deferred; commercial hosted stacks often lead **for now** |
| Compliance runway (STIR/SHAKEN, audit) | **2** | 4 | Edge is natural home; **not productized yet** |
| Operational cognitive load | **2** | 3 | Many layers (node, SBC, S3, adapter, solo vs fleet) — **docs help; runbooks must match** |
| Cost efficiency (low tenant count) | **2** | 2 | **By design** — don’t score ourselves down for a trade we chose |

**Weighted read:** Runtime architecture **≥ 4**; operator platform **≤ 2**. That gap is **expected** until B′/D/W1 land — not a surprise, but **is** the operator-platform exposure.

---

## 3. Validated bets (keep)

| Bet | Why it survives scrutiny |
|-----|--------------------------|
| **Nodes never depend on directory/S3 for calls** | Matches serious SBC/OSS separation; avoids “license server blocks RTP” failure mode |
| **Carriers on SBC in fleet mode** | Required for move without carrier reprovision; aligns with peering farms |
| **`Egress` fixed trunk on nodes** | Eliminates dangling `path1` after tenant import — **real bug class** avoided |
| **SBC delivery vs node `inroutes` behaviour** | Two-layer DID — delivery rots if centralised; behaviour stays tenant-owned |
| **Solo path without fleet** | Product funnel + ops simplicity; fleet is opt-in |
| **SIP as runtime API + adapter seam** | Swap edge without rewriting nodes or orchestrator job model |

---

## 4. Honest challenges (do not hand-wave)

| Challenge | Severity | Mitigation / measure |
|-----------|----------|----------------------|
| **Move is orchestration-heavy** vs central-DB “flip a row” | High (UX) | Time-boxed maintenance window v1; drill cutover + rollback; publish RTO |
| **S3 races** (two writers, stale index) | High (ops) | B′ gatekeeper; single writer; git-review index until then |
| **Fleet PSTN double-hop** `Phone→SBC→Node→SBC→Carrier` | Medium | Latency drill; PCAP on production pilot; document vs solo |
| **SBC = PSTN choke point** | Medium (accepted) | SRV pool + shared DB; drill single-SBC loss |
| **Org-wide S3 IAM on nodes** (§2.6 mobility doc) | **High (security)** | Tighten to `instances/{ksuid}`; gatekeeper for `tenants/*` writes |
| **Control plane maturity lag** | Medium (market) | Phase B′/D; don’t promise MSP parity before shipped |
| **WebRTC deferred** | Medium (market) | Phase W1; interim node `:8089` — document limits |
| **Density / $/seat** vs monolith | Low for fleet ICP | Economic worksheet §7; don’t compete on cheapest shared hosting |

---

## 5. Scenario drills (repeatable benchmarks)

Run in **staging fleet** first; repeat quarterly on production pilot. Record results in §8 log.

### 5.1 Tenant move (fleet, same SBC pool)

| Metric | How to measure | Pass (initial) | Stretch |
|--------|----------------|----------------|---------|
| Planned maintenance window | Wall clock, announced | ≤ 15 min | ≤ 5 min |
| Failed calls during cutover | CDR / test handset | 0 on test extensions | 0 production |
| Phone re-registration time | SIP trace / phone UI | ≤ 120 s | ≤ 60 s |
| Rollback time | Orchestrator + adapter | ≤ 10 min | ≤ 5 min |
| Post-move: inbound PSTN | Test DID | Works | Works |
| Post-move: outbound PSTN | Test route | Works via `Egress` | Works |
| Catalog vs SBC truth | Compare S3 `meta.json` vs edge | Match within 1 min | Strong consistency |

**Procedure pointer:** `TENANT_MIGRATION_RUNBOOK.md` · `TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md` §6.

### 5.2 SBC instance loss (SRV pool)

| Metric | Pass (initial) |
|--------|----------------|
| New INVITE success after failover | ≥ 99% within 5 min drill window |
| REGISTER recovery | Phones re-home without manual reprovision |
| In-flight calls | Document survive vs drop (no surprise) |

### 5.3 Catalog / S3 unavailable

| Question | Required answer |
|----------|-----------------|
| Do established calls continue? | **Yes** |
| Can existing registrations work? | **Yes** (edge + node local) |
| Can tenant admin open SPA to known `api_base_url`? | **Yes** (Rule 3 break-glass) |
| Can a **new** tenant move start? | **No** (acceptable) — must fail safe, not half-apply |

### 5.4 Single node loss

| Metric | Record |
|--------|--------|
| RTO restore from backup | ___ min |
| Tenants affected | count |
| SBC still routes other tenants | Yes/No |

### 5.5 Solo → fleet promotion

| Metric | Record |
|--------|--------|
| Steps count | |
| DNS / phone change required? | Should → **no** (phones to SBC) |
| Downtime | ___ min |

### 5.6 Fleet PSTN latency (sanity)

| Path | RTT / post-dial delay (ms) |
|------|----------------------------|
| Solo: Phone → Node → Carrier | |
| Fleet: Phone → SBC → Node → SBC → Carrier | |
| Delta | Document if > ___ ms (set threshold per market) |

---

## 6. Reference architecture crosswalk

Map PBX3 layers to published patterns. **Gap = missing doc, code, or drill.**

| External pattern | PBX3 equivalent | Doc / code | Gap? |
|------------------|-----------------|------------|------|
| OpenSIPS **dispatcher** + **domain** | Tenant domain → node `setid` | `pbx3sbc/workingdocs/PEERING-PLAN.md` | Dispatcher IP attrs (known fix) |
| OpenSIPS **drouting** | Carrier/LCR on SBC | PEERING-PLAN | Phases 1–4 in flight |
| Asterisk **per-tenant DB** | Tenant miniDB export/import | `TENANT_MIGRATION_RUNBOOK.md` | Tooling S8.5–S8.6 |
| **Cell-based** SaaS / EC2 fleet | Sovereign nodes + catalog | `DESIGN_RULES.md` | Fleet badges deferred |
| **S3 as async config** (not hot path) | Catalog, backups, recordings | `S3_LAYOUT_PROPOSAL.md` | Gatekeeper B′ |
| **Anti-corruption layer** | `SbcFleetAdapter` | Mobility §2.4 | Second adapter impl = proof |

---

## 7. Capability priorities (ICP: MSP fleet + mobility)

**Not** a rival feature checklist — **Must / Should / Won’t** for *our* product.

| Capability | PBX3 fleet (committed) | Notes |
|------------|------------------------|-------|
| Tenant move without phone reconfig | **Must** | Our core bet |
| Solo install, no cloud deps | **Must** (Rule 6) | Funnel |
| Central instance picker | **Must** (v0) | |
| SSO across fleet | **Should** (Phase D) | **Gap today** |
| Fleet health dashboard | **Should** (later) | **Gap today** |
| WebRTC softphone at edge | **Should** (W1) | **Gap today** |
| STIR/SHAKEN | **Should** (edge) | Planned at SBC |
| API-first everything | **Won’t** (v1) | SIP + node API first |
| Cheapest $/seat density | **Won’t** | Not our game |

Named-vendor parity matrix (private): `~/GiT/pbx3-ops/devdocs/oss-move/competitive/ARCHITECTURE_COMPETITIVE_EXCERPTS.md`.

---

## 8. Drill log

| Date | Scenario | Environment | Result | Owner | Follow-up |
|------|----------|-------------|--------|-------|-----------|
| 2026-07-08 | Inter-extension via SBC | `sbc.pbx3.com` pilot | **Pass** (manual) | — | Soak more tenants |
| | Tenant move E2E | | | | |
| | SBC failover | | | | |
| | S3 down drill | | | | |

---

## 9. Red-team checklist (every fleet feature PR)

| # | Question | If **yes** → |
|---|----------|--------------|
| R1 | Does this put directory/S3/control plane in the **SIP/RTP path**? | **Reject** (Rule 1) |
| R2 | Does runtime **require** catalog fetch to place/answer a call? | **Reject** |
| R3 | Does orchestrator call OpenSIPS tables/CLI **directly**? | **Reject** — use `SbcFleetAdapter` (Rule 7) |
| R4 | Does schema add SPA-specific fields (`spa_*`, route names, form keys)? | **Reject** (Rule 8) |
| R5 | Does SPA shape **define** fleet JSON (not derive display from fleet facts)? | **Reject** (Rule 8) |
| R6 | Does this assume **only** pbx3sbc (no adapter swap story)? | **Fix** — document adapter method |
| R7 | Does fleet feature **break** solo Rule 6 path? | **Fix** — fleet opt-in only |
| R8 | Two writers to same S3 object without gatekeeper? | **Reject** until B′ |

---

## 10. Economic sanity (worksheet)

Fill annually or when pricing fleet SKU.

| | Solo node | Fleet (per tenant) |
|--|-----------|---------------------|
| VMs (node + SBC amortised) | | |
| S3 / egress | | |
| Ops hours / month (per 100 tenants) | | |
| **$/tenant/month** (internal) | | |

**Win condition:** Fleet line wins on **move cost + MSP ops hours**, not raw VM density. If fleet $/seat ≫ shared-box density at same N, that is **OK** if mobility SLA justifies it — **document the SLA**.

---

## 11. When to re-score this document

| Trigger | Action |
|---------|--------|
| First successful **automated** tenant move | Update mobility score; fill §8 |
| B′ gatekeeper shipped | Bump catalog consistency to 3–4 |
| Phase D SSO shipped | Bump operator platform |
| Phase W1 WSS on SBC | Bump WebRTC row |
| Production pilot **> 3 tenants** on SBC | Complete §5.1–5.6 drills |
| Security incident on org S3 | Revisit §4 IAM row immediately |
| Second `SbcFleetAdapter` implementation (even stub) | Bump edge replaceability to 5 |

---

## 12. External knowledge limits

Model/training knowledge of commercial PBX internals is **incomplete and dated**. Treat third-party architecture claims as **hypotheses** until verified via:

1. **Drills** (§5) — our ground truth  
2. **MSP interviews** — 2–3 operators on OpenSIPS+Asterisk farms  
3. **Public docs only** for peer engines (Kamailio / OpenSIPS) and any vendor under review — note version and date  
4. **This scorecard** — updated after each drill, not after each blog post  

Competitive narrative excerpts stay in private ops (`oss-move/competitive/`).

---

## 13. Related docs

| Topic | Doc |
|-------|-----|
| Stakeholder overview | `FLEET_SYSTEM_OVERVIEW.md` |
| Non-negotiable rules | `DESIGN_RULES.md` |
| Trunk / peering | `FLEET_TRUNK_PEERING_DECISION.md` |
| Move wizard + control plane | `TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md` |
| Build phases | `IMPLEMENTATION_PLAN.md` |
| Move procedure | `TENANT_MIGRATION_RUNBOOK.md` |
| SBC implementation | `pbx3sbc/workingdocs/PEERING-PLAN.md` |
