# Fleet toll fraud & call-pattern velocity (requirements)

**Status:** **V0 framing** (2026-07-22) — direction of flow + phased testable steps locked; implementation not started.  
**Related:** **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** (Gatekeeper notify delivery); **`FLEET_LOG_RETENTION_REQUIREMENTS.md`** § CDR / SQLite; instance **CoS** / dial policy (prevention); **`DESIGN_RULES.md`** Rule 1 (directory out of call path), Rule 5 (notify ≠ call-path SLA); SBC Fail2ban / pike (**SIP abuse only**).

---

## Problem

Fraudsters compromise a business PBX or SIP path and drive **high volumes of outbound** (often automated) calls to **premium-rate or high-cost international** destinations. Attackers take a cut from expensive destination carriers; the tenant or MSP gets a surprise bill.

Common patterns (industry):

| Type | Shape | Product relevance |
|------|--------|-------------------|
| **IRSF** (International Revenue Share Fraud) | Rapid concurrent / burst outbound to high-rate countries or premium ranges | **Primary target** for velocity detect |
| **Wangiri** | One-ring missed call → employee redials premium number | Later / noisy; needs inbound+outbound correlation |
| **Traffic pumping** | Manufactured calls into toll-free to trigger access charges | Mostly **carrier / toll-free** side — not instance outbound velocity |

Industry levers we already map elsewhere: **geo-restrict / CoS**, **harden credentials**, **disable DISA-class features**, **carrier fraud desk**. This track owns **monitor call patterns → alert** (and later optional act), complementary to prevention and carrier backstops.

---

## Direction of flow (locked)

```text
Prevention (CoS / dial policy / kill DISA-class features)
    → Detection (instance CDR patterns — “velocity”)
        → Notify (Gatekeeper ops-events → email)
            → Later: warn / block (only after notify proven)
                ↔ Carrier fraud desk / ITSP geo-block = backstop, not HoR
```

| Plane | Role |
|-------|------|
| **Instance** | **Detection** (+ optional later local warn/block) — next to Asterisk CDR / **SQLite searchable CDR** and CoS; knows tenant, extension, dialled dest, billsec |
| **Gatekeeper** | **Notify delivery** (+ optional rollup of events nodes already detected) — **not** the place that scores every call (**Rule 1**) |
| **SBC** | **SIP abuse** (Fail2ban, pike, door-knock) — volumetric REGISTER/INVITE; **not** dial-pattern / toll-fraud velocity |
| **Carrier** | Fraud desks / geo-blocks — complementary backstop; document as such |

**Reuse:** Same notify plane as instance-down / REGISTER-loop / Egress Unavail — structured `ops-events` → SMTP (`notify_failures` + optional ops mailbox). Do **not** invent a second mail stack.

**Prevention vs detection:** CoS / dial policy **blocks** bad dials when configured. Velocity **reports** odd patterns when prevention was incomplete, bypassed, or credentials were abused. Velocity is **not** a substitute for CoS.

---

## Phases (testable)

### V0 — Framing

| Item | Detail |
|------|--------|
| **Goal** | Spec + threat map + plane ownership settled enough to build |
| **Done when** | This document exists; prevention vs detection vs notify vs edge roles explicit; open questions listed |

**Status:** **Done** (this doc, 2026-07-22).

---

### V1 — Data plane

| Item | Detail |
|------|--------|
| **Goal** | Reliable instance CDR input for time windows and queries |
| **Direction** | **SQLite on-node** as search / velocity HoR; CSV (or dump) as cold archive — **`FLEET_LOG_RETENTION_REQUIREMENTS.md`** |
| **Done when** | Scanner (or precursor query) can read recent outbound CDR with dest, time, extension/tenant context on a lab node; retention/prune does not break the window |
| **Non-goal** | Fleet-central CDR warehouse; scoring on Gatekeeper; treating SBC MySQL `acc` as fraud signal |

---

### V2 — Detect + notify (IRSF-shaped)

| Item | Detail |
|------|--------|
| **Goal** | Thin outbound pattern rules → Gatekeeper mail |
| **Action** | **Notify only** — no auto-block until false-positive story is proven |
| **Example signals** | ≥N outbound attempts (or concurrent channels) to high-cost / international-class prefixes in T minutes; optional off-hours volume (product fork — see open questions) |
| **Emit** | Instance cron/scanner (same shape as `pbx3:ops-register-loops` / egress qualify) → `POST /api/v1/ops-events` `{type: velocity_…}` → SMTP |
| **Done when** | Lab-seeded burst to a designated “high-cost” prefix fires **one** mail (hysteresis / de-dupe); cleared or quiet period defined; Gatekeeper down ≠ call-path impact (**Rule 5**) |

---

### V3 — Rule authorship

| Item | Detail |
|------|--------|
| **Goal** | Operators can tune thresholds / prefixes without redeploy |
| **Direction** | Fleet template and/or per-tenant rules (product fork — see open questions) |
| **Done when** | Change a threshold on control or instance UI/config → next scan uses it; documented defaults for greenfield |

---

### V4 — Audience + hygiene

| Item | Detail |
|------|--------|
| **Goal** | Right recipients; safe alert bodies |
| **Direction** | Fleet ops first (`notify_failures`); tenant-admin subscription optional later; **mask / truncate dialled digits** in mail |
| **Done when** | Ops receive usable alerts without full number dump; subscription story documented |

---

### V5 — Act (optional)

| Item | Detail |
|------|--------|
| **Goal** | Beyond notify — only after V2 proven |
| **Candidates** | Local warn tone / admin banner; temporary CoS tighten; hard block on matching dest |
| **Done when** | Explicit product choice + lab acceptance; default remains notify-only until then |

---

## Explicitly later / adjacent (not blocking V2)

- Wangiri heuristics (inbound short + outbound redial correlation)  
- Traffic pumping / toll-free inbound flooding  
- SBC Fail2ban **Peer auto-whitelist** (next carrier onboard — ops-notify / peering track)  
- Webhooks / Slack / PagerDuty (notify-plane evolution)  
- Prometheus/Grafana as pretty metrics (not HoR for this track)

---

## Dependencies (already shipped)

| Dependency | Use |
|------------|-----|
| Gatekeeper SMTP + `users.notify_failures` | Delivery |
| `POST /api/v1/ops-events` | Event ingress (REGISTER, Fail2ban ban, Egress Unavail patterns) |
| Instance CoS / dial policy | Prevention cousin |
| Log retention / CDR prune paths | Window hygiene; V1 may extend SQLite ingest |

---

## Open questions (product forks)

1. **MVP rule set** — IRSF destination surge only, or also **off-hours volume** from day one?  
2. **Rule authorship** — fleet-wide templates vs per-tenant (or both)?  
3. **Near-real-time vs batch** — channel/AMI hooks vs periodic CDR scan (batch closer to existing ops scanners)?  
4. **Audience** — fleet ops only for V2, or tenant admins in the same arc?  
5. **V1 hard prerequisite** — full searchable SQLite CDR before V2, or agreed interim (e.g. thin SQLite ingest / Master.csv scan) for lab?

Settle before coding V2; V1 choice (question 5) may unblock a thinner first lab slice.

---

## Suggested build order

1. **V0** — this doc. **Done.**  
2. **V1** — confirm/finish instance CDR query surface for velocity windows.  
3. **V2** — IRSF-shaped scanner + ops-event + mail on golden/lab.  
4. **V3** — tunable rules.  
5. **V4** — audience + digit hygiene.  
6. **V5** — act only if still wanted after notify runs in anger.

---

## References

| Doc | Role |
|-----|------|
| **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** | Delivery plane; velocity pointer |
| **`FLEET_LOG_RETENTION_REQUIREMENTS.md`** | Instance SQLite CDR HoR |
| **`CONTROL_HOST.md`** | Gatekeeper env / ops-events ops |
| **`DESIGN_RULES.md`** | Rule 1, Rule 5 |
| Instance CoS / dial policy (SPA + GenAst) | Prevention |

---

*Last updated: 2026-07-22 — V0 framing (direction of flow + V0–V5 phases).*
