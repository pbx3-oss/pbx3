# Phone model: durable harvest vs ephemeral render (+ fleet inventory)

**Status:** Parked notes **2026-08-26** — **not scheduled**; not a build lock.  
**Parent:** **`EXTENSION_PHONE_IMAGE_FROM_UA_REQUIREMENTS.md`** (AstDB `registrar/contact` source).  
**Why this note:** Same UA source can feed **home display**, optional **fleet inventory**, or both. Trust and freshness differ by posture.

---

## 0. Clincher — `last_seen` / `reported_at`

**Any durable or rolled-up model/MAC is only honest if it carries when it was observed.**

| Lock | |
|------|--|
| L1 | Every stored or directory-projected phone hint includes **`last_seen`** (or `reported_at`) — ISO time of the AstDB observation that produced the slug. |
| L2 | UI always surfaces that time (“as of …”). No bare model/MAC as “current phone.” |
| L3 | Stale after a handset swap is **expected**; catch-up on next observe is the fix. Do not treat missing freshness as a defect to hide. |
| L4 | **Wrong window is short.** `user_agent` in AstDB only changes when the endpoint **REGISTER**s (new/re-REGISTER). Until then the stored hint matches what Asterisk last saw. Incorrect durable/fleet data lasts at most until **next REGISTER → next harvest/observe** (cron cadence), not an unbounded drift. |
| L5 | **Change can be a warning signal (later).** A new UA/model (or MAC) vs prior observation may mean a desk swap — or someone registering a device they shouldn’t. Needs **retained prior context/history** to sense change. **Parked:** detect / notify only when scheduled; **not** v1 harvest or image ship. Do **not** auto-block REGISTER or calls from inventory drift. |

Without **L1–L4**, prefer posture **B** and skip durable/fleet copies. **L5** is optional later (needs history). **With L1–L4**, posture **A** and optional fleet inventory are acceptable ops hints.

---

## 1. Shared facts

- Asterisk AstDB `registrar/contact` already has `user_agent` (and endpoint = shortuid) for phones registered **to this home**.
- End users can swap or reprogram a different handset anytime. **Any stored copy can be wrong until the next observation.**
- The SIP **User-Agent only changes on REGISTER**. A swap that has not yet registered still shows the old UA in AstDB (correct for “what is registered”); once the new phone registers, AstDB updates and the next harvest/render catches up (**L4**).
- Therefore: model/MAC roll-ups are **ops hints**, never security, CoS, DID, or “allowed phone” truth — and only with **§0 last_seen**.

---

## 2. Two home postures (open choice before implement)

| | **A — Durable soft harvest** (current parent lock) | **B — Ephemeral on render** |
|---|-----------------------------------------------------|------------------------------|
| When | Async cron / sidekick | Extension **list** or **edit** API/SPA load |
| Home DB | Soft-fill `ipphone.devicemodel` **+ last_seen** (S3 soft write) | **No** durable auto-write (or display-only overlay) |
| Freshness | Stale until next harvest; honesty = **last_seen** | Fresh on each render (if registered now); last_seen = now |
| Swap risk | Wrong model/image until catch-up — OK if last_seen shown | Wrong only if mid-session swap without refresh |
| Cost | Cheap reads later; cron AMI dump | AMI/`database show` (or cached dump) on list/edit path |
| Parent S2 | Fits (“never on SPA request path”) | **Reopens S2** — request-path AstDB read allowed for this feature |
| Images | Easy from stored `devicemodel` + pack | Map live UA → model → asset on the fly |

**Operator nervousness (swap → wrong inventory):** Mitigated by **§0**, not by pretending the copy is live. Posture **B** avoids a wrong durable row; **A** keeps a row but labels it with **last_seen**. Same durable trail is what makes **L5** (unexpected change → ops warning) possible later.

**Decide A vs B before coding slices A–E** of the parent doc. If **B** wins, re-lock parent S2/S3 (and drop or shrink the cron utility). If **A** wins, parent implement must add **last_seen** alongside soft `devicemodel` (schema/API/SPA as needed).

---

## 3. Optional fleet directory inventory

**Idea:** Each home (after observe) pushes **slugs** up via **Gatekeeper** (fleet service token → catalog/S3) — e.g. model slug, optional MAC, shortuid, tenant, instance id, **`reported_at` / last_seen** (required).

| Lock (if ever built) | |
|----------------------|--|
| F1 | **Optional.** Solo / no fleet token → no push. Home display must not need directory (**Rules 1, 6**). |
| F2 | **Async fail-soft.** Control down → skip push; phones keep working (**Rule 11**). |
| F3 | **Not authoritative** + **§0.** Always store / show **`reported_at`**. UI: “as of …”, never “the phone on the desk.” |
| F4 | **Stale is expected and brief.** Wrong only after REGISTER changes UA until next observe + push (**L4**). Catch-up is normal; do not gate telephony on inventory. |
| F5 | **Write path = Gatekeeper**, not instance Sanctum catalog mutate (**Rule 10**). |
| F6 | **Not live telemetry** in `instance-index` — separate inventory object(s), infrequent (sibling of DID inventory / async offload, not pulse badges). |

Works with **either** posture A (push after harvest) or **B** (optional periodic observe-only job that never writes `ipphone`, or push only when an admin opens Fleet — product call later). **No last_seen → no inventory row.**

---

## 4. What not to do

- Use directory (or stale `devicemodel`) to **block** REGISTER / calls (including on **L5** change).
- Show model/MAC **without** last_seen / reported_at.
- Treat UA or MAC inventory as proof of physical asset without freshness + human judgment.
- Put Gatekeeper tokens in the SPA (**Rule 12**).
- Require directory for extension panel images on a solo box.

**Later (parked):** ops notify when harvested model/MAC **changes** — needs prior history (**L5**). Not first harvest/image ship; revisit with **`FLEET_OPS_NOTIFICATION_REQUIREMENTS.md`** when wanted.

---

## 5. Suggested decision order (when scheduled)

1. Keep **§0 last_seen** non-negotiable for any durable or fleet copy.  
2. Choose **home posture A vs B** (display + soft-write).  
3. Implement AstDB read + UA→model map (shared).  
4. Slice E images against that choice.  
5. Only then: optional fleet inventory (F1–F6) if MSP still wants a cross-node phone list.
