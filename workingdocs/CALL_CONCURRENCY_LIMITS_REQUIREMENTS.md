# Call concurrency limits (`maxin` / `maxout`)

**Status:** **Locked 2026-10-20** (operator confirm).  
**Implements in:** **pbx3cagi** (Asterisk `GROUP` / `GROUP_COUNT`); SPA/API field tidy as follow-on.  
**Related TODO:** product **`TODO.md`** — pbx3cagi `maxin` / `maxout` call counters.  
**Smoke:** **`DBSTRUCT_SMOKE_CHECKLIST.md`** Ingress `maxin` cap.

---

## 1. Problem

Schema + SPA expose overlapping knobs; CAGI enforcement is incomplete / likely wrong:

| Knob | Loaded by CAGI today | Enforced today |
|------|----------------------|----------------|
| Tenant **`maxin`** | Yes | `Ingress` — **GROUP category likely mismatched** |
| Tenant **`chanmax`** | Yes | `OutRoute` — same mismatch risk |
| Tenant **`voip_max`** | Yes | `OutVoip` — GROUP OK; over-limit = silent no-Dial |
| Tenant **`maxout`** | **No** | Never |
| Instance **`globals.maxin` / `maxout` / `voipmax`** | **No** | SPA only |

Inbound also uses a **shared** group name across tenants while the limit is per-tenant.

---

## 2. Product model (locked)

### 2.1 Keep: `maxin` + `maxout` only

| Knob | Scope | Meaning | On exceed |
|------|--------|---------|-----------|
| **`cluster.maxin`** | **Tenant** | Max concurrent **inbound** for this tenant | Busy |
| **`cluster.maxout`** | **Tenant** | Max concurrent **outbound** for this tenant (all trunk tech) | Busy |
| **`globals.maxin`** | **Instance** | Max concurrent **inbound** on this home (all tenants) | Busy |
| **`globals.maxout`** | **Instance** | Max concurrent **outbound** on this home (all tenants) | Busy |

Both tenant and instance caps apply when set (either may reject). Internal ext↔ext — **out of scope**.

### 2.2 Drop / ignore: `voip_max` and `chanmax`

| Knob | Disposition |
|------|-------------|
| **`cluster.voip_max`** / **`globals.voipmax`** | **Ignore in CAGI.** No longer meaningful without ISDN/analog alternate pathways. Leave DB columns for ETL/compat; **hide or remove from SPA** in a follow-on (not required to ship CAGI fix). Stop loading/checking in AGI. |
| **`cluster.chanmax`** | **Superseded by tenant `maxout`.** Same job (tenant outbound ceiling). CAGI should enforce **`maxout`**, not `chanmax`. SPA: migrate tenant **ChanMax** field → **Max out** (`maxout`); keep reading `chanmax` as fallback only if `maxout` null during transition, then drop from UI. |

### 2.3 Counting rules

- Asterisk `GROUP` / `GROUP_COUNT` on the home only.
- Tenant groups keyed by **`shortuid`** (fallback `pkey`).
- Instance groups: fixed categories (e.g. `pbx3in` / `pbx3out`).
- **GROUP API must match:** `Set(GROUP(<category>)=<name>)` ↔ `GROUP_COUNT(<name>@<category>)`.
- After join, reject when **`count > limit`** (**locked**).
- **`0` / empty / NULL = unlimited** (**locked**). Positive N enforces. Schema defaults may stay 30 for new rows.

### 2.4 Where checks run

| Check | Entry |
|-------|--------|
| Tenant + instance **maxin** | `Ingress` |
| Tenant + instance **maxout** | Outbound gate once before trunk dial (`OutRoute` / shared helper used by `OutVoip` / `OutTrunk`) |

Remove voip_max branch behaviour from `OutVoip` (no silent skip-on-voip-count).

### 2.5 Solo vs fleet

Same rules. Instance globals = house ceiling on multi-tenant homes.

### 2.6 Observability — log (and later alert) on every limit hit

**Required with the CAGI fix:** every hard reject must leave an **operator-visible record** of *which* limit fired and *for whom*. Silent Busy is not enough.

**v1 — structured home log (ship with enforcement):**

- Emit one line (Asterisk/`pbx3cagi` NOTICE or dedicated channel — same family as other ops-visible CAGI messages) on each reject, **before** Busy treatment.
- Fields (stable tokens, grep-friendly), e.g.  
  `PBX3_CONCUR_LIMIT knob=maxin scope=tenant shortuid=hf3zzv limit=1 count=2 direction=in channel=… uniqueid=…`  
  or `knob=maxout scope=instance shortuid=- limit=30 count=31 direction=out …`
- **knob:** `maxin` | `maxout`  
- **scope:** `tenant` | `instance`  
- **who:** tenant **`shortuid`** (and/or Name) when scope=tenant; instance FQDN/shortuid when scope=instance  
- **limit** / **count** at decision time  
- **direction:** `in` | `out`  
- Enough call identity for desk debug (`channel`, `uniqueid`, and inbound DNID / outbound dialled digits when cheap)

**v1.1 — optional rate note:** log **every** hit (not sampled). If noisy in soak, add a follow-on throttle; do not start with silent drops.

**Later (not blocking v1):** hook the same event into fleet ops notify / Home badge if operators want email/SMS on sustained hits — separate from this CAGI fix; reuse **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** patterns when scheduled. SPA “limits hit today” is optional polish.

---

## 3. Non-goals

- Gatekeeper / control plane for the counter itself.
- Queue `maxlen`, PJSIP endpoint max contacts, SBC dialog limits.
- CAGI Phase 4 file splits.
- Toll-fraud velocity (#8).
- Immediate schema DROP of `voip_max` / `chanmax` columns (compat later).
- Fleet SMTP / SPA badge for limit hits in the first CAGI package (log is enough for v1).

---

## 4. Implementation sketch

1. Fix GROUP set/count; shortuid-keyed tenant in/out groups.
2. Load tenant **`maxout`** + instance **`globals.maxin` / `maxout`**; stop using **`voip_max` / `chanmax`** for enforcement (optional one-release fallback: if `maxout` null and `chanmax` set, honour `chanmax`).
3. Busy on hard reject; no silent no-Dial; **emit §2.6 log line** on every reject.
4. Harness + lab: `maxin=1` / `maxout=1` — assert Busy **and** log line / token present.
5. SPA follow-on: tenant Max out; hide VoIP max / ChanMax.
6. **pbx3cagi** deb bump when shipping.

---

## 5. Lock checklist (accepted 2026-10-20)

1. **Only `maxin` / `maxout`** (tenant + instance) — drop **`voip_max` / `voipmax`** from product behaviour.
2. **Tenant outbound = `maxout`**, not `chanmax` (SPA rename; short fallback OK).
3. **`0` = unlimited**; reject when `count > limit` after join.
4. **Internal calls** uncapped.
5. **Log every hit** (§2.6) with knob + scope + who; fleet email/badge later.
