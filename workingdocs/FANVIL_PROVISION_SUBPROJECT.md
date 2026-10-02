# Fanvil provision sub-project (D3 slice)

**Status:** **Parked / as-and-when** (2026-10-02). Seed streams + lab recipe ready; **mule handset pending**. Not on the critical path for provision A–C10.  
**Owns:** Fanvil stock streams, lab soak, NAT row, optional FDMCS/RPS notes.  
**Parent:** `PROVISIONING_SERVER_REQUIREMENTS.md` §0.2 / §4.4–§4.6 · plan **D3** · recipe **`PROVISIONING_LAB_RECIPE.md` §5**.  
**Sibling later:** Grandstream / Gigaset (same D3 bucket; separate when started).

---

## 0. Stance

| Item | Stance |
|------|--------|
| Format | **Module XML** under current FDPS-era firmwares (`VOIP_CONFIG_FILE` / `SIP_*` / `AUTOUPDATE_*`). Older CFG/TXT engines may still exist on legacy gear — mule will tell us. |
| Engine | Dumb `#INCLUDE` + substitute — **no** Fanvil-specific kernel. Authoring absorbs stanza shape (§4.6). |
| Discovery | Lab = **manual Static Provisioning Server** URL. **FDMCS** / RPS automation = later. |
| Docs trap | Fanvil **XML Operation Guide** = Push/Browser LCD XML — **not** auto-provision. Chatbot “standard” XML samples are unreliable; prefer phone export / Autoprovision Description / fielded templates. |
| mTLS | Fanvil CA already in ops `3pcerts.pem` pack; edge prove later if desired. |

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
