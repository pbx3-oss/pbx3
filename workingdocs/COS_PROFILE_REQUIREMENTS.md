# CoS profiles requirements (named class of service)

**Status:** **Shipped on `main` 2026-09-27** — Slices A–F + Q6. Package floor **pbx3 0.0.6-8** (cagi unchanged **1.0.0-22**).  
**Scope:** Tenant outbound **deny** CoS — assignment model + GenAst dialplan shape. Repos: **pbx3**, **pbx3api**, **pbx3spa**, **private offline migrate tool**, **pbx3-docs**.  
**Not:** CAGI, SBC / Gatekeeper, per-mode (lunch) CoS matrices, allow-list OutRoutes as CoS, Follow-me, velocity (stays detection/act).  
**Related:** **`TIME_BASED_ROUTING_REQUIREMENTS.md`** §5.10 / Q8 (binary CoS cue) · **`HIGH_RISK_DIAL_BLOCK_POSTURE.md`** · **`AST_CONFIG_GENERATOR_SUBPROJECT.md`** (O(phones) CoS debt) · SPA backlog **`pbx3spa/workingdocs/LEGACY_PBX_PANEL_BACKLOG.md`** · private audit **`~/GiT/pbx3-ops/devdocs/pbx3api/workingdocs/COS_AUDIT_PROTOTYPE.md`**.

**Lab hosts**

| Host | Use |
|------|-----|
| **Golden** (`08jzwn`) | Primary Commit / dial prove |
| **bzy54n / VirginiaOne / singleton** | Package floor when rolling |
| **SBC** | Out of scope |

**Git / way back (locked)**

| Rule | Detail |
|------|--------|
| Feature branch | **`cos-profiles`** merged to **`main`** (2026-09-27) |
| Escape hatch | Was drop-branch before F; **closed** after accept |
| Explicitly rejected | Dual GenAst engine (`cos_engine=legacy\|profiles`), long-lived dual-emit, or “keep both forever” |

**Testing rule:** Unit/offline fixtures with each schema/GenAst slice; golden dial smoke before merge. A slice is not done on “worked once.”

---

## 1. Problem

Today CoS **works** but is brutal:

1. **GenAst emits ~3 contexts per phone** (`…opencos`, `…closedcos`, `…Cosend`) — O(phones), flagged as debt in the Ast config generator track.  
2. **Assignment UX** is a per-phone checkbox matrix × Standard / After-hours × N deny rules. Operators think in **roles** (Staff / Lobby / Restricted), not N×M ticks.  
3. **Three attachment knobs** — rule `default*`, rule `oride*` (GenAst-only, no junction backfill), and junction rows — easy for SPA to diverge from Commit. Profiles collapse assignment to **profile lists + optional Tenant-wide**.  
4. **Dispatcher `[COS_$clst]`** routes via `CALLERID(num)` into per-phone contexts and heavy `_X.` matching — fragile if CLIP ≠ extension pkey.  
5. **Naming** — “class of service” sounds like a privilege class; the `cos` table is really a **deny pack**, and the phone’s privilege is the **set** of packs.

**Keep as strengths**

- Deny-pattern packs → congestion/Hangup (previous PBX muscle memory; high-risk prevention HoR).  
- **Time-aware privilege** — Standard vs After-hours (day-parts Q8 cue) — see **§1.1**.  
- `globals.cosstart` master on/off.  
- Feature / emergency / park retrieve bypass CoS into the tenant context.

### 1.1 Why CoS is time-dependent (do not “simplify away”)

**previous PBX heritage:** Early CoS users needed to **throttle the PBX out of hours**. PBX/SIP credential abuse was (and remains) common; quiet buildings + compromised endpoints + international/premium routes = large fraud bills. Open vs closed CoS matrices existed so the **same extension** could dial more freely in business hours and be locked down after hours (e.g. **no international out of hours**) without re-provisioning the phone.

**Still a first-class need:** Detection (velocity, Fail2ban) helps; **prevention** still wants clock-gated privilege. Big-iron / CUCM express the same idea as COR/CSS × time-of-day overlays. Teams mostly schedules **inbound** only — our outbound deny layer must stay time-aware.

**For implementers / future agents**

| Do | Do not |
|----|--------|
| Keep **two privilege intensities** per profile (Standard / After-hours) in v1 | Collapse to a single rule list and drop After-hours “to simplify” |
| Treat After-hours as **stricter outbound** for fraud/cost | Confuse After-hours CoS with inbound lunch/evening **destinations** (day-parts) |
| Keep binary cue from site STATE as v1 clock (Q8) | Assume OPEN/CLOSED means the schedule type system has only two modes |
| Plan later “night-like modes” without losing after-hours lockdown | Ship per-mode (lunch) CoS matrices unless a real shop demands it |

Related prevention: **`HIGH_RISK_DIAL_BLOCK_POSTURE.md`** (always-on packs / Tenant-wide) complements After-hours lists; it does not replace them.

---

## 2. Current behaviour (baseline)

### 2.1 Data

| Table / flag | Role |
|--------------|------|
| **`cos`** | Deny pack: `dialplan` patterns; `defaultopen`/`defaultclosed`; `orideopen`/`orideclosed` |
| **`ipphonecosopen` / `ipphonecosclosed`** | Per-extension rule membership (Standard / After-hours) |
| **`globals.cosstart`** | `ON` → emit CoS; `OFF` → skip |

### 2.2 Call path

```text
PJSIP context=COS_$clst
  → feature / emergency / park / long CALLERID → tenant context
  → else STATE CLOSED → {clst}{ext}closedcos
  → else → {clst}{ext}opencos
       → include deny rule contexts (+ overrides)
       → Cosend → Goto(tenant,${EXTEN},1)
```

Phones land in `COS_$clst` via `pjsip_phone.tmpl` (`context=COS_$clst`).

### 2.3 High-risk seed

**`HIGH_RISK_DIAL_BLOCK_POSTURE.md`:** seeded `HR_*` rules with `defaultopen`/`defaultclosed=YES`. Under profiles (**Slice C done** — `SeedCosHighRiskOnTenantCreate`):

1. Attach `HR_*` to the **tenant default profile** (visible in normal profile edit).  
2. Set **Tenant-wide = ON** for Standard and After-hours on those rules (so an “Unrestricted” profile cannot omit them while Tenant-wide is ON).  
3. Operator can still clear Tenant-wide or narrow/delete the rule — that is intentional and must be obvious in UI/help.

---

## 3. Goals

1. **Named CoS profiles** as the assignment HoR (one profile per extension).  
2. **GenAst O(profiles)**, not O(phones).  
3. Keep **deny-rule atoms** (`cos` table) and **time-aware** Standard / After-hours (§1.1) — not a single timeless list.  
4. **Forward-convert** existing junction matrices without silent dial-privilege change.  
5. **previous-PBX migrate** path: same convert after 1:1 junction copy.  
6. **Branch-drop** escape — no dual-path product debt.  
7. Test with the code (§10).

---

## 4. Locked product model

### 4.1 Vocabulary (meanings must stay obvious in SPA)

| Term | Meaning (operator-facing) | Today’s analogue |
|------|---------------------------|------------------|
| **CoS rule** | A deny pack: patterns that get congestion | `cos` row |
| **CoS profile** | A named phone class (Staff / Lobby / …) with its own Standard + After-hours rule lists | New — replaces per-phone junction as HoR |
| **Standard / After-hours** | Which of the profile’s two lists applies right now | Was open/closed matrix; cue still STATE |
| **Default profile** | Fixed per-tenant profile **new extensions** get; edit its lists to change default policy | Convert/seed `is_default=YES` row — not a movable flag |
| **Tenant-wide** | When ON for a rule: GenAst also includes that rule on **every** profile (Standard and/or After-hours as flagged) | `orideopen` / `orideclosed` — **not** labelled Override/Mandatory in SPA |

SPA labels stay **Standard** / **After-hours** (not “open/closed” — lunch is inbound-closed-ish but still Standard CoS). See day-parts §5.10.

**Do not** use SPA labels **Override** or **Mandatory** — both mislead (previous PBX heritage / false absolutism). Column names may stay `oride*` in DB until a later rename; product copy = **Tenant-wide**.

### 4.1.1 Two knobs — do not conflate

| Knob | Answers | Who can “escape”? |
|------|---------|-------------------|
| **Profile membership** | May phones **on this profile** hit this deny? | Put the phone on another profile, or edit this profile’s lists |
| **Tenant-wide** (per rule, per side) | Should **every** profile get this deny at Commit? | Only the **operator** — turn Tenant-wide OFF, or edit/delete the rule. Phones/profiles cannot opt out while it is ON |

**Default profile ≠ Tenant-wide.**  
Default profile = **fixed** inheritance slot for **new phones** (and blank `cos_profile` at GenAst) — edit that profile’s lists to change default policy.  
Tenant-wide = optional **all-profiles** include at GenAst.

**Defaults:** Tenant-wide **OFF** on SPA create (previous PBX defaulted Override ON — **rejected** for pbx3). High-risk seed is the exception that turns Tenant-wide **ON** for `HR_*` (§2.3).

**Lab check:** If operators confuse the two knobs in Slice D, fix copy/layout before merge — wrong mental model = wrong dial policy.

### 4.2 Extension

- Exactly **one** `cos_profile` reference (tenant-scoped).  
- No dual matrix as primary UX after Slice D.  
- Empty / missing profile on a phone when `cosstart=ON`: treat as **tenant default profile** at GenAst (or refuse Commit with a clear error — lock in implement: **prefer default fallback** so previous PBX convert one-offs never black-hole).

### 4.3 Profile contents

Each profile holds:

- Identity: `id`, `shortuid`, `pkey` (Asterisk-safe; unique per cluster), `cname`, `description`, `active`, `cluster`.  
- **Standard** set: ordered/set of `cos` rule pkeys.  
- **After-hours** set: same.

Junction shape (illustrative — exact table names at implement):

- `cos_profile`  
- `cos_profile_open` / `cos_profile_closed` — `(cluster, profile_pkey, cos_pkey)`  
- `ipphone.cos_profile` — profile pkey (or shortuid; store consistently with other FKs = **shortuid or pkey — prefer pkey** to match rule junctions today)

### 4.4 Rules panel

- CRUD deny packs (`dialplan` required).  
- **Tenant-wide** toggles (map to `orideopen` / `orideclosed`): when YES, GenAst includes that rule on **all profiles** for that side. No requirement to backfill profile junction rows (GenAst-only include — same mechanics as today’s override).  
- Help text (required): e.g. *“When on, this deny applies to every CoS profile at Commit — not only profiles that list the rule. Turn off to allow a profile to omit it.”*  
- **`defaultopen` / `defaultclosed`:** demoted. Convert / high-risk seed input only for building the default profile’s lists. Hide or read-only after Slice D — do not keep a third “default” path beside Default profile.

### 4.5 Tenant default profile (**fixed** — Q6)

- Exactly **one** Default profile per tenant (`is_default=YES`, unique per cluster).  
- That row is **durable**: evolve tenant default policy by **editing its Standard / After-hours lists**, not by electing a different profile as default.  
- **Do not** move the default flag between profiles in SPA (no “make this the Default” toggle). Convert / tenant seed / empty-tenant bootstrap may create the initial Default; operators do not re-point it.  
- New extension (create with “Tenant default”) → assign that fixed Default’s pkey.  
- Existing phones keep their stored `cos_profile`; changing Default’s **lists** changes dial rights for everyone still on that profile (including phones left on convert’s Migrated/Default). Renaming the Default’s **display name** is fine; deleting the Default profile is **forbidden**.  
- Other profiles (Staff / Restricted / …) are explicit classes only.

### 4.6 GenAst / PJSIP shape

```text
PJSIP context = COS_{clst}_{profile_pkey}

[COS_{clst}_{profile_pkey}]
  include → shared bypass (features / emergency / park slots)
  _X. → read STATE → Goto open or closed profile context

[COS_{clst}_{profile_pkey}_open]
  include tenant-wide Standard rules (orideopen=YES)
  include this profile’s Standard rules
  include → …_end

[COS_{clst}_{profile_pkey}_closed]
  include tenant-wide After-hours rules (orideclosed=YES)
  include this profile’s After-hours rules
  include → …_end

[COS_{clst}_{profile_pkey}_end]
  _X. → Goto({clst},${EXTEN},1)

[rule_pkey]   ; unchanged deny contexts
  patterns → Playtones(congestion) + Hangup
```

| Requirement | Detail |
|-------------|--------|
| Context count | O(profiles × ~3) + O(rules) + shared bypass per tenant (or one bypass include reused) |
| No per-phone Cosend | Retired |
| No `CALLERID(num)` dispatch into per-phone CoS | Phone’s PJSIP `context=` *is* the profile |
| `cosstart=OFF` | Phones use tenant context directly (or omit CoS includes — match today’s OFF behaviour) |
| Park / `*X.` / emergency | Still bypass deny filters into tenant context |
| Tmpl | `pjsip_phone.tmpl` / WebRTC: `context=COS_$clst_$cos_profile` (overlay may still override) |

### 4.7 Binary cue (reaffirm Q8) — clock for time-aware CoS

After-hours lists exist for **out-of-hours outbound throttle** (§1.1), not because inbound only has two modes. v1 reuses site STATE as the clock:

| Schedule / force | CoS set |
|------------------|---------|
| `STATE == CLOSED` (incl. master/tenant force CLOSED) | After-hours (`*_closed`) — typically **stricter** (e.g. block intl) |
| Else (open and non-closed day-parts, including lunch) | Standard (`*_open`) |

**Rejected:** per-mode CoS matrices (lunch column, etc.). Lunch may still use **Standard** dial rights while inbound uses a lunch destination — different jobs.

**Future (not v1):** replace binary CLOSED cue with an explicit **night-like modes** list without dropping two privilege intensities — see staged path toward single-set profile + night policy only after a lossless bridge.

---

## 5. Convert / migrate

### 5.1 Existing pbx3 DBs (Slice A)

Idempotent convert:

1. For each phone, fingerprint `(sorted open cos_pkeys, sorted closed cos_pkeys)`.  
2. For each distinct fingerprint in a tenant, create a profile (`pkey` e.g. `mig-{short hash}` or sequential `class1`…; `cname` e.g. `Migrated (N phones)`).  
3. Attach rule sets to that profile.  
4. Set `ipphone.cos_profile`.  
5. Build **tenant default profile**:  
   - Prefer fingerprint matching the set of rules with `defaultopen`/`defaultclosed=YES` if that fingerprint exists; else most common fingerprint; else empty “Unrestricted” profile.  
6. Mark default.  
7. Leave `ipphonecos*` rows in place (read-only / ignored by GenAst once profiles are authoritative).

**Behaviour:** Same denies open vs closed as before convert (modulo Tenant-wide / `oride*`, which already was GenAst-global).

### 5.2 previous PBX ETL (`private offline migrate tool`, Slice E)

1. Keep today’s 1:1 copy of `cos` + `ipphonecosopen` / `ipphonecosclosed`.  
2. Run the **same fingerprint → profile** pass (shared script or duplicated logic with fixture tests).  
3. Do not require operators to hand-build profiles before first Commit.

### 5.3 One-off / rare fingerprints

A profile with a single member is valid. Operator may rename/merge profiles later (merge is **optional polish**, not v1 must-have).

---

## 6. SPA / API surface

| Surface | Behaviour |
|---------|-----------|
| **Rules** | Deny-pack CRUD; **Tenant-wide** (Standard / After-hours); dialplan; active. No “Override” / “Mandatory” labels |
| **Profiles** (new) | List/create/edit: Standard + After-hours rule multi-select; **Default** is fixed (badge only — edit lists to change default policy); active |
| **Extension** | Single **Profile** dropdown (cname); no dual checkbox matrix as primary |
| **Instance globals** | `cosstart` unchanged |
| **Nav** | Prefer split: **CoS rules** + **CoS profiles** (crystal clear) |

API: Profile CRUD under a dedicated resource (e.g. `cosprofiles`); extension field on show/update; deprecate matrix `GET/PUT extensions/{id}/cos` after SPA cutover (may remain read-only for lab).

---

## 7. Delivery slices

Do **not** mix with Follow-me, CAGI Phase 4, or other dial-locus rewrites.

| Slice | Repos | Operator-visible | Done when |
|-------|--------|------------------|-----------|
| **0** — requirements accepted | — | — | **Done 2026-09-27** |
| **A** — schema + idempotent convert | pbx3, pbx3api (schema reg) | None if GenAst still legacy until B | **Done 2026-09-27** — `apply/convert-cos-profiles` + fixture `scripts/tests/convert-cos-profiles-test.sh` |
| **B** — GenAst + PJSIP context | pbx3 | Commit dialplan shape | **Done 2026-09-27** (offline fixture + **golden smoke**). 70→6 CoS contexts; Staff `prohibited`≠Unrestricted; floor HR on Unrestricted; park/999 bypass; `cosstart` OFF→tenant context. CLOSED GotoIf present (open/closed lists same on lab fingerprints). |
| **C** — API + seed | pbx3api | — | **Done 2026-09-27** — `cosprofiles` CRUD; extension `cos_profile`; HR_* → default profile + floor ON; feature/unit tests |
| **D** — SPA Profiles + extension dropdown | pbx3spa | New UX | **Done 2026-09-27** (+ follow-ups pending commit: Tenant-wide label; rule Key on create; extension **create** profile; create dirty-flag fix) |
| **E** — ETL + docs | private offline migrate tool, pbx3-docs | Migrate / MkDocs | **Done 2026-09-27** — overlay + convert hook; MkDocs; fixture smoke on `~/Backups/{wdcvs,regal,pdh4s03}` (parity 0 mismatches) |
| **F** — merge gate | all | — | **Done 2026-09-27** — accepted; merged **`cos-profiles`** → **`main`**; package **0.0.6-8** |

**Suggested code order:** A → B (call path) → C → D → lab → E → F.

---

## 8. Decisions (locked unless amended)

| # | Topic | Decision |
|---|--------|----------|
| **Q1** | Assignment HoR | **CoS profile** (one per extension) |
| **Q2** | Rule atoms | Keep **`cos` deny packs**; patterns → congestion |
| **Q3** | Open vs closed | **Binary** Standard / After-hours from STATE (day-parts Q8) — **time-aware privilege required** (§1.1); not optional polish |
| **Q4** | Escape hatch | **Feature branch only** — no dual GenAst engine |
| **Q5** | Tenant-wide | Keep **`oride*`** mechanics: when ON, GenAst includes rule on **all** profiles for that side. SPA label **Tenant-wide** only — not Override/Mandatory |
| **Q6** | Default profile | **One fixed Default profile** per tenant. Evolve by editing its rule lists. **No** SPA/API reassignment of `is_default` between profiles (bootstrap/convert/seed only). Cannot delete the Default |
| **Q7** | Missing profile | GenAst falls back to **default profile** |
| **Q8** | Junction tables | Keep through track; GenAst ignores once profiles authoritative; drop only after merge confidence (optional later) |
| **Q9** | previous PBX | Junction copy + **same fingerprint convert** |
| **Q10** | CAGI / SBC | **Out of scope** |
| **Q11** | Lab | **Golden only** until F |
| **Q12** | Branch name | **`cos-profiles`** |
| **Q13** | Tenant-wide default | **OFF** on SPA create (reject previous PBX Override default ON). High-risk seed sets Tenant-wide **ON** for `HR_*` |
| **Q14** | Clarity gate | If Slice D lab shows people mixing Default profile with Tenant-wide, fix UX/copy before merge — do not ship confusing labels |

---

## 9. Success criteria

1. Operator assigns **Staff** vs **Restricted** via profile dropdown; dial privileges differ as configured.  
2. Commit dialplan context count scales with **profiles**, not phone count.  
3. Converted golden (or fixture): privileges match pre-convert junction matrices.  
4. High-risk seed: default-profile phones blocked; Unrestricted profile **also** blocked while Tenant-wide is ON; clearing Tenant-wide or the rule restores opt-out.  
5. Park retrieve, feature codes, emergency still bypass CoS.  
6. Operators can state in one sentence what Default profile vs Tenant-wide do (Q14).  
7. Disliked lab → branches dropped; **0.0.6-7** / **1.0.0-22** package floor untouched.

---

## 10. Testing (mandatory)

| Layer | When | Examples |
|-------|------|----------|
| **Convert unit** | Slice **A** (same PR as schema) | Same open/closed sets → one profile; different → two; empty → unrestricted/default; `oride*` not in fingerprint; idempotent re-run; default-profile pick order |
| **GenAst offline** | Slice **B** before golden dial | N phones / 2 profiles → ~O(profiles) CoS blocks; PJSIP `context=COS_{clst}_{profile}`; floor includes; bypass; `cosstart` OFF |
| **API** | Slice **C** | Profile CRUD; extension assign; default unique; HR_* on default profile + floor ON; new ext → default |
| **Golden dial** | Slice **B**/ **F** smoke (not first emit proof) | Staff≠Restricted; floor-on Unrestricted; force CLOSED → After-hours; park/`*5`/emergency; `cosstart` OFF |
| **previous-PBX migrate** | Slice **E** (same convert as A) | **Done 2026-09-27** offline on operator samples `~/Backups/{wdcvs,regal,pdh4s03}` — 0 junction↔profile mismatches; regal 4 fingerprints / 32 phones; empty-CoS → Unrestricted. Smoke: private offline migrate tool `scripts/tests/cos-profiles-migrate-smoke.sh` |

**Not in v1:** sipplab CoS pack; dual GenAst engine compare; SPA E2E for Tenant-wide.

---

## 11. Out of scope / rejected

- Per-day-part CoS matrices.  
- Dropping After-hours / time-aware CoS “to simplify” (§1.1).  
- AGI CheckCos every outbound dial as primary design.  
- Allow-list OutRoute as replacement for deny CoS.  
- Fleet/SBC never-route as CoS substitute (already deferred in high-risk posture).  
- Auto-merge of migrated profile names into pretty “Staff/Lobby” without operator edit.  
- Package floor bump before Slice F acceptance.

---

## 12. Changelog

| Date | Note |
|------|------|
| 2026-09-27 | Initial lock for operator review — profiles HoR, branch-drop escape, slices A–F, previous PBX fingerprint post-pass. |
| 2026-09-27 | **Tenant-wide** naming (not Override/Mandatory); default OFF; ≠ Default profile; HR_* seed = default profile + Tenant-wide ON; Q13–Q14 clarity gate. |
| 2026-09-27 | §1.1 — CoS is **time-dependent** (out-of-hours toll-fraud throttle); After-hours required; do not simplify away. |
| 2026-09-27 | **Accepted** — implement on **`cos-profiles`**; Slice 0 done. SPA label may change after first-out UX. |
| 2026-09-27 | §10 — per-slice test cadence; previous-PBX migrate fixtures via operator samples on request (Slice E). |
| 2026-09-27 | **Slice A done** — schema + convert + fixture; GenAst still junctions until B. |
| 2026-09-27 | **Slice B done** — GenAst O(profiles) + `$cos_context` PJSIP; fixture `genclass-cos-profiles-test.php`. Golden dial smoke still gate for F. |
| 2026-09-27 | **Slice C done** — CosProfile API + Extension assign/default; HR_* seed attaches default profile + Tenant-wide ON. |
| 2026-09-27 | **Slice D done** — SPA CoS profiles + extension profile dropdown; rules/nav Tenant-wide wording. |
| 2026-09-27 | **Slice E done** — private offline migrate tool overlay + convert post-pass; pbx3-docs CoS rules/profiles. Fixture migrate awaits operator previous PBX samples. |
| 2026-09-27 | **Slice E fixture** — offline migrate+convert on `~/Backups/wdcvs` (Unrestricted), `regal` (4 profiles / parity OK), `pdh4s03` (per-tenant Unrestricted). Smoke script in private offline migrate tool. |
| 2026-09-27 | **Slice F lab (Aelintra)** — profiles Staff/`20hq48`, Restricted/`p67y3v`, UnrestrictedLab/`bfdjzc`; phones **491–493**; rule `LAB_INTL` `_00.`; `HR_UK070` Tenant-wide ON. Dialplan+CLI: Staff≠Restricted intl; Tenant-wide 070 on empty UnrestrictedLab; CLOSED→After-hours LAB_INTL vs OPEN Cosend; park/999/`*_X.` bypass. Backup `/opt/pbx3/bkup/cos-lab-f-*`. **Note:** GenAst `oride*` is pkey-global (other tenants’ Tenant-wide can still `include` same rule pkey). **Await operator accept (Q14).** |
| 2026-09-27 | **SPA label lock:** **Tenant-wide** (was “Tenant floor”) — clearer for operators; DB `oride*` unchanged. |
| 2026-09-27 | **Slice F desk (Aelintra):** HR intl CoS OK; `PREMIUM_0900` Tenant-wide ON → congestion before OutRoute. |
| 2026-09-27 | **Committed on `cos-profiles`:** (1) SPA **Tenant-wide** + CoS rules layout; (2) CoS rule **Key** on create; (3) Extension create CoS profile + API `cos_profile`; (4) Create panels `beginHydrate`/`markClean` (PANEL_PATTERN); (5) **Q6 fixed Default**. MkDocs timers-cos / api reference.
| 2026-09-27 | **Q6 amended** — Default profile is **fixed** per tenant (edit lists in place). Moving the default flag between profiles rejected (operator confusion / lost “what was default”). |
| 2026-09-27 | **Accepted + merged** — **`cos-profiles`** → **`main`** (pbx3 / api / spa / docs / private offline migrate tool); package **pbx3 0.0.6-8**. |
