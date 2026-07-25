# Ast config generator sub-project

**Status:** Hermit-crab in progress (2026-07-25) — branch **`genast-hermit`**. Phases A–C lab-proven; **C2** (DB `pjsip_overlay` + SPA extension-edit) implemented on branch — migrate + Commit prefer DB, file fallback.  
**Owns:** Asterisk config generation (`genAst` / `GenClass` / endpoint staging / dialplan emit), including **phone PJSIP staging/overlay**, **extensions.conf structure**, **and** the paired **pbx3cagi** cleanup.  
**CAGI plan:** `pbx3cagi/workingdocs/REFACTOR_PLAN.md` (Phase 0 harness done; Phase 1.3 → 1.1 → 2.x when resumed). Linked by dialplan ↔ AGI contract; still two repos / two commit roots.  
**Study depth (ephemeral):** `~/.cursor/plans/genast_challenger_review_0db5c469.plan.md` — reference only; **this file is durable truth.**

---

## 0. Locked decisions + hermit-crab build order

### Locked — PJSIP phones (G2 / Phase C) — shipped on branch, lab OK

- **Stock:** always read `pjsip_phone.tmpl` on Commit (`get`).
- **Thin overlay:** fragment matched by `type=`; keys **replace** if present on that object, **add** if absent (Fail2ban-`.local` mental model). Not a second appended stanza (Asterisk keeps the first duplicate key).
- **Home of record:** `ipphone.pjsip_overlay` (TEXT). Commit prefers DB; optional file `ASTENDPOINTS/{shortuid}_phone.overlay.conf` only when DB empty.
- **Not:** full frozen `*_phone.conf` copy-once; **not** full PJSIP stanza in DB as sole source of truth (SARK-old freeze).
- **`create*`:** ensure `endpoints/` only; **`set*`:** write overlay **file** path (ops mirror / hand edit); SPA/API write the DB column.
- **Legacy cleanup:** one-time lab `rm endpoints/*_phone.conf` after deploy — do **not** auto-delete in genAst.
- **API:** extension delete removes `*_phone.overlay.conf` (pbx3api); DB column goes with the row.

### Locked — Overlay home of record (Phase C2 — built)

**Direction:** store the **same thin overlay text** on the extension (ipphone) row — column `pjsip_overlay` (TEXT, nullable). Commit reads DB overlay (preferred) and merges with tmpl; file under `endpoints/` is optional ops fallback when DB is empty.

| Corner | How DB overlay covers it |
|--------|---------------------------|
| Stock tmpl rolls | Still always from tmpl; overlay stays thin |
| One-phone escape | Overlay fragment only (`[$id]` + `type=` + keys) |
| SPA edit | Extension advanced field (admin) → column |
| Backup / restore | Overlay travels with DB |
| Tenant move | Overlay travels with extension row |
| Delete extension | Column gone with row (+ delete file mirror if any) |

**SPA:** MSP/admin “PJSIP overlay” textarea on **extension edit**. Privilege: admin (not end-user). Structured qualify/codec forms later if needed.

**Rejected for C2:** JSON map of all PJSIP keys as a second schema; editable **full** stanza that replaces tmpl for that phone.

**Deploy:** Laravel migration `2026_07_25_000000_add_pjsip_overlay_to_ipphone` on each node; hot-patch GenClass/HelperClass; SPA build. Lab: move `fkdd5d` file overlay into DB then remove file (or leave file until DB set).

### Locked — dialplan north star (Phase E; separate from G2)

- GenAst = **routing-table compiler** (match → AGI stub); CAGI = **call engine** (Dial **decision**, CF, fleet AoR).
- Separate **authority** (who decides dial string) from **locus** (who runs `Dial()` / holds the bridge).
- **One Dial decision authority** — GenAst must not invent a second dial recipe. Today’s hardcoded `Q{ext}` `Dial(...)` in GenClass (~1217–1222) is the fork to remove.
- **`Q*` target flow (locked 2026-07-25):** keep queue members as `Local/Q{ext}@tenant`; change only the body of `Q*`:
  1. `Queue()` → `Local/Q{ext}@tenant`
  2. `exten Q{ext}` → short AGI → **PrepDial(`type=queue`)** (same dial recipe as LepDial / fleet AoR)
  3. CAGI **Set** dial string on channel (e.g. `PBX3_DIAL`) and **return** — one-and-done short run; do **not** `EXEC Dial` / idle through the bridge
  4. Next dialplan priority → `Dial(${PBX3_DIAL})` — dialplan owns the bridge
- PrepDial already special-cases `type=queue` (ringdelay / twin / recording ghosts); today it still `EXEC Dial` at the end — E/G flips that to set-and-return for the `Q*` path first.
- **Phase G** generalizes the same short-run pattern to LepDial / other dials; `Q*` is the first proof point (preserves the original reason `Q*` lived in dialplan).
- More `#include`s only for static patterns (presets already do this well).
- **Surgical bug (Phase B):** `genExtensionsEndpoints` appl/`$row` shadow — **fixed** on `genast-hermit`.
- CoS O(phones) contexts: do not grow; redesign later.
- Orthogonal to phone overlay — do not block G2/C2 on dialplan rewrite.

### Rejected

- Always-tmpl with **no** overlay (operator needs hand override).
- Full stanza in DB as the only endpoint source (recreates copy-once / blocks tmpl rolls).
- ARI / realtime rewrite; less AGI / more dialplan; per-tenant context file sprawl as the main fix.
- Long-lived dual GenAst stacks aiming for byte-identical everything; “clone fat `extensions.conf` then optimize.”

### Hermit-crab phases (build order)

Same Commit entrypoint throughout (`genAst.sh` → `GenClass::genAsterisk()`). Strangle one segment at a time; no parallel production challenger.

| Phase | Work | Done when |
|-------|------|-----------|
| **A — Characterize** | Fixture capture + normalize/diff script; baseline on pre-change output | `scripts/genast-characterize.sh` diffs two Commit output dirs cleanly |
| **B — `$row` landmine** | Fix appl/`$row` shadow in `genExtensionsEndpoints` only | **Done** on `genast-hermit` |
| **C — G2 phones (file overlay)** | Tmpl + merge Helper; pbx3api overlay delete; lab `rm` legacy freeze | **Lab OK** (golden override + calls) |
| **C2 — DB overlay** | Extension column + API/SPA; Commit merges from DB; backup/move carry overlay | **Built** — migrate + lab verify pending |
| **D — Sideways** | WebRTC (then trunks/queues) same overlay pattern | Same acceptance as phones |
| **E — Dialplan thin + `Q*` short-run** | Remove GenAst hardcoded `Q*` Dial; `Q*` → short AGI PrepDial(queue) → Set dial var → return → dialplan `Dial(${PBX3_DIAL})`; thin stubs; call smoke | One Dial **decision** path (CAGI); `Q*` proves short-run AGI + dialplan locus |
| **F — G3 hygiene** | SBC FQDN input, clearer xlate, `$clstkey`, less shell-cp | Emit boring |
| **G — Dial locus (generalize)** | Same short-run pattern for LepDial / other dials (CAGI decides; dialplan Dial) | AGI need not idle through bridge on normal calls |

**G1 inventory** is done (§2a). Not a gate before C.

---

## 1. Intent

Treat config generation as its own work track — not a one-off “delete staged phones after tmpl change” chore. Fold the parked **phone PJSIP staging** item into this track. Keep cagi struct refactor as a parallel cleanup that must not break GenAst-emitted AGI argv / Dial forms.

```text
pjsip_phone.tmpl  --(always on get)-->  + overlay (DB pjsip_overlay preferred; file fallback)
                                              |
                                    merge by type= (replace/add keys)
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
| Phone overlays | `ipphone.pjsip_overlay` (HoR); optional file `etc/asterisk/endpoints/{shortuid}_phone.overlay.conf`. Legacy `{shortuid}_phone.conf` ignored after G2 |
| Ready outputs | `pjsip_ready_phones.conf`, webrtc/trunks, queues, `extensions*` (via Commit) |
| Characterize | [`scripts/genast-characterize.sh`](../pbx3-1/opt/pbx3/scripts/genast-characterize.sh), [`workingdocs/genast-characterize/`](genast-characterize/) |
| Ops | [`OPS_ASTERISK_AFTER_EGRESS_GENAST.md`](OPS_ASTERISK_AFTER_EGRESS_GENAST.md) — full restart vs reload |

### Out (non-goals)

- SPA panel UX (except where Commit already triggers genAst).
- Gatekeeper / directory catalog / S3 control plane.
- SBC OpenSIPS config (except **consuming** fleet edge FQDN / `outbound_proxy` as generator inputs).
- Implementing cagi Phase 1+ code in this repo (owned by pbx3cagi).

### Related parked residue (list under this track; not first coding slice)

- Hardcoded SBC FQDN in `xlatePjsipBuff` (`sip:sbc.pbx3.com`) — Phase F / G3.
- Page / `***` presets.
- Tighter OpenSIPS gate / tenant DNS ≠ VIP (edge; pointer only).
- [`TODO.md`](TODO.md) **pjsipuser for extensions** / NAT tmpl keys — fold here when touched.

---

## 2a. G1 inventory (tmpl → get/create → ready) — done

Defines live in [`config.php`](../pbx3-1/opt/pbx3/php/config.php). Commit entry: `GenClass::genAsterisk()` → private `genPjsip*` / `genQueues`.

| Domain | Template define / file | Staging path | Helper CRUD | GenClass → ready |
|--------|------------------------|--------------|-------------|------------------|
| **Phone (G2)** | `PJSIP_PHONE_TEMPLATE` → `pjsip_phone.tmpl` | Optional `ASTENDPOINTS/{shortuid}_phone.overlay.conf` (`PJSIP_PHONE_OVERLAY`). Legacy `{shortuid}_phone.conf` **ignored** after G2 | `get/create/set/move/deletePjsipPhoneInstance` | `genPjsipPhones` → `xlatePjsipBuff` → `PJSIP_READY_PHONES` |
| WebRTC | `PJSIP_WEBRTC_TEMPLATE` → `pjsip_webrtc.tmpl` | Copy-once `ASTENDPOINTS/{shortuid}_webrtc.conf` | `*PjsipWebrtcInstance` | `genPjsipWebrtc` → `PJSIP_READY_WEBRTC` — Phase D |
| Trunks | `PJSIP_TRUNK_*_TEMPLATE` (snd/rcv/trusted/egress) | Copy-once `ASTTRUNKS/{pkey}_trunk.conf` (Egress always re-copied) | `*PjsipTrunkInstance` | `genPjsipTrunks` → `PJSIP_READY_TRUNKS` — later |
| Queue | `QUEUE_TEMPLATE` → `queue.tmpl` | Copy-once `ASTQUEUES/{pkey}_queue.conf` | `create/get/setQInstance` | `genQueues` — later |
| Transport | `PJSIP_TRANSPORT_TEMPLATE` → `pjsip_transport.tmpl` | None (read tmpl each Commit) | n/a | `genPjsipTransport` → `PJSIP_TRANSPORT` |

---

## 3. Staging today (problem — pre-G2)

`HelperClass::createPjsipPhoneInstance($key)` **used to**:

- Target: `ASTENDPOINTS/{key}_phone.conf`.
- Copy `pjsip_phone.tmpl` **only if** target missing or zero-size.
- Commit path: `getPjsipPhoneInstance` → read staged file → `GenClass::xlatePjsipBuff` → `pjsip_ready_phones.conf`.

**Consequence:** tmpl rollouts did not reach existing phones until operators deleted staged files. WebRTC/trunks/queues still use that copy-once pattern until Phase D.

---

## 4. Staging target model

**Chosen default:** packaged **tmpl is source of truth for stock keys**; staged files are either absent for stock phones or hold a **thin overlay** only. Merge: **append overlay after tmpl, before xlate**.

**Acceptance (G2 phones):**

1. Change `pjsip_phone.tmpl` (e.g. add/change a stock key), Commit — **all stock phones** pick up the change **without** deleting staged files.
2. Per-phone override via `ASTENDPOINTS/{shortuid}_phone.overlay.conf` — keys replace/add on the matching `type=` object (pre-xlate); not a frozen full tmpl copy.
3. Fleet vs singleton: `$outbound_proxy` / tenant-AoR Q dials remain **fleet-gated** (`PBX3_FLEET_MODE` / active `Egress`); singleton stays direct-to-contact.
4. WebRTC (and later trunks) follow the same model once phones are proven.

### Legacy cleanup (lab / deploy)

After deploying G2: one-time delete `endpoints/*_phone.conf` (frozen copies). Stock phones need no overlay. **Do not** auto-delete in genAst.

### Commit smoke (golden)

1. Deploy pbx3 with G2; optionally remove legacy `*_phone.conf`.
2. Edit an innocuous comment or stock line in `pjsip_phone.tmpl`.
3. Commit / genAst — confirm `pjsip_ready_phones.conf` reflects the tmpl change for existing shortuids without deleting overlays.
4. Confirm fleet `$outbound_proxy` still expands via `xlatePjsipBuff` / `isFleetMode()`.

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

- Fleet dial string (authority = CAGI PrepDial): `PJSIP/{shortuid}/sip:{shortuid}@{tenant.fqdn}`.
- Singleton: `PJSIP/{shortuid}`.
- **Today:** GenAst still hardcodes that fleet form on `Q{ext}` (`GenClass` ~1217–1222). **Phase E:** same string from PrepDial(`type=queue`); dialplan `Dial(${PBX3_DIAL})` after short AGI return.
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

## 6. Phases (map to hermit-crab)

| Legacy label | Hermit phase | Owner | Work |
|--------------|--------------|-------|------|
| **G0** | — | Docs | Framing — **done** |
| **G1** | — | pbx3 | Inventory §2a — **done** |
| **G4 early** | **A** | pbx3 | Characterize normalize/diff |
| — | **B** | pbx3 | `$row` shadow fix |
| **G2** | **C** | pbx3 + pbx3api | Phone file overlay + merge + API delete — **lab OK** |
| — | **C2** | pbx3 + pbx3api + spa | DB overlay column on extension; Commit from DB |
| — | **D** | pbx3 | WebRTC / trunks overlay parity |
| dialplan | **E** | pbx3 + cagi | `Q*` short-run: PrepDial decide → dialplan Dial; thin stubs |
| **G3** | **F** | pbx3 | Hygiene |
| — | **G** | pbx3 + cagi | Generalize short-run locus to LepDial |
| **C1+** | with E/G | pbx3cagi | Struct refactor; keep §5 green |

---

## 7. Repos and commits

| Change | Repo / branch |
|--------|----------------|
| GenClass / HelperClass / templates / genAst / characterize | **pbx3** `genast-hermit` |
| Extension delete overlay / C2 API | **pbx3api** `genast-hermit` |
| C2 SPA overlay field | **pbx3spa** (`main` — shipped with C2) |
| AGI handlers / harness / PrepDial set-and-return | **pbx3cagi** (Phase E/G) |

`pbx3-master/` is not a git root — commit per repo.

---

## 8. Success criteria (framing)

- TODO treats staging as part of this sub-project, not an orphan park item.
- This doc answers: what the generator track is, how staging fits, how it relates to cagi cleanup, hermit-crab order, and what “done” looks like for each phase.
- G2: tmpl change reaches ready phones without deleting staged files; overlays stay thin; key merge replace/add.
- C2 (next): overlay text on extension row is home of record for SPA/backup/move.
- Characterize script exists before relying on feel for generator diffs.
