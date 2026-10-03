# Grandstream provision sub-project (D3 slice)

**Status:** **Lab green 2026-10-03** — GRP2602P stream soak (MAC **EC74D7438221** / 408): **`P237` Config Server Path**, **`P52=4` Auto**, far BYE OK. Optional vs GDMS.  
**Lab mule:** **Grandstream GRP2602P** · firmware **1.0.7.3**.  
**Streams:** `grandstream.{Common,Extension,udp}` · sample `workingdocs/samples/grandstream-grp2602p-cfg-template.xml`.  
**Owns:** Optional Grandstream stock streams (`gs_provision` / P-values), lab soak when using our listener, NAT row, GDMS posture docs. **Not** a mandate that GS sites use our provision server.  
**Parent:** `PROVISIONING_SERVER_REQUIREMENTS.md` §0.2 / §4.4–§4.6 · plan **D3** · recipe **`PROVISIONING_LAB_RECIPE.md` §6**.  
**Siblings:** **`FANVIL_PROVISION_SUBPROJECT.md`** · **`POLY_PROVISION_SUBPROJECT.md`**. Gigaset (same D3 bucket; separate when started).

**OEM guide:** [Grandstream SIP Device Provisioning Guide](https://www.grandstream.com/hubfs/Product_Documentation/gs_provisioning_guide.pdf) · P-value templates: [support/tools](https://www.grandstream.com/support/tools).

---

## 0. Stance

| Item | Stance |
|------|--------|
| Format | **XML P-value bag** (`<gs_provision>` → `<config>` → `<Pnnn>…</Pnnn>`). Legacy binary `cfg{mac}.bin` exists; we target **XML only** for stock streams. |
| Authoring | Opaque `P271`, `P237`, … map to web-UI knobs. **Do not invent P-numbers** — lift from the model’s firmware configuration template (CSV/XML from Grandstream tools). |
| File names | Phone requests **`cfg{mac}.xml`** (lowercase mac, no colons), then model / generic **`cfg.xml`** fallback. Our edge today serves `…/provisioning/{mac}.cfg` and `?mac=` — mule may need URL/path alignment or phone Config Server Path + filename convention; settle on first soak. |
| Engine | Dumb `#INCLUDE` + substitute — **no** Grandstream-specific kernel. |
| Discovery | **GDMS free** → preferred operator path for many GS sites. **Two supported postures:** (1) **GDMS end-to-end** (templates in GDMS; **no** our provision listener) — OK / no barrier; (2) GDMS/GAPS **redirect** → our `provision.{apex}` when home-rendered stream wanted. Lab mule may still use manual Config Server Path. |
| mTLS | GS client CA still open for public-edge (ops inventory); lab = manual URL + `optional` edge is fine. Need only if phones hit **our** edge. |
| **Manual SIP (UI)** | **Locked 2026-10-03:** Straightforward. **SIP User ID** = shortuid; **Account Name** may be dialable ext (display). UI also offers **Authenticate ID** / Auth UID — **leave unused** when SIP User ID is already shortuid (lab: unused → REGISTER OK). Contrast Fanvil, where both User and Auth User must be shortuid. |

---

## 0.1 Product posture (locked 2026-10-02)

**We do not need Grandstream customers to use our provisioning server.** Free GDMS removes the “must build GS streams day one” pressure. Stock `grandstream.*` remains useful for sites that want secrets/home MAC map / same fleet provision URL as Yealink/Snom — optional, not mandatory for GS to work on PBX3.

### 0.2 Working manual SIP account (GRP2602P 1.0.7.3, REGISTER green)

Operator fields that worked (Accounts → Account 1 / SIP Settings — labels as on phone UI):

| UI label | Working value | PBX3 meaning |
|----------|---------------|--------------|
| Account Name | `408` | Dialable Name / label only |
| SIP Server | `hf3zzv.pbx3.com` | `$sipdomain` (tenant FQDN) |
| Outbound Proxy | `sbc.pbx3.com` | `$outbound` (SBC) |
| SIP User ID | `74y2h3` | `$sipuser` (shortuid) |
| Authenticate ID (Auth UID) | *(unused)* | Optional; leave blank when SIP User ID = shortuid |
| SIP Authentication Password | *(secret)* | `$password` |

**SIP User ID** alone carries the PJSIP identity when Auth UID is blank. Fanvil needs both fields set: **`FANVIL_PROVISION_SUBPROJECT.md` §0.1**.

### 0.3 Dial plan (feature codes) — locked 2026-10-03 (GRP2602P 1.0.7.3)

Grandstream evaluates an **Account dial plan** (one pattern per line) **before** sending INVITE. Stock defaults do **not** pass PBX3 star-codes that end with `*` and have no trailing digits (e.g. `*56*`, `*21*`).

**OOTB patterns (GRP2602P):**

```text
x+
\+x+
*x+
*xx*x+
```

| Pattern | Why it fails our codes |
|---------|------------------------|
| `*x+` | Digits after `*`, no trailing `*` |
| `*xx*x+` | Needs more digits **after** the second `*` |

**Required add (lab):** one more line:

```text
*xx*
```

That matches `*56*`, `*21*`, and the same shape of RCS / CAGI feature codes (`CALL_TYPE_INVENTORY.md`).

**P-value (GRP2602P template):** **P290** = Account 1 dial plan.

**Stream / GDMS string (locked shape):** keep OOTB family + `*xx*`:

```text
{ x+ | \+x+ | *x+ | *xx*x+ | *xx* | [3469]11 }
```

| Piece | Role |
|-------|------|
| `x+` | Extensions / digit strings |
| `\+x+` | E.164-style `+…` (OOTB) |
| `*x+` | `*97`, `*72`, … (digits after `*`) |
| `*xx*x+` | Multi-tier `*xx*…` with more digits |
| `*xx*` | **Required** — codes that **end** on second `*` (`*56*`, `*21*`). Chatbot plans that omit this **fail** PBX3 feature codes |
| `[3469]11` | 311/411/611/911-style |

**Fanvil:** no phone dialplan change — feature codes work OOTB.

**XML:** escape `<` `>` `&` inside P290 if a pattern uses them.

---

## 1. Template map (GRP2602P starter, 2026-10-03)

From `workingdocs/samples/grandstream-grp2602p-cfg-template.xml` (`<gs_provision>` / `<Pnnn>`):

| P-value | Template meaning | PBX3 stream target |
|---------|------------------|--------------------|
| **P271** | Account active | `1` |
| **P270** | Account Name | `$ext` or `$desc` (lab used dialable **408**) |
| **P47** | SIP Server | `$sipdomain` |
| **P48** | Outbound Proxy | `$outbound` — **host/FQDN only** (no `://`; chatbot paste often injects junk) |
| **P103** | DNS Mode | `0` = A Record for fleet SBC FQDN (not NAPTR/SRV) |
| **P35** | SIP User ID | `$sipuser` |
| **P36** | Authenticate ID | omit / empty (lab: unused when User ID = shortuid) |
| **P34** | Auth password | `$password` (sndcreds) |
| **P3** | Display Name | `$desc` |
| **P52** | Account NAT Traversal | **`4` = Auto** — locked (2026-10-03 soak). UI order: `0=No, 1=STUN, 2=Keep-Alive, 3=UPnP, 4=Auto, 5=VPN`. **`0`** → far BYE fail. |
| **P76** | STUN server | **omit** from stream — Auto + OBP was enough; STUN alone did not fix BYE. |
| **P1119** | NAT keep-alive interval | `30` (optional with Auto) |
| **P30** | Local SIP port | leave / `5060` |
| **P212** | Config Upgrade Via | `2` = HTTPS |
| **P237** | **Config Server Path** | `$provpath` → `provision.pbx3.com:41363/provisioning` (GS guide; **not** P192) |
| **P192** | Firmware Server Path | **omit** — never point at provision (lab bug: P192←prov caused `grp2600fw.bin` GETs) |
| **P194** | Automatic Upgrade | `0` = No (lab) |
| **P2** | Web UI admin password | `$padminpass` ← **cluster.padminpass** (lab default **44068**). Globals `PADMINPASS` override only. User web **P1362** / `$puserpass` optional later. |
| **P31** / **P64** | NTP / TZ | UK/GMT-friendly for lab |

**Chatbot hygiene:** root must be `<gs_provision>` / `<config>` — ignore `gs_id_c_e`. Never put `://` in **P48**.

| **P290** | Account 1 dial plan | See §0.3 — **must** include `*xx*` |

**Still optional / confirm on mule export:** Use SBC / outbound-proxy-mode knobs if 1.0.7.3 exposes them beyond **P48**.

**Request path:** GS wants **`cfg{mac}.xml`**. Kernel + edge extract **`cfg([0-9A-Fa-f]{12})\.xml`** (tipped).

**`<mac>` element:** optional per GS guide; kernel `$mac` substitute not wired yet — omit or add var when authoring.

---

## 2. Resume checklist (streams)

1. Get **full** GRP2602P **1.0.7.3** configuration template (or export from lab phone) — fill outbound + dial-plan P-numbers.
2. Author `grandstream.Common` / `grandstream.Extension` (+ empty transport stub); dial plan **must** include `*xx*`.
3. Edge + home: route/serve **`cfg{mac}.xml`**.
4. Tip streams; set **408** MAC + `#INCLUDE grandstream.Extension`; `sndcreds=Always` or Once.
5. Claim MAC / map sync.
6. Phone → Config Server Path = our HTTPS base; reboot; prove GET **200** on `cfg{mac}.xml`.
7. REGISTER + audio + BYE + feature-code `*xx*` smoke.
8. Optional: export → ops `devdocs/provisioning/grandstream/`.

**Out of scope for first pass:** binary `cfg.bin`, AES XML encryption, **GDMS API** (manual GDMS enroll fine), BLF, Gigaset.

**If site uses GDMS end-to-end:** our streams optional — REGISTER/NAT already green on PBX3.

---

## 3. Exit (this sub-project slice)

- [x] **GRP2602P 1.0.7.3** **manual SIP** REGISTER green (Sirius 408 / `74y2h3`, 2026-10-03)
- [x] Call / BYE + **NAT Traversal = Auto** (default) — lab OK; NAT row filled
- [x] Feature codes: add dial-plan line `*xx*` (defaults alone reject `*56*` / `*21*`) — §0.3
- [x] `grandstream.*` v0 authored (P47/P48/P290+`*xx*`/P52/P76/P192…) — reject chatbot `gs_id_c_e` / `://`
- [x] Request path **`cfg{mac}.xml`** — kernel + edge MAC extract
- [x] Lab tip: MAC **EC74D7438221** on **408**, `#INCLUDE grandstream.*`, Config Server Path, GET **200**, REGISTER + `*xx*` + far BYE with **`P52=4` Auto**
- [ ] Optional MkDocs blurb under phone-provisioning

Then close GS under D3 or open next brand.
