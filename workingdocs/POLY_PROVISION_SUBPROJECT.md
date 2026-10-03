# Poly provision sub-project (D2 + D3 slice)

**Status:** **Manual SIP UI soak** (2026-10-03). First-tranche brand; **no stock streams yet**. Assist-not-core (§1).  
**Owns:** Poly/UCS-style stock streams, lab soak, NAT row, discovery note (Lens/ZTP).  
**Parent:** `PROVISIONING_SERVER_REQUIREMENTS.md` §0.2 / §4.6 · plan **D2** (discovery) + **D3** (streams) · recipe **`PROVISIONING_LAB_RECIPE.md` §7**.  
**Siblings:** **`FANVIL_PROVISION_SUBPROJECT.md`** · **`GRANDSTREAM_PROVISION_SUBPROJECT.md`**.

**Working assumption (operator):** Classic **Polycom UCS / VVX** config dialect has **not** meaningfully changed for lab purposes — master `000000000000.cfg` + `site.cfg` / `sip-interop.cfg` + per-MAC `…-reg.cfg` with `reg.1.*` attributes. Verify on first mule firmware; do not trust chatbot samples blindly.

---

## 0. Stance

| Item | Stance |
|------|--------|
| Format | **Closed XML** (§4.6) — attribute-heavy (`reg.1.address="…"`) inside elements; whole-stanza INCLUDE, not Yealink last-wins lines |
| Classic file set | Phone typically fetches: **`000000000000.cfg`** (master / APPLICATION CONFIG_FILES list) → **`site.cfg`** / **`sip-interop.cfg`** (shared) → **`{mac}-reg.cfg`** (per device). Lowercase MAC, no colons |
| Engine | Dumb `#INCLUDE` + substitute. Phone-side tokens like `[PHONE_MAC_ADDRESS]` in master CONFIG_FILES are **Poly’s** expansion, not ours |
| URL / edge | Today we serve `{mac}.cfg` / `?mac=`. Poly wants **multiple named files**. Lab may point Config Server at a directory URL and map requests → streams (`poly.Master` / `poly.Common` / `poly.Extension`), or serve a single combined body if firmware accepts it — **settle on mule** |
| Discovery | **Lens / ZTP still uncertain** post-HP (§0.2 / plan **D2**). Lab = **manual Provisioning Server** URL. If Lens is free/easy end-to-end (GDMS-like), **vendor-cloud-only OK** — our streams optional |
| mTLS | Poly client CA in ops public-PKI pack; edge prove later if phones hit us |
| Role | Assist — not required for Poly desks to work on PBX3 |
| **Manual SIP (UI)** | **Straightforward** once ports + transport set (§0.1). No Fanvil dual-user quirk observed in lab notes. |

### ChatGPT sample (sanity)

Roughly matches classic UCS: master APPLICATION → `CONFIG_FILES="…-reg.cfg, site.cfg, sip-interop.cfg"` and a `-reg.cfg` with `reg.1.*`. Usable as a **starting sketch**, not law. Ignore Asterisk `pjsip.conf` paste and “generate a script” fluff. Prefer OEM UCS admin / provisioning guide for the mule model + a phone **config export** if available.

### 0.1 Working manual SIP / site knobs (lab 2026-10-03)

OOTB pitfalls (otherwise straightforward):

| Knob | OOTB | Set for PBX3 |
|------|------|--------------|
| **Timezone** | **GMT** | Site-local (same class of lock as Yealink/Snom UK defaults in streams) |
| **SIP server port** | *(empty — no default)* | Must set — lab/fleet **`5060`** (`$bindport`) |
| **Proxy / outbound proxy port** | *(empty — no default)* | Must set — same **`5060`** (`$bindport`) |
| **Transport(s)** | **DNSnaptr** | **UDPOnly** for current fleet SBC face (`UDPOnly` \| `TCPpreferred` \| `DNSnaptr` \| `TCPonly` \| `TLS`) |

Ports are required on **both** SIP server and proxy (not address-only). Leaving transport at DNSnaptr is wrong for our UDP SBC path.

Auth/address mapping for streams still follows the sketch below (`reg.1.address` / `auth.userId` = `$sipuser`, server = `$sipdomain`, outbound = `$outbound`) — confirm shortuid vs display on next REGISTER green tick.

### 0.2 NAT / far-end BYE (lab 2026-10-03)

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

## 1. Not on `main` yet

| Artifact | Notes |
|----------|-------|
| Streams | e.g. `poly.Master` / `poly.Common` / `poly.Extension` (names TBD); Common must set timezone + **UDPOnly** + both ports + **STUN** (§0.2) |
| Lab soak | Recipe §7 — UI knobs §0.1; NAT/BYE §0.2 open until STUN proven |
| NAT row | `FLEET_DESK_PHONE_NAT.md` — Poly row open (far BYE fails OOTB) |

Sketch (placeholders — align to mule export):

```xml
<?xml version="1.0" standalone="yes"?>
<!-- poly.Extension / *-reg.cfg shape -->
<phone>
  <reg
    reg.1.displayName="$desc"
    reg.1.address="$sipuser"
    reg.1.label="$ext"
    reg.1.auth.userId="$sipuser"
    reg.1.auth.password="$password"
    reg.1.server.1.address="$sipdomain"
    reg.1.server.1.port="$bindport"
    reg.1.outboundProxy.address="$outbound"
    reg.1.outboundProxy.port="$bindport"
  />
  <!-- transport: UDPOnly (not DNSnaptr); STUN: feature.nat.stun.* — exact names from mule export -->
</phone>
```

Transport / timezone / **STUN** (§0.2) / site defaults live in `poly.Common` / `sip-interop`-shaped fragment.

---

## 2. When the mule arrives (resume checklist)

1. Note model + UCS/firmware version; grab OEM provisioning PDF or export from phone web UI.
2. Confirm boot fetch order and filenames vs our edge routes.
3. Author streams; tip home; extension `#INCLUDE poly.Extension` (etc.).
4. Claim MAC / map if fleet; set **Settings → Provisioning Server** (HTTPS → `provision.{apex}:41363/…`).
5. Exit: GET(s) **200** → REGISTER via SBC → audio + **far BYE** (enable STUN §0.2); fill NAT.
6. Spike **D2**: does Lens/ZTP give a free MAC→URL path we care about, or stay manual / partner-only?

**Out of scope for first pass:** Lens automation API, firmware CDN (`sip.ld` hosting), full softkey/BLF matrix, non-VVX families until needed.

---

## 3. Exit (this sub-project slice)

- [x] Manual SIP UI knobs locked (§0.1): GMT→local TZ; both ports; Transport **UDPOnly** (not DNSnaptr)
- [x] Far-end BYE fails OOTB; STUN is **provisioning-only** (no Web UI) — §0.2; **BYE re-soak open**
- [ ] One Poly model lab-green (REGISTER + call + **far BYE** with STUN) **or** documented Lens/GDMS-style cloud-only path
- [ ] File/URL mapping documented (master + reg vs single stream)
- [ ] `poly.*` matches firmware / export (include §0.1 + STUN §0.2)
- [ ] NAT row green; recipe §7 checks ticked
- [ ] **D2** discovery note updated (Lens usable? yes/no/partner)

Then close Poly under D2/D3 or open next brand.
