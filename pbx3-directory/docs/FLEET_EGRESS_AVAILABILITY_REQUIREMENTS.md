# Fleet Egress — trunk availability & SBC failover (future requirement)

**Status:** **Not implemented** — documented 2026-07-09 after lab egress validation.  
**Related:** **`FLEET_TRUNK_PEERING_DECISION.md`** §4 (Egress / EgressFailover), §6 (SBC HA); **`FLEET_EGRESS_LAB_ROLLBACK.md`**; Phase A template **`pjsip_trunk_egress.tmpl`**.

---

## Problem (observed in lab, 2026-07-09)

1. **PJSIP qualify (OPTIONS)** from fleet Asterisk to **`sip:sbc.pbx3.com`** on the **Egress** AOR fails. SBC logs show **door-knock blocked** / no matching endpoint — the SBC is not a registrable SIP endpoint for trunk qualify in the same way a carrier peer is.
2. With default **`qualify_frequency=30`**, Asterisk marks **Egress Unavailable**. Asterisk 20 **refuses outbound** `Dial(PJSIP/num@Egress)` → `invalid URI 'Egress'`.
3. **Lab workaround (Phase A):** **`qualify_frequency=0`** on **`pjsip_trunk_egress.tmpl`**. Outbound works; endpoint shows **NonQual** / **Not in use** — **no signal of SBC reachability** on the node.
4. **Product need:** Operators and automation must know whether the **Egress path** (and ultimately PSTN) is usable **before** or **during** outage — not only when a call fails.

This is **not cosmetic**. It blocks trunk health UI, alerting, and informed failover.

---

## Requirements (when prioritized)

### R1 — SBC must answer OPTIONS for fleet Egress qualify

| Item | Detail |
|------|--------|
| **Who sends** | Fleet node Asterisk → **`contact=sip:<sbc-host>[:5060]`** on Egress AOR |
| **Who receives** | SBC (any pool member that node targets) |
| **Expected** | **200 OK** to OPTIONS (or SIP-appropriate response), not door-knock drop |
| **Scope** | Requests from **dispatcher-known Asterisk source IP(s)** with Request-URI / To matching SBC service name or a dedicated **fleet-qualify** URI |
| **Acceptance** | `pjsip show endpoint Egress` → **Avail** (or equivalent) with RTT; qualify can stay **> 0** without breaking dial |

**Open design:** Dedicated OPTIONS handler branch in **`opensips.cfg.template`** (before door-knock reject) vs always-200 for known fleet node IPs to `sbc.pbx3.com` RURI.

### R2 — Instance trunk availability visible to operators

| Surface | Behaviour |
|---------|-----------|
| **Asterisk** | Egress endpoint state reflects SBC reachability (qualify or equivalent) |
| **SPA** | Trunk / fleet health shows Egress up/down (today fleet routes **hide** path pickers — status still needed) |
| **Preflight / alerts** | **`FleetPreflightService`** (or successor) can fail or warn when Egress Unavail **before** move/cutover; push notify to subscribed operators when prioritized — **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** |

### R3 — SBC failure handling (signalling path)

When primary SBC is unreachable, outbound PSTN must not silently black-hole. Candidate approaches (pick one or combine in design review):

| Approach | Notes |
|----------|--------|
| **`EgressFailover` trunk** | Second row in instance DB (`pjsip_trunk_egress.tmpl` clone), **`contact=sip:<sbc2>`**; seed script already supports **`PBX3_SBC_EGRESS_FAILOVER_HOST`** |
| **pbx3cagi failover** | Today fleet mode **forces single Egress** — **no** path rotation. Failover requires **explicit Phase A+** work: try Egress, then EgressFailover |
| **Stable SBC VIP (preferred)** | Single trunk contact = SBC VIP — aligns with **`FLEET_TRUNK_PEERING_DECISION.md`** §6 (**active–passive**, not shared-DB SRV pool) |
| **SBC-side only** | Node always sends to the VIP; pair health is **SBC/VIP** concern — node qualify still needed for “can I reach the edge entry point?” |

**Explicitly out of scope for v1 lab:** Multi-SBC failover without documented active–passive + VIP (§6 prerequisite for production fleet SLA).

### R4 — Do not break outbound dial for qualify failure (behaviour policy)

Product must decide:

| Policy | Tradeoff |
|--------|----------|
| **A — Strict** | Unavail → no dial (today’s Asterisk default with qualify on) — good for “fail closed” if SBC is down |
| **B — Permissive dial** | Unavail still allows dial (qualify off) — good for lab; bad for ops visibility |
| **C — Qualified but failover** | Unavail on Egress → auto-seize **EgressFailover** before dial (requires R3 + cagi) |

**Recommendation to decide later:** **C** for production fleet with **R1** qualify on both trunks; keep **B** only for dev/lab flags.

---

## Current state (Phase A lab, 2026-07-09)

| Component | State |
|-----------|--------|
| **`pjsip_trunk_egress.tmpl`** | **`qualify_frequency=0`** (shipped **`117340f`**) |
| **`EgressFailover`** | Seed script only; **not** used by **pbx3cagi** fleet dial |
| **SBC OPTIONS** | Not handled for fleet node → `sbc.pbx3.com` qualify |
| **pbx3cagi** | Fleet mode → **Egress only**, no trunk failover loop |

---

## Suggested implementation order (future)

1. **SBC OPTIONS handler** for fleet Asterisk sources (R1) — unblocks re-enabling qualify on Egress template.
2. **Re-enable `qualify_frequency`** (e.g. 30) on egress template after R1 verified on golden + second node.
3. **SPA / API** trunk health from Asterisk endpoint state or AMI (R2).
4. **`EgressFailover` + cagi** sequential dial (R3) — after SBC active–passive VIP (§6) or second lab SBC exists.
5. **Peering `DR_FAILOVER`** on SBC for carrier leg — separate from node→SBC leg; already partially in template.

---

## References

| Doc | Section |
|-----|---------|
| **`FLEET_TRUNK_PEERING_DECISION.md`** | §4 Egress trunks, §6 SBC HA / active–passive VIP |
| **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** | §11.8 inbound/outbound asymmetry; §3 Phase A |
| **`FLEET_EGRESS_LAB_ROLLBACK.md`** | qualify workaround + live patches |
| **`pbx3sbc/workingdocs/PEERING-PLAN.md`** | Carrier failover (`DR_FAILOVER`) — not node→SBC |
| **`seed-fleet-egress-trunk.sh`** | `EgressFailover` optional seed |

---

*Last updated: 2026-07-09 — requirement capture; no code change beyond Phase A qualify workaround.*
