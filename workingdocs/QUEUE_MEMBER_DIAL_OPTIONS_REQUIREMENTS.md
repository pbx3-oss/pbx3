# Queue member Dial options (per queue)

**Status:** **Locked 2026-10-20** (operator confirm).  
**Supersedes park:** **`AST_CONFIG_GENERATOR_SUBPROJECT.md` §5.2.1** (was “leave `cktT` hardcoded”).  
**Related TODO:** Queue member Dial options — per queue.
---

## 1. Two different “options” layers

| Layer | Today | Owns |
|-------|--------|------|
| **Queue() flags** | SPA **Options** → `queue.options` (default `CiIknrtT`) → GenAst `Queue(name,options,…)` | How the **queue application** behaves (join announce, ring, etc.) |
| **Member Dial options** | Hardcoded in CAGI PrepDial `type=queue` as `,,cktT` | Letters on the **agent-leg** `Dial()` after answer (park, transfer, answered-elsewhere) |

This track is **only** the member Dial options layer. Do **not** overload `queue.options` for Dial letters.

Default member set today: **`cktT`**

| Letter | Role |
|--------|------|
| **`c`** | Answered-elsewhere / no missed call when Queue cancels other rings |
| **`k`** | Park (`*5` / featuremap) on agent leg |
| **`t`** | Blind transfer from callee |
| **`T`** | Attended transfer |

Timeout slot stays **empty** (Agent Ring Timeout / `queue.timeout` owns ring duration). Recording letters stay **out** (ghost recordings on queue dial-legs).

---

## 2. Product goals (locked intent)

1. **Per-queue** control of member Dial letters (not instance-global hardcode).
2. **SPA/API expose** curated controls — operator can clear **`c`** (or other allowlisted letters) when a site wants that.
3. **Filter / allowlist** — never free-text Dial options (arity footgun, timeout fight, ghost `x`/`X`/`w` recordings).
4. **Future letters without routine CAGI rebuild** — new toggles that are already in CAGI’s character allowlist = **API + SPA only**.

---

## 3. Allowlist model (no free text)

### 3.1 Product allowlist (API + SPA)

- Single source of truth for UX: e.g. pbx3api constant / config list of `{ letter, label, help, default_on }`.
- SPA renders **toggles** (or equivalent) for that list only; compose a sorted/canonical string for storage.
- API **rejects** create/update if any character is outside the product allowlist (422).
- **v1 product allowlist (locked):** `c`, `k`, `t`, `T` only. Default all **on** → stored `cktT`.
- Expanding later (e.g. add `r` for ring) = ship API+SPA allowlist entry; no CAGI change if letter already in CAGI charset (§3.2).

### 3.2 CAGI character ceiling (defense + forward room)

- CAGI does **not** hardcode `cktT` as the only legal set.
- On PrepDial queue path: load per-queue string from DB; **strip any char not in `PBX3_QUEUE_DIAL_OPT_CHARS`** (compile-time string, documented).
- **CAGI ceiling (locked intent):** wider than v1 UX — documented Asterisk Dial-option subset that **excludes** recording/`w`/`x`/`X` and digits/commas. Exact charset chosen at implement time; **must include at least `cktT`**.
- Empty / missing / all-stripped after filter → **default `cktT`** (safe for existing queues; blank must not silently remove park/`c`).
- Adding a letter **outside** the CAGI ceiling still needs a cagi bump (rare). Adding inside ceiling = SPA/API only.

### 3.3 Storage

- New tenant column e.g. **`queue.member_dial_opts`** TEXT (name TBD), default **`cktT`** (or NULL → treat as default).
- Do **not** reuse `queue.options`.
- Migrate / seed: existing rows NULL → runtime default `cktT` (no mass rewrite required).

---

## 4. Per-queue identity (required)

Shared `Q{ext}` cannot infer queue from the extension alone.

**Locked approach** (from prior §5.2.1 analysis, Asterisk 20):

1. GenAst, on queue extension, immediately before `Queue()`: `Set(_PBX3_QUEUE_SUID={queue shortuid})`.
2. `app_queue` copies `_`-prefixed vars onto the Local member leg.
3. PrepDial reads `PBX3_QUEUE_SUID`, loads that queue’s `member_dial_opts`, applies §3.2 filter.
4. Missing variable → default `cktT`.

PSTN / non-PrepDial members remain a separate path (out of scope unless later specified).

---

## 5. SPA / API UX

- Queue create/edit: section **Member Dial options** (name TBD), distinct from **Options** (Queue flags).
- Curated toggles bound to product allowlist; show short help per letter (`c` = missed-call hygiene, etc.).
- Read/write via existing queue CRUD; validation on API.
- MkDocs: one short note — Queue Options vs Member Dial options; default `cktT`; when to drop `c`.

---

## 6. Non-goals

- Free-text Dial option field.
- Changing Agent Ring Timeout via this string.
- Recording letters on member Dial.
- Replacing Queue() `options` panel.
- Fleet/Gatekeeper involvement.

---

## 7. Implementation order (sketch)

1. Lock §3 allowlists (v1 UX letters + CAGI ceiling charset).
2. Schema `member_dial_opts` + API validate + SPA toggles.
3. GenAst `_PBX3_QUEUE_SUID` + CAGI PrepDial load/filter/default.
4. Harness: default `cktT`; queue with `ktT` (no `c`) → options string without `c`; missing suid → default.
5. Lab: park + missed-call with default; desk with `c` off if operator cares.
6. Package: **pbx3** (GenAst) + **pbx3cagi** + **pbx3api** + **pbx3spa** as needed.

---

## 8. Lock checklist (accepted 2026-10-20)

1. Curated toggles + API allowlist; **not** free text; separate from Queue() Options.
2. Default **`cktT`**; blank/null → default (never silent empty).
3. Per-queue via **`_PBX3_QUEUE_SUID`** as above.
4. **v1 letters** = `c`/`k`/`t`/`T` only; CAGI ceiling wider so future UX letters often need no cagi rebuild.
5. Dropping **`c`** is a supported operator choice.
