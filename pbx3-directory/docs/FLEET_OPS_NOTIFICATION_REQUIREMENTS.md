# Fleet ops — failure notification (requirements)

**Status:** **v1 + lifecycle + misconfig REGISTER** (2026-07-16) — catalog `/up` probe + SMTP; maintenance/decommission mail; node REGISTER-loop → Gatekeeper (**notify only**; instance Asterisk F2B jail **off** — SIP ban on SBC). Move-job / egress / Fail2ban ban→email / velocity = later.  
**MVP:** Notify interested operators of **failure conditions**.  
**Later (same notify plane, different detection):** **call-pattern velocity / toll-fraud style checks** — see § Velocity checking; **misconfig REGISTER** — see § Misconfigured phones; SBC Fail2ban ban→email.  
**Related:** **`IMPLEMENTATION_PLAN.md`** § Fleet & monitoring (`last_seen_at` probe); **`FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`** (trunk health → alerts); **`DESIGN_RULES.md`** Rule 5 (directory outage ≠ instance SLA); Fleet users / abilities (Gatekeeper); instance **CoS** / dial policy (prevention layer, not a substitute for velocity alerts).

---

## Problem

Operators can miss fleet failures until a customer calls: instance API down, node unreachable from the control plane, tenant-move jobs stuck/failed, or (once available) Egress Unavail. Today there is **local mitigation** (fail2ban on nodes) and **in-panel visibility** when someone is looking, but **no push notification** to people who care.

We need a durable way for **interested users** to learn about failure conditions without sitting in Fleet mode.

---

## Design stance (settled for this plan)

| Topic | Choice |
|-------|--------|
| **v1 scope** | **Failure conditions only** |
| **Home of record** | **Gatekeeper** — subscriptions + delivery (Fleet control plane) |
| **v1 channel** | **Email** to subscribed Fleet users (+ optional static ops address) |
| **Detection** | Reuse / extend the planned **catalog probe** (`api_base_url` → `last_seen_at`); do not invent a second health system |
| **Mail transport** | **SMTP** for v1 (`Mailer` + `SmtpMailer`). No SES as HoR — portable; other providers = new `Mailer` class later |
| **Call path** | Notify plane is **not** in the call path (**Rule 5**). Calls keep working if Gatekeeper or mail is down; operators simply go dark on alerts |
| **Prometheus / Grafana** | **Out of this leg.** Optional later for fleet/instance **pretty metrics** (dashboards, quality time series) — not the v1 notify HoR. DIY farms often bolt these on; we may document exporters later without making Alertmanager the product subscription model. |
| **Velocity / call-pattern checks** | **Out of v1.** Important product need (toll fraud / odd dial behaviour) — reuse notify **delivery** later; detection is CDR/dial analysis, not `/up` probes. Carriers often offer similar services but can be **slow to inform**; in-fleet detection aims for faster operator signal. |

```mermaid
flowchart LR
  probe["Gatekeeper probe job"] --> nodes["Instance /up"]
  probe --> state["Catalog health state"]
  state --> rules["Notify rules"]
  rules --> subs["Subscriber list"]
  subs --> email["Email delivery"]
```

---

## Industry patterns (grounding — not a product teardown)

Patterns common across PBX / MSP / CPaaS ops. **Not** verified UIs of current 3CX/Twilio/FreePBX releases — useful shape only. Competitive fleet shape lives in **`ARCHITECTURE_PEER_REVIEW.md`**; this section is about **detect → notify**.

### Detection

| Pattern | Who uses it (roughly) | Idea |
|---------|------------------------|------|
| **Active probe / heartbeat** | CloudWatch instance status, MSP RMM, many PBX “system health” crons | Control plane polls `/health` or SIP OPTIONS; mark down after N misses |
| **Passive metrics + thresholds** | Prometheus/Grafana, Kamailio exporters, Twilio Monitor–class | Agents push CPU, call-fail %, ASR, trunk RTT; alert on rules |
| **SIP qualify / OPTIONS** | Asterisk PJSIP, OpenSIPS gateway monitoring | Endpoint Unavail → ops signal (our egress track) |
| **CDR / quality analytics** | CPaaS (Twilio, Telnyx), contact-center suites | Error-code spikes, short calls, regional outages — service health more than box-down |
| **Velocity / toll-fraud rules** | Carrier fraud desks, MSP “international surge” alerts, some hosted PBX add-ons | Rate/destination anomalies on outbound (premium, unusual country, burst dials) — often hours behind if carrier-only |

### Notification

| Pattern | Typical shape |
|---------|----------------|
| **Email on state change** | Classic PBX / small MSP — still the default MVP |
| **Webhook → Slack / Teams / PagerDuty** | Modern SaaS ops; product emits event, customer routes |
| **Cloud alarms (SNS / EventBridge / CloudWatch)** | AWS-shaped fleets — close to our EC2 mental model (`DESIGN_RULES.md`) |
| **In-product dashboard + badge** | Commercial cloud PBX “system status”; email secondary |
| **Tiered severity** | info → warn → page (page only on call-path or multi-node impact) |

### Telecom-specific nuances

- **Control plane vs call path** — serious designs keep alerting off the media path (**Rule 5**).
- **Flap control** — SIP trunks flap; use **hysteresis** + optional “cleared” messages (or digests).
- **Two audiences** — fleet/ops (node down, SBC Unavail) vs tenant admin (their trunks/extensions) — often different subscriptions. Velocity alerts may need **tenant-scoped** recipients as well as fleet ops.
- **CPaaS** leans on API status + webhooks + Monitor alerts, not “SSH the box”; **hosted PBX / MSP** lean on panel health + email/SMS.
- **DIY OpenSIPS/Asterisk farms** often bolt on Nagios/Zabbix/Prometheus rather than rich notify inside the PBX UI.
- **Carrier fraud services** are valuable as a backstop; product velocity checks aim to **spot odd dial patterns earlier** (minutes, not next-business-day invoices).

### How that maps to our MVP

Gatekeeper probe → catalog state → subscribed **email** sits in the **CloudWatch-style status check + email** lane — normal for an MSP fleet console, deliberately simpler than CPaaS Monitor or full Prometheus. **Settled (2026-07-16):** this leg is **failure notification only**; do not pull Prometheus/Alertmanager into v1. Natural evolutions after email (still notify-plane): **webhooks**, then PagerDuty-class routing. **Pretty metrics** (Prometheus + Grafana for fleet/instance dashboards, SIP/CDR time series) are a **separate optional track** — bolt-on or documented exporters, not a substitute for Gatekeeper subscriptions.

---

## Requirements (when prioritized)

### R1 — Detect failure conditions

| Signal | Source | Notes |
|--------|--------|-------|
| **Instance unreachable** | Gatekeeper probe of instance `api_base_url` (e.g. `/up`) | **v1 done** — down after 2 misses + cleared |
| **Catalog maintenance / decommissioned** | Catalog lifecycle (`PATCH` status) | **Done** — mail on → maintenance / → decommissioned / back → active |
| **Move job failed / aborted** | Gatekeeper tenant-move jobs | Notify on terminal failure (and optionally long stuck `running`) |
| **Egress Unavail** | Instance trunk / AMI state (depends on **`FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`** R1–R2) | Wire in only after qualify/health signals exist |

**Acceptance:** A controlled lab outage (stop API on one node) produces a durable “instance down” event on the control plane within the probe interval.

### R2 — Subscribe interested users

| Item | Detail |
|------|--------|
| **Who** | Gatekeeper Fleet users (email on the user record); optional global ops mailbox via env/config |
| **What** | Per-user (or ability-gated) subscription: all fleet failures vs selected instances |
| **Authorship** | Subscriptions live on Gatekeeper (SQLite or successor), not on each node |
| **Ability** | Likely `fleet_admin` or a dedicated `fleet_notify` (decide at implement) — default: admins can manage subscriptions |

**Acceptance:** Enabling notify for `fleet@…` and causing R1 down → that mailbox receives mail; unsubscribed users do not.

### R3 — Notify (v1 = email)

| Item | Detail |
|------|--------|
| **Channel** | Email (SMTP or provider API — choose at implement; keep adapter-shaped) |
| **Content** | Instance id/label/FQDN, failure type, first-seen / last-ok timestamps, link to Fleet UI (Instances / Jobs) when URL known |
| **Dedup / flap** | Do not mail on every probe tick; notify on **state transition** (or after hysteresis). Optional daily digest later |
| **Failure of notify** | Log on Gatekeeper; do not affect call path or block probe job |

**Acceptance:** One clear email per down transition; recovery may send a single “cleared” mail (product choice at implement).

### R4 — Non-goals (v1)

- SPA in-app inbox, Slack, Teams, webhooks, PagerDuty  
- **Prometheus / Grafana / Alertmanager** as the failure-notify plane (optional **metrics** track later — see design stance)  
- Threat / intrusion **analytics** (SIP scan correlation, Security Hub) — **except** Fail2ban **ban → email** and whitelist automation called out in § Fail2ban (planned, not v1 probe)  
- **Call-pattern velocity / toll-fraud detection** (see § Velocity checking — planned later, not v1)  
- Node-local mail (each Asterisk emailing operators) as the fleet path  
- Putting notification or directory availability into the **call path**  
- Requiring S3 or SPA to be up for probes to run (Gatekeeper owns the job)

---

## Relation to other tracks

| Track | How it feeds notify |
|-------|---------------------|
| **`last_seen_at` probe + SPA badges** (`IMPLEMENTATION_PLAN.md` § Fleet & monitoring) | **Primary detection** for instance reachability; badges = in-UI; this doc = push |
| **Egress availability** | Once Egress qualify works, Unavail becomes a first-class failure signal (R1) |
| **Failover + shadowing** | Separate mini-project; notify may later cover failover events |
| **S7+ Security Hub** | Compliance / attested audit — not ops failure mail |
| **Prometheus / Grafana (optional later)** | Pretty metrics / quality time series — **not** this notify leg |
| **Velocity checking (planned later)** | Odd outbound call patterns → same notify delivery; separate detection — § below |
| **Fail2ban (SBC)** | Auto-whitelist **inbound Peers**; **manual** site IPs; **ban → email** — § below |

---

## Fail2ban — whitelist automation + ban notify (planned)

**Context:** SBC Fail2Ban UI (status / manual whitelist / sync) already exists. Manual coverage is not enough for production peering.

### Whitelist (edge — pbx3sbc-admin)

| Source | Requirement |
|--------|-------------|
| **Carrier inbound Peer IPs** | **Automate:** on Peer create/update/delete for inbound signaling rows (`role=inbound` / literal source IPs), add/remove Fail2ban whitelist + sync. |
| **Customer site IPs** | **Manual only** (existing Fail2Ban whitelist UI is enough). **Operator discipline:** whitelist known site/office NAT CIDRs **before phones go live** — no site CRM, no auto-discovery. Without this, one misconfigured phone can ban the whole site. |

Authorship stays on the **SBC** (**Rule 13**). Detail: **`pbx3sbc/workingdocs/PEERING-PLAN.md`** §0.1.

### Ban → email (same notify delivery plane)

| Item | Direction |
|------|-----------|
| **Signal** | New Fail2ban ban (and optionally unban / recidive) on SBC SIP jails — for **unknown / non-whitelisted** scanners |
| **Why notify** | Ops need to know an unknown IP was blocked |
| **Not for misconfig phones on known sites** | See § Misconfigured phones — ban is the wrong tool there |
| **Not v1 failure-probe** | Separate from instance `/up` down |

**Open questions:** throttle ban mail (scan storms).

---

## Misconfigured phones — REGISTER loops (notify on node; ban on SBC)

**Problem:** Handsets often fire repeated failed REGISTER (right extension, wrong password). On known office NATs, **Fail2ban must not be the primary response** — one bad phone behind shared NAT can take down the whole site.

| Stance | Detail |
|--------|--------|
| **Where SIP is seen** | Phones always transit the **SBC**; instance `:5060` is **SBC-only**. Asterisk source IP is the SBC, never the handset/site. |
| **Instance Fail2ban (Asterisk jail)** | **Off** — banning would only hit SBC peers and break trunks. Keep **sshd** / API jails. |
| **SBC Fail2ban** | Ban/whitelist on **real** client IPs. **Known office NAT** → manual whitelist (no site CRM). **Cellular / road warrior** → do **not** whitelist (dynamic); temporary ban on abuse is OK. Scanners → ban. |
| **Notify (shipped)** | Node `pbx3api` `pbx3:ops-register-loops` scans Asterisk messages; peer gate = SBC IPs in node `ignoreip`; threshold **5 / 600s**; resolves shortuid → dialable ext + name; `POST /api/v1/ops-events` `{type:misconfig_register}` → Gatekeeper SMTP. Enable: `PBX3_OPS_REGISTER_LOOP_ENABLED=true` + Gatekeeper URL/token. |
| **Mail** | Dialable extension (+ shortuid + name), source IP (SBC), instance, count/window — fix credentials. |
| **Later** | Ban→email from SBC Fail2ban for unknown IPs (same notify plane). |

---

## Velocity checking (planned later — not v1)

**Intent:** Spot and **report** odd outbound **call patterns** so operators hear before (or faster than) the carrier fraud desk — e.g. burst dials to a high-value / premium number, sudden volume to an unusual country, or similar velocity anomalies.

**Why not v1:** Detection needs **call/dial data** (CDR, channel events, or dialplan hooks), rule definitions (destinations, rates, windows), and careful false-positive policy. That is a different system from Gatekeeper `/up` probes. **Prevention** already has a partial cousin in instance **CoS / dial policy**; velocity is **detection + notify**, not a replacement for CoS.

**Reuse from this leg:** Subscriptions + email (and later webhooks) as the **delivery** plane. Prefer emitting a structured “velocity alert” event into the same notify path rather than a second mail stack.

**Sketch (when prioritized):**

| Piece | Direction |
|-------|-----------|
| **Signals (examples)** | N outbound attempts to same high-cost prefix in T minutes; first-seen country for a tenant in window; concurrent outbound spike vs baseline |
| **Where to analyze** | Prefer **on-node** near CDR/Asterisk (low latency, tenant-local); optionally summarize to Gatekeeper for fleet-wide ops mail |
| **Action v1 of this track** | **Notify only** (email) — do not auto-block calls until rules and false-positive story are proven |
| **Carrier services** | Keep as backstop; document that in-fleet velocity is complementary, not a substitute for ITSP fraud tooling |
| **Audience** | Fleet ops ± tenant admins (product decision); may differ from instance-down subscribers |

**Open questions (velocity track):** rule authorship (fleet template vs per-tenant); block vs warn; near-real-time vs batch CDR; interaction with CoS; privacy of dialled digits in alert bodies.

---

## Suggested implementation order

1. **Catalog probe job** on Gatekeeper → persist `last_seen_at` / health (shared with SPA badges). **Done (v1).**  
2. **Subscription store** + Fleet Users checkbox. **Done (v1).**  
3. **Email adapter (SMTP)** + transition-based notify for instance down/up. **Done (v1).**  
4. **Move-job terminal failure** notify.  
5. **Egress Unavail** (after egress R1–R2).  
6. **Misconfigured phones** (REGISTER-loop notify on node; SIP ban on SBC) — **Done** (node scanner + Gatekeeper ops-events; instance Asterisk jail off).  
7. Later (notify plane): webhooks / Slack; Fail2ban ban→email for unknown IPs.  
8. **Separate track:** optional Prometheus + Grafana for metrics dashboards.  
9. **Velocity checking track:** on-node pattern rules → notify delivery.  
10. **Fail2ban Peer auto-whitelist** (next carrier onboard).

---

## Open questions (settled for v1 / remaining)

### Failure notify (v1) — settled 2026-07-16

- Hysteresis: **2** missed probes before “down”.  
- Cleared / recovery emails: **yes** (one mail).  
- Subscription: fleet-wide `notify_failures` flag (not per-instance yet).  
- Solo / no-Gatekeeper installs: out of scope.  
- Rate limits / quiet hours: later.

### Velocity / Fail2ban / misconfig REGISTER

- See sections above.

---

## References

| Doc | Section |
|-----|---------|
| **`DESIGN_RULES.md`** | Rule 5 — directory outage ≠ instance SLA; EC2 mental model (monitor the fleet) |
| **`IMPLEMENTATION_PLAN.md`** | § Fleet & monitoring |
| **`FLEET_EGRESS_AVAILABILITY_REQUIREMENTS.md`** | R2 preflight / alerts |
| **`ARCHITECTURE_PEER_REVIEW.md`** | Competitive fleet shape (not notify-specific) |
| **`pbx3sbc/workingdocs/PEERING-PLAN.md`** | §0.1 Fail2ban — auto carrier inbound; manual site IPs |
| **`CENTRAL_ADMIN_DIRECTION.md`** | Central monitoring (direction) |

---

*Last updated: 2026-07-16 — v1 probe+SMTP; misconfig REGISTER notify on node; instance Asterisk F2B jail disabled (SIP defense on SBC).*
