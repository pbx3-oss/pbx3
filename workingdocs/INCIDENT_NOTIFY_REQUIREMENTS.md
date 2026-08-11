# Incident notify — requirements (locked sketch)

**Status:** Product direction locked **2026-08-11**. **Not scheduled** (nice feature; not first-out).  
**Heritage:** SARK `mcstcaller.php` + `/etc/asterisk/sark_mcstcnf.conf` — customer-defined callgroups; fan-out voice into a conference + optional SMS. Originated for a RoRo ferry ops use-case (qualified personnel into a bridge on “incident”).  
**Related:** Existing tenant **`meetme`** / GenAst **ConfBridge** · greetings · **not** fleet ops SMTP (`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`) · TODO parked item.  
**Repos when built:** **pbx3** (schema + GenAst + originator) · **pbx3api** (CRUD + fire) · **pbx3spa** (panel). No Gatekeeper / SBC change for v1.

---

## 1. One-line purpose

Let a **tenant admin** define named **incident teams** (voice destinations + optional SMS numbers). When something the **customer** calls an incident fires (feature code today; API/webhook later), the system **calls the team into a conference** and optionally **SMS-notifies** them.

---

## 2. Stance (locked)

| # | Lock |
|---|------|
| **I0** | **Tenant-owned.** Lists, greetings, rooms, triggers, SMS credentials (or shared instance SMS account with tenant-scoped lists) live under the cluster. Not fleet catalog; not Gatekeeper. |
| **I1** | **Customer defines “incident.”** Product does **not** detect incidents. Trigger = dialplan feature / shortcode (v1) + optional authenticated **Fire** API (v1.1). |
| **I2** | **Voice first, SMS second.** v1 must ship usable callout→ConfBridge without SMS. SMS is a pluggable adapter; one concrete provider in v1 is enough. |
| **I3** | **Reuse ConfBridge / `meetme`.** Do not reintroduce MeetMe. Incident group points at an existing (or auto-created) conference room. |
| **I4** | **UI is part of the product.** SARK was INI-only; PBX3 ships SPA CRUD + test fire. No operator-edited Asterisk INI as the admin surface. |
| **I5** | **SMS = provider interface**, not hardwired Clickatell in a script. Config selects handler + secrets; new carriers = new adapter class/module. |
| **I6** | **Distinct from fleet ops notify.** Ops probe/SMTP = instance/MSP plane. Incident notify = tenant response team. Do not merge UIs or event models. |
| **I7** | **Solo and fleet.** Same tenant feature on both; fleet mobility follows tenant DB (no SBC special-case). |

---

## 3. What it is / is not

| Is | Is not |
|----|--------|
| Named callout lists + bridge + optional SMS | Monitoring, failover, health probes |
| Mass / team notify for *human* incidents | Toll-fraud / velocity (different track) |
| Softphone-adjacent ops tool for response teams | A full mass-notification SaaS (schedules, geo, two-way SMS, compliance packs) |
| Feature code (+ later Fire API) | Automatic “incident detected” from CDR/AMI |

Market note: standalone vendors sell similar “crisis conference / incident bridge” services. Differentiator here is **already on the PBX** (auth, dialplan, CLIP, conference, tenant admin).

---

## 4. Happy path (v1)

```text
Tenant admin creates Incident team "Bridge watch"
  → members: ext 101, ext 205, +4477… (voice); SMS numbers optional
  → room = meetme 9001; greeting = usergreeting…; trigger shortcode *88*1
Someone dials *88*1 (or SPA Test fire / Fire API)
  → originator resolves members → Originate / callfiles
  → each answer → play greeting → ConfBridge(9001)
  → if SMS enabled → provider adapter sends smsmsg to smsnums
```

**Callee experience:** Phone rings with configured CLIP (e.g. “Incident”); answer; short greeting; join bridge with other responders.

---

## 5. Data model (sketch)

Tenant-scoped tables (names illustrative):

### `incident_team` (or `incnotify`)

| Field | Notes |
|-------|--------|
| `pkey` / name | Unique within tenant (e.g. `bridge-watch` or numeric shortcode id) |
| `cluster` | Tenant shortuid |
| `trigger` | Feature digits / shortcode that fires this team |
| `room` | FK/`pkey` into `meetme` |
| `greeting` | Sound / greeting id (same family as queues/IVR) |
| `callerid` / alphatag | Outbound CLIP for callouts |
| `waittime`, `maxretries`, `retrytime` | Originate behaviour (SARK defaults OK) |
| `sms_enabled` | YES/NO |
| `sms_msg` | Body (cap ~160 for GSM adapters) |
| `active` | YES/NO |

### `incident_member`

| Field | Notes |
|-------|--------|
| `team` | Parent |
| `kind` | `extension` \| `external` \| `sms` (or voice+sms flags on one row) |
| `target` | Extension pkey / E.164 / MSISDN |
| `channel_hint` | Optional; prefer resolve at fire time via GenAst/PJSIP + OutRoute |

**v1 UX preference:** Admin picks **extension** or **external number** (routed via tenant MainOut / normal egress), not raw `SIP/foo@peer` strings. Advanced “raw Dial string” can be deferred.

### SMS account

| Option | When |
|--------|------|
| **A — Instance globals** (one SMS account for all tenants) | Simplest MSP / lab |
| **B — Per-tenant secrets** | Multi-customer privacy |

**Lock for v1:** **A** unless a customer needs B; schema should allow B later (`sms_*` on team or tenant `cluster`).

Provider fields (instance or tenant): `smshandler`, `smsuser` / `smsapiid`, `smspassword` / apikey, `smsoriginator`.

---

## 6. Runtime

### 6.1 Trigger

| Trigger | v1 | Later |
|---------|----|--------|
| Dialplan feature / shortcode | **Yes** | — |
| SPA **Test fire** (auth’d admin) | **Yes** | — |
| REST `POST …/incident-teams/{id}/fire` | Soft yes (same as Test fire) | External webhook / automation |
| AMI / cron / probe hooks | No | Optional |

Custom apps like SARK `mcastdial` are **generated** from DB (GenAst), not hand-maintained contexts per site.

### 6.2 Voice path

Prefer **AMI Originate** (or call files under `/var/spool/asterisk/outgoing` as SARK did — either is fine; AMI is easier to observe from API). On answer: context that plays greeting then `ConfBridge(${room})`.

Resolve destinations:

| Member | Channel |
|--------|---------|
| Extension | Local PJSIP endpoint for that tenant |
| External | Via tenant outbound / Egress path (same as normal dial) |

Concurrency: fan-out all members (SARK behaviour). No “first answer wins / cancel others” in v1 (that is a different product = ring group / page).

### 6.3 SMS path

```text
IncidentFire
  → if sms_enabled and members have SMS targets
  → SmsProvider::send(account, numbers[], body)
```

**v1 adapter:** one HTTPS provider (Clickatell **or** Twilio — pick at implement time from credentials ease). Stub/`null` provider for voice-only labs.

Interface (PHP sketch):

```php
interface IncidentSmsProvider {
    /** @param list<string> $msisdns */
    public function send(array $account, array $msisdns, string $body): void;
}
```

Do **not** copy SARK’s dynamic `$smsvars['smshandler']($smsvars)` call — register adapters in a map.

---

## 7. SPA / API

| Surface | Behaviour |
|---------|-----------|
| List | Incident teams for current tenant |
| Detail | Name, trigger, room, greeting, CLIP, retries, SMS toggle/msg, members |
| Members | Add/remove extension picker + external number + SMS MSISDN |
| **Test fire** | Confirms + fires (rate-limit; audit log line) |
| Permissions | Tenant admin (same family as other tenant config panels) |

Panel pattern: existing list/detail (**`PANEL_PATTERN.md`**). Nav under tenant Features / Call handling (exact label at implement).

---

## 8. Non-goals (v1)

- Automatic incident detection / correlation
- Two-way SMS, delivery receipts UI, opt-out compliance packs
- Schedules, escalation ladders, on-call rotations (PagerDuty-class)
- Multicast RTP paging (different SARK `mcast` feature)
- Merging with fleet ops notification
- Per-carrier billing / SKU metering
- Recording the bridge by default (optional later via existing conf record hooks if any)

---

## 9. Implementation map + estimate

Rough **focused** effort (one engineer familiar with the stack). Contiguous calendar time will be longer if context-switching.

| Slice | Work | Repos | Est. |
|-------|------|-------|------|
| **N0** | Schema + seed help keys; wipe/audit hooks if needed | pbx3 | **0.5 d** |
| **N1** | Originator script + GenAst trigger + answer→greeting→ConfBridge | pbx3 | **1–1.5 d** |
| **N2** | API CRUD + Fire + Sanctum permissions | pbx3api | **1–1.5 d** |
| **N3** | SPA list/detail + member editor + Test fire | pbx3spa | **1.5–2 d** |
| **N4** | SMS provider interface + **one** live adapter + config surface | pbx3 (+ api/spa fields) | **1 d** |
| **N5** | Lab acceptance + short MkDocs / help blurb | docs / lab | **0.5 d** |

| Package | Days | Notes |
|---------|------|--------|
| **Voice-only MVP** (N0–N3, N5; SMS stub) | **~4–5** | Enough to demo ferry-style callout |
| **v1 complete** (MVP + N4) | **~5–7** | Matches “nice feature, not huge” feel |
| **Polish** (webhook auth docs, second SMS carrier, audit panel) | **+1–2** | Optional |

Risks that inflate estimate: external-number dial string edge cases on fleet egress; CLIP presentation; ConfBridge profile/PIN surprises; SMS provider sandbox pain — keep N4 behind a feature flag if the carrier stalls.

---

## 10. Lab acceptance (when built)

1. Create team on golden tenant; members = two local extensions + one mobile via Egress.  
2. Dial trigger → both desks + mobile ring; answer → same ConfBridge room; greeting plays.  
3. SPA Test fire behaves the same.  
4. SMS off → no provider calls; SMS on + sandbox → message received.  
5. Inactive team / unknown trigger → no-op (logged).  
6. Other tenants unaffected (cluster scope).  
7. Solo node: same behaviour without fleet.

---

## 11. Open questions (resolve at implement, not blockers)

| # | Question | Lean default |
|---|----------|--------------|
| Q1 | Numeric trigger vs named feature code? | Numeric / `*88*n` family like heritage |
| Q2 | Auto-create `meetme` room on team create? | Yes, or require pick existing room |
| Q3 | Twilio vs Clickatell first adapter? | Whichever we already have a lab account for |
| Q4 | Should Fire API be public (token) or Sanctum-only in v1? | Sanctum-only; document webhook later |
| Q5 | Bridge recording / PIN enforce? | Follow room’s existing meetme settings |

---

## 12. Resume when scheduled

1. Confirm Q1–Q3 quickly.  
2. Implement **voice MVP** (N0–N3); demo.  
3. Add **N4** SMS when a provider account is ready.  
4. Park webhooks / rotations until a customer asks.
