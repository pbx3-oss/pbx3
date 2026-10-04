# Fanvil provision sub-project (D3 slice)

**Status:** **Provision path lab green** (2026-10-03) — `sysConf` streams; mTLS CA tip still open. Not on the critical path for provision A–C10.  
**Lab mule:** **Fanvil X3U Pro** · software **2.12.20** · Sirius **412** / `27b2mr`.  
**Owns:** Fanvil stock streams, lab soak, NAT row, optional FDMCS/RPS notes.  
**Parent:** `PROVISIONING_SERVER_REQUIREMENTS.md` §0.2 / §4.4–§4.6 · plan **D3** · recipe **`PROVISIONING_LAB_RECIPE.md` §5**.  
**Siblings:** **`GRANDSTREAM_PROVISION_SUBPROJECT.md`** · **`POLY_PROVISION_SUBPROJECT.md`**. Gigaset (same D3 bucket; separate when started).

---

## 0. Stance

| Item | Stance |
|------|--------|
| Format | **X3U / X3U Pro ≥2.2.10:** auto-provision = **`sysConf`** (camelCase; same family as UI Config Export). Older `VOIP_CONFIG_FILE` module XML is ignored on 2.12 — lab 2026-10-03 GET **200** but phone did not apply. `FlashProtocol` **5** = HTTPS. |
| Engine | Dumb `#INCLUDE` + substitute — **no** Fanvil-specific kernel. Authoring absorbs stanza shape (§4.6). |
| Discovery | Lab = **manual Static Provisioning Server** URL. **FDMCS** / RPS automation = later. |
| Docs trap | Fanvil **XML Operation Guide** = Push/Browser LCD XML — **not** auto-provision. Chatbot “standard” XML samples are unreliable; prefer phone export / Autoprovision Description / fielded templates. |
| Export fixture | **Curate only** — not a stream source. Full redacted: ops `devdocs/provisioning/fanvil/x3u-pro-2.12.20-sysconf-export.xml` · excerpt `workingdocs/samples/fanvil-x3u-pro-sysconf-export.xml`. Use for field names / NAT/timezone checks if soak fails; do not wholesale import. |
| mTLS | Device presents Fanvil client cert on HTTPS. Edge needs **official Fanvil Root CA** (Partner Portal / Support — not public Mozilla). Ops `3pcerts` #8 may be stale. Lab 2026-10-03: Magrathea **FAILED verify** / 400 until CA tipped. |
| **SIP auth (UI)** | **Locked 2026-10-03 (X3U Pro 2.12.20, Sirius 412 / `27b2mr`):** Fanvil/OEM docs often show **Username**=extension and **Authentication Name**=auth id as *different* values (3CX-style). That model assumes the registrar’s SIP user **is** the extension. **PBX3 does not:** PJSIP endpoint / digest identity = **shortuid** only; dialable **Name** (`412`) is not an Asterisk endpoint. Lab: User=`412` + Auth=`27b2mr` → home **404**; both fields = **`$sipuser`** → REGISTER OK. Put `$ext` in **Display Name** only. **Proxy User** leave blank (working UI). |

### 0.1 Working UI scrape → stream map (X3U Pro 2.12.20, REGISTER green)

Scraped from phone **Line → SIP → Register Settings** HTML (`lines.htm` form fields). UI label **SIP User** (not “Username”).

| UI label | Form `name` | Working value | Stream tag | Substitute |
|----------|-------------|---------------|------------|------------|
| SIP User | `SIP_PhoneNum_R` | `27b2mr` | `Phone_Number` | `$sipuser` |
| Authentication User | `SIP_RegUser_R` | `27b2mr` | `Register_User` | `$sipuser` |
| Display Name | `SIP_DisPlayName_R` | `412` | `Display_Name` | `$ext` |
| Authentication Password | `SIP_RegPasswd_R` | (secret) | `Register_Pswd` | `$password` |
| Realm | `SIP_LocalDomain_R` | *(empty)* | — | leave empty |
| Server Name | `SIP_Name_RW` | *(empty)* | `Sip_Name` | empty |
| Server Address | `SIP_RegAddr_R` | `hf3zzv.pbx3.com` | `Register_Addr` | `$sipdomain` |
| Server Port | `SIP_RegPort_R` | `5060` | `Register_Port` | `$bindport` |
| Proxy Server Address | `SIP_ProxyAddr_R` | `sbc.pbx3.com` | `Proxy_Addr` | `$outbound` |
| Proxy Server Port | `SIP_ProxyPort_R` | `5060` | `Proxy_Port` | `$bindport` |
| Proxy User | `SIP_ProxyUser_R` | *(empty)* | `Proxy_User` | empty |
| Proxy Password | `SIP_ProxyPasswd_R` | *(empty)* | `Proxy_Pswd` | empty |
| Transport | `SIP_Transport_RW` | UDP (`0`) | `Transport` | `0` |
| Registration Expiration | `SIP_ExpireTime_RW` | `3600` | `Register_TTL` | `3600` |

Line picker showed `412@SIP1` (cosmetic); REGISTER identity is still shortuid in **SIP User** / **Authentication User**.

**Feature codes:** Fanvil sends PBX3 star-codes (`*56*`, `*21*`, …) **OOTB** — no phone dialplan edit. Grandstream needs an extra `*xx*` pattern: **`GRANDSTREAM_PROVISION_SUBPROJECT.md` §0.3**.

**Ghost calls / INVITE source:** X3U has **no** Yealink/GS/Poly-style “accept SIP from proxy only”. Lab 2026-10-03: `BanAnonymous` / `AllowIPCall=0` / per-line **`SignalPort` alone** did **not** stop LAN `:5060` INVITEs (Contact moved to 5160 but global listen stayed 5060). Stream sets **`BanAnonymous=1`**, global **`SIPPort=5160`**, and line **`SignalPort=5160`** (obscurity; REGISTER still to `$bindport` on SBC).

### 0.1a UI export (`sysConf`) ↔ stream tags (2026-10-03)

Same working SIP row as §0.1, from Config Export. Export uses camelCase; streams keep underscore module tags (phone auto-provision accepts that dialect per Fanvil Autoprovision Description).

Streams use the same camelCase tags as export (`PhoneNumber`, `RegisterAddr`, …). `FlashProtocol` **5** = HTTPS. Common ships UK timezone; Sirius lab may still show UTC-5 until site-overridden.

### 0.2 Timezone (lab 2026-10-03)

| Knob | OOTB | Notes |
|------|------|--------|
| **Time Sync (SNTP)** | **ON** | Syncs UTC clock from NTP — does **not** set local display zone |
| **Time zone / region** | **Beijing** (China) | Factory default; phone shows Beijing wall time until changed |

**Sirius lab:** forced **UTC-5** (Eastern) manually. Stock `fanvil.Common` already ships UK London (`Time_Zone` / `Time_Zone_Name` + `Enable_SNTP`) — same class as Yealink/Snom. Site streams must set the zone for that locale; **do not assume SNTP ON alone fixes the clock face**.

---

## 1. Already on `main`

| Artifact | Path |
|----------|------|
| Streams | `pbx3-1/opt/pbx3/provisioning/streams/fanvil.{Common,Extension,udp}` |
| Lab soak | `PROVISIONING_LAB_RECIPE.md` §5 |
| Stream notes | `provisioning/streams/README.md` |
| Kernel expand smoke | `provision-kernel-test.php` (Fanvil INCLUDE) |
| NAT checklist row | `pbx3-directory/docs/FLEET_DESK_PHONE_NAT.md` — **STUN Off** lab-green (Sirius 412) |

Extension entry for mule:

```text
#INCLUDE fanvil.Extension
#INCLUDE fanvil.udp
```

---

## 2. When the mule arrives (resume checklist)

1. Tip `fanvil.*` onto host home if not already.
2. Spare extension: MAC, `sndcreds=Once`, stream above.
3. Claim MAC / map sync (fleet).
4. Phone UI → Static Provision → `https://provision.{apex}:41363/provisioning` (HTTPS, after reboot).
5. Exit: GET **200** → REGISTER via SBC → audio + BYE; fill NAT row.
6. If UI offers **config export/download** (Snom/Yealink-style): save under ops `devdocs/provisioning/fanvil/` and reshape `fanvil.*` to match firmware dialect.
7. Tune as needed: `Download_Protocol` 4 vs 5; STUN/`NAT_Type`; tag names vs export.

**Out of scope for first pass:** BLF/DSS keys, FDMCS enroll automation, full OEM parameter dump, GS/Gigaset.

---

## 3. Exit (this sub-project slice)

- [x] Manual SIP REGISTER + calls OK (**X3U Pro 2.12.20**, Sirius 412 / `27b2mr`, STUN Off default)
- [x] OOTB timezone **Beijing** despite SNTP ON — set site zone (lab UTC-5); streams ship UK (§0.2)
- [x] Provision path lab-green — `sysConf` GET → REGISTER (**2026-10-03**)
- [x] `fanvil.*` = sysConf for ≥2.2.10 (legacy module XML ignored)
- [x] NAT row filled (STUN Off / `NATType=0`)
- [x] Recipe §5 provision exit checks (mTLS restore still open)
- [ ] Tip Fanvil Root CA + restore Magrathea `ssl_verify_client optional`
- [ ] Short MkDocs note under phone-provisioning (optional) or defer to B2-style page later

Then either close Fanvil under D3 or open FDMCS / next brand.
