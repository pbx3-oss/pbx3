# Fanvil provision sub-project (D3 slice)

**Status:** **Mule soak in progress** (2026-10-03). Seed streams on `main`; REGISTER auth quirk locked below. Not on the critical path for provision A–C10.  
**Owns:** Fanvil stock streams, lab soak, NAT row, optional FDMCS/RPS notes.  
**Parent:** `PROVISIONING_SERVER_REQUIREMENTS.md` §0.2 / §4.4–§4.6 · plan **D3** · recipe **`PROVISIONING_LAB_RECIPE.md` §5**.  
**Siblings:** **`GRANDSTREAM_PROVISION_SUBPROJECT.md`** · **`POLY_PROVISION_SUBPROJECT.md`**. Gigaset (same D3 bucket; separate when started).

---

## 0. Stance

| Item | Stance |
|------|--------|
| Format | **Module XML** under current FDPS-era firmwares (`VOIP_CONFIG_FILE` / `SIP_*` / `AUTOUPDATE_*`). Older CFG/TXT engines may still exist on legacy gear — mule will tell us. |
| Engine | Dumb `#INCLUDE` + substitute — **no** Fanvil-specific kernel. Authoring absorbs stanza shape (§4.6). |
| Discovery | Lab = **manual Static Provisioning Server** URL. **FDMCS** / RPS automation = later. |
| Docs trap | Fanvil **XML Operation Guide** = Push/Browser LCD XML — **not** auto-provision. Chatbot “standard” XML samples are unreliable; prefer phone export / Autoprovision Description / fielded templates. |
| mTLS | Fanvil CA already in ops `3pcerts.pem` pack; edge prove later if desired. |
| **SIP auth (UI)** | **Locked 2026-10-03 (Sirius 412 / `27b2mr`):** Fanvil/OEM docs often show **Username**=extension and **Authentication Name**=auth id as *different* values (3CX-style). That model assumes the registrar’s SIP user **is** the extension. **PBX3 does not:** PJSIP endpoint / digest identity = **shortuid** only; dialable **Name** (`412`) is not an Asterisk endpoint. Lab: User=`412` + Auth=`27b2mr` → home **404**; both fields = **`$sipuser`** → REGISTER OK. Put `$ext` in **Display Name** only. **Proxy User** leave blank (working UI). |

### 0.1 Working UI scrape → stream map (Sirius Fanvil, REGISTER green)

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

---

## 1. Already on `main`

| Artifact | Path |
|----------|------|
| Streams | `pbx3-1/opt/pbx3/provisioning/streams/fanvil.{Common,Extension,udp}` |
| Lab soak | `PROVISIONING_LAB_RECIPE.md` §5 |
| Stream notes | `provisioning/streams/README.md` |
| Kernel expand smoke | `provision-kernel-test.php` (Fanvil INCLUDE) |
| NAT checklist row | `pbx3-directory/docs/FLEET_DESK_PHONE_NAT.md` (Fanvil — blank) |

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

- [ ] One Fanvil model lab-green (provision + REGISTER + call/BYE)
- [ ] `fanvil.*` matches that firmware (export-aligned if possible)
- [ ] NAT row filled; recipe §5 exit checks ticked
- [ ] Short MkDocs note under phone-provisioning (optional) or defer to B2-style page later

Then either close Fanvil under D3 or open FDMCS / next brand.
