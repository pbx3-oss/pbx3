# Extension device model harvest (sidekick utility)

**Status:** Design locked for implement **2026-08-09** — **not scheduled** (nice-to-have; not first-out).  
**Name:** `harvest-devicemodel` (script) / “UA model sidekick”.  
**Problem:** Without HTTP provisioning we no longer learn desk-phone **model** at config time. Customers liked handset images on the extension panel.  
**Opportunity:** Fleet edge already stores `location.user_agent` on REGISTER. A soft, optional sidekick fills `ipphone.devicemodel` on the home.  
**Related:** Rule **1** / **7** · `Device.imageurl` · `getimages.sh` (`PBX3_PHONEIMAGES_URL`) · `PROVISIONING_SERVER_REQUIREMENTS.md` (maybe don’t build provisioner) · Magrathea Filament **Locations** (UA already visible).

---

## 1. Stance (locked)

| # | Lock |
|---|------|
| S1 | **Optional.** Unset config → no-op exit 0. Solo/direct without edge stays valid. **Do not** mandate SBC for core PBX3. |
| S2 | **Async only.** Never on REGISTER, dial, GenAst, or SPA request path. |
| S3 | **Soft write.** Update `ipphone.devicemodel` only when NULL/empty **or** equal to last auto value. Never overwrite a non-empty value that differs from what we would write (operator / migrate ownership). |
| S4 | **Key = shortuid + tenant domain.** Never by contact IP (one handset → many AoRs). |
| S5 | Home talks to edge via a **registration-summary API** (token), not OpenSIPS SQL from the node (Rule 7). First adapter = Magrathea / `pbx3sbc-admin`. |
| S6 | **Do not** rewrite `ipphone.desc` (User) or `ipphone.device` (MAC vendor). Those stay as today. |
| S7 | Images are a **separate** concern: model string → asset lookup later; this utility’s deliverable is **`devicemodel` only**. |

---

## 2. Roles

| Piece | Owns |
|-------|------|
| OpenSIPS | Writes `location.user_agent` on successful REGISTER (already) |
| **pbx3sbc-admin** | Machine-readable **registration summary** for homes (new thin fleet route) |
| **pbx3 home** | Cron/`harvest-devicemodel.sh` → map UA → model → soft UPDATE `ipphone` |
| SPA (later) | Show image when `devicemodel` + asset pack present |

```text
Magrathea location (username, domain, user_agent, expires)
        → GET /fleet/registrations  (fleet token)
        → harvest-devicemodel on home (filter domains → this node’s tenants)
        → UA mapper
        → UPDATE ipphone SET devicemodel=? WHERE shortuid=? AND cluster=? AND (devicemodel IS NULL OR trim(devicemodel)='')
```

---

## 3. Edge API (Magrathea / pbx3sbc-admin)

**Add** under existing `fleet.token` middleware (same family as `GET /fleet/health`):

`GET /api/fleet/registrations`

**Query (optional):** `domain=` (repeatable or comma-separated) to scope; omit = all non-expired.

**Response (JSON):**

```json
{
  "generated_at": "2026-08-09T15:32:16Z",
  "registrations": [
    {
      "username": "q5zjhw",
      "domain": "18c8z3.pbx3.com",
      "user_agent": "Yealink SIP-T31P 124.86.0.40",
      "expires": 1723219936,
      "contact": "sip:q5zjhw@192.168.1.97:5060"
    }
  ]
}
```

**Rules:**

- Read-only projection of usrloc `location` (same source as Filament Locations).  
- Prefer **non-expired** rows only (`expires > now`).  
- If multiple contacts per username@domain, pick **latest `last_modified`** (or any stable rule; document it).  
- No OpenSIPS vocabulary required in the **home** script beyond this JSON.

**Auth:** existing fleet edge token (`fleet.token`). Homes get URL + token from operator env / future fleet meta — **not** baked into SPA.

---

## 4. Home utility

### 4.1 Packaging / invoke

| Item | Choice |
|------|--------|
| Path | `/opt/pbx3/scripts/harvest-devicemodel.sh` (+ small PHP or Python helper for map + SQLite) |
| Cron | Optional `/etc/cron.d/pbx3-harvest-devicemodel` — **commented/off by default** |
| Cadence | Every 15–60 minutes when enabled (REGISTER churn is slow) |
| Config | Env or `/opt/pbx3/etc/harvest-devicemodel.env`: `PBX3_REG_SUMMARY_URL`, `PBX3_REG_SUMMARY_TOKEN` |

```bash
# no-op when unset
PBX3_REG_SUMMARY_URL=https://sbc.example/api/fleet/registrations
PBX3_REG_SUMMARY_TOKEN=…
```

Exit codes: `0` success or disabled; `1` config/HTTP/parse error (cron-mailable); never touch call plane.

### 4.2 Algorithm

1. If URL/token unset → log + exit 0.  
2. `GET` registrations JSON (TLS verify on; allow lab override only via explicit insecure flag if ever needed).  
3. Load this node’s tenants: `cluster.fqdn` / `cluster.shortuid` map from `sqlite.db`.  
4. For each registration where `domain` matches a local tenant FQDN:  
   - Resolve `ipphone` by `shortuid = username` and `cluster = that tenant’s shortuid` (or cluster pkey→shortuid — match how SPA joins).  
   - `model = map_ua(user_agent)`; skip if unmapped.  
   - Soft UPDATE `devicemodel` per S3.  
5. Log counts: fetched / matched / written / skipped(owned) / unmapped.

### 4.3 UA → model map (v0, lab-proven)

| Pattern | `devicemodel` value |
|---------|---------------------|
| `Yealink SIP-T(\w+)` | `Yealink T$1` (e.g. `Yealink T31P`, `Yealink T46U`) |
| `snomD(\d+)` or `snomD717/` | `Snom D$1` / `Snom D717` |
| `Browser Phone` / `SIPJS` / `JsSIP` | `WebRTC` |

Firmware tokens ignored. Unknown UA → skip (leave `devicemodel` alone).

Extensible later via `/opt/pbx3/etc/ua-model-map.json` (optional); ship built-in regexes first.

### 4.4 Lab fixtures (Magrathea, 2026-08-09)

| Domain | shortuid | User-Agent | Expected `devicemodel` |
|--------|----------|------------|-------------------------|
| `9wvvnb.pbx3.com` | `59507r` | `snomD717/10.1.198.19` | `Snom D717` |
| `18c8z3.pbx3.com` | `q5zjhw` | `Yealink SIP-T31P 124.86.0.40` | `Yealink T31P` |
| `18c8z3.pbx3.com` | `1nvd41` | `Yealink SIP-T46U 108.86.0.90` | `Yealink T46U` |
| `dhbm8x.pbx3.com` | `hb64kj` | `Yealink SIP-T46U 108.86.0.90` | `Yealink T46U` |
| `9wvvnb.pbx3.com` | `77k4xz` | `Yealink SIP-T46U 108.86.0.90` | `Yealink T46U` |
| `dhbm8x.pbx3.com` | `fkdd5d` | `snomD717/10.1.198.19` | `Snom D717` |
| `dhbm8x.pbx3.com` | `xqhy1q` | `Yealink SIP-T31P 124.86.0.40` | `Yealink T31P` |
| `dhbm8x.pbx3.com` | `e7sa15gi` | `Browser Phone 0.3.24 (SIPJS -…` | `WebRTC` |

Same LAN IP on multiple AoRs is expected — join must be shortuid@domain.

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
- Hardwiring OpenSIPS DB credentials on the home.  
- Stomping `desc` / `device`.  
- Perfect vendor coverage.  
- Directory / Gatekeeper in the loop (v1 = home↔edge only).  
- Call-path or GenAst dependency.

---

## 7. Implement slices (when scheduled)

| Slice | Deliverable |
|-------|-------------|
| **A** | `GET /api/fleet/registrations` on **pbx3sbc-admin** + token auth |
| **B** | UA mapper unit tests (fixtures in §4.4) |
| **C** | `harvest-devicemodel` on **pbx3** + optional cron (off by default) |
| **D** | Lab: enable on golden/kildare against Magrathea; verify `devicemodel` |
| **E** | SPA image / model display + durable phoneimages host (see §9) |

---

## 8. Acceptance

- Disabled config → exit 0; no DB writes.  
- Magrathea fixtures §4.4 → correct `devicemodel` on matching homes after one run.  
- Non-empty foreign `devicemodel` unchanged on re-run.  
- Unmapped UA → no write.  
- Edge down / 401 → exit 1; sqlite unchanged.  
- No change to REGISTER / dial behaviour.

---

## 9. Phoneimages pack (ops)

| Item | Value |
|------|--------|
| Historic URL | `http://sailpbx.com/phoneimages.zip` (pre-scrub `getimages.sh`; **dead** as of 2026-08-09 — 302 to sail6-docs HTML) |
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
