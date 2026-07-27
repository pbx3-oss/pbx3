# Tenant short dial requirements (per-tenant dial aliases)

**Status:** Requirements draft — design direction locked 2026-07-27; open questions in §8. **No implementation yet.**  
**Scope:** Allow an extension on tenant A to call an extension on tenant B **when allowed**, using a **dial alias** (prefix) that is **local to the calling tenant**, plus the target’s normal extension (`pkey`). Same call recipe whether B is on **this node or another** (fleet).  
**Not:** Globally unique extension numbers (SARK model — rejected). Not directory/gatekeeper in the call path (**Rule 1**). Not replacing PSTN OutRoute / Egress.  
**Related:** Fleet AoR dial (`sip:shortuid@tenant.fqdn`) · L1 `in-multi-tenant-a-b` (usrloc domain discrimination only) · legacy InterSARK / SailToSail / `DUNS_INTERSITE` OutRoute · **`CALL_TYPE_INVENTORY.md`** · **`DESIGN_RULES.md` Rule 1**.

**Naming:** *alias* and *prefix* mean the same thing here — a short digit string on the calling tenant that points at another tenant. Prefer product term **dial alias**; dialplan may still call it a prefix pattern.

---

## 1. Problem

PBX3 tenants are **namespaces**. Extension `1000` may exist on many tenants. SARK-style “dial the other site’s extension bare” worked only because extensions were **globally unique**. That mandate is gone.

Operators still need **short, memorable dialling** between related tenants (sister companies, campus buildings, MSP multi-tenant on one or many nodes) **without** caring whether the target tenant is local or remote.

**Operator mental model (locked):** on tenant A, define a local alias — e.g. alias `1234` means tenant `xyzxyz` — then dial that alias plus the remote extension.

Today’s near-misses:

| Mechanism | Gap |
|-----------|-----|
| Same-tenant LepDial / fleet AoR | Does not address *other* tenants’ `pkey`s |
| `in-multi-tenant-a-b` L1 | Proves SBC **domain discrimination** under dual REG — not short dial |
| OutRoute / INTERSITE / InterSARK trunks | Digit patterns + trunk peers; uniqueness / node-local assumptions; not a first-class tenant→tenant product |
| Dial by phone `shortuid` | Unique but **not** human short-dial UX |

---

## 2. Goals

1. **Per-tenant dial aliases** — on calling tenant only: `alias → target tenant`; dial `{alias}{extension}` (exact digit plan in §8).  
2. **Location-agnostic** — one call recipe for same-node and cross-node; no “if local then Local/ else trunk” branch in the product model.  
3. **Allow = configured** — if the alias row exists and is active on this tenant, dialling it is allowed (optional CoS refine in §8).  
4. **Rule 1** — alias table is **node-local / tenant-local**. No live directory/gatekeeper lookup at call time.  
5. **Fleet-native routing** — alias resolves to **tenant FQDN** (from target `shortuid`); place call as SIP toward that domain via SBC.  
6. **Preserve local dial** — bare `1000` still means *this* tenant’s `1000`.  
7. **Forward path from legacy** — document migrate story for InterSARK / INTERSITE patterns without requiring unique exts.

---

## 3. Locked direction

### 3.1 Product model

| Concept | Role |
|---------|------|
| **Dial alias** | Short digit string **local to the calling tenant** meaning “reach tenant T” (e.g. `1234` → `xyzxyz`). Not org-global. |
| **Alias row** | Maps **alias → target tenant** (`cluster` shortuid; FQDN derived) + active/description. Lives on the **calling tenant’s** DB. |
| **Extension** | Target tenant’s normal phone `pkey` (may collide with local numbers). |
| **Call recipe** | Always: resolve alias → FQDN → `INVITE sip:{extension}@{tenant_fqdn}` via SBC. |

**Example:** Tenant `pb0wsk` configures alias `81` → `dhbm8x`. A phone on `pb0wsk` dials `811000` → rings `1000` on `dhbm8x` (wherever that tenant is hosted). Tenant `dhbm8x` does **not** automatically get a reverse alias; it configures its own if needed (one-way OK).

```text
Phone @ tenant X
  dials  <alias> + <ext>
            │
            ▼
Tenant X DB:  alias → target shortuid / fqdn   (this tenant only)
            │
            ▼
SBC:       domain → dispatcher setid → Asterisk hosting that tenant
            │        (same instance or other — caller dialplan does not care)
            ▼
Tenant T:  inbound / internal path → LepDial(ext) → phone
```

### 3.2 Why not unique extensions again

- Collides with multi-tenant density and convert-from-diverse DBs.  
- Breaks the moment two tenants both want `1000`.  
- Dial aliases restore SARK *UX* (short digits) without SARK *constraint*.

### 3.3 Why not shortuid-as-dial-prefix

Tenant `shortuid` / FQDN remain the **routing key**. Dialling `xyzxyz1000` is possible but poor UX. The **alias** is the human handle; shortuid/FQDN stay under the hood.

### 3.4 Why always via SBC / tenant FQDN

- One recipe for co-located and remote tenants (user requirement).  
- Reuses domain → dispatcher for **extension** delivery after the SBC change in §3.6.  
- Avoids dual maintenance of Local/ vs PJSIP/ peer dial strings.  
- Singleton / non-fleet: §8 Q5 — either feature fleet-gated or a documented thinner path.

### 3.5 Relation to phone AoR (`shortuid@fqdn`)

LepDial to a **registered phone** still uses `sip:{phone_shortuid}@{fqdn}`.  
**Alias dial** uses `sip:{extension_pkey}@{fqdn}` — the target tenant’s dialplan extension, **not** the phone shortuid.  
Do **not** require the caller to know the target phone’s `shortuid`.

### 3.6 SBC routing (locked 2026-07-27)

Today OpenSIPS treats Asterisk → `user@{tenant.fqdn}` as **usrloc → phone Contact** (fleet station dial). Phones REGISTER as **shortuid**, so `sip:1000@dhbm8x.pbx3.com` **misses** usrloc and does **not** fall through to the hosting Asterisk.

| R-URI | Today | Alias dial needs |
|-------|--------|------------------|
| `sip:{shortuid}@{fqdn}` | usrloc → phone | Unchanged (station dial) |
| `sip:{ext}@{fqdn}` | usrloc miss → fail | **New:** miss → **dispatcher** for that domain |

**Locked recipe:**

```text
Asterisk (caller tenant)
  INVITE sip:{ext}@{target_fqdn}  via SBC
       │
       ▼
OpenSIPS:  lookup(location) for user@domain
       │
       ├─ hit  → RELAY to phone Contact   (existing AoR path)
       │
       └─ miss → ds_select for domain’s setid → hosting Asterisk
                 (R-URI still ext@fqdn) → tenant LepDial(ext)
```

Same-node “hairpin” back to the same Asterisk via dispatcher is **correct** for alias dial (unlike shortuid AoR, where hairpin was the bug). Cross-node is the same miss→dispatcher path to the other instance.

**Rejected for v1:** Calling node resolves `ext → shortuid` then dials existing AoR (avoids SBC change but needs remote phone maps / breaks location-agnostic simplicity).

**SBC slice is required** — not “verify only.” Keep station-dial usrloc behaviour intact; add miss→dispatcher only for this class of INVITE (from Asterisk + tenant domain + no contact).

### 3.7 Locked from operator discussion (2026-07-27)

| Decision | Lock |
|----------|------|
| Shape | Simple **alias → tenant** on the **calling tenant** |
| Naming | alias ≈ prefix — either word OK; product = **dial alias** |
| Scope | **Per calling tenant** — not a shared instance/org directory of codes |
| Reverse | Not automatic; B configures its own alias to call A back |
| SBC | **usrloc miss → dispatcher** for `ext@tenant.fqdn` from Asterisk |

---

## 4. Current / legacy baseline (do not silently break)

### 4.1 Fleet same-tenant AoR (keep)

PrepDial fleet dial string keeps tenant domain in R-URI so multi-tenant usrloc does not 404/hairpin. Covered by L1 `in-multi-tenant-a-b`.

### 4.2 InterSARK / SailToSail / INTERSITE

CAGI `OutTrunk` special-cases **InterSARK** / **SailToSail** for CLID (leave extension CLIP). GenAst emits OutRoute digit patterns (e.g. `DUNS_INTERSITE`).  

**Stance:** Treat as **legacy interconnect**. New product is **per-tenant dial aliases**, not more unique-ext assumptions. Convert/migrate guidance in §7; no requirement to keep InterSARK as the long-term UX.

### 4.3 Cos / outbound

Short dial is an **internal-ish** feature, but it still leaves the calling tenant’s Cos context via a dedicated GenAst pattern / CAGI command (name TBD). It must not accidentally match PSTN OutRoute patterns (digit-plan hygiene — §8).

---

## 5. Target shape (logical — names TBD at implement)

### 5.1 Dial alias table (calling tenant)

| Field (logical) | Purpose |
|-----------------|--------|
| `cluster` | Calling tenant (owner of this alias) |
| `alias` | Dial digits (e.g. `1234` or `81`) |
| `target_cluster` | Target tenant shortuid (e.g. `xyzxyz`) |
| `active` | Enable/disable |
| `description` | Operator label |

**Uniqueness (locked):** `alias` unique within the **calling tenant**. Different tenants may reuse the same alias digits for different targets.

### 5.2 GenAst

Emit dialplan matches from this tenant’s alias rows → CAGI (e.g. `SiteDial` / `AliasDial`) with alias + remainder (extension).

**Ordering:** Alias patterns must not steal local extensions or PSTN routes (digit-plan hygiene — §8 Q1–Q2).

### 5.3 CAGI

1. Parse DNID → alias + extension.  
2. Lookup alias row on **calling** tenant; deny if missing/inactive.  
3. Build dial string toward `sip:{ext}@{target_fqdn}` via SBC (fleet).  
4. CLID policy (§8 Q6).  
5. Post-dial / busy / VM (§8).

### 5.4 Target tenant receive path

INVITE `sip:{ext}@{fqdn}` arrives via SBC → Asterisk tenant context. Must:

- Resolve like a local station dial to that ext (LepDial path).  
- Distinguish **alias/site** vs PSTN for CoS / recording / CLIP if required (§8 Q7).  
- Not require the calling phone to be registered on the target tenant.

### 5.5 SPA / API

- Per-tenant admin: list/add/edit dial aliases (digits → target tenant picker).  
- Help: “Alias is only for this tenant. Dial alias then extension. Extensions need not be unique across tenants.”  
- Fleet console: optional later helper — **not** on the call path.

### 5.6 Provisioning / sync

- **v1:** Configure aliases on each calling tenant manually.  
- **Later:** Control-plane assisted push still writes **local** alias rows (Rule 1).

---

## 6. Non-goals (v1)

- Mandating globally unique extensions.  
- Live directory / gatekeeper / S3 lookup during dial (**Rule 1**).  
- Replacing Egress / PSTN OutRoute.  
- Dial-by-name directory, BLF across tenants, or presence federation.  
- Requiring tenant DNS to equal VIP (existing AoR residue stays separate).  
- Automatic mesh of every tenant to every other tenant.  
- Changing L1 `in-multi-tenant-a-b` meaning (that stays usrloc discrimination).

---

## 7. Legacy / SARK conversion notes

| Legacy | Guidance |
|--------|----------|
| Unique ext + bare dial | Map sister sites to **dial aliases**; keep local bare dial. |
| InterSARK / SailToSail trunks | Candidates to replace with aliases; preserve CLIP preference where operators relied on extension CLI. |
| `*_INTERSITE` OutRoute digit maps | Inventory per tenant at implement; do not auto-delete; dual-run until aliases proven. |
| Same-node multi-tenant lab | Alias dial **must** still go FQDN/SBC recipe (no Local shortcut) so convert behaviour matches fleet. |

**Acceptance for convert:** Documented operator recipe; no silent change of PSTN routes.

---

## 8. Open questions (lock before code)

| Id | Question | Status / notes |
|----|----------|----------------|
| **Q1** | Digit plan: **fixed-width** alias (e.g. 2–4 digits + ext) vs **delimiter** (`81*1000`)? | **Open** — fixed-width is phone-friendly; delimiter avoids ambiguity with variable ext lengths. |
| **Q2** | Extension length after alias: fixed, variable `_X.`, or per-alias? | **Open** — must not steal local exts / PSTN. |
| **Q3** | Alias uniqueness scope? | **Locked** — unique per **calling tenant** only. |
| **Q4** | Table ownership? | **Locked** — per calling tenant alias rows (not instance/org shared code directory). |
| **Q5** | Singleton / non-fleet nodes: feature hidden, or alternate dial without SBC? | **Open** — recommend fleet-gated v1. |
| **Q6** | CLID: always calling extension (InterSARK-like), tenant DDI, or policy per alias? | **Open** — recommend extension CLIP default. |
| **Q7** | Target trust: how does receiving tenant know “alias dial” vs carrier? | **Open** — CoS / recording / CLIP. |
| **Q8** | Deny behaviour: congestion / playback / attendant? | **Open** — keep simple for v1. |
| **Q9** | CoS: all classes on tenant, or per-class grant? | **Open** — start tenant-wide (alias exists ⇒ allowed). |
| **Q10** | Bidirectional? | **Locked** — one-way OK; reverse alias configured separately on B. |
| **Q11** | SBC: dial `ext@fqdn` vs resolve to shortuid on node? | **Locked** — `ext@fqdn` + **usrloc miss → dispatcher** (§3.6). |

---

## 9. Delivery slices (when scheduled)

Own track — do not interleave with day-parts CheckState rewrite or CAGI Phase 4. Lock §8 first.

| Slice | Repos | Operator-visible |
|-------|--------|------------------|
| **A** — schema + API + SPA dial aliases (no dial yet) | pbx3, pbx3api, pbx3spa | Admin CRUD |
| **B** — OpenSIPS usrloc-miss → dispatcher for `ext@tenant.fqdn` | **pbx3sbc** | None (lab INVITE probe) |
| **C** — GenAst pattern + CAGI AliasDial (`ext@fqdn` via SBC) | pbx3, pbx3cagi | Dial works fleet lab |
| **D** — Receive-path trust / CLIP / CoS polish | pbx3cagi, maybe sbc | Correct CLI + permissions |
| **E** — L1 recipe `site-dial-a-b` (SIPp dual catcher) | call-tests | Pack regression |
| **F** — Legacy INTERSITE / InterSARK migrate notes | docs | Operator path |

**Order note:** Slice **B** before or with **C** — without miss→dispatcher, AliasDial to `ext@fqdn` fails on today’s SBC. Do not regress station dial (`shortuid@fqdn` usrloc hit).

Lab: golden sipp ↔ affcot (or duns) with two site codes; same-node first, then bzy if up for cross-node proof of identical recipe.

---

## 10. Repo / component checklist

| Component | Change |
|-----------|--------|
| sqlite (+ Laravel migrates) | Dial alias table (per calling tenant) |
| GenAst / `GenClass` | Alias dialplan patterns |
| pbx3cagi | Parse, lookup, dial to `ext@fqdn` via SBC |
| pbx3api / pbx3spa | Dial aliases admin |
| OpenSIPS / SBC | **Required:** from-Asterisk `ext@tenant.fqdn` — usrloc hit → phone; **miss → dispatcher** (§3.6). Must not break shortuid AoR. |
| call-tests | New L1 id when B–D land |
| tt_help_core | Dial-alias help |
| DESIGN / MkDocs (later) | Operator-facing fleet page |

---

## 11. Sequencing vs other work

- **After** L1 pack confidence (302 + multi-tenant AoR done).  
- **Independent** of time-based routing §8 (different contract).  
- **Before** treating InterSARK as permanent product.  
- **Not** blocked on S10.7 / directory features (call path must not use them).  
- Park implementation until §8 answers are explicit.

---

## 12. Success criteria

1. Tenant A configures alias `NN` → tenant B shortuid; dial `NN`+`{ext}` rings B’s ext.  
2. Same dial works with B on **same** golden node and (lab) on **another** fleet node without dialplan fork (SBC miss→dispatcher).  
3. Bare local extension dial unchanged.  
4. Directory/gatekeeper down: alias dial still works from local rows.  
5. Extension number collision across tenants does not misroute (alias required).  
6. L1 (when built) covers alias dial separately from `in-multi-tenant-a-b` (usrloc only).  
7. Station dial (`shortuid@fqdn`) still usrloc→phone after the SBC change (no regression).

---

## 13. L1 / inventory pointers

| ID | Role |
|----|------|
| `in-multi-tenant-a-b` | Existing — usrloc domain discrimination (peer REG noise) |
| `site-dial-a-b` (planned) | SIPp UAC as tenant A phone dials site code + B ext → catcher on B |
| Inventory | Add/adjust major row when implement starts — keep distinct from AoR-only test |

---

## 14. Revision

| Date | Note |
|------|------|
| 2026-07-27 | Initial draft: prefix namespaces; location-agnostic SBC/FQDN recipe; Rule 1; reject unique-ext; InterSARK legacy; open §8 Q1–Q10. |
| 2026-07-27 | Operator framing: **per-tenant dial alias** (`1234` → `xyzxyz`); alias≈prefix naming; lock Q3/Q4/Q10. |
| 2026-07-27 | SBC: lock **usrloc miss → dispatcher** for `ext@tenant.fqdn` (Q11); slice B; reject node-side ext→shortuid for v1. |
