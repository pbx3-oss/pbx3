# Inbound DISA vs CALLBACK

**Status:** **Locked 2026-10-20** (operator confirm).  
**Related TODO:** **#8c** · open checklist “Inbound DISA vs CALLBACK”.  
**Toll fraud:** related to **#8**.

---

## 1. Product posture (locked)

| Mode | Posture |
|------|---------|
| **DISA** (immediate dial-tone after PIN / open trunk) | **Drop.** High toll-fraud risk. Do not offer in SPA. Do not accept on API write. |
| **CALLBACK** (queue / deferred callback flows) | **Future feature.** Useful (especially queues) but needs real design/implementation. **Hide** from SPA dropdowns until scheduled. Do not accept on API write until then. |
| **None** | Only supported value for `disa` on inbound routes / trunks today. |

**If a site later needs “remote dial-tone”:** do **not** revive classic DISA. Prefer a **secure dial-tone** path: caller hits a DDI, presents credentials (**CLID allowlist and/or passcode**), then receives dial-tone. Spec that track when demanded — separate from this lock.

**CALLBACK implementation:** park until deliberately scheduled. Use public Asterisk/queue callback howtos as research input; productize under a new requirements doc when started (queue UX, auth, fraud bounds, CAGI/GenAst).

---

## 2. Near-term UX / API (ship with this lock)

1. **SPA:** Remove **DISA** and **CALLBACK** from inbound-route (and any trunk) DISA controls. Prefer **hide/remove the whole DISA + DISA pass controls** while neither mode is available (None-only UI is noise).
2. **On Save** (inbound route): persist **`disa` cleared** (null / empty / None) and clear **`disapass`** so leftover DISA/CALLBACK rows do not stay armed after an operator save.
3. **API:** Validation accepts only empty/null/None for `disa` (reject `DISA` and `CALLBACK` with 422). Same for trunk `disa` if still in schema.
4. **Existing DB rows** with DISA/CALLBACK remain until edited/saved or an optional one-shot ops clean; do not require a package migration for v1 hide.
5. **CAGI:** No new DISA/CALLBACK investment. Classic paths may remain dead code until a secure dial-tone / callback track; do not document as supported.

---

## 3. Non-goals (now)

- Implementing queue CALLBACK.
- Implementing secure dial-tone (future ask).
- Privilege-gating DISA for “advanced” users (rejected — drop, don’t gate).

---

## 4. Lock checklist (accepted 2026-10-20)

1. Drop **DISA** from product surface.  
2. Hide **CALLBACK**; treat as future feature.  
3. Remote dial-tone later = **authenticated** path (CLID and/or passcode), not classic DISA.  
4. SPA hide + API reject + clear on save.
