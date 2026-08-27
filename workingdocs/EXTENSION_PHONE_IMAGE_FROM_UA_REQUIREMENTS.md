# Extension device model harvest (sidekick utility)

**Status:** **Lab green on `.31` (2026-08-27)** — posture **A** implemented (harvest + API + SPA fields). Package cron still **off by default**; `.31` cron enabled. Images (slice F) not required for this pass.  
**Prior locks:** 2026-08-09 edge registrations API — **superseded**. 2026-08-26 AstDB-home source. 2026-08-27 design lock.  
**Name:** `harvest-devicemodel` (script) / “UA model sidekick”.  
**Problem:** Without HTTP provisioning we no longer learn desk-phone **vendor/model** at config time. Customers liked handset images on the extension panel.  
**Opportunity:** Asterisk stores each registered contact’s `user_agent` in AstDB under `registrar/contact`. An optional home cron soft-fills harvest columns.  
**Related:** `getimages.sh` (`PBX3_PHONEIMAGES_URL`) · `PROVISIONING_SERVER_REQUIREMENTS.md` (won't-do) · pbx3api `Ami`.  
**Sibling:** **`PHONE_MODEL_DURABLE_VS_EPHEMERAL.md`** — posture **A locked**; optional fleet inventory parked.

---

## 1. Stance (locked)

| # | Lock |
|---|------|
| S1 | **Optional.** Disabled / cron off → no-op exit 0. Solo and fleet use the **same** path. **Do not** require SBC. |
| S2 | **Async only.** Never on REGISTER, dial, GenAst, or SPA request path. |
| S3 | **Soft write** on `devicevendor` + `devicemodel`: empty → fill; current equals this run’s mapped values → bump `lastseen` (set `firstseen` if null); else **skip** (treat as operator-owned). No separate “last auto” column in v1. |
| S4 | **Key = PJSIP endpoint shortuid.** Look up `ipphone` by shortuid (+ cluster if needed). **Never** by contact IP. |
| S5 | **Source = this home’s Asterisk AstDB** — `database show registrar/contact`. **No** edge registration API; **no** OpenSIPS SQL from the node. |
| S6 | **Never** rewrite `ipphone.desc` (User). **Never** rewrite `ipphone.device` from harvest (type enum — §1.1). |
| S7 | Images are a **separate** concern (slice E). Harvest deliverable = `devicevendor` + `devicemodel` + `firstseen`/`lastseen`. |
| S8 | Only phones whose REGISTER lands on **this** Asterisk appear in AstDB. |
| S9 | **UA changes only on REGISTER.** Lag at most until next REGISTER + next harvest. Honesty = **`lastseen`** (UTC ISO). |
| S10 | **Skip** rows whose `device` is `WebRTC` or `MAILBOX` (no harvest write). |
| S11 | Contact expired / missing → **do not clear** vendor/model; **do not** bump `lastseen`. |
| S12 | **MAC is not canon.** Optional best-effort inventory only (§1.2). **Drop** OUI → vendor (`getVendorFromMac`). SIP UA is canon for brand/model. |

### 1.1 `ipphone.device` — type enum only

**Allowed values (v1):** `WebRTC` | `MAILBOX` | `General SIP`.  
New variants only via an explicit future requirement.

| Action | Rule |
|--------|------|
| Create / update API | SIP → always `General SIP`; WebRTC → `WebRTC`; mailbox → `MAILBOX`. **No** OUI write into `device`. |
| Existing DBs | One-shot normalize: any other non-empty value (Yealink, Snom, …) → `General SIP`. |
| SARK ETL | Same: never leave vendor strings in `device` — force enum (**sark-to-pbx3** REQUIREMENTS **#14**). |
| Harvest | Does not touch `device`. |

**Not** the purged **Device** templates table (won't-do 2026-08-25).

### 1.2 `ipphone.macaddr` — best-effort inventory

- User **CRUD** on SIP extensions (create / edit / clear). Already updateable in API/SPA.
- **Not** truth for vendor, model, images, or type.
- Changing/clearing MAC must **not** rewrite `device`.
- Keep DB **UNIQUE** for hygiene.
- Hide on WebRTC.
- Create UX: optional MAC field; **no** “SIP (MAC)” subtype flavour.
- Help: optional desk inventory note — not phone identity.
- SPA edit Identity: readonly fields first — **Device** then **MAC** (UX 2026-08-27).

### 1.3 Harvest columns

| Column | Role |
|--------|------|
| `devicevendor` | Brand from UA map (e.g. `Yealink`, `Snom`). Soft-filled by harvest only (not SPA mass-assign). |
| `devicemodel` | Model **token** only (e.g. `T46U`, `D717`) — **not** `"Yealink T46U"` and **not** the display composite. |
| `firstseen` | UTC ISO — first successful harvest soft-write/confirm. Repurposed provisioner column (on SQLite create). |
| `lastseen` | UTC ISO — latest such observation. Same. |

**Display / list composite (locked):** `{devicemodel} ({devicevendor})` — e.g. `T46U (Yealink)`, `D717 (Snom)`. SPA builds this; do **not** store the composite in either column.

SARK provision `firstseen`/`lastseen` must **not** be imported (leave NULL — harvest owns the columns). `devicevendor` NULL on import.

---

## 2. Roles

| Piece | Owns |
|-------|------|
| Asterisk (home) | `registrar/contact/…` JSON (`user_agent`, `endpoint`, …) |
| **pbx3 home** | Cron/`harvest-devicemodel` → AstDB → map → soft UPDATE |
| SPA (later) | Image / “as of lastseen” when pack present |

```text
Asterisk AstDB registrar/contact (endpoint, user_agent, expiration_time, …)
        → harvest-devicemodel on home
        → UA mapper → (devicevendor, devicemodel)
        → soft UPDATE devicevendor, devicemodel, firstseen, lastseen
```

---

## 3. AstDB source

**CLI (lab proof):**

```text
asterisk -rx 'database show registrar/contact'
```

**Shape:**

```text
/registrar/contact/{endpoint};@{hash}: {"endpoint":"jxpg8b","user_agent":"Yealink SIP-T46U 108.86.0.90","expiration_time":"…", …}
```

| Field | Use |
|-------|-----|
| `endpoint` | PJSIP endpoint = extension **shortuid** |
| `user_agent` | Input to UA → vendor + model map |
| `expiration_time` | Prefer non-expired; if multiple contacts, pick **latest** |

Prefer AMI `Action: Command` / `database show registrar/contact`. Parse `key: json`; skip malformed / missing endpoint+UA.

**No new SBC / Gatekeeper API.**

---

## 4. Home utility

### 4.1 Packaging / invoke

| Item | Choice |
|------|--------|
| Path | `/opt/pbx3/scripts/harvest-devicemodel.sh` (+ PHP helper) |
| Cron | Optional `/etc/cron.d/pbx3-harvest-devicemodel` — **commented/off by default** |
| Cadence | **Every 15 minutes** when enabled (AstDB dump is cheap; REGISTER churn is slow) |
| Enable | `PBX3_HARVEST_DEVICEMODEL=1` (or enabled cron). Unset / `0` → exit 0 |

Exit: `0` success or disabled; `1` AMI/CLI/parse/DB error; never touch call plane.

### 4.2 Algorithm

1. If disabled → exit 0.  
2. Dump `registrar/contact`.  
3. One row per `endpoint` (latest non-expired).  
4. For each endpoint:  
   - Resolve `ipphone` by shortuid.  
   - If `device` ∈ {WebRTC, MAILBOX} → skip.  
   - `(vendor, model) = map_ua(user_agent)`; skip if unmapped.  
   - Soft UPDATE per S3; set `firstseen` if null; always bump `lastseen` on write/confirm.  
5. Log: contacts / endpoints / written / skipped(owned|type) / unmapped / missing ipphone.

### 4.3 UA → vendor + model map (v0 starter)

**Source (operator, 2026-08-27):** starter set. Ship built-in; optional `/opt/pbx3/etc/ua-model-map.json` later.

**Provenance:** Seed patterns often from **provision HTTP** UAs; SIP REGISTER UAs can differ (e.g. Snom). Tune against live AstDB.

**Match order:** `yealink` (SIP-…) **before** `yealinkDECT`. First match wins.

**Output shape (locked):** map returns **`devicevendor`** + **`devicemodel`** separately. Human display = `{devicemodel} ({devicevendor})` (e.g. `T46U (Yealink)`).

| Key | Regex (PCRE) | `devicevendor` | `devicemodel` | Display |
|-----|--------------|----------------|---------------|---------|
| `cisco` | `Cisco-CP-(\d{4}-3PCC)` | `Cisco` | capture (e.g. `7841-3PCC`) | `7841-3PCC (Cisco)` |
| `polycom` | `PolycomVVX-(VVX_\w+)\-UA` | `Polycom` | capture | `{model} (Polycom)` |
| `snom` / `snom_slash` | `(snom\w+)\-SIP` **or** `^(snomD\d+)` | `Snom` | model token (e.g. `D717`) | `D717 (Snom)` |
| `yealink` | `Yealink\sSIP-([\w-]+)\s` | `Yealink` | capture (e.g. `T46U`) | `T46U (Yealink)` |
| `yealinkDECT` | `Yealink\s([\w-]+)\s` | `Yealink` | capture | `{model} (Yealink)` |
| `panasonic` | `Panasonic_(KX-\w+)\/` | `Panasonic` | capture | `{model} (Panasonic)` |
| `aastra` | `Aastra(\d{4}i)\s` | `Aastra` | capture | `{model} (Aastra)` |
| `fanvil` | `Fanvil\s(\w+)\s` | `Fanvil` | capture | `{model} (Fanvil)` |
| `zoiper_z` | `^Z\s+([\d.]+)` | `Zoiper` | product ver (e.g. `5.6.13`) | `5.6.13 (Zoiper)` — lab `.31` form |
| `zoiper` | `Zoiper[^0-9]*([\d.]+)` | `Zoiper` | capture | `{ver} (Zoiper)` |
| `bria_mobile` | `Bria\s+Mobile\s+(iOS\|Android)\s+release\s+([\d.]+)` | `Bria` | `Mobile {plat} {ver}` | `Mobile iOS 6.23.5 (Bria)` |
| `bria` | `Bria[^0-9]*([\d.]+)` | `Bria` | capture | `{ver} (Bria)` fallback |

```php
// Canonical starter (implement helper splits vendor vs model per table above)
$manufacturer_regex = [
	'cisco' => 'Cisco-CP-(\d{4}-3PCC)',
	'polycom' => 'PolycomVVX-(VVX_\w+)\-UA',
	'snom' => '(snom\w+)\-SIP',
	'snom_slash' => '^(snomD\d+)',
	'yealink' => 'Yealink\sSIP-([\w-]+)\s',
	'yealinkDECT' => 'Yealink\s([\w-]+)\s',
	'panasonic' => 'Panasonic_(KX-\w+)\/',
	'aastra' => 'Aastra(\d{4}i)\s',
	'fanvil' => 'Fanvil\s(\w+)\s',
];
```

**Softphones:** `Browser Phone` / `SIPJS` / `JsSIP` → skip harvest when `device=WebRTC` (S10). Unknown UA → skip.

**Brand coverage (v0)** — prefer live AstDB SIP UAs. Soak: **`pbx3sbc/workingdocs/SBC_SOAK_ENDPOINT_REFERENCE.md`**.

| Region weight | Brands | Notes |
|---------------|--------|-------|
| **Both US + EU** | **Yealink**, **Fanvil** | Seeded |
| **EU-strong** | **Snom** | Dual UA forms |
| **US / global SMB** | **Grandstream** | Need SIP UA sample (unit ordered 2026-08-27) |
| **EU DECT/IP** | **Gigaset** | Need SIP UA sample (unit ordered 2026-08-27) |
| **Enterprise** | **Poly**, **Cisco** 3PCC | Seeded common forms |
| **Legacy EU** | **Panasonic**, **Aastra** | Seeded |
| **Softphones** | Zoiper, Bria, etc. | Label or skip image |

**Out of scope v0 brand chase:** VTech own-brand, Htek/Mitel/Avaya unless customer sample.

### 4.4 Lab fixtures

**Lab home `.31` (2026-08-26):**

| shortuid | User-Agent | `devicevendor` | `devicemodel` | Display |
|----------|------------|----------------|---------------|---------|
| `jxpg8b` | `Yealink SIP-T46U 108.86.0.90` | `Yealink` | `T46U` | `T46U (Yealink)` |
| `pqjfth` | `snomD717/10.1.198.19` | `Snom` | `D717` | `D717 (Snom)` |
| `pz9vmk` | `Z 5.6.13 v2.10.20.14` | `Zoiper` | `5.6.13` | `5.6.13 (Zoiper)` |

**Earlier samples (still valid):**

| shortuid | User-Agent | `devicevendor` | `devicemodel` | Display |
|----------|------------|----------------|---------------|---------|
| `59507r` | `snomD717/10.1.198.19` | `Snom` | `D717` | `D717 (Snom)` |
| `q5zjhw` | `Yealink SIP-T31P 124.86.0.40` | `Yealink` | `T31P` | `T31P (Yealink)` |
| `1nvd41` / … | `Yealink SIP-T46U …` | `Yealink` | `T46U` | `T46U (Yealink)` |

---

## 5. Schema / API / SPA (follow-ons)

| Layer | Implement |
|-------|-----------|
| DB | Add `devicevendor`; ensure `firstseen`/`lastseen` on SQLite (+ ALTER for existing). Comments: harvest not provision. Normalize `device` enum. |
| pbx3api | Remove `getVendorFromMac` side effects. Expose `devicevendor`, `devicemodel`, `firstseen`, `lastseen` **read-only**. `macaddr` stays updateable; `device` type-only on write. |
| SPA | Device readonly (type); MAC editable after Device. Later: model/image + “as of lastseen”. |
| Help | Update `device` / `macaddr`; add keys for harvest fields when exposed. |
| ETL | **sark-to-pbx3 #14** — `device` → enum; do not import SARK firstseen/lastseen; `devicevendor` NULL. |

**List:** User = `desc`. Device = type enum. Brand/model = harvest columns (not Device table).

---

## 6. Non-goals (v1)

- HTTP phone provisioning for images.  
- Edge / OpenSIPS registration-summary API.  
- OUI / `manuf.txt` as vendor canon.  
- Stomping `desc` or type `device` from harvest.  
- Perfect vendor coverage.  
- Directory / Gatekeeper / SBC in the loop.  
- Call-path or GenAst dependency.  
- Clearing vendor/model when REGISTER expires.  
- L5 change notify / fleet phone inventory.

---

## 7. Implement slices (when scheduled)

| Slice | Deliverable |
|-------|-------------|
| **A** | Schema: `devicevendor` + `firstseen`/`lastseen`; `device` normalize SQL; drop OUI→device |
| **B** | Read + parse `registrar/contact` |
| **C** | UA mapper unit tests (fixtures §4.4) — vendor + model split |
| **D** | Soft UPDATE + optional cron (off by default) |
| **E** | Lab enable on `.31` / golden |
| **F** | SPA image / “as of” + phoneimages host (§9) — **shelved 2026-08-27** (partner-portal assets first; Handset text OK without images) |
| **G** | SARK ETL #14 + drop `getVendorFromMac` |

---

## 8. Acceptance

- Disabled → exit 0; no DB writes.  
- §4.4 fixtures → correct `devicevendor` + `devicemodel` + `lastseen`.  
- Differing non-empty harvest fields unchanged on re-run (operator-owned).  
- Unmapped UA → no write.  
- `device` remains enum-only; WebRTC/MAILBOX skipped.  
- MAC change does not alter `device`.  
- Asterisk / AMI down → exit 1; sqlite unchanged.  
- No REGISTER / dial behaviour change.  
- No SBC registration API dependency.

---

## 9. Phoneimages pack (ops)

### 9.0 Distribution lock (2026-08-27)

| Lock | |
|------|--|
| P1 | **Private** assets repo (e.g. `aelintra/phoneimages`) is the **source of truth** — vendor dirs, README, rights notes. **Not** public; **not** in product packages. |
| P2 | Homes **do not** `git clone` / `git pull` the assets repo. They consume a **release zip** (or equivalent tarball) via existing `getimages.sh` / `PBX3_PHONEIMAGES_URL` into `/opt/pbx3/cache/phoneimages/`. |
| P3 | Cadence: monthly (or weekly — same as historic getimages cron) when URL is set. Unset → no images; harvest text still works. |
| P4 | **Fence + takedown:** keep distribution private/controlled. If a rights holder objects, remove the asset from the private repo + cut a new release; homes pick up the omission on next pull. Softphone **logos** optional; missing image = OK (Handset label only). |
| P5 | Do **not** bake ProVu (or other supplier) URLs into installer / product tree. Ops copy into the private repo; PBX only sees our zip URL. |

| Item | Value |
|------|--------|
| Historic URL | `http://sailpbx.com/phoneimages.zip` (pre-scrub; **dead** / 403 as of 2026-08) |
| **Authoring copy (interim)** | **`~/GiT/nonGitStuff/phoneimages/`** until the private repo exists — then migrate tree there. |
| **Ingest source** | **[ProVu](https://www.provu.co.uk/products/)** desk photos (ops copy per §9.1); optional softphone logos (operator judgment). |
| **Home consume** | `/opt/pbx3/cache/phoneimages/<vendor>/…` via zip URL |
| Package default | **Unset** |

### 9.1 ProVu copy rules (Grandstream + Gigaset)

**Base URL:** `https://www.provu.co.uk/products/{grandstream|gigaset}/{ModelFolder}/`

| Prefer | Skip |
|--------|------|
| **`{Model}-1-medium.jpg`** (v0) | thumbs, large, square, alt angles, PDFs |
| else `{Model}-medium.jpg` | |

**Grandstream:** Desk/WP (`GXP*`, `GRP*`, `WP*`). Skip ATAs / EXT.  
**Gigaset:** Handsets only (`*H`, Maxwell…). Skip bases, multi-packs, marketing dirs.

**Note:** Gigaset AstDB UA is often the **base**; library photo is often the **handset** — bridge later if needed.

**Image map (slice F) — clear rule:**

1. Vendor directory = lowercased `devicevendor` (`Yealink` → `yealink/`, `Snom` → `snom/`).  
2. Filename from **`devicemodel` token only** (ignore display parentheses):  
   - **Yealink:** first **three** chars of token → `T46U` / `T46G` → `T46.jpg` (SARK fuzzy).  
   - **Snom:** `snom` + token → `D717` → `snomD717.jpg`.  
   - **Others:** conventional `{token}.jpg` or small override map if library names disagree.  
   - **Softphones (optional):** e.g. `zoiper/zoiper.jpg` logo; else no file.  
3. Optional override map file may win over (2). Display string `T46U (Yealink)` is **never** a filesystem key.

| Display | Columns | Likely asset |
|---------|---------|--------------|
| `T31P (Yealink)` / `T46U (Yealink)` | Yealink + T31P / T46U | `yealink/T31.jpg`, `yealink/T46.jpg` |
| `D717 (Snom)` | Snom + D717 | `snom/snomD717.jpg` |
| `5.6.13 (Zoiper)` | Zoiper + 5.6.13 | `zoiper/zoiper.jpg` (optional logo) or none |
| WebRTC | — | none |
