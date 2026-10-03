# Poly provision sub-project (D2 + D3 slice)

**Status:** **Streams v0 authored** (2026-10-03) — tip + GET/REGISTER/BYE soak next. Manual SIP UI locks done. Assist-not-core (§1).  
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
| URL / edge | **Lab v0 = single combined UCS body** via `{mac}.cfg` or `{mac}-reg.cfg` (kernel already extracts 12-hex MAC from either). Classic `000000000000.cfg` / `site.cfg` → edge **404** (zero/no MAC) — not required for first mule if phone fetches the MAC file |
| Discovery | **Lens / ZTP still uncertain** post-HP (§0.2 / plan **D2**). Lab = **manual Provisioning Server** URL. If Lens is free/easy end-to-end (GDMS-like), **vendor-cloud-only OK** — our streams optional |
| mTLS | Poly client CA in ops public-PKI pack; edge prove later if phones hit us |
| Role | Assist — not required for Poly desks to work on PBX3 |
| **Manual SIP (UI)** | **Straightforward** once ports + transport set (§0.1). No Fanvil dual-user quirk observed in lab notes. |
| **sndcreds** | Prefer **Always** for Poly — phone re-polls and often will not stay provisioned/register without secrets on every GET. Kernel already supports Always; SPA select + lab **410** use Always. |
| **OUI soft-fill** | Saving a Poly/Polycom MAC with blank `provision` auto-sets `#INCLUDE poly.Extension` + `poly.udp` and bumps empty/`Once` → **Always** (`manuf.txt` / `getmaclist.sh`; IEEE bare **Poly** OUIs e.g. `48:25:67`). Does not write `devicevendor` (S12). **Lab E2E still open** after tip. |

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
| Symptom | Outbound call audio OK; **far-end hangup does not clear the Poly** (Contact/NAT class — same as Snom **401** / Yealink **T31P** before STUN). |
| Browser NAT UI | Shows **IP address**, **Signalling port**, **Media Port Start**, **keepalive interval** only — **no STUN** controls. |
| STUN path | **Provisioning only.** Chatbot “Web GUI STUN fields” is a hallucination — do not hunt the browser. Lab/manual soak without our streams needs a **config file push / export-edit / Lens template**, not the Web UI. |

**Expected fix** — enable STUN in UCS config (fleet: `stun.l.google.com` / **3478**). Candidate params (confirm spelling on mule firmware / OEM admin guide):

```text
feature.nat.stun.enabled="1"
nat.stun.server="stun.l.google.com"
nat.stun.port="3478"
```

**Streams:** `poly.Common` (or sip-interop fragment) **must** ship STUN — this is the product path for far BYE. Re-soak far hangup before ticking the NAT checklist green.

---

## 1. On disk (streams v0)

| Artifact | Path / notes |
|----------|--------------|
| Streams | `pbx3-1/opt/pbx3/provisioning/streams/poly.{Common,Extension,udp}` |
| Lab soak | Recipe §7 — Sirius **410** / MAC `482567B0A593` |
| NAT row | Open until far BYE green with stream STUN |

Extension entry:

```text
#INCLUDE poly.Extension
#INCLUDE poly.udp
```

`poly.Common`: STUN + rport + UK SNTP (`gmtOffset=0`) + admin pass.  
`poly.Extension`: shortuid auth, `$sipdomain` / `$outbound`, both ports, **UDPOnly**, `reg.1.nat.traversal.mode=Auto`. Password on its own `<reg/>` line (sndcreds).

---

## 2. Lab tip / soak (resume)

1. Tip `poly.*` onto Sirius home; set **410** provision to `#INCLUDE poly.Extension` + `poly.udp`; `sndcreds=Once`.
2. Claim MAC / map sync (fleet) — MAC **482567B0A593**.
3. Phone UI → **Settings → Provisioning Server** → HTTPS `https://provision.pbx3.com:41363/provisioning` (or full `…/482567b0a593.cfg` if the UI wants a file).
4. Reboot; expect GET **200** on `{mac}.cfg` or `{mac}-reg.cfg`.
5. Exit: REGISTER via SBC → audio + **far BYE**; fill NAT row.
6. If phone insists on `000000000000.cfg` first and never pulls MAC file — document and decide whether to add a zero-MAC edge path later.
7. Spike **D2**: Lens/ZTP free path?

**Out of scope for first pass:** Lens automation API, firmware CDN (`sip.ld` hosting), full softkey/BLF matrix, non-VVX families until needed.

---

## 3. Exit (this sub-project slice)

- [x] Manual SIP UI knobs locked (§0.1): GMT→local TZ; both ports; Transport **UDPOnly** (not DNSnaptr)
- [x] Far-end BYE fails OOTB; STUN is **provisioning-only** (no Web UI) — §0.2; **BYE re-soak open**
- [x] `poly.*` v0 authored (UCS XML + STUN + UDPOnly + ports); single-file URL path documented
- [ ] One Poly model lab-green (REGISTER + call + **far BYE** with stream STUN) **or** documented Lens/GDMS-style cloud-only path
- [ ] Export-align / tweak if VVX 250 rejects v0 tags
- [ ] NAT row green; recipe §7 checks ticked
- [ ] **D2** discovery note updated (Lens usable? yes/no/partner)

Then close Poly under D2/D3 or open next brand.
