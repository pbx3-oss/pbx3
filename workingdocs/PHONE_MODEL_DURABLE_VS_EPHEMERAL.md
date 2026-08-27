# Phone model: durable harvest vs ephemeral render (+ fleet inventory)

**Status:** **Posture A locked 2026-08-27** — build when scheduled (not first-out).  
**Parent:** **`EXTENSION_PHONE_IMAGE_FROM_UA_REQUIREMENTS.md`** (AstDB `registrar/contact` source).  
**Why this note:** Same UA source can feed **home display**, optional **fleet inventory**, or both. Trust and freshness differ by posture.

---

## 0. Clincher — `firstseen` / `lastseen`

**Any durable or rolled-up vendor/model is only honest if it carries when it was observed.**

Home columns (repurposed from defunct provisioner; add to SQLite if missing):

| Column | Role |
|--------|------|
| `firstseen` | UTC ISO — first harvest that mapped a UA and soft-wrote / confirmed auto vendor+model |
| `lastseen` | UTC ISO — most recent such harvest observation |

| Lock | |
|------|--|
| L1 | Every stored or directory-projected phone hint includes **`lastseen`** (fleet may mirror as `reported_at`) — time of the AstDB observation that produced the values. |
| L2 | UI always surfaces that time (“as of …”). No bare vendor/model/MAC as “current phone.” |
| L3 | Stale after a handset swap is **expected**; catch-up on next observe is the fix. Contact expiry → **stop bumping** `lastseen`; **leave** vendor/model (do not clear). |
| L4 | **Wrong window is short.** `user_agent` in AstDB only changes when the endpoint **REGISTER**s. Incorrect durable/fleet data lasts at most until **next REGISTER → next harvest** (**15 min** cron when enabled). |
| L5 | **Change can be a warning signal (later).** New vendor/model vs prior row may mean a desk swap. **Parked:** detect / notify when scheduled; **not** v1. Do **not** auto-block REGISTER or calls. |

Without **L1–L4**, prefer posture **B**. **With L1–L4**, posture **A** (locked) is acceptable.

---

## 1. Shared facts

- Asterisk AstDB `registrar/contact` already has `user_agent` (and endpoint = shortuid) for phones registered **to this home**.
- End users can swap handsets anytime. **Any stored copy can be wrong until the next observation.**
- SIP **User-Agent only changes on REGISTER**.
- Vendor/model (and optional MAC) are **ops hints**, never security / CoS / DID / “allowed phone” truth — and only with **§0**.
- **`ipphone.macaddr`** is **best-effort inventory** (user CRUD); **not** canon for vendor/model. SIP UA harvest is canon.

---

## 2. Home posture — **A locked** (2026-08-27)

| | **A — Durable soft harvest** (**locked**) | **B — Ephemeral on render** (rejected for v1) |
|---|-----------------------------------------------------|------------------------------|
| When | Async cron / sidekick | Extension list/edit API path |
| Home DB | Soft-fill `devicevendor` + `devicemodel` + `firstseen`/`lastseen` | No durable auto-write |
| Freshness | Stale until next harvest; honesty = **`lastseen`** | Fresh on each render |
| Parent S2 | Fits (never on SPA request path) | Would reopen S2 |
| Images | From stored vendor + model + pack | Live map on render |

**B is not scheduled.** Fleet inventory (§3) remains optional / later.

---

## 3. Optional fleet directory inventory

**Idea:** Each home (after observe) pushes **slugs** up via **Gatekeeper** — vendor, model, optional MAC, shortuid, tenant, instance id, **`reported_at` / lastseen** (required).

| Lock (if ever built) | |
|----------------------|--|
| F1 | **Optional.** Solo / no fleet token → no push. Home display must not need directory (**Rules 1, 6**). |
| F2 | **Async fail-soft.** Control down → skip push (**Rule 11**). |
| F3 | **Not authoritative** + **§0.** Always show **`reported_at`**. |
| F4 | Stale is expected and brief (**L4**). |
| F5 | **Write path = Gatekeeper**, not instance Sanctum (**Rule 10**). |
| F6 | **Not** live telemetry in `instance-index`. |

**No lastseen → no inventory row.**

---

## 4. What not to do

- Use directory or stale harvest to **block** REGISTER / calls (including on **L5**).
- Show vendor/model/MAC **without** lastseen / reported_at.
- Treat UA or MAC as proof of physical asset without freshness + judgment.
- Put Gatekeeper tokens in the SPA (**Rule 12**).
- Require directory for extension images on a solo box.
- Write OUI / vendor strings into **`ipphone.device`** (type enum only — see parent).

**Later (parked):** ops notify on harvest change (**L5**) — **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`**.

---

## 5. Decision order (implement)

1. §0 `firstseen` / `lastseen` non-negotiable.  
2. ~~Choose A vs B~~ → **A**.  
3. AstDB read + UA → `devicevendor` + `devicemodel` map.  
4. Soft write + cron (parent slices).  
5. Slice E images.  
6. Optional fleet inventory (F1–F6) only if still wanted.
