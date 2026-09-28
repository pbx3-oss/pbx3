# Fleet toll fraud & call-pattern velocity (requirements)

**Status:** **V0 framing done** (2026-07-22); **V1–V2 + V5 auto-block** shipped (2026-07-24). **IRSF product close (2026-08-11):** SPA velocity inactive honesty + reactivate clears `z_updater`; **CDR pack v1**. **V3 fleet policy** shipped (2026-08-11) — S3 `catalog/velocity-policy.json`. **WP1 off-hours** shipped (2026-08-11). V4 deferred; CFIM/failed/Wangiri not separate (see implementation plan).  
**Lab testing:** CDR fixture pack first; SIPp optional E2E.  
**Related:** **`FLEET_TOLL_FRAUD_VELOCITY_IMPLEMENTATION_PLAN.md`** · **`VELOCITY_CDR_PACK.md`** · **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** (Gatekeeper notify delivery); **`FLEET_LOG_RETENTION_REQUIREMENTS.md`** § CDR / SQLite (Phase 6 `master.db` shipped); instance **CoS** / dial policy (prevention + **act**); **`DESIGN_RULES.md`** Rule 1 (directory out of call path), Rule 5 (notify ≠ call-path SLA); SBC Fail2ban / pike (**SIP abuse only** — outside→in; velocity is the **inside→out** cousin); living research **`TELEPHONE_FRAUD_RESEARCH.md`** (fleet vs carrier ownership).

---

## Problem

Fraudsters compromise a business PBX or SIP path and drive **high volumes of outbound** (often automated) calls to **premium-rate or high-cost international** destinations. Attackers take a cut from expensive destination carriers; the tenant or MSP gets a surprise bill.

**Core nightmare (always has been):** a **compromised phone** (stolen credentials / weak device). Attackers often either (a) dial high-value numbers directly (**IRSF burst**) or (b) **CFIM / Follow-me it to a bad number** so spend happens on every inbound or divert — same compromise, different shape. Money runs up in minutes. **CoS is a big help when used**; velocity (+ later CFIM checks) catch what CoS missed — then **auto-block like Fail2ban, but inside→out** (set the phone **`active=NO`**), with **minimum inconvenience to the rest of the tenant**.

### Patterns (threat map)

| Type | Shape | Product stance |
|------|--------|----------------|
| **IRSF burst** | Rapid outbound to high-rate / premium destinations | **V2/V5 primary** — CDR velocity + `active=NO` |
| **CFIM / Follow-me abuse** | Compromised phone: set forward to a bad number; spend without a “hot dialer” | **High priority later** — often *what they do* after compromise; detect config change and/or forward legs; same act (`active=NO` and/or clear CF) |
| **Saturday-night blitz** | Off-hours / weekend outbound surge (ops have seen this) | **Later rule** after IRSF burst — off-hours window signal (was deferred; now named) |
| **Failed-attempt scanning** | Many short/failed tries across premium ranges (recon) | **Later rule** — disposition/failed-heavy window; ops have seen this |
| **Wangiri** | One-ring missed call → employee redials premium | Later; prefer **warn before callback** (human-dependent) over noisy post-redial correlation — see implementation plan WP5 sketch |
| **Traffic pumping** | Manufactured calls into toll-free | Carrier / toll-free side — not instance HoR |
| **Low-and-slow premium** | Few calls, long billsec to expensive dest | **Hard without a strict high-value CoS policy** — lean on **prevention (CoS)**; velocity is a poor sole detector |
| **DISA / remote outdial** | Classic PBX hack path | **We can support DISA technically but we don’t ship it** — keep it that way; not a detection target |
| **Voicemail outdial** | VM compromised → external dial | **Ensure locked out** (prevention audit) — confirm product cannot outdial from VM; treat as hard requirement, not a velocity phase |

Industry levers: **geo-restrict / CoS**, **harden credentials**, **no DISA**, **VM outdial locked**, **carrier fraud desk**. This track owns **monitor patterns → alert → `active=NO` on the offending phone**, complementary to prevention and carrier backstops.

---

## Direction of flow (locked)

```text
Prevention (CoS / dial policy / kill DISA-class features)
    → Detection (instance CDR patterns — “velocity”)
        → Notify (Gatekeeper ops-events → email)
            → Auto-block on PBX (`ipphone.active=NO` + genAst — Fail2ban inside→out)
                ↔ Carrier fraud desk / ITSP geo-block = backstop, not HoR
```

Analogy:

| Edge (already) | Instance velocity (this track) |
|----------------|--------------------------------|
| SBC **Fail2ban** — abusive **inbound** SIP (REGISTER/INVITE flood) → ban source IP | Velocity auto-block — abusive **outbound** dial pattern → set phone **`active=NO`** (inside→out) |

```text
CDR fixture or live calls
        → /var/log/asterisk/master.db (cdr table)
            → pbx3:ops-velocity (batch scan)
                → POST /api/v1/ops-events {type: velocity_irsf}  (notify)
                → local act: ipphone.active = NO (+ genAst)   (auto-block)
```

| Plane | Role |
|-------|------|
| **Instance** | **Detection + auto-block** — CDR scan; set **`ipphone.active=NO`** for the offending phone; GenAst omits inactive endpoints |
| **Gatekeeper** | **Notify delivery** only — **not** the place that scores or blocks calls |
| **SBC** | **SIP abuse** Fail2ban/pike (outside→in) — **not** dial-pattern velocity |
| **Carrier** | Fraud desks / geo-blocks — complementary backstop |

**Reuse:** Same notify plane as other ops-events → SMTP. Do **not** invent a second mail stack. Do **not** put block decisions on Gatekeeper or OpenSIPS for this threat.

**Prevention vs detection vs act:** CoS **blocks** bad dials when configured. Velocity **detects** odd patterns, **mails** ops, then sets **only** the offending phone **`active=NO`** so the scam stops with **minimum inconvenience to the rest of the tenant**. Velocity is not a substitute for CoS; it is the automatic brake when CoS was not enough.

---

## Settled forks (2026-07-23)

| # | Fork | Decision |
|---|------|----------|
| 1 | MVP rule | **IRSF destination surge only** — off-hours volume deferred past V2 |
| 2 | Rule authorship | **V2:** env defaults on the node; **V3:** fleet-wide template first (per-tenant later) |
| 3 | Timing | **Batch CDR scan** (artisan/cron, same shape as `pbx3:ops-register-loops`) — not AMI near-real-time |
| 4 | Audience | **Fleet ops only** (`notify_failures`) for V2; tenant admins later (V4) |
| 5 | V1 prerequisite | **Use existing `master.db`** (Phase 6) — no Master.csv interim; lab fixture writes SQLite-shaped rows |

**Residuals (tune in lab, not blockers):** exact **N / T / Q** after first golden run; production prefixes — **starter packs** **`VELOCITY_PREFIX_SEEDS.md`** (UK incl. **`070`**; US NANP Caribbean); research §7 / Uboss; lab stays **`0900` / `+44900` / `0044900`**. V3 fleet template still later. **Act gaps above are requirements, not residuals** (attribution, clear CF, hangup-or-bleed).

---

## Phases (testable)

### V0 — Framing

| Item | Detail |
|------|--------|
| **Goal** | Spec + threat map + plane ownership settled enough to build |
| **Done when** | This document exists; prevention vs detection vs notify vs edge roles explicit |

**Status:** **Done** (2026-07-22; forks settled 2026-07-23).

---

### V1 — Data plane

| Item | Detail |
|------|--------|
| **Goal** | Reliable instance CDR input for time windows and queries |
| **HoR** | **`/var/log/asterisk/master.db`** via Asterisk `cdr_sqlite3_custom` — already shipped (log-retention Phase 6). CSV `Master.csv` = archive/S3 only |
| **Code already there** | pbx3api `CdrIndexService` / `GET /cdr`; `PBX3_CDR_SQLITE_PATH`; prune `pbx3:cdr-prune` |
| **Non-goal** | Fleet-central CDR warehouse; scoring on Gatekeeper; treating SBC MySQL `acc` as fraud signal; rebuilding Phase 6 |

#### Columns (velocity needs)

From packaged `cdr_sqlite3_custom.conf` table `cdr`:

| Column | Velocity use |
|--------|----------------|
| `calldate` | Window filter |
| `src` | Extension / CLI context |
| `dst` | Dialled dest → prefix match |
| `disposition` | Prefer answered / attempted outbound (exclude pure internal noise where possible) |
| `accountcode` | Tenant / billing context when populated |
| `billsec` / `duration` | Optional severity / filters later |
| `dcontext` / `channel` | Heuristics to exclude obvious internal dials |

#### Query contract (scanner input)

- Window: rows with `calldate` in the last **T** minutes.
- Candidate set: outbound-ish rows whose `dst` matches a configured **high-cost prefix** list (see V2).
- Exclude: empty `dst`; clearly internal patterns (e.g. shortuid-only / local extension shapes — document heuristics in implementation).
- Tenant context: prefer `accountcode` when set; else best-effort from channel/context — do not block V1 on perfect tenant attribution.

#### CDR fixture (lab)

- **Purpose:** seed velocity-shaped rows without SIPp / live trunks.
- **Shape:** artisan **`pbx3:cdr-fixture`** in **pbx3api** (`CdrFixtureService`); env-gated (`PBX3_CDR_FIXTURE=1` / `--force`) and **refuses** live `/var/log/asterisk/master.db` unless `--allow-live`.
- **Path safety:** default write target = **`PBX3_CDR_SQLITE_PATH`** override pointing at a **lab copy** of `master.db` (or empty SQLite with `cdr` schema via `--path=`) — **do not** casually INSERT into live golden `master.db` without an explicit flag.
- **Decks:** `irsf` (default), `failed-scan`, `internal-noise`, `mixed`. Lab premium prefix **`0900` / `+44900` / `0044900`** (matches `PBX3_OPS_VELOCITY_PREFIXES` default).
- **CSV import (lab):** artisan **`pbx3:cdr-import-csv`** — classic Asterisk `Master.csv` / `accountcode.csv` / `.gz` (golden `/var/log/asterisk/cdr-csv/`) → lab SQLite; same path safety as fixture.
- **Query helper:** **`VelocityCdrQuery`** + artisan **`pbx3:cdr-velocity-query`** (also `--probe` on fixture). Window **T** + prefix list; excludes empty/`isInternalDst` shapes.
- Insert N rows with recent `calldate`, lab `dst` prefixes, `src` / `accountcode` filled.
- Done when: fixture + one query helper returns the burst rows V2 will count.

| Item | Detail |
|------|--------|
| **Done when** | On a lab node (or fixture DB): query returns recent outbound CDR with dest, time, and extension/tenant context; prune retention does not empty the active window; fixture path documented |
| **Status** | **Done** (2026-07-24) — unit tests `VelocityCdrFixtureTest`; smoke: `php artisan pbx3:cdr-fixture --path=/tmp/cdr-lab.db --probe --force` |

---

### V2 — Detect + notify (IRSF-shaped)

| Item | Detail |
|------|--------|
| **Goal** | Thin outbound prefix-surge rule → Gatekeeper mail |
| **Action** | **Notify** in V2; **auto-block required in V5** (ships immediately after V2 lab prove-out — not optional forever) |
| **Command** | `pbx3:ops-velocity` (name locked) — schedule ~every minute when enabled |
| **Enable** | `PBX3_OPS_VELOCITY_ENABLED=true` (+ existing `PBX3_GATEKEEPER_URL` / `TOKEN`) |
| **Mirror** | Same shape as `pbx3:ops-register-loops` / `pbx3:ops-egress-qualify` |

#### MVP rule (lab defaults — env-tunable)

| Knob | Env (proposed) | Lab default |
|------|----------------|-------------|
| Count threshold | `PBX3_OPS_VELOCITY_N` | **10** |
| Window minutes | `PBX3_OPS_VELOCITY_T` | **5** |
| Quiet / hysteresis minutes | `PBX3_OPS_VELOCITY_Q` | **30** |
| High-cost prefixes | `PBX3_OPS_VELOCITY_PREFIXES` (comma list) | Small **lab** list (e.g. designated fake premium prefixes used by fixture) |

**Fire when:** count of matching outbound CDRs in window **T** ≥ **N**.

**Not in V2 (notify slice only):** off-hours volume; concurrent-channel AMI; Wangiri; **auto-block** (that is **V5**, required next).

#### Emit

`POST /api/v1/ops-events` with:

| Field | Value |
|-------|--------|
| `type` | **`velocity_irsf`** (locked) |
| Payload | Instance id/label/FQDN; **extension / src** when attributable; optional tenant/`accountcode`; **masked** dest prefixes (not full numbers); count; window T; first/last calldate in burst; later: whether auto-block applied |

Gatekeeper: handle `velocity_irsf` like other ops-events → SMTP to `notify_failures` (+ optional ops mailbox). Digits in mail: mask/truncate (V4 hygiene starts here — do not dump full `dst` lists).

#### Hysteresis / de-dupe

- Firing key: instance + **extension** (preferred) or accountcode + rule id `irsf`.
- First fire → one mail (`transition=down` or equivalent).
- Further scans while still over threshold within **Q** → **no** additional mail.
- After quiet period (**Q** minutes under threshold) → optional `cleared` mail (and unban story in V5).

| Item | Detail |
|------|--------|
| **Done when** | Fixture burst → **one** `velocity_irsf` mail; second scan within hysteresis → no spam; Gatekeeper down ≠ call-path impact (**Rule 5**); enable flag documented in **`CONTROL_HOST.md`** / node `.env` notes |
| **Status** | **Done** (2026-07-24) — `pbx3:ops-velocity` + Gatekeeper `velocity_irsf` SMTP; unit tests scanner + notify |

---

### Lab testing (settled 2026-07-23)

**Day-to-day:** a **good CDR fixture deck** is enough to exercise most detection shapes without SIPp — seed `master.db`-shaped rows and run the scanner(s).

| Pattern | Fixture approach |
|---------|------------------|
| **IRSF burst** | N outbound rows, high-cost `dst`, recent `calldate`, same `src` |
| **Saturday-night blitz** | Same burst with `calldate` in off-hours / weekend window |
| **Failed-attempt / short-call scanning** | Many rows, failed/busy or billsec under ~30s, premium-ish `dst`s |
| **Dormant extension** | Rows from `src` with no prior originations in fixture history window |
| **Concurrency** | Overlapping `calldate`/`duration` windows on same `src` or tenant |
| **Forward chain** | Paired inbound + outbound external legs (same window / linked ids if available) |
| **Low-and-slow** | Few rows, long `billsec`, expensive `dst` — proves CoS / future rule more than burst velocity |
| **CFIM / Follow-me** | Divert legs in CDR **plus** planted CFIM target for config detect |
| **VM outdial / DISA** | **Not** CDR-deck tests — prevention audits |

**Flow:** fixture → pointed `PBX3_CDR_SQLITE_PATH` → `pbx3:ops-velocity` (+ later rule packs) → mail / `active=NO`. No REGISTER, media, or live trunks for day-to-day.

**Pack (v1):** **`VELOCITY_CDR_PACK.md`** — `php artisan pbx3:cdr-velocity-pack` (or Pest). Asserts IRSF query contract across fixture decks.

**Optional E2E:** **SIPp** on golden when you want INVITE → real CDR → scanner confidence. Reuse **`pbx3sbc/attackTests`**; do not build a fleet call-generator. Edge SIPp flood ≠ toll-velocity HoR.

**Prevention note:** for live SIPp drills, use a lab allow-listed “high-cost” prefix or temporarily open CoS so the burst is intentional.

---

### V3 — Rule authorship

| Item | Detail |
|------|--------|
| **Goal** | Operators tune thresholds / prefixes without redeploy |
| **Direction** | **Fleet-wide** S3 `catalog/velocity-policy.json` — Gatekeeper sole writer; nodes read S3 (cache → env). SPA Fleet → Velocity. Per-tenant later |
| **Done when** | Change N/T/prefixes via Gatekeeper → next scan uses it; greenfield defaults documented |
| **Status** | **Done** (2026-08-11) — WP3 in **`FLEET_TOLL_FRAUD_VELOCITY_IMPLEMENTATION_PLAN.md`**; `GET`/`PUT` `/api/v1/velocity-policy`; `VelocityPolicyResolver` on node |

---

### V4 — Audience + hygiene

| Item | Detail |
|------|--------|
| **Goal** | Right recipients; safe alert bodies |
| **Direction** | Fleet ops already in V2; **tenant-admin** subscription optional later; digit mask required from V2 mail |
| **Done when** | Ops receive usable alerts without full number dump; tenant audience story documented if added |

---

### V5 — Auto-block (required; Fail2ban inside→out)

| Item | Detail |
|------|--------|
| **Goal** | Stop the compromised-phone spend **on the PBX** as soon as velocity fires — same *idea* as Fail2ban, opposite direction |
| **Priority** | **Required** product outcome; ship **immediately after** V2 notify lab (do not park as “maybe later”) |
| **Scope** | **One phone only** — the extension that sourced the surge. **Minimize inconvenience to the tenant as a whole:** do not deactivate sibling extensions, do not lock the tenant, do not change CoS fleet-wide. Whole-tenant act only if attribution is impossible (document as last resort; default is never) |
| **Attribution (must)** | Map CDR evidence → exactly one **`ipphone`** row before acting. Prefer stable id (`shortuid` / channel endpoint) over ambiguous CLI. **If attribution is uncertain → notify only, do not deactivate** (wrong-phone deactivate is worse than a delayed ban) |
| **Mechanism (locked)** | Flip **`ipphone.active`** to **`NO`** (existing active/inactive switch). GenAst already omits inactive phones from PJSIP |
| **Clear forwards (must)** | On act, also **clear CFIM / CFBS / Follow-me** (runtime AstDB and/or stored forward fields — whichever the product uses) for that extension. **`active=NO` alone may not stop divert spend** if inbound still hits a forward |
| **In-progress calls** | Deactivate + genAst does **not** tear down live channels by itself. Choose and document one: **(A)** AMI hangup of that endpoint’s channels on act, or **(B)** accept short bleed until natural hangup. Prefer **(A)** for IRSF money-clock |
| **Enforce** | After DB updates, **Commit / genAst** + reload as today (phone-only path if available). Must bite before the next fraud burst continues |
| **What gets blocked** | **Only that phone** (+ its forwards cleared) — rest of tenant keeps working |
| **Notify** | Mail notes extension deactivated, forwards cleared, and whether live channels were hung up |
| **Unban** | `active=YES` + Commit/genAst; forwards stay clear unless ops restore deliberately; optional TTL re-activate |
| **SPA / audit (should)** | Show phone was disabled **by velocity** (not a mysterious manual toggle); control who may re-enable (prefer MSP / high privilege — avoid easy re-enable by a compromised tenant admin session) |
| **Allowlist (should)** | Extensions that never auto-deactivate (fax/alarm/VIP) — env or fleet template later |
| **False positives** | Easy reactivation via UI for authorized roles; V2 lab tunes N/T before enabling act |
| **Non-goal** | Gatekeeper/SBC deciding the dial; second disable path beside `active` + clear-CF |

| Item | Detail |
|------|--------|
| **Done when** | Attributable fixture burst → correct phone only `active=NO` + forwards cleared → genAst/reload off-net → optional AMI hangup of live legs → mail explains act → reactivation restores service; uncertain attribution never deactivates the wrong phone |
| **Status** | **Done** (2026-07-24) — `VelocityPhoneAttributor` + `VelocityPhoneActuator`; enable with `PBX3_OPS_VELOCITY_ACT=true` (separate from notify); hangup via `channel request hangup` (option A); `z_updater=velocity`; allowlist `PBX3_OPS_VELOCITY_ALLOWLIST` |

---

### Implementer notes (locked gaps — 2026-07-23)

| Topic | Requirement |
|-------|-------------|
| **src → phone** | Explicit mapping rules + lab tests for multi-tenant nodes; fail safe = notify-only |
| **Clear CF on act** | Always with deactivate; CFIM abuse is a primary real-world vector |
| **Hangup vs bleed** | Document A vs B; default recommendation **AMI hangup** of that endpoint’s channels |
| **Timezone** | Off-hours / Saturday-night rules use a defined clock (tenant local vs node UTC) — settle when that rule ships |
| **Scanner silence** | Optional later: heartbeat that `pbx3:ops-velocity` is running (owned-box risk) |

---

## Explicitly later / adjacent (not blocking V2/V5)

**Next detection shapes (after IRSF + auto-block)** — include published CDR patterns worth stealing:

| Pattern | Note | Source / kin |
|---------|------|----------------|
| **CFIM / Follow-me to bad number** | Common post-compromise; config + CDR; **act always clears CF** with `active=NO` | Ops experience; industry “forwarding fraud” |
| **Saturday-night / off-hours blitz** | Time-window surge (tenant-local clock when rule ships) | Ops; common CDR fraud writeups |
| **Failed-attempt / short-call scanning** | Many short/failed CDRs to premium-ish prefixes — recon before the big run | Ops; “short-duration call storms” |
| **Dormant extension wakes up** | Outbound from an extension with little/no recent originations (e.g. 60d quiet) | Published CDR fraud patterns |
| **Concurrency above normal** | Overlapping outbound above trailing peak (esp. off-hours) — autodialer grabbing channels | Published CDR fraud patterns |
| **Forward chain ending off-net** | Inbound → paired outbound external/international within seconds (redirect / divert legs) | Published CDR fraud patterns; pairs with CFIM |
| **Premium / high-fraud country watchlist** | First-call or low-N alert to known IRSF-prone country/premium prefixes (beyond burst count) | Industry watchlists; SecAst-class fraud number DBs (we start with env list, not a paid DB) |
| **Wangiri** | Prefer short inbound from suspect CLI → **notify before human callback**; post-redial correlation secondary / noisy | Industry; human-dependent scam |

**Prevention audits (not velocity scanners):**

| Item | Note |
|------|------|
| **Voicemail outdial** | **Must stay locked out** — confirm no VM→PSTN path; hard prevention |
| **DISA** | Technically possible, **not shipped** — keep disabled |
| **Low-and-slow premium** | Strict **high-value CoS**; burst velocity alone is weak |
| **External forward barred by CoS** | Where product allows: prevent off-net CFIM for most classes (prevention cousin of CFIM detect) |

**Other deferred:**

- Traffic pumping / toll-free (carrier plane)  
- Tenant-wide deactivate as default (extension-first)  
- SBC Fail2ban Peer auto-whitelist (peering track)  
- Webhooks / Slack / PagerDuty; Prometheus as pretty metrics (not HoR)  
- Paid third-party fraud-number / reputation feeds (optional later; SecAst-class)

---

## Differentiation (intent)

**Market gap (category):** Many SMB / hosted PBX stacks emphasize **prevention** (outbound rules, country allow-lists, PIN) and **outside→in** (Fail2ban-class). Carrier tools add spend / path caps — often **slow** and **trunk-scoped**. Few ship **fast inside→out** “kill this compromised phone” as a first-class PBX feature.

**pbx3 intent:** on-box batch CDR → ops mail → **`ipphone.active=NO` + clear CF + hangup**, fixture-testable, **one phone** blast radius — Fail2ban’s cousin **inside→out**, built in for fleet/MSP.

Published pattern lists (e.g. CDR short-storms, dormant ext, concurrency, weekend blitz, forward chains) are **fair game** to implement as later rule packs; cite industry practice in release notes, not proprietary UI copy.

*(Named-vendor comparison table lives in private ops: `~/GiT/pbx3-ops/devdocs/oss-move/competitive/VELOCITY_COMPETITIVE_NOTES.md`.)*

---

## Dependencies (already shipped)

| Dependency | Use |
|------------|-----|
| Gatekeeper SMTP + `users.notify_failures` | Delivery |
| `POST /api/v1/ops-events` | Event ingress (extend with `velocity_irsf`) |
| Instance CoS / dial policy | Prevention cousin (`active` switch is the **act**) |
| Phase 6 `master.db` + `GET /cdr` + prune | V1 HoR — do not rebuild |
| Register-loop / egress-unavail scanners | Pattern for `pbx3:ops-velocity` |
| SBC Fail2ban (outside→in) | Conceptual cousin only — different plane |

---

## Suggested build order

1. **V0** — framing + forks. **Done.**  
2. **V1** — confirm `master.db` query surface + **CDR fixture** (path-safe). **Done** (2026-07-24).  
3. **V2** — `pbx3:ops-velocity` + Gatekeeper `velocity_irsf` + mail (fixture-first; SIPp optional). **Done** (2026-07-24).  
4. **V5** — **auto-block** via existing **`ipphone.active=NO`** (+ genAst) — required next; do not defer. **Done** (2026-07-24).  
5. **IRSF product close** — SPA “disabled by velocity” + reactivate clears stamp; **CDR pack v1**. **Done** (2026-08-11) — **`VELOCITY_CDR_PACK.md`**.  
6. **V3+ remainder** — see **`FLEET_TOLL_FRAUD_VELOCITY_IMPLEMENTATION_PLAN.md`** (WP0 ACT prove, V3 S3 policy, off-hours; V4/SBC/separate Wangiri deferred).

---

## Future — discrete product — **won't-do** (2026-08-11)

**Observation (historical):** detect + notify is mostly **generic Asterisk** (CDR SQLite / Master.csv + batch scan + mail/webhook). The pbx3-specific sticky bit is the **act** (`ipphone.active=NO`, AstDB CF clear, genAst).

**Locked won't-do:** do **not** stand up a separate velocity **repo + installer** (Go extract / portable “any Asterisk” SKU). Effort ≫ return; product path stays **in-tree** (`pbx3:ops-velocity` + Gatekeeper `velocity_irsf`). Finish V3+ in-fleet when designed (#8) — not a second product.

**Historical sketch (not a build plan):** standalone Go scanner + notify without Gatekeeper + per-distro act adapters was considered 2026-07-24; cancelled.

**Do not:** claim “every Asterisk” or market a discrete velocity SKU. **Do:** keep pbx3 as the only fraud-velocity product surface.

---

## References

| Doc | Role |
|-----|------|
| **`FLEET_TOLL_FRAUD_VELOCITY_IMPLEMENTATION_PLAN.md`** | Remainder build plan (V3/V4/detectors/SBC/lab) — draft until review locks |
| **`HIGH_RISK_DIAL_BLOCK_POSTURE.md`** | CoS prevention vs velocity vs SBC floor |
| **`VELOCITY_PREFIX_SEEDS.md`** | UK / US starter `PBX3_OPS_VELOCITY_PREFIXES` packs |
| **`VELOCITY_CDR_PACK.md`** | Fixture pack runner + case table |
| **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** | Delivery plane; add `velocity_irsf` when implementing |
| **`FLEET_LOG_RETENTION_REQUIREMENTS.md`** | Instance SQLite CDR HoR (Phase 6) |
| **`CONTROL_HOST.md`** | Gatekeeper env / ops-events ops |
| **`DESIGN_RULES.md`** | Rule 1, Rule 5 |
| Instance CoS / dial policy (SPA + GenAst) | Prevention + act surface |
| pbx3api `CdrIndexService` / `config/pbx3_cdr.php` | Existing CDR read path |
| pbx3api `CdrFixtureService` / `VelocityCdrQuery` / `pbx3:cdr-fixture` | V1 fixture + scanner input |
| `pbx3sbc/attackTests` SIPp notes | Optional E2E only |
| SBC Fail2ban | Outside→in analogue — not the implementation |
| Research: **`TELEPHONE_FRAUD_RESEARCH.md`** (§7 prefix seed) | Class A vs B; high-risk dial prefixes for production seed |

---

*Last updated: 2026-08-11 — IRSF product close + CDR pack v1; standalone SKU won't-do; V3/V4 later.*