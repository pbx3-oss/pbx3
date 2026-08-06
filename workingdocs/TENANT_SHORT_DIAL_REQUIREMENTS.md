# Tenant short dial requirements (per-tenant dial prefixes)

**Status:** Requirements locked 2026-07-27. **A–C + E L1 lab green** (2026-08-04) and **merged to `main`**. **D product-locked option A** (2026-08-05): our-SBC shortuid usrloc repair — see **§3.9.1**; implement on branch `slice-d-shortuid-usrloc-repair`. **E** pack-gate planned, not executed. **F** migrate recipe shipped — **`DIAL_PREFIX_LEGACY_MIGRATE.md`**.  
**Scope:** Allow an extension on tenant A to call an extension on tenant B **when allowed**, using a **dial prefix** that is **local to the calling tenant**, plus the target’s normal extension (`pkey`). Same call recipe whether B is on **this node or another** (fleet).  
**Not:** Globally unique extension numbers (SARK model — rejected). Not directory/gatekeeper in the call path (**Rule 1**). Not replacing PSTN OutRoute / Egress.  
**Related:** Fleet AoR dial (`sip:shortuid@tenant.fqdn`) · L1 `in-multi-tenant-a-b` (usrloc domain discrimination only) · legacy InterSARK / SailToSail / `DUNS_INTERSITE` OutRoute · **`CALL_TYPE_INVENTORY.md`** · **`DESIGN_RULES.md` Rule 1**.

**Naming (locked 2026-08-03):** Product term is **dial prefix** (or **prefix**). Historical workingdocs / some code may still say *alias* — same concept. Prefer **prefix** in UI, help, and new docs. Schema/API resource names (`dialalias`, `dialaliases`) may lag as implementation identifiers until a rename pass.

---

## 1. Problem

PBX3 tenants are **namespaces**. Extension `1000` may exist on many tenants. SARK-style “dial the other site’s extension bare” worked only because extensions were **globally unique**. That mandate is gone.

Operators still need **short, memorable dialling** between related tenants (sister companies, campus buildings, MSP multi-tenant on one or many nodes) **without** caring whether the target tenant is local or remote.

**Operator mental model (locked):** on tenant A, define a local **prefix** — e.g. prefix `81` means tenant site `dhbm8x.pbx3.com` — then dial that prefix plus the remote extension.

Today’s near-misses:

| Mechanism | Gap |
|-----------|-----|
| Same-tenant LepDial / fleet AoR | Does not address *other* tenants’ `pkey`s |
| `in-multi-tenant-a-b` L1 | Proves SBC **domain discrimination** under dual REG — not short dial |
| OutRoute / INTERSITE / InterSARK trunks | Digit patterns + trunk peers; uniqueness / node-local assumptions; not a first-class tenant→tenant product |
| Dial by phone `shortuid` | Unique but **not** human short-dial UX |

---

## 2. Goals

1. **Per-tenant dial prefixes** — on calling tenant only: `prefix → target tenant FQDN`; dial `{prefix}{extension}` (digit plan §3.8).  
2. **Location-agnostic (v1)** — one SBC/FQDN recipe for same-node and cross-node (deferred Local shortcut in §15). **Primary real-world use = sister sites on different nodes** (Q14).  
3. **Allow = configured** — active prefix row on this tenant ⇒ allowed for all CoS classes (v1).  
4. **Rule 1** — prefix table is **node-local / tenant-local**. No live directory/gatekeeper lookup at call time.  
5. **Fleet-native routing** — prefix row's **target is the tenant FQDN** (e.g. `dhbm8x.pbx3.com`); place call as `sip:{ext}@{target_fqdn}` via SBC. Do **not** require the target to exist in this node’s `cluster` table. Shortuid (if stored) is **label / optional key only**, not the dial target.  
6. **Preserve local dial** — bare `1000` still means *this* tenant’s `1000`.  
7. **Forward path from legacy** — document migrate story for InterSARK / INTERSITE patterns without requiring unique exts.  
8. **Return-call** — CallerID num is returnable AoR (`suid@fqdn`); CallerID name carries human detail (§3.9).

---

## 3. Locked direction

### 3.1 Product model

| Concept | Role |
|---------|------|
| **Dial prefix** | Short digit string **local to the calling tenant** meaning “reach that tenant FQDN” (e.g. `81` → `dhbm8x.pbx3.com`). Not org-global. Product name: **prefix** (not “alias”). |
| **Prefix row** | Maps **prefix → tenant FQDN** (required) + optional shortuid label; active/description. Lives on the **calling tenant’s** DB. Never store instance FQDN as target. |
| **Extension** | Target tenant’s normal phone `pkey` (may collide with local numbers). |
| **Call recipe (v1)** | Always: read prefix row → `INVITE sip:{extension}@{target_fqdn}` via SBC. |

**Example:** Tenant `pb0wsk` on **node A** configures prefix `81` → **`dhbm8x.pbx3.com`** (tenant live on **node B**). A phone on `pb0wsk` dials `811000` → rings `1000` on that FQDN’s host. Reverse prefix is not automatic.

```text
Phone @ tenant X (any node)
  dials  <prefix> + <ext>
            │
            ▼
Tenant X DB on this node:  prefix → target FQDN   (local row only — Rule 1)
            │
            ▼
SBC:       domain → dispatcher setid → Asterisk hosting that tenant FQDN
            │        (same instance or other — caller dialplan does not care)
            ▼
Tenant T:  inbound / internal path → LepDial(ext) → phone
```

### 3.1.1 Cross-node sister sites (locked 2026-08-03 — Q14)

| Topic | Lock |
|-------|------|
| **Primary case** | Sister / related sites almost always sit on **different fleet nodes** in production. Intra-node multi-tenant is secondary. |
| **Target identity** | **Tenant FQDN only** (e.g. `dhbm8x.pbx3.com`) — the SIP domain of that tenant. **Not** the instance / node FQDN (e.g. `08jzwn.pbx3.com`, `kildare.pbx3.com`). Instance host is for ops/API; short dial R-URI is always `{ext}@{tenant_fqdn}`. |
| **Always full FQDN** | Store complete tenant FQDN on the row. Dial uses that string only (Rule 1 — no live expand). |
| **Tenant move (new host, same FQDN)** | Prefix row **unchanged**. Home changes under the domain on the SBC (dispatcher); short dial keeps working. No rewrite, no BG expand. |
| **Tenant FQDN rename** | Prefix row `target_fqdn` goes stale until operator re-saves or a later reconcile job rewrites it. **Not** dial-path. Optional future `target_cluster` (shortuid) pin for rename-only reconcile. |
| **No dial-time expand** | Do **not** resolve shortuid → FQDN (or instance → tenant) at call time or via live Gatekeeper. |
| **Config UX** | Operator picks/enters **tenant** FQDNs from fleet-visible tenant list (preferred) or validated free form. Target need not live on this node. |
| **Shortuid** | Optional display pin only. If shortuid and FQDN disagree, **FQDN wins** for dial. |
| **Slice A gap** | First A cut used local tenant shortuid. **A′:** required `target_fqdn` (tenant); fleet-aware tenant-FQDN picker; never instance FQDN. Product UI name: **Dial prefixes**, not aliases. **Implemented** on branch `tenant-short-dial-a` (schema + API + SPA). |
### 3.2 Why not unique extensions again

- Collides with multi-tenant density and convert-from-diverse DBs.  
- Breaks the moment two tenants both want `1000`.  
- Dial prefixes restore SARK *UX* (short digits) without SARK *constraint*.

### 3.3 Why not shortuid-as-dial-prefix

Tenant `shortuid` / FQDN remain the **routing key**. Dialling `xyzxyz1000` is possible but poor UX. The **prefix** is the human handle; shortuid/FQDN stay under the hood for **routing** (and for **return-call** CallerID num — §3.9).

### 3.4 Why always via SBC / tenant FQDN (v1)

- One recipe for co-located and remote tenants.  
- Reuses domain → dispatcher for **extension** delivery after the SBC change in §3.6.  
- Avoids dual maintenance of Local/ vs PJSIP/ peer dial strings in v1.  
- **Inter-tenant dial requires the SBC.** Singleton multi-tenant without an SBC cannot use prefix dial in v1 (§3.8 Q5, §15 deferred shortcut).

### 3.5 Relation to phone AoR (`shortuid@fqdn`)

LepDial to a **registered phone** still uses `sip:{phone_shortuid}@{fqdn}`.  
**Prefix dial** uses `sip:{extension_pkey}@{fqdn}` — the target tenant’s dialplan extension, **not** the phone shortuid.  
Do **not** require the caller to know the target phone’s `shortuid`.  
**Return-call** (Bob redialling Alice) uses Alice’s **phone** AoR — see §3.9.

### 3.6 SBC routing (locked 2026-07-27)

Today OpenSIPS treats Asterisk → `user@{tenant.fqdn}` as **usrloc → phone Contact** (fleet station dial). Phones REGISTER as **shortuid**, so `sip:1000@dhbm8x.pbx3.com` **misses** usrloc and does **not** fall through to the hosting Asterisk.

| R-URI | Today | Prefix dial needs |
|-------|--------|------------------|
| `sip:{shortuid}@{fqdn}` | usrloc → phone | Unchanged (station dial **and** return-call) |
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

Same-node “hairpin” back to the same Asterisk via dispatcher is **correct** for prefix dial (unlike shortuid AoR, where hairpin was the bug). Cross-node is the same miss→dispatcher path to the other instance.

**Rejected for v1:** Calling node resolves `ext → shortuid` then dials existing AoR (avoids SBC change but needs remote phone maps / breaks location-agnostic simplicity).

**SBC slice is required** — not “verify only.” Keep station-dial usrloc behaviour intact; add miss→dispatcher only for this class of INVITE (from Asterisk + tenant domain + no contact).

### 3.7 Locked from operator discussion (2026-07-27)

| Decision | Lock |
|----------|------|
| Shape | Simple **prefix → tenant FQDN** on the **calling tenant** |
| Naming | product = **dial prefix** (legacy “alias” = same) |
| Scope | **Per calling tenant** — not a shared instance/org directory of codes |
| Reverse | Not automatic; B configures its own prefix to call A back |
| SBC | **usrloc miss → dispatcher** for `ext@tenant.fqdn` from Asterisk |

### 3.8 Digit plan and policy (locked 2026-07-27)

| Topic | Lock |
|-------|------|
| **Digit plan** | **Fixed-width prefix** (2–4 digits, length chosen per prefix row) + **variable extension remainder** (`_X.`). No delimiter. Dial = `{prefix}{ext}` (e.g. prefix `81` + `1000` → `811000`). |
| **Remainder charset** | **Digits only** (`0–9`). Remainder is a target **extension** (`pkey`-shaped). **No** star/hash feature shortcodes through the prefix path (e.g. `81*50*1000` is **deny**). Local feature codes stay on the calling tenant (dial without prefix). Reopen only on an explicit product ask (e.g. remote park as a **named** feature — not free R-URI passthrough). |
| **GenAst** | One dialplan pattern per active prefix; remainder is digit-only target extension. Prefer `_81X.` (or length-bounded) so `*`/`#` do not match. CAGI must also reject non-digit remainder if dialled outside pattern. |
| **Collision hygiene** | Operator owns not colliding with local exts / PSTN OutRoute. Admin help + validation guidance; no auto-steal of bare LepDial or OutRoute. |
| **Fleet gate** | Feature **fleet-gated** in v1. Requires SBC path. |
| **Singleton** | Multi-tenant singleton **without SBC** cannot inter-tenant prefix dial in v1 — accepted. See §15 for deferred Local shortcut. |
| **Deny** | Missing/inactive prefix **or non-digit remainder** → **congestion + hangup** (no attendant / custom playback v1). |
| **CoS** | **Tenant-wide:** active prefix row ⇒ allowed for all CoS classes. Per-class grant later if needed. |

### 3.9 CallerID and return-call (locked 2026-07-27)

Bare extension as CallerID **num** is not a reliable cross-tenant redial (Alice’s `1000` on Bob’s phone redials *Bob’s* `1000`). InterSARK extension CLIP assumed globally unique exts — gone.

| Layer | Value | Role |
|-------|--------|------|
| **CallerID num / From** | `{calling_phone_shortuid}@{calling_tenant_fqdn}` | Return / missed-call dial → existing station AoR (usrloc) |
| **CallerID name** | Human detail | What the phone shows as “who” |

**CallerID name (v1):** enough to recognise the caller without decoding shortuid — at minimum **extension** and **caller name** when known (e.g. `1000 Alice` or `Alice (1000)`). Optional tenant/site label later; do **not** rely on name for dialling.

```text
Bob’s phone shows:  name = "1000 Alice"   (or similar)
                    num  = ab12cd@pb0wsk.pbx3.com
Return / redial  →  sip:ab12cd@pb0wsk.pbx3.com  → Alice’s phone (usrloc)
```

**Lab implement (2026-08-04 — golden / Magrathea):** Handset **display** started as presentation **extension** (`CALLERID(num)` = pkey). **Network return AoR** in **`P-Asserted-Identity`** (`sip:suid@tenant.fqdn`) via **`SiteRing`** + dialplan gosub; Magrathea miss→hairpin uses `X-PBX3-Pres-Num` + kept PAI + From `sitedial`. SIPp: dialling `suid@fqdn` **usrloc-hits**. See **§3.9.1** for desk matrix outcome.

No reverse dial prefix required for *product* callback (Q10 one-way OK). Prefix dial R-URI stays `ext@fqdn` (miss→dispatcher; **Asterisk-sourced only** today).

#### 3.9.1 Desk return lab (2026-08-05) — findings + recommendation

**Lab path:** affcot (`9wvvnb`) ↔ duns (`dhbm8x`) via Magrathea; prefixes `81` both ways (reverse row added for capture). Phones: Snom D717 / similar; registered Contacts via Magrathea.

| Experiment | Result |
|------------|--------|
| CLID = bare ext (`1101`) | History redial → local/wrong digits; fail |
| CLID = `1101@calling-tenant` | Phone INVITE never usrloc/miss→home as hoped; **phone→`ext@fqdn` is not Asterisk miss→dispatcher** → no/home fail |
| CLID = `suid@fqdn` on receive (GenAst `SbcDomainRoute`) | Snom **does** URI-redial the **user**; **rewrites host to own registrar** |

**Snom redial trace (decisive):** after inbound with CLID `hb64kj@dhbm8x…`, redial emitted:

```text
INVITE sip:hb64kj@9wvvnb.pbx3.com   ← user correct, domain = local identity
From: "1101" <sip:59507r@9wvvnb.pbx3.com>   ← From correctly local
```

→ Magrathea/Asterisk look up `hb64kj` under **affcot** → **404**. Alice never rings.

**Snom setting check:** No documented toggle to “keep remote party domain on history redial.” Dial-plan `\d` = **this identity’s registrar** (append local domain). `block_url_dialing` is dial-pad letters only. From must stay local identity (else call appears to originate as remote); that does **not** justify rewriting **Request-URI** host — but desks do it anyway.

**Industry corroboration (operator note, 2026-08-05):** Snom call-log return anchors outbound INVITEs to the **active Identity/registrar domain**, not the host from the logged CLID URI; outbound proxy / identity domain can force Request-URI (and From/To) rewrite. Suggested mitigations: check Identity → SIP proxy/domain; **PBX/SBC dynamically remap/canonicalize** inbound from that registration domain (same shape as lean **option A**); or force registrar domain ≡ expected multi-tenant profile (not viable for cross-tenant history return). Confirms lab — phone-side “keep remote domain” is not the product path.

**Also observed (separate):** same-box site dial — callee hangup did not always clear caller (hairpin/BYE asymmetry). **Not Slice D.** Same Snom/Yealink pair. **2026-08-05:** looks OK now — **cause unknown**; keep an eye on it.

**LDAP:** display lookup can key off shortuid/CLIP; **click-to-dial** across tenants needs qualified dial (AoR or prefix+ext), not bare extension — else same domain-rewrite / local-ext problem.

**Rejected as sole product fix:** DID-on-every-extension (cost, PSTN trombone, incomplete). SUID uniqueness was never wrong — **handset host rewrite** broke full-AoR redial.

**Product lock (2026-08-05): option A.**

| Option | Meaning | Portability |
|--------|---------|-------------|
| **A (locked)** | CLID carries **shortuid** (user); **our SBC** repairs phone-originated INVITE: usrloc miss on `user@wrong-domain` → lookup Contact by **username** (globally unique shortuid) and RELAY / fix `$rd`. Guaranteed history return on **pbx3 + our edge**. | **Our SBC only** for *guaranteed* desk callback (forward site dial already SBC-shaped) |
| **B (rejected for v1)** | No history-return guarantee; coach name/LDAP display; return via reverse prefix / optional DID | Any SBC |

**Implement (A):** Magrathea / template change per **`pbx3sbc/workingdocs/SLICE_D_SHORTUID_USRLOC_REPAIR.md`** (**lab green** on `main`). Generator reject-all-digit shortuids **done** (`idpwgen` + PHP wrappers) on branch `shortuid-reject-all-digit`.

**SBC pattern (summary — detail in that file):** Today phone INVITE `user@caller-fqdn` skips usrloc and **`TO_DISPATCHER`** → caller home → 404. Slice B miss→dispatcher is **Asterisk-only** and does not apply. **Path 1 (locked):** before dispatcher, for phone-sourced INVITE where `$rU` looks like shortuid (**charset + letter**, no fixed length), **username-only** `location` query (shortuids globally unique — unlike digit exts); hit → same Contact **`route(RELAY)`** as Asterisk→phone. Gate auth: From user registered on `$fd` and `$si` matches Contact/`received`. **Path 2 (alt, not v1):** rewrite `$rd` to registered domain → dispatcher **callee** home. Keep receive CLID = `suid@fqdn`; CallerID **name** = human. Do not username-only digit R-URIs.

**Caveats (still true):**

- **No guaranteed reverse site-code** — bidirectional prefix optional (Q10).  
- Queue/IVR without phone shortuid: name where possible; num may be non-returnable.  
- Reverse-prefix numeric CLIP remains deferred polish (§15).  

---

## 4. Current / legacy baseline (do not silently break)

### 4.1 Fleet same-tenant AoR (keep)

PrepDial fleet dial string keeps tenant domain in R-URI so multi-tenant usrloc does not 404/hairpin. Covered by L1 `in-multi-tenant-a-b`.

### 4.2 InterSARK / SailToSail / INTERSITE

CAGI `OutTrunk` special-cases **InterSARK** / **SailToSail** for CLID (leave extension CLIP). GenAst emits OutRoute digit patterns (e.g. `DUNS_INTERSITE`).  

**Stance:** Treat as **legacy interconnect**. New product is **per-tenant dial prefixes**, not more unique-ext assumptions. Convert/migrate guidance in §7; no requirement to keep InterSARK as the long-term UX. Return-call for prefixes uses AoR num + human name (§3.9), not bare extension CLIP.

### 4.3 Cos / outbound

Short dial is an **internal-ish** feature, but it still leaves the calling tenant’s Cos context via a dedicated GenAst pattern / CAGI command (name TBD). It must not accidentally match PSTN OutRoute patterns (digit-plan hygiene — §3.8).

---

## 5. Target shape (logical — names TBD at implement)

### 5.1 Dial prefix table (calling tenant)

| Field (logical) | Purpose |
|-----------------|--------|
| `cluster` | Calling tenant (owner of this prefix) |
| `prefix` / `pkey` | Dial digits (e.g. `1234` or `81`) |
| **`target_fqdn`** | **Required.** Target **tenant** FQDN (e.g. `dhbm8x.pbx3.com`) — **the** dial target. Never instance FQDN. |
| `target_cluster` | Optional shortuid if catalog known — label / mobility only; **not** needed to dial |
| `active` | Enable/disable |
| `description` | Operator label |

**Uniqueness (locked):** `prefix` unique within the **calling tenant**. Different tenants may reuse the same prefix digits for different targets.

**Validation (target_fqdn):** non-empty full FQDN; product checks reject bare shortuids and known **instance** fqdn patterns when distinguishable. Lowercase on save; strip scheme/user if pasted.

**Help copy (SPA):** “Target is the other **tenant’s** domain (e.g. site.pbx3.com), not the instance hostname.”

**Do not** require target ∈ this node’s `cluster` table.

### 5.2 GenAst

Emit dialplan matches from this tenant’s prefix rows → CAGI (e.g. `SiteDial` / `PrefixDial`) with prefix + remainder (extension).

**Ordering:** Prefix patterns must not steal local extensions or PSTN routes (§3.8). Fleet-gated: emit only when fleet mode / SBC path available.

### 5.3 CAGI

1. Parse DNID → prefix + extension.  
2. Lookup prefix row on **calling** tenant; deny if missing/inactive → congestion + hangup.  
3. **Reject non-digit remainder** (feature shortcodes, `*`, `#`) → congestion + hangup (Q13; same deny as §3.8).  
4. Use **`target_fqdn` from the prefix row** (not a local cluster resolve of shortuid alone). Deny if FQDN missing/empty.  
5. Build dial string toward `sip:{ext}@{target_fqdn}` via SBC (fleet).  
6. Set **CallerID num** = calling phone `suid@fqdn`; **CallerID name** = human detail (§3.9).  
7. Post-dial / busy / VM as for comparable internal dial.

### 5.4 Target tenant receive path

INVITE `sip:{ext}@{fqdn}` arrives via SBC → Asterisk tenant context. Must:

- Resolve like a local station dial to that ext (LepDial path).  
- Mark as **site-dial / internal** (not carrier) for CoS / recording (channel var / SIP header — at implement).  
- Preserve CallerID num (AoR) and name for the ringing phone.  
- Not require the calling phone to be registered on the target tenant.

### 5.5 SPA / API

- **Who:** **Instance admin only** (`abilities:admin`). Not tenant-panel operators. There is no customer/tenant-group CRM model; cross-tenant dial prefixes are fleet/node ops, not per-tenant self-serve.  
- Per-admin: list/add/edit dial prefixes (digits → **target FQDN**).  
- **Target field (Q14):** **restricted picker** of known tenant FQDNs only — local tenants with `fqdn` **plus** fleet `tenant-home` `cname`s when catalog is reachable. No freeform invent. Labels show friendly name/shortuid + FQDN. Persist `target_fqdn` (required); shortuid optional pin. Catalog down → local-known only (Create stays if any local FQDN exists).  
- Help: “Prefix is only for this tenant. Dial prefix then extension. Target is the other **tenant’s** FQDN (e.g. sister.pbx3.com) — not the instance hostname — and that site may sit on another fleet node. No feature codes after the prefix.”  
- Fleet console: optional later helper — **not** on the call path.  
- Hide / no-op on non-fleet singleton (v1).

### 5.6 Provisioning / sync

- **v1:** Configure prefixes on each calling tenant manually.  
- **Later:** Control-plane assisted push still writes **local** prefix rows (Rule 1).

---

## 6. Non-goals (v1)

- Mandating globally unique extensions.  
- Live directory / gatekeeper / S3 lookup during dial (**Rule 1**).  
- Replacing Egress / PSTN OutRoute.  
- Dial-by-name directory, BLF across tenants, or presence federation.  
- Requiring tenant DNS to equal VIP (existing AoR residue stays separate).  
- Automatic mesh of every tenant to every other tenant.  
- Changing L1 `in-multi-tenant-a-b` meaning (that stays usrloc discrimination).  
- **Singleton multi-tenant prefix dial without an SBC** (accepted limitation; §15 maybe later).  
- **Co-located Local shortcut** in v1 (deferred §15 — not “never”).  
- Promising **bare extension** as the return-call contract (use `suid@fqdn` + CallerID name).  
- **Feature shortcodes via prefix** (`81*50…`, remote park by free digits, etc.) — digits-only remainder; local codes stay local.  
- **Same-node-only product** — rejected (Q14); sister sites almost always span nodes.

---

## 7. Legacy / SARK conversion notes

| Legacy | Guidance |
|--------|----------|
| Unique ext + bare dial | Map sister sites to **dial prefixes**; keep local bare dial. |
| InterSARK / SailToSail trunks | Candidates to replace with prefixes; human “who” moves to CallerID name; return uses AoR / PAI, not bare extension. |
| `*_INTERSITE` OutRoute digit maps | Inventory per tenant; do not auto-delete; dual-run until prefixes proven. |
| Same-node multi-tenant lab (v1) | Prefix dial **must** still go FQDN/SBC recipe (no Local shortcut) so convert behaviour matches fleet. |

### Operator migrate recipe (slice F)

**Full runbook:** **`DIAL_PREFIX_LEGACY_MIGRATE.md`** (inventory SQL, dual-run, retire gates, CLIP coaching, fleet FQDN rules).

Summary:

1. **Inventory (per calling tenant):** InterSARK / SailToSail trunks and `*_INTERSITE` OutRoute maps (old digits → peer).  
2. **Choose fixed prefix(es)** (2–4 digits) not colliding with local LepDial, OutRoutes, or emergency patterns.  
3. **Admin → Dial prefixes:** one row per sister: prefix → **tenant FQDN** of B (not instance/node FQDN). Bidirectional ⇒ mirror row on B.  
4. **Commit / genAst** on both homes after prefix CRUD.  
5. **Dual-run:** keep InterSARK trunks until prefix path greened (site dial + station AoR regression).  
6. **Retire:** deactivate INTERSITE OutRoutes / InterSARK peers only after operator training; no auto-delete of PSTN routes.  
7. **CLIP coaching:** callers show **local extension**; return is best-effort via phone history / PAI (`suid@fqdn`); do not promise InterSARK-style globally unique bare-ext redial.

**Acceptance for convert:** Operator recipe documented (above file); no silent change of PSTN routes. **Done 2026-08-04** (docs only).  

---

## 8. Locked decisions (was open)

| Id | Decision | Lock |
|----|----------|------|
| **Q1** | Digit plan shape | **Fixed-width prefix** (2–4 digits per row); no delimiter. |
| **Q2** | Extension after prefix | **Variable remainder** (`_X.`); **digits only** (no feature shortcodes / `*` / `#`); operator collision hygiene. |
| **Q3** | Prefix uniqueness | Unique per **calling tenant** only. |
| **Q4** | Table ownership | Per calling tenant prefix rows (not instance/org shared directory). |
| **Q5** | Singleton / non-fleet | **Fleet-gated**; SBC required. Singleton multi-tenant without SBC = no prefix dial in v1. Deferred Local shortcut §15. |
| **Q6** | CLID | **Num** = returnable AoR; **name** = human detail (§3.9). No per-prefix CLID policy knobs in v1. |
| **Q7** | Target trust | Mark receive as **site-dial / internal** (not carrier); mechanism at implement. |
| **Q8** | Deny behaviour | **Congestion + hangup** (missing/inactive prefix **or** non-digit remainder). |
| **Q13** | Feature codes via prefix | **No** — prefix path is extension digs only; local `*…` patterns unchanged on calling tenant. Explicit remote-feature product later if ever. |
| **Q9** | CoS | **Tenant-wide** (active prefix ⇒ all classes). |
| **Q10** | Bidirectional | One-way OK; reverse prefix configured separately on B. |
| **Q11** | SBC dial target | `ext@fqdn` + **usrloc miss → dispatcher** (§3.6). |
| **Q12** | Return-call | CallerID **num** = `suid@fqdn`; CallerID **name** = ext + caller name (§3.9). |
| **Q14** | Target = **tenant FQDN** (not instance FQDN); cross-node sister sites primary | Always full tenant FQDN on row for dial. Move (same FQDN, new host) = prefixes keep working via SBC domain→home. Rename FQDN = re-save/reconcile, not dial-time expand. Shortuid optional label only. No local-`cluster` requirement for target. |

---

## 9. Delivery slices (when scheduled)

Own track — do not interleave with day-parts CheckState rewrite or CAGI Phase 4. §8 locked — schedule when ready.

| Slice | Repos | Operator-visible |
|-------|--------|------------------|
| **A** — schema + API + SPA dial prefixes (no dial yet) | pbx3, pbx3api, pbx3spa | Admin CRUD |
| **A′** — target = FQDN (Q14): required `target_fqdn`; fleet-aware FQDN picker (not local cluster shortuid-only); API does not require target ∈ local `cluster` | pbx3, pbx3api, pbx3spa | Admin can aim at remote sister site by FQDN |
| **B** — OpenSIPS usrloc-miss → dispatcher for `ext@tenant.fqdn` | **pbx3sbc** | None — **lab Magrathea + template** (Pres-Num / PAI / sitedial hairpin) |
| **C** — GenAst pattern + CAGI PrefixDial (`ext@fqdn` via SBC) + CLIP | pbx3, pbx3cagi | Dial works fleet lab (presentation ext; see §3.9 lab note) |
| **D** — Receive-path + return lab | pbx3cagi, sbc (+ lab desks) | Path partial; **open ToDo** → lab + choose **least-ugly guaranteed** return (no bidir prefix assume) — **`TODO.md`** |
| **E** — L1 recipe `site-dial-a-b` | **sipplab** | Dual-host L1 lab green 2026-08-04 — **not pack-gated**; plan when scheduled: sipplab **`workingdocs/SITE_DIAL_PACK_GATE_PLAN.md`** |
| **F** — Legacy INTERSITE / InterSARK migrate notes | docs | **Done 2026-08-04** — **`DIAL_PREFIX_LEGACY_MIGRATE.md`** |

**Order note:** Complete **A′ (Q14)** before treating Admin as done for C — local-only target picker is **not** product-complete. Slice **B** before or with **C** — without miss→dispatcher, PrefixDial to `ext@fqdn` fails on today’s SBC. Do not regress station dial (`shortuid@fqdn` usrloc hit). Slice **D** includes return-call URI lab check.

**Lab hosts (locked 2026-07-27; VM path 2026-07-30):** Keep SIPp EC2 (EIP + Peer **99**) as **carrier/DID**. **Extension platform** = local ARM VM **`sippuac`** (`192.168.1.51`, no Peer) — office NAT OK for phone UAC; EC2 fallback only if needed. Same host cannot be both Peer and clean phone IP. See **sipplab** `docs/HOST_SETUP.md` / `docs/examples/aelintra-lab.md`. Same-node golden first (sipp ↔ affcot/duns); **cross-node required for Q14 sign-off** (e.g. golden → bzy or kildare).

---

## 10. Repo / component checklist

| Component | Change |
|-----------|--------|
| sqlite (+ Laravel migrates) | Dial alias table (per calling tenant) |
| GenAst / `GenClass` | Alias dialplan patterns (fleet-gated) |
| pbx3cagi | Parse, lookup, dial to `ext@fqdn` via SBC; set AoR num + human name |
| pbx3api / pbx3spa | Dial prefixes admin |
| OpenSIPS / SBC | **Required:** from-Asterisk `ext@tenant.fqdn` — usrloc hit → phone; **miss → dispatcher** (§3.6). Must not break shortuid AoR. |
| call-tests | New L1 id when B–D land |
| tt_help_core | Dial-prefix help (incl. return-call / display name) |
| DESIGN / MkDocs (later) | Operator-facing fleet page |

---

## 11. Sequencing vs other work

- **After** L1 pack confidence (302 + multi-tenant AoR done).  
- **Independent** of time-based routing §8 (different contract).  
- **Before** treating InterSARK as permanent product.  
- **Not** blocked on S10.7 / directory features (call path must not use them).  
- §8 locked — implement when scheduled (not blocked on further requirements).

---

## 12. Success criteria

1. Tenant A configures prefix `NN` → **target FQDN** of B; dial `NN`+`{ext}` rings B’s ext.  
2. Same dial works with B on **same** golden node and on **another** fleet node (cross-node = primary) without dialplan fork (SBC miss→dispatcher).  
3. Bare local extension dial unchanged.  
4. Directory/gatekeeper down: prefix dial still works from local rows (**including stored target_fqdn**).  
5. Extension number collision across tenants does not misroute (prefix required).  
6. L1 (when built) covers prefix dial separately from `in-multi-tenant-a-b` (usrloc only).  
7. Station dial (`shortuid@fqdn`) still usrloc→phone after the SBC change (no regression).  
8. Bob’s return-call via CallerID num `suid@fqdn` rings Alice; CallerID name shows human detail; bare ext redial is **not** required to reach Alice.  
9. Feature absent / no-op on non-fleet singleton (v1).  
10. Admin can set target to a remote tenant’s **FQDN** even when that tenant is not in this node’s `cluster` table.

---

## 13. L1 / inventory pointers

| ID | Role |
|----|------|
| `in-multi-tenant-a-b` | Existing — usrloc domain discrimination (peer REG noise) |
| `site-dial-a-b` | SIPp **phone** UAC (Domain, non-Peer) dials prefix+ext → UAS on B — dual-host lab **[sipplab `docs/examples/site-dial-lab.md`](https://github.com/aelintra/sipplabs/blob/main/docs/examples/site-dial-lab.md)** (green 2026-08-04) |
| Inventory | Add/adjust major row when implement starts — keep distinct from AoR-only test |

---

## 14. Revision

| Date | Note |
|------|------|
| 2026-07-27 | Initial draft: prefix namespaces; location-agnostic SBC/FQDN recipe; Rule 1; reject unique-ext; InterSARK legacy; open §8 Q1–Q10. |
| 2026-07-27 | Operator framing: **per-tenant dial prefix** (`1234` → `xyzxyz`); product prefix; legacy alias OK; lock Q3/Q4/Q10. |
| 2026-07-27 | SBC: lock **usrloc miss → dispatcher** for `ext@tenant.fqdn` (Q11); slice B; reject node-side ext→shortuid for v1. |
| 2026-07-27 | **§8 fully locked:** digit plan (fixed prefix + variable ext); fleet-gated / SBC-required; CLID num=`suid@fqdn` + name=human; deny=congestion; CoS tenant-wide; Q12 return-call; deferred co-located Local shortcut (§15). |
| 2026-07-27 | Lab: second SIPp EC2 as **extension platform** (non-Peer EIP) when prefix implement starts; Peer-99 host stays carrier/DID. |
| 2026-08-03 | **Q13 / remainder charset:** digits only after prefix; no feature shortcodes through prefix path (unless later explicit product reopen). Deny = congestion. |
| 2026-08-03 | **Q14:** target is **tenant FQDN** (not instance). Always full FQDN; move preserves FQDN → no prefix rewrite; rename re-save/reconcile; no dial-time expand. |
| 2026-08-04 | **D residual:** lab → **least-ugly *guaranteed* return** recipe (SUID / DID / PAI / hybrid candidates); no implement until findings. |

---

## 15. Deferred: co-located Local shortcut (maybe later)

**Not v1.** Documented so singleton multi-tenant or hairpin cost can be revisited without rediscovering the tradeoff.

**Idea:** If `target_cluster` exists in **this node’s** local `cluster` table, dial `Local/{ext}@{target_cluster}` (or `Goto(target,ext,1)`) instead of `sip:{ext}@{fqdn}` via SBC. Cross-node / unknown target still uses SBC miss→dispatcher. Co-location test is **node-local DB only** (Rule 1 OK).

| Variant | What it is | Rough effort | Risk |
|---------|------------|--------------|------|
| **S1 — Singleton GenAst branch** | When `!fleet_mode`, PrefixDial patterns emit `Goto`/`Local/` into target tenant context; no SBC. | **Small** (~½–1 day once prefix GenAst exists) | Dual dialplan vs fleet; PostDial/busy/VM parity easy to miss. |
| **S2 — CAGI co-locate branch** | If target in local `cluster` → `Local/`; else `sip:ext@fqdn`. Fleet same-node + enables singleton if ungated. | **Medium** (~1–2 days + L1 both paths) | Two live recipes; fixes may land on one path only. |
| **S3 — Pure conf tweak** | Hand overlay `exten => _81X.,1,Goto(...)` with no CAGI. | **Tiny** lab hack | **Reject as product** — fights GenAst Commit; no CRUD/CLID. |

Also deferred (related polish): reverse-prefix **numeric** CLIP if desk-phone URI redial proves weak — not the v1 return contract (§3.9).
| 2026-08-03 | **Product naming:** prefer **dial prefix** / **prefix** over alias in UI and docs. |
