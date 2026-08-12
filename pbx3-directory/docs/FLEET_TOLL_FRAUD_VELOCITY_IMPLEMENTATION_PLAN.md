# Fleet toll fraud / velocity — implementation plan (remainder)

**Status:** **Accepted** (2026-08-11) — **WP0 + WP3 done**; **WP1** off-hours coded (orchestrator + detector + Gatekeeper mail).  
**Parent requirements:** **`FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md`** · posture **`HIGH_RISK_DIAL_BLOCK_POSTURE.md`** · seeds **`VELOCITY_PREFIX_SEEDS.md`** · CDR pack **`VELOCITY_CDR_PACK.md`** · notify delivery **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`**.  
**Design rules:** Rule **1** (directory/Gatekeeper out of call path), **5** (notify ≠ SLA), **6** (solo still works on env), **10** (fleet ≠ instance Sanctum), **12** (browser never holds ops IAM), **13** (SBC = projection, not HoR for policy authorship where catalog owns it).

---

## 0. Already shipped (do not rebuild)

| Slice | Status |
|-------|--------|
| V0 framing + forks | Done |
| V1 CDR / fixture / `VelocityCdrQuery` | Done |
| V2 `pbx3:ops-velocity` → Gatekeeper `velocity_irsf` + SMTP | Done |
| V5 act (`active=NO` + clear CF + hangup + genAst + `z_updater`) | Done (flag `PBX3_OPS_VELOCITY_ACT`) |
| IRSF SPA honesty + reactivate clears stamp | Done |
| CDR pack v1 | Done |
| CoS high-risk seed (`HR_*`) | Done (prevention plane) |
| UK/US velocity prefix starter files | Done (node env / file, not fleet-authored yet) |
| Standalone velocity SKU | **won't-do** |

**Lab:** WP0 ACT prove **done** (2026-08-11) — see §3 WP0.

---

## 1. Scope of this plan

| In | Out |
|----|-----|
| **V3** fleet-wide rule template | **V4** tenant-admin mail (**deferred**); per-tenant rule authorship |
| **Off-hours detector** (+ thin detector frame) | Separate CFIM / failed-scan / Wangiri detectors (same high-value dial path; L3) |
| Lab ACT prove (WP0 now) | **SBC thin never-route**; Slack/PagerDuty; paid feeds; live customer cutover |

---

## 2. Locks (review complete pending Accept)

All checklist items locked below.

### L1 — V3 authorship + transport — **LOCKED** (2026-08-11)

| Topic | Lock |
|-------|------|
| **HoR** | **S3** `catalog/velocity-policy.json` (single fleet-wide document) |
| **Writer** | **Gatekeeper only** (same sole-writer posture as other `catalog/*`) |
| **Mutate API** | Gatekeeper `GET`/`PUT` (or equivalent) for operators/SPA — writes through to S3; do **not** treat Gatekeeper SQLite as HoR |
| **Readers when Gatekeeper is down** | **Yes** — nodes and SPA read S3 directly (as long as S3 is up); edits wait until Gatekeeper returns |
| **Node consume** | Each `pbx3:ops-velocity` run: GET S3 object (short timeout); cache to `storage/app/ops-velocity-policy.json`; on pull fail → last good cache → else env defaults (**Rule 5 / 6**) |
| **Override** | Node env `PBX3_OPS_VELOCITY_*` wins when `PBX3_OPS_VELOCITY_POLICY=local` (or solo / no catalog) so lab fixtures stay frictionless (**Rule 6**) |
| **SPA** | Fleet mode edits via Gatekeeper only — never node Sanctum, never direct S3 write from browser (**Rule 10 / 12**). **No Filament** writer for this object (avoids dual-authorship with SPA). |
| **Editor cadence** | **API first** (Gatekeeper `GET`/`PUT` → S3), then **SPA Fleet** form on that same API — not Filament-on-control / Magrathea |
| **Not** | Push/SSH to nodes; directory/S3 in SIP path; instance Sanctum mutating fleet policy |

**Policy JSON sketch:**

```json
{
  "version": 1,
  "updated_at": "…",
  "irsf": {
    "n": 10,
    "t_minutes": 5,
    "q_minutes": 30,
    "prefixes": ["0900", "+44900", "0044900"],
    "act_enabled": false
  },
  "detectors": {
    "irsf": true,
    "off_hours": false
  },
  "off_hours": {
    "tz": "UTC",
    "windows": [{"dow": [6, 0], "start": "18:00", "end": "06:00"}],
    "n": 20,
    "t_minutes": 60
  },
  "allowlist_extensions": []
}
```

Do **not** put `sbc_never_route` in the velocity policy for this plan (L4 deferred). CFIM/failed-scan/Wangiri flags omitted until a gap is proven (L3).

### L2 — V4 tenant audience — **LOCKED defer** (2026-08-11)

| Topic | Lock |
|-------|------|
| **Audience** | **Fleet ops only** — existing `notify_failures` + optional `GATEKEEPER_OPS_NOTIFY_EMAIL` |
| **Tenant admin mail** | **Out of this plan** — do not implement WP4 / `tenant_notify_emails` now |
| **Hygiene** | Keep masked/truncated dests in fleet mail (already V2) |
| **Revisit** | Separate decision later if product wants customer-facing velocity mail |

~~Rejected for now:~~ node tenant-row emails; `meta.json` recipient resolve.

### L3 — Detector priority + shared act — **LOCKED** (2026-08-11)

**Product framing:** Most “extra” shapes are still **outbound to a high-value / suspected number**. CoS prevention + IRSF velocity + V5 act already own that path. Do not invent parallel universes where a separate detector is the only brake.

| Priority | Detector | Stance |
|----------|----------|--------|
| **0** | **IRSF burst** (existing) | Keep — primary detect/act on high-value prefix surge |
| **1** | **Off-hours / weekend blitz** | **Build next** — classic pattern; among the **most damaging**; time-window surge (same act). Clock: node TZ / policy `off_hours.tz` |
| **—** | **CFIM / Follow-me** | **Case of the same problem**, not a separate threat class: divert still dials PSTN. Act already **clears CF** with `active=NO`. Optional later: config-plant detect as an *early signal* under the IRSF family — **not** WP1 headline ahead of off-hours |
| **—** | **Failed / short-call scan** | Still a call toward a high-value number → **CoS + existing velocity + ACT** should catch/kill; **no separate detector in this plan** unless lab proves a gap |
| **—** | **Wangiri** | Subtle; redial to a **recognised/suspected** target should hit CoS/IRSF. **Nice later add-on:** notify/warn **before** the human hits callback (Wangiri depends on that click) — e.g. short inbound from a suspect/premium CLI → fleet mail *before* an outbound attempt, not only after CDR. **No separate detector in this plan** unless we schedule that add-on |

**Shared act:** unchanged — `VelocityPhoneActuator` + attributor; hysteresis per `(type, extension)`; Gatekeeper templates for types we actually emit (`velocity_irsf`, `velocity_off_hours`, …).

**Event types deferred with detectors:** `velocity_cfim`, `velocity_failed_scan`, `velocity_wangiri` — not scheduled unless a gap is proven.

### L4 — SBC thin floor — **LOCKED defer** (2026-08-11)

| Topic | Lock |
|-------|------|
| **Prevention home** | **Tenant CoS** (`HR_*` seeds and later packs) — including sat / junk CCs previously floated as an SBC floor |
| **S3 role** | Evolve **rule sets / packs over time** in catalog (and related seeds); **adopt into the tenants that need them** — not a one-shot fleet hard-block |
| **Why not SBC now** | Fleet-wide SBC refuse is hard to exception: one user may need satphone (and will pay). Tenant CoS → ops can **open that tenant** on request without biting the whole fleet |
| **Compromise** | S3 store-and-forward + per-tenant adoption beats duplicating a refuse list on the edge |
| **WP6** | **Out of this plan** |
| **Revisit** | Only if product later wants a true no-tenant-can-open fleet refuse |

Posture doc (**`HIGH_RISK_DIAL_BLOCK_POSTURE.md`**) updated to match.

### L5 — Explicit deferrals (stay deferred unless you pull them in)

- **V4 tenant-admin velocity mail** (L2)  
- **SBC thin never-route floor** (L4) — sat/high-risk stay on tenant CoS  
- **Separate CFIM / failed-scan / Wangiri detectors** (L3) — treat as same high-value dial path; optional CFIM config early-signal later  
- Dormant extension wake-up  
- Concurrency-above-normal  
- Forward-chain CDR correlation  
- Premium first-call watchlist beyond prefix lists  
- Scanner heartbeat / silence alarm  
- Per-tenant velocity templates  

---

## 3. Work packages

### WP0 — Lab ACT prove — **DONE** (2026-08-11)

Ops prove of **already-shipped** V5 act on golden. Green before stacking V3/off-hours.

| Step | Result |
|------|--------|
| Host | golden **08jzwn** |
| Phone | sacrificial **1199** / tenant **9wvvnb** (`z_updater` was `sipp-pack`) |
| Fixture | `pbx3:cdr-fixture --deck=irsf --count=12 --src=1199 --accountcode=9wvvnb --path=/tmp/cdr-velocity-wp0.db` |
| Scanner | `pbx3:ops-velocity` → `emitted=1 acted=1 errors=0` |
| Act | `active=NO` `z_updater=velocity` |
| Restore | `active=YES` + genAst / pjsip reload; flags **`ENABLED=false` `ACT=false`** after |
| Local Pest | 12 velocity-related tests passed before lab |

**Done when:** met. Next: **WP3**.

### WP1 — Detector framework + off-hours — **DONE** (2026-08-11)

**Repos:** `pbx3api`, Gatekeeper notify, tests, CDR pack extensions.

| Task | Detail |
|------|--------|
| 1.1 | `VelocityOrchestrator` runs IRSF + optional off-hours |
| 1.2 | `VelocityOffHoursScanner` + `VelocityOffHoursClock` — high-risk prefixes inside policy windows; emit `velocity_off_hours` |
| 1.3 | Gatekeeper mail + throttle key `(off_hours, extension)` |
| 1.4 | Act path: reuse V5 actuator |
| 1.5 | Pest: clock + emit/hysteresis + outside-window + orchestrator dual emit |
| 1.6 | Clock: node TZ / policy `off_hours.tz`; enable via `detectors.off_hours` or `PBX3_OPS_VELOCITY_OFF_HOURS` |

**Done when:** unit tests green; tip Gatekeeper + node when enabling lab off-hours.

### WP2 — (removed)

Failed-scan and Wangiri are **not** separate WPs (L3). Reopen only if lab shows CoS + IRSF miss them.

### WP3 — V3 fleet policy — **DONE** (2026-08-11)

| Task | Detail |
|------|--------|
| 3.1 | Gatekeeper `GET`/`PUT` `/api/v1/velocity-policy` → S3 `catalog/velocity-policy.json` (`fleet_read` / `fleet_admin`) |
| 3.2 | Node `VelocityPolicyResolver`: S3 → cache → env; `PBX3_OPS_VELOCITY_POLICY=local` for env-only |
| 3.3 | Defaults match lab env (`0900` / `+44900` / `0044900`, N=10, T=5, Q=30, act off) |
| 3.4 | SPA Fleet → **Velocity** editor on Gatekeeper API |
| 3.5 | CONTROL_HOST + requirements V3 marked done |
| 3.6 | Pest: local / S3 apply / cache fallback |

**Done when:** met in code + unit tests. Lab: tip Gatekeeper + node IAM GetObject + seed PUT when rolling.

### WP4 — V4 tenant mail — **DEFERRED** (L2)

Not in this build. Fleet `notify_failures` only. Revisit when product wants customer-facing velocity mail.

### WP5 — Wangiri / CFIM-config / failed-scan — **DEFERRED** (L3)

Not separate builds in this plan. Rely on CoS + IRSF prefix velocity + ACT (CF clear already on act).

**Wangiri revisit sketch (not scheduled):** short inbound from a suspect/premium CLI → **warn email before callback** (the scam needs a human to hit return-call). Stronger than post-facto redial correlation; still notify-plane only (Rule 5). Optional CFIM *config* early-signal later if ops want faster than CDR.

### WP6 — SBC thin never-route — **DEFERRED** (L4)

Not in this build. Sat / high-risk prevention stays on **tenant CoS** so a paying satphone (or similar) can be released per customer. Revisit only for a hard fleet refuse.

---

## 4. Suggested build order (execution)

```text
WP0 lab ACT prove          ★ now (ops)
WP3 V3 fleet policy (thin) — S3 + Gatekeeper write + node pull for IRSF (+ off_hours knobs)
WP1 detector frame + off-hours
WP2 / WP4 / WP5 / WP6 — deferred or removed per L2–L4
```

**Rationale:** **WP0 now** → **V3 thin** → **off-hours** as the only new detector class in this plan. CFIM/failed/Wangiri stay on the same high-value dial path; V4 and SBC floor deferred.

---

## 5. Test matrix

| Layer | What |
|-------|------|
| **Unit** | Each detector + attributor/actuator + policy merge (env vs cache vs pull) |
| **Pack** | Extend `pbx3:cdr-velocity-pack` (and CFIM config fixture) |
| **Gatekeeper** | NotifyDispatcher per `type` (fleet recipients only) |
| **Lab WP0** | Golden disposable phone ACT |
| **Regression** | Solo node without Gatekeeper still runs IRSF on env |

---

## 6. Doc / TODO touchpoints (when locking + shipping)

| Doc | Update |
|-----|--------|
| This plan | Status → **Accepted** + date; strike rejected alternatives |
| `FLEET_TOLL_FRAUD_VELOCITY_REQUIREMENTS.md` | Mark WP slices done; keep build order in sync |
| `FLEET_OPS_NOTIFICATION_REQUIREMENTS.md` | New event types + V4 |
| `CONTROL_HOST.md` | Policy pull + flags |
| `HIGH_RISK_DIAL_BLOCK_POSTURE.md` | Note SBC floor deferred (tenant CoS exceptions) |
| `TODO.md` #8 | Point at this plan; tick slices |
| `TODO_OPS.md` | Tip SHAs + WP0 prove |

---

## 7. Review checklist (for you)

Please mark each:

1. ~~**L1**~~ — **locked:** S3 `catalog/velocity-policy.json` HoR; Gatekeeper sole writer; readers OK if Gatekeeper down.  
2. ~~**L2**~~ — **locked:** V4 deferred; **fleet ops mail only** for now.  
3. ~~**L3**~~ — **locked:** off-hours next; CFIM = same PSTN case (act already clears CF); failed-scan/Wangiri covered by CoS+IRSF unless lab gap.  
4. ~~**L4**~~ — **locked:** SBC thin floor **deferred**; sat/high-risk stay on **tenant CoS**.  
5. ~~**WP order**~~ — **locked:** WP0 now → V3 thin → off-hours.  
6. ~~**SPA vs Filament**~~ — **locked:** Gatekeeper **API first**, then **SPA Fleet**; Filament must not write this object.  
7. ~~**WP0 timing**~~ — **locked:** **now**.

---

*Accepted 2026-08-11 — execute WP0 → WP3 → WP1.*
