# Extension device model harvest (sidekick utility)

**Status:** Design re-locked **2026-08-26** (AstDB-home source) — **not scheduled** (nice-to-have; not first-out).  
**Prior lock (2026-08-09):** edge `GET /fleet/registrations` — **superseded** (more surface than needed).  
**Name:** `harvest-devicemodel` (script) / “UA model sidekick”.  
**Problem:** Without HTTP provisioning we no longer learn desk-phone **model** at config time. Customers liked handset images on the extension panel.  
**Opportunity:** Asterisk already stores each registered contact’s `user_agent` in AstDB under `registrar/contact`. A soft, optional sidekick on the **home** fills `ipphone.devicemodel`.  
**Related:** `ipphone.devicemodel` · `getimages.sh` (`PBX3_PHONEIMAGES_URL`) · `PROVISIONING_SERVER_REQUIREMENTS.md` (won't-do) · pbx3api `Ami` (Command / AstDB).  
**Sibling (parked):** **`PHONE_MODEL_DURABLE_VS_EPHEMERAL.md`** — posture **A** (durable soft harvest, this doc) vs **B** (ephemeral AstDB on list/edit render); optional fleet inventory (**stale-OK / not authoritative**). Choose A vs B before implement.

---

## 1. Stance (locked)

| # | Lock |
|---|------|
| S1 | **Optional.** Disabled / cron off → no-op exit 0. Solo and fleet use the **same** path. **Do not** require SBC for this feature. |
| S2 | **Async only.** Never on REGISTER, dial, GenAst, or SPA request path. |
| S3 | **Soft write.** Update `ipphone.devicemodel` only when NULL/empty **or** equal to last auto value. Never overwrite a non-empty value that differs from what we would write (operator / migrate ownership). |
| S4 | **Key = PJSIP endpoint shortuid** (AstDB `endpoint` / key prefix). Look up `ipphone` on this node by shortuid (+ cluster if ambiguous). **Never** by contact IP. |
| S5 | **Source = this home’s Asterisk AstDB** — `database show registrar/contact` (AMI `Action: Command` or privileged systemcmd). **No** edge registration API; **no** OpenSIPS SQL from the node. |
| S6 | **Do not** rewrite `ipphone.desc` (User) or `ipphone.device` (MAC vendor). Those stay as today. |
| S7 | Images are a **separate** concern: model string → asset lookup later; this utility’s deliverable is **`devicemodel` only**. |
| S8 | Only phones whose REGISTER lands on **this** Asterisk appear in AstDB. Edge-only contacts are out of scope (and not needed for home extension images). |
| S9 | **UA changes only on REGISTER.** Soft-filled `devicemodel` can lag at most until next REGISTER + next harvest. Prefer recording **last_seen** with the write (see sibling **`PHONE_MODEL_DURABLE_VS_EPHEMERAL.md`** §0). |

---

## 2. Roles

| Piece | Owns |
|-------|------|
| Asterisk (home) | Writes `registrar/contact/…` JSON including `user_agent` + `endpoint` on successful REGISTER (already) |
| **pbx3 home** | Cron/`harvest-devicemodel` → read AstDB → map UA → model → soft UPDATE `ipphone` |
| SPA (later) | Show image when `devicemodel` + asset pack present |

```text
Asterisk AstDB registrar/contact (endpoint, user_agent, expiration_time, …)
        → harvest-devicemodel on home (AMI Command or systemcmd)
        → UA mapper
        → UPDATE ipphone SET devicemodel=? WHERE shortuid=? AND … soft guards …
```

---

## 3. AstDB source

**CLI (lab proof):**

```text
asterisk -rx 'database show registrar/contact'
```

**Shape (PJSIP realtime / res_pjsip):** one AstDB entry per contact:

```text
/registrar/contact/{endpoint};@{hash}: {"endpoint":"jxpg8b","user_agent":"Yealink SIP-T46U 108.86.0.90","expiration_time":"…", …}
```

| Field | Use |
|-------|-----|
| `endpoint` | PJSIP endpoint = extension **shortuid** |
| `user_agent` | Input to UA → model map |
| `expiration_time` | Prefer non-expired; if multiple contacts for one endpoint, pick **latest** `expiration_time` |

**Access (implement either; prefer AMI for consistency with other ops):**

1. **AMI** — `Action: Command` / `Command: database show registrar/contact` (same family as other home AMI reads).  
2. **Privileged systemcmd** — equivalent CLI via existing internal privilege path if that is already the house pattern for CLI dumps.

Parse lines as `key: json`; ignore malformed JSON; skip rows without `endpoint` + `user_agent`.

**No new SBC / Gatekeeper API.**

---

## 4. Home utility

### 4.1 Packaging / invoke

| Item | Choice |
|------|--------|
| Path | `/opt/pbx3/scripts/harvest-devicemodel.sh` (+ small PHP helper for map + SQLite; AMI via existing Ami patterns or `asterisk -rx`) |
| Cron | Optional `/etc/cron.d/pbx3-harvest-devicemodel` — **commented/off by default** |
| Cadence | Every 15–60 minutes when enabled (REGISTER churn is slow) |
| Enable | Env e.g. `PBX3_HARVEST_DEVICEMODEL=1` (or cron present + enabled). Unset / `0` → exit 0 |

Exit codes: `0` success or disabled; `1` AMI/CLI/parse/DB error (cron-mailable); never touch call plane.

### 4.2 Algorithm

1. If disabled → log + exit 0.  
2. Dump `registrar/contact` (AMI or systemcmd).  
3. Collapse to one row per `endpoint` (latest non-expired contact).  
4. For each endpoint:  
   - Resolve `ipphone` by `shortuid = endpoint` on this node’s `sqlite.db` (scope by cluster if needed).  
   - `model = map_ua(user_agent)`; skip if unmapped.  
   - Soft UPDATE `devicemodel` per S3.  
5. Log counts: contacts / endpoints / written / skipped(owned) / unmapped / missing ipphone.

### 4.3 UA → model map (v0 starter)

**Source (operator, 2026-08-27):** not every popular vendor — a **start**. Ship as built-in; extend later via `/opt/pbx3/etc/ua-model-map.json` (optional).

**Provenance:** These patterns were written for **provisioning HTTP(S)** request `User-Agent` strings (handset fetching config), **not** necessarily SIP `User-Agent` on REGISTER. Wire forms can **differ slightly** (e.g. Snom `-SIP` vs `snomD717/…` in AstDB). Treat the array as a **seed**; tune against live `registrar/contact` UAs (lab + field) and keep dual patterns where both appear.

**Match order matters:** try **`yealink`** (SIP-…) **before** **`yealinkDECT`** (broader). First match wins.

| Key | Regex (PCRE) | Capture → `devicemodel` (v0 display) |
|-----|--------------|--------------------------------------|
| `cisco` | `Cisco-CP-(\d{4}-3PCC)` | `Cisco $1` (e.g. `Cisco 7841-3PCC`) |
| `polycom` | `PolycomVVX-(VVX_\w+)\-UA` | `Polycom $1` |
| `snom` | `(snom\w+)\-SIP` **or** `^(snomD\d+)` / `(snom\w+)[/ ]` | Title-case model from capture. **Two wire forms seen:** legacy/SARK-era `…-SIP`, lab `.31` `snomD717/10.1.198.19` (slash + firmware). Keep **both** patterns — old regex vs vendor change is unresolved; dual match is cheap. |
| `yealink` | `Yealink\sSIP-([\w-]+)\s` | `Yealink $1` (e.g. `Yealink T46U`) |
| `yealinkDECT` | `Yealink\s([\w-]+)\s` | `Yealink $1` (W-series / non-SIP- token forms) |
| `panasonic` | `Panasonic_(KX-\w+)\/` | `Panasonic $1` |
| `aastra` | `Aastra(\d{4}i)\s` | `Aastra $1` |
| `fanvil` | `Fanvil\s(\w+)\s` | `Fanvil $1` |

```php
// Canonical starter (copy into helper when implementing)
$manufacturer_regex = [
	'cisco' => 'Cisco-CP-(\d{4}-3PCC)',
	'polycom' => 'PolycomVVX-(VVX_\w+)\-UA',
	'snom' => '(snom\w+)\-SIP',           // e.g. snomD785-SIP…
	'snom_slash' => '^(snomD\d+)',        // e.g. snomD717/10.1.198.19 — lab .31
	'yealink' => 'Yealink\sSIP-([\w-]+)\s',
	'yealinkDECT' => 'Yealink\s([\w-]+)\s',
	'panasonic' => 'Panasonic_(KX-\w+)\/',
	'aastra' => 'Aastra(\d{4}i)\s',
	'fanvil' => 'Fanvil\s(\w+)\s',
];
```

**Also keep (not in array above):** `Browser Phone` / `SIPJS` / `JsSIP` → `WebRTC`.

**Brand coverage (v0 base = popular US + Europe desks)** — not “every vendor in the old image zip.” Prefer **live AstDB SIP UAs**. Provision HTTP UAs are a seed only. Soak list still useful: **`pbx3sbc/workingdocs/SBC_SOAK_ENDPOINT_REFERENCE.md`**.

| Region weight | Brands (desk) | Regex / notes |
|---------------|---------------|---------------|
| **Both US + EU (must)** | **Yealink**, **Fanvil** | Seeded; tune SIP vs provision UA |
| **EU-strong** | **Snom** (VTech owns Snom; VTech own-brand SIP handsets → **ignore**) | Seeded + slash form; dual UA forms |
| **US-strong / global SMB** | **Grandstream** | **Need** SIP UA sample — operator ordering lab unit (2026-08-27) |
| **EU (esp. DACH) DECT/IP** | **Gigaset** | **Need** SIP UA sample — operator ordering lab DECT unit (2026-08-27) |
| **Enterprise both sides** | **Poly** (Polycom), **Cisco** (3PCC / multiplatform) | Seeded for common forms; not SMB default |
| **Legacy EU** | **Panasonic**, **Aastra**/Mitel heritage | Seeded; declining new-buy share — keep for installed base |
| **Softphones** | Zoiper, Bria, Linphone | Label or skip image; capture UA when seen (Zoiper lab `Z 5.6…`) |

**Out of scope for v0 brand chase:** VTech (exited own SIP handset line after Snom acquisition), Htek/Mitel/Avaya unless a customer forces a sample.

**Snom note:** Starter had only `-SIP` (likely provisioning HTTP UA). Lab AstDB SIP UA shows slash+firmware. **HTTP provision UA ≠ SIP REGISTER UA** in general — keep dual forms; expand from AstDB samples, don’t assume provision scrapers are complete for harvest.

Unknown UA → skip (leave `devicemodel` alone). Firmware tokens ignored when outside the capture.

### 4.4 Lab fixtures

**Lab home `.31` (2026-08-26) — AstDB proof:**

| shortuid | User-Agent | Expected `devicemodel` |
|----------|------------|-------------------------|
| `jxpg8b` | `Yealink SIP-T46U 108.86.0.90` | `Yealink T46U` (yealink) |
| `pqjfth` | `snomD717/10.1.198.19` | `Snom D717` via `snom_slash` |
| `pz9vmk` | `Z 5.6.13 v2.10.20.14` | *(unmapped — skip)* |

**Earlier Magrathea-era samples (still valid map cases if those endpoints register on a home):**

| shortuid | User-Agent | Expected `devicemodel` |
|----------|------------|-------------------------|
| `59507r` | `snomD717/10.1.198.19` | `Snom D717` via `snom_slash` |
| `q5zjhw` | `Yealink SIP-T31P 124.86.0.40` | `Yealink T31P` |
| `1nvd41` / `77k4xz` / `hb64kj` | `Yealink SIP-T46U …` | `Yealink T46U` |
| `e7sa15gi` | `Browser Phone … SIPJS …` | `WebRTC` |

---

## 5. Schema / API / SPA (follow-ons)

| Layer | Now | When implementing harvest |
|-------|-----|---------------------------|
| DB | `ipphone.devicemodel` exists; guarded | Soft UPDATE from utility only |
| pbx3api | Not in mass-assign | Expose read-only on extension show/list when useful |
| SPA list | User=`desc`, Device=`device` (vendor) | Optional later: model column or icon from `devicemodel` |
| Images | Historic pack URL known (see §9); still opt-in via `PBX3_PHONEIMAGES_URL` | Map `devicemodel` → file under `/opt/pbx3/cache/phoneimages`; edit panel image |

**List column reminder:** User ≠ model (migrate often stuffed model-ish strings into `desc`). Device = MAC **vendor**. Harvest fills **`devicemodel`** only.

---

## 6. Non-goals (v1)

- HTTP phone provisioning for images.  
- Edge / OpenSIPS registration-summary API (superseded).  
- Hardwiring OpenSIPS DB credentials on the home.  
- Stomping `desc` / `device`.  
- Perfect vendor coverage.  
- Directory / Gatekeeper / SBC in the loop.  
- Call-path or GenAst dependency.  
- Harvesting contacts that never REGISTER to this Asterisk.

---

## 7. Implement slices (when scheduled)

| Slice | Deliverable |
|-------|-------------|
| **A** | Read + parse `registrar/contact` (AMI or systemcmd) → endpoint / UA / expiry |
| **B** | UA mapper unit tests (fixtures in §4.4) |
| **C** | Soft UPDATE `ipphone.devicemodel` + optional cron (off by default) |
| **D** | Lab: enable on `.31` (and/or golden); verify mapped shortuids |
| **E** | SPA image / model display + durable phoneimages host (see §9) |

---

## 8. Acceptance

- Disabled → exit 0; no DB writes.  
- §4.4 mapped fixtures → correct `devicemodel` after one run.  
- Non-empty foreign `devicemodel` unchanged on re-run.  
- Unmapped UA → no write.  
- Asterisk / AMI down → exit 1; sqlite unchanged.  
- No change to REGISTER / dial behaviour.  
- No dependency on SBC registration API.

---

## 9. Phoneimages pack (ops)

| Item | Value |
|------|--------|
| Historic URL | `http://sailpbx.com/phoneimages.zip` (pre-scrub; **dead** as of 2026-08-09) |
| Local unpack (lab) | **`~/GiT/nonGitStuff/phoneimages/`** — ~3.9M, 138 JPEGs, vendor dirs: aastra, cisco, fanvil, panasonic, polycom, snom, vtech, yealink |
| Consume on node | Tree must land as `/opt/pbx3/cache/phoneimages/<vendor>/…` (same layout `getimages.sh` expects after unzip). Lab: rsync this tree, or zip it and set `PBX3_PHONEIMAGES_URL`. |
| Package default | **Unset** — do not bake a third-party host into the product tree |

**Filename conventions (slice E map from `devicemodel`):**

| Harvested `devicemodel` | Likely asset |
|-------------------------|--------------|
| `Yealink T31P` / `Yealink T46U` | `yealink/T31.jpg`, `yealink/T46.jpg` (strip trailing letter variants) |
| `Snom D717` | `snom/snomD717.jpg` |
| `WebRTC` | none (skip image) |

Yealink files are short model (`T31.jpg`) without P/G/U/W suffix — mapper must normalize.
