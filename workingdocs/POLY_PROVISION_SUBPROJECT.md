# Poly provision sub-project (D2 + D3 slice)

**Status:** **Lab green 2026-10-03** — VVX 250 + correct **streams** (master/`-reg.cfg`, STUN, far BYE). Discovery = DHCP 66 / manual URL; **no Lens build-out** unless asked. Assist-not-core (§1).  
**Lab mule:** **Poly VVX 250** · firmware **6.4.3.5059** · Sirius **410** / `g0ntwm` · MAC **482567B0A593**.  
**Owns:** Poly/UCS-style stock streams, lab soak, NAT row, discovery note (Lens/ZTP).  
**Parent:** `PROVISIONING_SERVER_REQUIREMENTS.md` §0.2 / §4.6 · plan **D2** (discovery) + **D3** (streams) · recipe **`PROVISIONING_LAB_RECIPE.md` §7**.  
**Siblings:** **`FANVIL_PROVISION_SUBPROJECT.md`** · **`GRANDSTREAM_PROVISION_SUBPROJECT.md`**.

**Working assumption (operator):** Classic **Polycom UCS / VVX** config dialect has **not** meaningfully changed for lab purposes — master `000000000000.cfg` + `site.cfg` / `sip-interop.cfg` + per-MAC `…-reg.cfg` with `reg.1.*` attributes. Lab mule is **VVX 250 / 6.4.3.5059**; prefer OEM UCS admin for that build + phone export over chatbot samples.

---

## 0. Stance

| Item | Stance |
|------|--------|
| Format | **Closed XML** (§4.6) — attribute-heavy (`reg.1.address="…"`) inside elements; whole-stanza INCLUDE, not Yealink last-wins lines |
| Classic file set | Phone typically fetches: **`000000000000.cfg`** (master / APPLICATION CONFIG_FILES list) → **`site.cfg`** / **`sip-interop.cfg`** (shared) → **`{mac}-reg.cfg`** (per device). Lowercase MAC, no colons |
| Engine | Dumb `#INCLUDE` + substitute. Phone-side tokens like `[PHONE_MAC_ADDRESS]` in master CONFIG_FILES are **Poly’s** expansion, not ours |
| URL / edge | **UCS master + settings (lab 2026-10-03):** Phone fetches `{mac}.cfg` as **APPLICATION master** (not settings). Kernel serves `poly.Master` (`APP_FILE_PATH=sip.ld`, `CONFIG_FILES={mac}-reg.cfg`) for Poly `{mac}.cfg` / `000000000000.cfg`; **`{mac}-reg.cfg`** is the `polycomConfig` settings body. Serving settings as `{mac}.cfg` → “Could not get application name”. **Edge must extract MAC from `{mac}-reg.cfg`** (not only `{mac}.cfg`) or home never sees settings → phone “reverting to previous config”. |
| Discovery | **Primary assist:** customer **DHCP 66** and/or **manual Provisioning Server URL** → `https://provision.{apex}:41363/provisioning`. **Poly Lens can** point phones at us (or own CFG end-to-end) but **do not build Lens integration** unless a customer asks — streams are the product. |
| **First boot (lab green)** | Factory / OOTB: **admin password**, then provision URL via **UI** and/or **DHCP 66**. No manual SIP knobs when streams apply. Reboot/apply → master + `-reg.cfg`. |
| mTLS | Poly client CA in ops public-PKI pack; edge optional |
| Role | Assist — not required for Poly desks to work on PBX3 |
| **Manual SIP (UI)** | Fallback only (§0.1). Stream path preferred. |
| **sndcreds** | Prefer **Always** for Poly — phone re-polls and often will not stay provisioned/register without secrets on every GET. Kernel already supports Always; SPA select + lab **410** use Always. |

### ChatGPT sample (sanity)

Roughly matches classic UCS: master APPLICATION → `CONFIG_FILES="…-reg.cfg, site.cfg, sip-interop.cfg"` and a `-reg.cfg` with `reg.1.*`. Usable as a **starting sketch**, not law. Ignore Asterisk `pjsip.conf` paste and “generate a script” fluff. Prefer OEM UCS admin / provisioning guide for the mule model + a phone **config export** if available.

### 0.1 Working manual SIP / site knobs (VVX 250 / 6.4.3.5059, lab 2026-10-03)

OOTB pitfalls (otherwise straightforward):

| Knob | OOTB | Set for PBX3 |
|------|------|--------------|
| **Timezone** | **GMT** | Site-local (same class of lock as Yealink/Snom UK defaults in streams) |
| **SIP server port** | *(empty — no default)* | Must set — lab/fleet **`5060`** (`$bindport`) |
| **Proxy / outbound proxy port** | *(empty — no default)* | Must set — same **`5060`** (`$bindport`) |
| **Transport(s)** | **DNSnaptr** | **UDPOnly** for current fleet SBC face (`UDPOnly` \| `TCPpreferred` \| `DNSnaptr` \| `TCPonly` \| `TLS`) |

Ports are required on **both** SIP server and proxy (not address-only). Leaving transport at DNSnaptr is wrong for our UDP SBC path.

Auth/address mapping for streams still follows the sketch below (`reg.1.address` / `auth.userId` = `$sipuser`, server = `$sipdomain`, outbound = `$outbound`) — confirm shortuid vs display on next REGISTER green tick.

### 0.2 NAT / far-end BYE (VVX 250 / 6.4.3.5059, lab 2026-10-03)

| Observation | Detail |
|-------------|--------|
| OOTB | Outbound audio OK; **far-end hangup stuck** (LAN Contact) — same class as Snom **401** / Yealink **T31P** before STUN. |
| Browser NAT UI | **IP / ports / keepalive** only — **no STUN**. Empty `nat.ip` correct; keepalive **30** after apply. |
| STUN path | **Provisioning only** (`poly.Common`). Verify via REGISTER Contact (public `x-ast-orig-host`) + far BYE — not the NAT page. |
| Lab green | **2026-10-03** Sirius **410** — master `{mac}.cfg` + `{mac}-reg.cfg` **200**; keepalive **30**; Contact public; **far BYE clears**. |

**Stream params (locked on mule):**

```text
feature.nat.stun.enabled="1"
nat.stun.server="stun.l.google.com"
nat.stun.port="3478"
nat.keepalive.interval="30"
reg.1.nat.traversal.mode="Auto"
```

**Override trap:** Web/keypad `{mac}-web.cfg` / `{mac}-phone.cfg` beat streams until Reset Web/Local Configuration.

**Apply path:** `{mac}.cfg` = UCS **APPLICATION** master (`poly.Master`); settings = `{mac}-reg.cfg`. Edge must MAC-extract `-reg.cfg`. Optional-file 404s are normal; `sip.ld` 404 OK (we don’t host firmware). STUN apply may force a second reboot.

---

## 1. On disk (streams v0)

| Artifact | Path / notes |
|----------|--------------|
| Streams | `pbx3-1/…/streams/poly.{Master,Common,Extension,udp}` |
| Lab soak | Recipe §7 — Sirius **410** / MAC `482567B0A593` |
| NAT row | **Green** 2026-10-03 (stream STUN + far BYE) |

Extension entry:

```text
#INCLUDE poly.Extension
#INCLUDE poly.udp
```

`poly.Master`: APPLICATION → `CONFIG_FILES={mac}-reg.cfg`.  
`poly.Common`: STUN + keepalive + rport + UK SNTP (`gmtOffset=0`).  
`poly.Extension`: shortuid auth, `$sipdomain` / `$outbound`, both ports, **UDPOnly**, `reg.1.nat.traversal.mode=Auto`. Password on its own `<reg/>` line (sndcreds).

---

## 2. Lab tip / soak (resume)

1. Tip `poly.*` onto Sirius home; set **410** provision to `#INCLUDE poly.Extension` + `poly.udp`; `sndcreds=Always`.
2. Claim MAC / map sync (fleet) — MAC **482567B0A593**.
3. Phone (factory/OOTB): **admin password** → **Settings → Provisioning Server** → `https://provision.pbx3.com:41363/provisioning` (directory base).
4. Reboot/apply; expect GET **200** on `{mac}.cfg` then `{mac}-reg.cfg` (optional-file 404s OK).
5. Exit: REGISTER via SBC → audio + **far BYE**; NAT keepalive **30**. **Done 2026-10-03** (incl. factory-reset re-soak).
6. **D2:** DHCP **66** / manual URL. Lens capable but **out of scope** unless a customer asks.

**Out of scope for first pass:** Lens automation API, firmware CDN (`sip.ld` hosting), full softkey/BLF matrix, non-VVX families until needed.

---

## 3. Exit (this sub-project slice)

- [x] Manual SIP UI knobs locked (§0.1): GMT→local TZ; both ports; Transport **UDPOnly** (not DNSnaptr)
- [x] Far-end BYE fails OOTB; STUN is **provisioning-only** (no Web UI) — §0.2
- [x] `poly.*` v0 + master/`-reg.cfg` path + edge MAC suffix extract
- [x] One Poly model lab-green (REGISTER + call + **far BYE** with stream STUN) — VVX 250 / **410**
- [x] NAT row green; keepalive **30** + public Contact
- [x] Factory-reset path: admin password + Provisioning Server URL only (no manual SIP)
- [x] **D2** discovery: **DHCP 66** / manual URL (Lens exists — **do not build** unless asked)
- [x] Product focus = **correct streams** (not Lens)

Poly D2/D3 slice closed for assist; open next brand when ready.
