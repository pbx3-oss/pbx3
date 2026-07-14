# PBX3 fleet — architecture peer review (grounding document)

**Status:** Reference — **not** a living scorecard (use `ARCHITECTURE_REVIEW_SCORECARD.md` for drills and re-scoring).  
**Audience:** Product, architects, ops — read when you need to stay grounded on *what we are* and *what we are not*.  
**First written:** 2026-07-09 (external architecture challenge vs comparable systems).  
**Related:** `FLEET_SYSTEM_OVERVIEW.md` · `DESIGN_RULES.md` · `ARCHITECTURE_REVIEW_SCORECARD.md`

---

## How to use this doc

- **Read this** when debating product direction, comparing to competitors, or feeling pressure to “just use a central DB like everyone else.”
- **Run drills and update scores** in `ARCHITECTURE_REVIEW_SCORECARD.md` — numbers live there, not here.
- **Training-data caveat (§8)** applies forever: commercial internals change; verify with drills and operator interviews.

---

## 1. What you built (in industry terms)

PBX3 fleet is closest to **“Kamailio/OpenSIPS farm + Asterisk workers + async ops catalog”**, productized with **tenant portability** as a first-class concern. That pattern is common in **carrier and large MSP** builds; it is **uncommon** in SMB hosted-PBX products, which usually pick one of:

| Pattern | Examples | Mobility model |
|--------|----------|----------------|
| **Monolith multi-tenant** | FusionPBX multi-tenant, many VitalPBX/Yeastar cloud installs | Tenants share one DB; “move” = row update, not fleet orchestration |
| **Central product + distributed workers** | 3CX (MSP/cluster), some Wildix | Central console; clustering varies; not always “phone never changes FQDN” |
| **API control plane + global edge** | Twilio, Bandwidth, Telnyx | Mobility is trivial in software; not a classic PBX admin model |
| **Carrier class-5** | BroadWorks, Metaswitch | Massive centralized routing; mobility is ops-heavy, not DIY |
| **DIY telco stack** | OpenSIPS + RTPengine + Asterisk farms | **Your nearest cousin** — domain routing, dispatcher, drouting, SBC choke point |

Your **EC2-cell + SBC front door + S3 filing cabinet** model is not weird. It is a **disciplined version of a pattern telco engineers already trust**, with clearer separation of runtime vs management than most open-source PBX stacks document.

---

## 2. Where the design measures well (genuinely strong)

### 2.1 Runtime vs management separation (Rules 1, 5, 7)

This is textbook good. Many products quietly violate it (central DB in the registration path, “cloud license server” gates calls). Your golden rule — *calls survive catalog/control-plane outage* — matches how serious SBC deployments are supposed to behave. **Better than** typical monolithic hosted PBX.

### 2.2 Fleet trunk placement decision

Putting carriers on the SBC and fixing nodes to `Egress` is the **right** trade for tenant mobility. The rejected hybrid (phones via SBC, carriers on nodes) would have been a chronic migration tax. This aligns with **OpenSIPS peering farms** and enterprise SBC practice.

### 2.3 Sovereign nodes (Rule 6 solo path)

Most “cloud PBX” products force you into their control plane on day one. Letting solo = install + SPA + node API, fleet = opt-in, is a **product and ops win**. Comparable to “single EC2 works without Organizations” — rare in telephony products.

### 2.4 Replaceable edge + SIP as wire API (Rule 7)

`SbcFleetAdapter` as the only orchestrator touchpoint is mature architecture. Many teams embed OpenSIPS table knowledge in app code and never escape it. You are **ahead of** where most Asterisk+OpenSIPS DIY farms end up after three years.

### 2.5 Catalog → SPA one-way (Rule 8)

Prevents a failure mode seen repeatedly in internal platforms: admin UI shape becomes the schema, then every new client needs a migration. **Better than** many internal MSP portals.

### 2.6 DID two-layer model

SBC = delivery (which node), node `inroutes` = behaviour (regex, blocks, splits) is clean. Central registries that try to own dialplan semantics usually rot. **Sensible vs** “one giant DID table owns everything.”

### 2.7 v0 boring catalog

Static `instance-index.json`, login-time fetch, defer fleet telemetry — correct for stated scale. **Better than** over-building a mini-AWS before you have MSP traffic.

---

## 3. Where to expect pressure (honest challenges)

### 3.1 Mobility and blast radius vs minimum cost per seat

Monolith multi-tenant runs more tenants per VM. Your model trades **ops clarity and move simplicity** for **more moving parts** (SBC tier, S3, orchestrator, per-node sovereignty). For 50 tenants on one box, FusionPBX-style multi-tenant is cheaper. For **MSP fleet + tenant moves**, your model wins. Be explicit about target scale; the design is right for **fleet MSP**, not “cheapest shared hosting.”

### 3.2 PSTN path is a deliberate double-hop in fleet mode

`Phone → SBC → Node → Egress → SBC → Carrier` adds latency and failure domains vs solo node trunks. Industry accepts this **when** mobility and edge security matter. **Measure it**; don’t assume it’s negligible for international or latency-sensitive customers.

### 3.3 Tenant move is orchestration-heavy vs “flip a row”

Even with SBC repoint, you still have miniDB export/import, registration refresh, in-flight calls, optional DID projection. Products like 3CX or central-DB multi-tenant can feel “instant” because the tenant never left the shared brain. Your move is **safer for blast radius** but **harder to make invisible**. Industry leaders either accept a maintenance window or invest heavily in hot migration (v1 MVP is conservatively scoped — fine, but it’s a competitive gap until proven).

### 3.4 Control plane is still aspirational relative to runtime

Runtime design is ahead of: central auth (Phase D deferred), gatekeeper for S3 races, fleet health/observability, WebRTC/WSS (Phase W1). Compared to 3CX or commercial cloud PBX, **admin UX cohesion** and **single sign-on across fleet** will lag until Phase D/B′ land. The architecture allows catching up without rewriting telephony — that’s the point of Rules 7–8 — but **today** you’re stronger on call architecture than on operator platform maturity.

### 3.5 S3 as ops source of truth has a ceiling

Fine at small fleet, low churn. Competitors at scale use **Postgres + job queue + event log**. The gatekeeper idea is the right mitigation; until it exists, **catalog races** are the biggest architectural risk vs “boring central DB.” Not wrong — **immature relative to scale**, not wrong at v0.

### 3.6 SBC HA — active–passive (updated 2026-07-14)

**Prior note:** SRV pools of OpenSIPS with shared DB is standard DIY; commercial SBCs offer deeper tooling.

**Product direction now:** Prefer **active–passive + VIP** with **local MySQL projections** (no shared live DB on the call path). Still measure failover time and registration recovery — don’t infer from design docs. See **`FLEET_TRUNK_PEERING_DECISION.md`** §6.

### 3.7 Security/compliance runway

STIR/SHAKEN, robocall mitigation, TLS/SRTP ubiquity, audit logging across fleet — enterprise buyers will score these. The design doesn’t block them (edge is the natural home), but **deferred WebRTC/TLS normalization** is a gap vs competitors pitching “modern comms.”

### 3.8 Internal complexity budget

You now have: node dialplan, SBC drouting, dispatcher, adapter, S3 schemas, two DID modes, move wizard, solo vs fleet divergence. **Operational cognitive load** is high. Monolith competitors trade that for less flexibility. Good docs help; **runbooks and drill frequency** determine whether this is an advantage or a support burden.

---

## 4. Scorecard snapshot (2026-07-09)

Rough positioning against “serious fleet PBX / MSP platform.” **Update scores in `ARCHITECTURE_REVIEW_SCORECARD.md`** after drills.

| Dimension | PBX3 design | Typical monolith cloud PBX | DIY OpenSIPS farm | CPaaS (Twilio-class) |
|-----------|-------------|----------------------------|-------------------|----------------------|
| Call path independence from control plane | **Strong** | Weak–medium | Strong (if done right) | Strong |
| Tenant mobility without phone reprovision | **Strong** (fleet) | Medium | Strong (if built) | N/A (different product) |
| Blast radius / tenant isolation | **Strong** | Weak | Medium | Strong (logical) |
| Cost efficiency at low tenant count | Medium | **Strong** | Medium | Pay-per-use |
| Operator platform maturity | Medium (planned) | **Strong** | Weak | **Strong** (API) |
| Edge replaceability | **Strong** (explicit) | Weak | Medium | N/A |
| Time-to-first-working-box (solo) | **Strong** (Rule 6) | Medium | Weak | Weak |
| Observability / fleet SRE story | Weak (v0) | Medium | Weak | **Strong** |

**Weighted read:** Runtime architecture scores high; operator platform scores low until B′/D/W1 — **expected**, but that **is** the competitive exposure.

---

## 5. Verdict

The design is **coherent and defensible**. It is **not** trying to be the cheapest multi-tenant monolith; it is trying to be a **portable, EC2-like fleet with a replaceable SIP edge** — and on that goal it compares **favorably** to both DIY farms (better documentation and boundaries) and SMB cloud PBX products (better mobility and blast-radius story).

The main risks are not “wrong layer split.” They are **execution and scale seams**: move wizard reliability, S3 consistency/gatekeeper, fleet observability, central auth, and proving the double-hop PSTN path is acceptable in production.

**One sentence for stakeholders:** You chose telco-style federation over monolith simplicity; that is the right trade for MSP mobility **if** you invest in orchestration and ops tooling to match the runtime architecture.

---

## 6. What we do not know reliably — and how to measure

Training knowledge of commercial PBX internals is **incomplete and dated**. Do not treat “how 3CX does tenant move internally” as ground truth without verification.

### 6.1 Scenario benchmarks (repeatable drills)

| Scenario | Metrics |
|----------|---------|
| Tenant move (same fleet) | Cutover time, failed calls, re-registration time, rollback time |
| SBC single instance loss | Time to recover registrations, new call failure rate |
| S3/catalog unavailable | Can admin still work? Can new moves start? Do calls continue? |
| Node loss | RTO for tenants on that node, backup restore time |
| Solo → fleet promotion | Steps, downtime, data migration risk |

Detailed pass criteria: **`ARCHITECTURE_REVIEW_SCORECARD.md`** §5.

### 6.2 Reference architecture crosswalk

Map each layer to a published pattern and note deltas:

- OpenSIPS **dispatcher + domain** → SBC homing  
- **drouting** → carrier/LCR on edge  
- **Asterisk per-tenant DB** → miniDB portability  
- AWS **cell-based architecture** / **static discovery** → S3 catalog  

Gaps in the crosswalk = intentional bets or missing pieces.

### 6.3 Competitive parity matrix (for your ICP only)

Rows: tenant move, MSP multi-instance admin, SSO, WebRTC, STIR/SHAKEN, recording retention, solo install, API automation.  
Columns: PBX3 fleet v1, 3CX MSP, one OpenSIPS+Asterisk reference build, optional Twilio Elastic SIP.  
Score **Must / Should / Won’t** — not feature count. Template: **`ARCHITECTURE_REVIEW_SCORECARD.md`** §7.

### 6.4 Operator interviews

Talk to 2–3 MSPs running **OpenSIPS/Kamailio + Asterisk** (not sales demos). Ask: what broke at night, what they wish they’d centralized, what they’re glad they kept on the node. That cohort is the **real** comparator.

### 6.5 Red-team the founding rules

Try to violate Rule 1 or Rule 8 in a design review for the next feature. If a proposal needs “directory in the call path” or “add `spa_panel_key` to `meta.json`,” reject it. Rules are only as good as enforcement. Checklist: **`ARCHITECTURE_REVIEW_SCORECARD.md`** §9.

### 6.6 Economic model

$/tenant/month at N={10, 100, 1000} including: nodes, SBC VMs, S3, ops hours. Compare to monolith density. The architecture should **win on move/ops cost**, not necessarily on raw infra cost.

---

## 7. Knowledge limits (standing)

| Source | Trust level |
|--------|-------------|
| **Your drills and CDRs** | Ground truth |
| **Your design docs + locked decisions** | Ground truth for intent |
| **MSP operator interviews** | High for ops reality |
| **Public vendor docs** (versioned, dated) | Medium — verify |
| **Model/training recall of “how X works inside”** | **Low** — hypothesis only |

When in doubt: measure, drill, interview — don’t debate from memory.

---

## 8. Related docs

| Topic | Doc |
|-------|-----|
| Stakeholder overview | `FLEET_SYSTEM_OVERVIEW.md` |
| Non-negotiable rules | `DESIGN_RULES.md` |
| Drills, scores, PR red-team | `ARCHITECTURE_REVIEW_SCORECARD.md` |
| Trunk / peering | `FLEET_TRUNK_PEERING_DECISION.md` |
| Move wizard + control plane | `TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md` |
| Build phases | `IMPLEMENTATION_PLAN.md` |
