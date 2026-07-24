# Ast config generator sub-project

**Status:** Challenger review parked (2026-07-24) — decisions locked, **no merge yet**. Code WIP stashed on branch `genast-phone-overlay` (do not treat as shipped).  
**Owns:** Asterisk config generation (`genAst` / `GenClass` / endpoint staging / dialplan emit), including **phone PJSIP staging/overlay**, **extensions.conf structure**, **and** the paired **pbx3cagi** cleanup.  
**CAGI plan:** `pbx3cagi/workingdocs/REFACTOR_PLAN.md` (Phase 0 harness done; Phase 1.3 → 1.1 → 2.x when resumed). Linked by dialplan ↔ AGI contract; still two repos / two commit roots.  
**Full study plan (Cursor):** `~/.cursor/plans/genast_challenger_review_0db5c469.plan.md`

---

## 0. Challenger findings (2026-07-24) — pick up next session

### Locked — PJSIP phones (G2)

- **Stock:** always read `pjsip_phone.tmpl` on Commit (`get`).
- **Hand overlay required:** optional `ASTENDPOINTS/{shortuid}_phone.overlay.conf`, **append** pre-xlate (one-phone escapes that stay out of DB).
- **Not:** full frozen `*_phone.conf` copy-once (causes tmpl-roll delete chore).
- **`create*`:** ensure `endpoints/` only; **`set*`:** write overlay path only.
- **Legacy cleanup:** one-time lab `rm endpoints/*_phone.conf` after deploy — do **not** auto-delete in genAst.
- **API gap:** extension delete must also remove `*_phone.overlay.conf` (pbx3api Helper today only deletes `*_phone.conf` / webrtc).
- **WIP:** premature HelperClass/config edits live in **stash** on `genast-phone-overlay` — review against this contract before commit.

### Locked — dialplan north star (separate track from G2)

- GenAst = **routing-table compiler** (match → AGI stub); CAGI = **call engine** (Dial, CF, fleet AoR).
- Thin further; **one Dial authority** — kill GenAst fleet `Q{ext}` Dial fork (`GenClass` ~1217–1222); same PrepDial path as LepDial.
- More `#include`s only for static patterns (presets already do this well).
- **Surgical bug:** `genExtensionsEndpoints` inner `foreach ($this->appl as $row)` **shadows** tenant `$row` (~990) — can corrupt localarea / open-close / fleet FQDN / VM context after any appl rows; `$this->applrow` unset. Fix before large dialplan refactor.
- CoS O(phones) contexts: do not grow; redesign later.
- Orthogonal to phone overlay — do not block G2 on dialplan rewrite.

### Rejected

- Always-tmpl with **no** overlay (operator needs hand override).
- DB JSON overrides (revisit only if SPA edits overlays).
- ARI / realtime rewrite; less AGI / more dialplan; per-tenant context file sprawl as the main fix.

### Resume order when coding

1. Unstash / review G2 on `genast-phone-overlay` vs §0 phone contract; API overlay delete; golden smoke.
2. Optional surgical: appl/`$row` shadow fix.
3. Later: webrtc overlay parity; dialplan thin; G3 SBC FQDN; `$clstkey` xlate bug in `pjsip_phone.tmpl`.

---

## 1. Intent

Treat config generation as its own work track — not a one-off “delete staged phones after tmpl change” chore. Fold the parked **phone PJSIP staging** item into this track. Keep cagi struct refactor as a parallel cleanup that must not break GenAst-emitted AGI argv / Dial forms.

```text
pjsip_phone.tmpl  --(always on get)-->  + optional {shortuid}_phone.overlay.conf
                                              |
                                         xlate on Commit
                                              v
                              pjsip_ready_*.conf + extensions*
                                              |
                                    agi(SYSAGI, …) / Dial(…)
                                              v
                                         pbx3cagi
```

---

## 2. Scope

### In

| Area | Location |
|------|----------|
| Entry | `scripts/genAst.sh` → `php/utilities/runAstGen.php` → `GenClass::genAsterisk()` |
| Generator | [`php/classes/GenClass`](../pbx3-1/opt/pbx3/php/classes/GenClass) |
| Staging CRUD | [`HelperClass`](../pbx3-1/opt/pbx3/php/classes/HelperClass) `create/get/set/move/deletePjsip*Instance` |
| Templates | `etc/asterisk/templates/` (`pjsip_phone`, webrtc, trunks, queue, transport, …) |
| Staged instances | `etc/asterisk/endpoints/{shortuid}_phone.conf` (and webrtc/trunk peers as today) |
| Ready outputs | `pjsip_ready_phones.conf`, webrtc/trunks, queues, `extensions*` (via Commit) |
| Ops | [`OPS_ASTERISK_AFTER_EGRESS_GENAST.md`](OPS_ASTERISK_AFTER_EGRESS_GENAST.md) — full restart vs reload |

### Out (non-goals)

- SPA panel UX (except where Commit already triggers genAst).
- Gatekeeper / fleet catalog / S3 control plane.
- SBC OpenSIPS config (except **consuming** fleet edge FQDN / `outbound_proxy` as generator inputs).
- Implementing cagi Phase 1+ code in this repo (owned by pbx3cagi).

### Related parked residue (list under this track; not first coding slice)

- Hardcoded SBC FQDN in `xlatePjsipBuff` (`sip:sbc.pbx3.com`).
- Page / `***` presets.
- Tighter OpenSIPS gate / tenant DNS ≠ VIP (edge; pointer only).
- [`TODO.md`](TODO.md) **pjsipuser for extensions** / NAT tmpl keys — fold here when touched.

---

## 3. Staging today (problem)

`HelperClass::createPjsipPhoneInstance($key)`:

- Target: `ASTENDPOINTS/{key}_phone.conf`.
- Copies `pjsip_phone.tmpl` **only if** target missing or zero-size.
- Commit path: `getPjsipPhoneInstance` → read staged file → `GenClass::xlatePjsipBuff` expands `$id`, `$outbound_proxy`, etc. → write `pjsip_ready_phones.conf`.

**Consequence:** tmpl rollouts (e.g. fleet `$outbound_proxy`) do not reach existing phones until operators delete/refresh staged files, then Commit. Always-from-tmpl would wipe any intentional per-phone edits.

Same copy-once pattern exists for WebRTC (and trunk staging helpers).

---

## 4. Staging target model

**Chosen default:** packaged **tmpl is source of truth for stock keys**; staged files are either absent for stock phones or hold a **thin overlay** only.

**Acceptance (first staging fix when coding starts):**

1. Change `pjsip_phone.tmpl` (e.g. add/change a stock key), Commit — **all stock phones** pick up the change **without** deleting `endpoints/*_phone.conf`.
2. Any genuine per-phone override (if still required) survives via overlay file or DB-driven substitution only — not by freezing a full copy of an old tmpl.
3. Fleet vs singleton: `$outbound_proxy` / tenant-AoR Q dials remain **fleet-gated** (`PBX3_FLEET_MODE` / active `Egress`); singleton stays direct-to-contact.
4. WebRTC (and later trunks) follow the same model once phones are proven.

Exact overlay format (sidecar fragment vs merge rules) is an implementation detail of the coding slice — not locked here beyond “tmpl wins for stock; overrides are thin.”

---

## 5. GenAst ↔ CAGI shared contract

Keep these stable while either side refactors. Changing shape = coordinated change + `make test` (cagi) + Commit/genAst lab check (node).

### 5.1 Named AGI commands GenAst emits (representative)

From `GenClass` dialplan generation (argv after `SYSAGI`):

| Command | Typical use |
|---------|-------------|
| `LepDial` | Extension shortuid dial entry |
| `OutRoute` | Outbound route plan |
| `OutTrunk` | Trunk match line |
| `IVR` | IVR menu |
| `Ingress` | Peer/inbound ingress |

Feature star-codes also call `agi(${SYSAGI},…)` via [`extensions_presets.conf`](../pbx3-1/opt/pbx3/etc/asterisk/configs/extensions_presets.conf) (CFIM/CFBS/DND/agents/ChanSpy, etc.) — treat as part of the same contract surface.

CAGI also receives dials/AGI from queue/recording paths (e.g. `SetRecord`, PrepDial-style behaviour in cagi) that GenAst or templates may touch; do not change argv arity casually.

### 5.2 Dial forms (fleet-sensitive)

- Fleet: `Dial(PJSIP/{shortuid}/sip:{shortuid}@{tenant.fqdn})` (Q dial / ring-group path).
- Singleton: `Dial(PJSIP/{shortuid})`.
- Phone endpoint `$outbound_proxy` → SBC only in fleet mode (`xlatePjsipBuff` / `isFleetMode()`).

### 5.3 Duplicate fleet gate

- GenAst: `GenClass::isFleetMode()` — env `PBX3_FLEET_MODE`, else active trunk `pkey=Egress`.
- CAGI: `pbx3_fleet_mode()` — same idea in `pbx3cagi.c`.

Future hygiene: single documented semantics; optional shared source later if both are edited. Do not diverge silently.

### 5.4 CAGI track pointer

- Plan: **`pbx3cagi/workingdocs/REFACTOR_PLAN.md`**
- Harness: **`TEST_HARNESS.md`**, **`TEST_RECIPE.md`** — run **`make test`** after each cagi refactor step.
- Resume order when product allows: Phase **1.3** (dead code) → **1.1** (structs) → **2.x** (splits). Conjunction with this sub-project = review contract above before changing GenAst dialplan emitters or cagi command handlers.

---

## 6. Phases (high level)

| Phase | Owner | Work |
|-------|--------|------|
| **G0** | Docs | This file + TODO rebucket — **done when merged**. |
| **G1** | pbx3 | Inventory: list all tmpl → staged → ready paths (phone, webrtc, trunks, queues). |
| **G2** | pbx3 | **Staging/overlay** for phones (acceptance §4); then webrtc parity. |
| **G3** | pbx3 | GenClass hygiene (fleet FQDN input, clearer xlate, less shell-cp). |
| **G4** | pbx3 | Optional generator tests / golden Commit smoke (separate from cagi harness). |
| **C1+** | pbx3cagi | Existing refactor phases; keep §5 contract green. |

Do not start G2 coding until G1 inventory is short and agreed; do not start cagi Phase 1.1 until Phase 0 suite still green on the branch tip.

---

## 7. Repos and commits

| Change | Repo |
|--------|------|
| GenClass / HelperClass / templates / genAst | **pbx3** |
| AGI handlers / harness | **pbx3cagi** |
| SPA Commit trigger only if API contract changes | **pbx3api** / **pbx3spa** (rare) |

`pbx3-master/` is not a git root — commit per repo.

---

## 8. Success criteria (framing)

- TODO treats staging as part of this sub-project, not an orphan park item.
- This doc answers: what the generator track is, how staging fits, how it relates to cagi cleanup, and what “done” looks like for the first staging fix.
