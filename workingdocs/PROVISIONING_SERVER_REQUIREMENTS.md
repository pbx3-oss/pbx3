# Provisioning — requirements (sketch)

**Status:** **Reopened 2026-09-08** (supersedes won't-do 2026-08-23).  
**v1 direction:** **instance-local** HTTP phone provisioner on each home — independently, at least for now. **Not** building the fleet edge nginx provision proxy / shared provision host yet (that shape remains in §0 as a later option). Still **no** **sark3pcerts** panel. Manufacturer/reseller RPS (**M1**) remains a valid alternative alongside in-house.  
**2026-08-25:** Instance **Device** template table / API / SPA **purged** (TODO #28). Extension `ipphone.device` remains a type label only. Revival must **not** reintroduce Device templates — retrofit SARK 6.5-style expand from extension/handset data.  
**Earlier (2026-08-10):** Preferred fleet shape was home-local listener + edge nginx provision proxy — deferred past instance-local v1.  
**Earlier (2026-08-06):** Explored fleet S3 MAC inventory + dedicated provision host; secrets/HoR split made that path hard.  
**Reference notes:** private prior co-located provisioner / SARK archives (operator only — not in product tree).  
**Related:** **`FLEET_DESK_PHONE_NAT.md`** · **`pbx3spa/workingdocs/EXTENSION_PROVISIONING_*`** (extension SIP fields / Commit) · **`TLS_AND_CERTIFICATES.md` §0** · **`DESIGN_RULES.md`** Rule 1 / 7 / 13 · **`TODO.md`** #23 / #28 / **0k**.

---

## 0. Preferred fleet shape (2026-08-10)

**Same idea as the SBC, for HTTP config instead of SIP.**

| Layer | Role |
|-------|------|
| **Edge provision proxy** | nginx (or equivalent). Has a **stable public A/AAAA**. Terminates HTTPS (wildcard / edge LE — detail TBD). Routes to the instance that currently homes the phone’s tenant — by **Host / SNI = tenant FQDN** and/or by **MAC** (always present on GET or POST). |
| **Home listener** | Co-located on the instance (tenant-aware). Reads **`ipphone`** (same secret HoR as Asterisk). Lift and polish existing **SARK / prior co-located** provision routines (`device.php`-class: MAC → template expand → body). |
| **Phone** | Provision URL uses the **tenant FQDN** (same string as SIP domain) *or* a stable provision hostname; request carries **MAC** in query/path/body. DNS for the phone-facing name points at the **proxy**, not at the home. SIP REGISTER / media still follow the normal fleet path (**SBC** + tenant domain string) — provision A ≠ SIP next hop. |

```text
Phone GET/POST https://{tenant-or-provision-host}/…  (MAC in query, path, or body)
  → DNS A/AAAA → provision proxy (stable; does not change on tenant move)
  → nginx routes by Host/SNI and/or MAC → current home backend
  → home listener expands vendor config from local SQLite (SARK lift)
  → phone applies config → SIP REGISTER via SBC (unchanged)
```

**Routing keys (either or both):**

| Key | Source | Notes |
|-----|--------|--------|
| **Tenant Host / SNI** | URL hostname = tenant FQDN | SBC-analogue; simple when phones are provisioned per-tenant URL |
| **MAC** | Always on the request (GET query/path or POST body — vendor-dependent) | Lookup MAC → tenant → home (catalog or home-published index). Useful when Host is a shared provision name, or as a cross-check |

Prefer **fail closed**: unknown Host and unknown MAC → 404/502; never guess across tenants. If both present and disagree, reject.

**Tenant move:** update the proxy’s **backend map** (and any MAC→home index) from catalog — same mobility events as SBC `setid` projection. **No** DNS change on move; **no** phone re-key of provision host; secrets never leave the home row for render.

**Why this works (operator stance):** Routing is the hard fleet bit; once Host and/or MAC → home is correct, the provision **application** is mostly already written in SARK-era routines — lift, harden, and polish rather than invent a second inventory.

### Relationship to `TLS_AND_CERTIFICATES.md` §0

§0 says tenant names are **SIP domain strings** and must **not** be public A records **aimed at homes** (SPA/API stay on instance DNS; SIP via SBC).

**Deliberate provision exception:** tenant FQDN (or `*.apex`) **may** have A/AAAA that resolve to the **provision proxy only**. That is not “tenant → home” and must not be used as the SIP next hop. Document in TLS §0 when this ships (cross-link; do not silently contradict).

---

## 0.1 Build or not? / management options (retained)

Desk-phone HTTP provisioning remains a crowded market (vendor RPS, reseller platforms). In-house is optional — but **if** we host it for fleet, prefer **§0** over inventing S3-as-password-store.

| # | Path | Idea | Secrets | When |
|---|------|------|---------|------|
| **M1** | **Don't own HTTP** | Vendor RPS / reseller delivers config | Stay on instance | Many MSP customers |
| **M2** | **Thin export** | CSV/JSON for someone else’s RPS | One-shot reveal; not S3 inventory | Follow-on to M1 |
| **M3 + edge proxy** | **Preferred if we build** | Home listener + nginx Host and/or MAC→home (**§0**) | Single HoR = extension row | Fleet in-house provision |
| **M3 solo** | Co-located only | No proxy; phone hits instance directly | Same | Solo / lab / air-gap |
| **M4** | S3 MAC directory only | Route map in S3; secret fetch from home | Instance | Alternate; heavier |
| **M5** | Pre-rendered blob in S3 | Dumb file GET | Secret inside blob | Avoid unless explicit SKU |

**Hard rule:** Asterisk and the **first place that embeds the SIP password into a phone config** share **one secret HoR** (the extension row). §0 keeps that. Do **not** re-split secrets into a fleet provision DB without a deliberate S1–S3 choice from the old §6 sketch.

**What we still need either way:** solid **extension + MAC + secret + Commit/PJSIP** (`EXTENSION_PROVISIONING_*`).

---

## 1. One-line purpose

Serve vendor phone config files keyed by **MAC** (and vendor “common” descriptors), embedding SIP identity and registrar/proxy so a desk phone can register without manual SIP setup — with **fleet mobility** that does not require DNS or phone URL changes on tenant move.

---

## 2. Product class

| Concern | Stance |
|---------|--------|
| **What it is** | Home **HTTP provision listener** + optional **edge reverse-proxy** for fleet Host routing |
| **What it is not** | Not Asterisk; not Gatekeeper; not SBC call plane; not SPA; **not** required for calls once phones are configured |
| **SARK lift** | Port behaviour from private archives / SARK `device.php` (MAC → `#INCLUDE` expand → text). Polish auth, HTTPS, multi-tenant pathing, sndcreds |
| **Call plane** | Phones **register / media** via normal fleet SIP (SBC → instance). Provision is **config HTTP only** |
| **Directory / Rule 1** | Proxy routing may **read** catalog home facts (projection). Provision must not become a call-routing dependency. Proxy/home down → already-provisioned phones keep working |
| **Rule 7** | Provision proxy is a **replaceable edge** sibling of the SBC (HTTP, not SIP). Prefer dumb nginx + map over a fat app on the edge |
| **Compete?** | Thin MAC→config; do not out-feature vendor RPS |

---

## 3. Happy path (phone)

```text
Phone discovers provision URL (DHCP opt66/114, PnP, or manual)
  → GET https://{tenant-fqdn}/provisioning…?mac=…   (or vendor path forms)
  → DNS → provision proxy A/AAAA
  → Proxy: Host/SNI → current home
  → Home: MAC → Device stack → expand → body (SARK routines)
Phone applies config → SIP REGISTER to SBC / domain from file
```

| Name | Role |
|------|------|
| **Tenant FQDN in URL / Host** | Stable phone-facing name; same string as SIP domain |
| **Provision proxy A/AAAA** | Stable edge IP(s); **does not move** with tenant |
| **Home backend** | Instance provision listener (localhost or private); secrets + templates here |
| **SIP contact in file** | Fleet: **SBC** + tenant domain string. Solo: instance FQDN/IP |

---

## 4. Responsibilities

### 4.1 Edge proxy

| Do | Notes |
|----|--------|
| HTTPS terminate (or passthrough — prefer terminate + wildcard) | Own LE / wildcard story on the proxy |
| Route by Host / SNI and/or MAC → home | Host map and/or MAC→tenant→home index from catalog; refresh on move/onboard |
| Extract MAC from request | Vendor forms: query `mac=`, path `/{mac}.cfg`, POST body — normalize 12-hex |
| Health / 502 when home unknown | Unknown tenant Host or unknown MAC → 404/502; no cross-tenant leak |
| No secret render | Proxy does not read `ipphone` passwords |

### 4.2 Home listener

| Do | Notes |
|----|--------|
| HTTP(S) MAC / descriptor → vendor config | Same URL families as SARK (`?mac=`, `/{mac}.cfg`, Yealink common, …) |
| Template expand | Device `#INCLUDE`; `$localip` / `$ext` / `$password` / ports; optional BLF |
| Credential gating | `sndcreds` Always \| Once \| No |
| Multi-tenant | Resolve tenant from Host / path; only that cluster’s phones |
| Unknown MAC | **404** |
| Logging | URI, MAC, UA, success/404; no secrets |

---

## 5. Inputs (home)

| Input | Source | Note |
|-------|--------|------|
| Extension + MAC + secret + device stack | `ipphone` (+ Device) | Authored on instance; **HoR for secrets** |
| BLF / line keys | fkey tables | As today / SARK |
| SIP host policy | Fleet: embed **SBC** + tenant domain; not home public IP | Matches W1 / fleet desk path |
| OUI → vendor | `manuf.txt` helper | Create-time UI; not every GET |

---

## 6. Routing HoR (proxy map)

**HoR for “which home serves this tenant?”** remains the **directory / catalog** (Rule 13) — same fact family as SBC `setid`.

| Concern | Stance |
|---------|--------|
| **Map key** | Tenant FQDN / shortuid (Host) **and/or** normalized MAC |
| **Map value** | Home provision base URL (or instance id → resolved provision endpoint) |
| **MAC index** | Optional fleet projection `MAC → tenant → home` (catalog or published from homes). Needed if routing by MAC or shared provision hostname |
| **Update** | Onboard, move, delete, MAC assign/clear — same job family as SBC domain repoint |
| **Projection** | nginx map / lua / small sidecar — edge is not a second HoR |

**Not required for §0:** S3 MAC inventory as provision HoR (old lean). MAC inventory in S3 stays an **alternate** (M4/M5) if we ever abandon home-local render.

### Historical alternate — S3 MAC inventory (parked)

Earlier lean locked “S3 keyed by MAC” for a dedicated fleet listener. That path reopened the **secret dual-consumer** problem (S1 password in S3 / S2 fetch from home / S3 blob). **§0 supersedes that as the preferred design.** Keep the S1–S3 discussion only if M4/M5 is explicitly chosen later.

---

## 7. Non-goals

- Tenant create / installer / Mode 4 (“provision” overloaded elsewhere)
- Asterisk PJSIP / Commit / genAst (instance)
- SPA extension authoring (**`EXTENSION_PROVISIONING_*`**)
- SIP proxy, RTP, registrar on the provision proxy
- Browser holding ops IAM
- Requiring provisioner for **calls** once phones are configured
- Full vendor matrix day one — Snom / Yealink first
- DHCP server product — document opt66 → tenant provision URL; optional later

---

## 8. Security (thin)

| Topic | Stance |
|-------|--------|
| Open GET by MAC | SARK LAN default; MAC = weak capability |
| HTTPS | Required off-lab; proxy owns edge cert |
| mTLS + vendor CAs | Optional hardened remote |
| Secrets in body | Only when `sndcreds` allows; prefer Once for first boot |
| Writes from phones | Ignore PUT / vendor upload (404/no-op) |
| Cross-tenant | Host must select exactly one tenant; never serve another cluster’s MAC |

---

## 9. Relationship to other tracks

| Track | Boundary |
|-------|----------|
| **Extension provisioning (SPA/API)** | Authors `ipphone` + Commit → PJSIP on **home** |
| **This track** | Delivers **phone config HTTP**; proxy routes; home renders |
| **Fleet DNS / LE §0** | SIP: no tenant A→home. Provision: tenant/wildcard A→**proxy** (exception — update TLS §0 when shipping) |
| **SBC** | Runtime SIP; model for Host/domain → home routing |
| **Tenant move** | Catalog + SBC setid + **provision proxy map** — one mobility story |

---

## 10. Implementation map (when scheduled)

| Slice | Likely home | Notes |
|-------|-------------|--------|
| Home listener | **pbx3** / **pbx3api** (or small co-located PHP) | Lift SARK `device.php` behaviour; multi-tenant Host |
| Edge proxy | Small edge host or co-located with control/SBC ops box | nginx + map from catalog; **not** in SIP path |
| Map refresh | Gatekeeper / move job hook | Same events as SBC domain repoint |
| Device templates | Seed from archives / Device table | Subset OK |
| SPA | Later | Show provision URL = `https://{tenant-fqdn}/…` |
| TLS §0 note | **`TLS_AND_CERTIFICATES.md`** | Document provision A→proxy exception |

---

## 11. Open decisions (narrow)

0. **Schedule build?** — Direction preferred; priority TBD (TODO).  
1. **Cert on proxy** — Wildcard `*.apex` vs per-tenant SAN vs name `provision.{apex}` with path-based tenant (path would change phone URL shape — Host-based preferred).  
2. **Where proxy runs** — Shared fleet box vs next to Magrathea vs control plane; must stay off call-path critical path (Rule 1 / 5).  
3. **Map transport** — Regenerated nginx conf vs lua (MAC extract from URI/body) vs auth_request to Gatekeeper (cache carefully).  
4. **Primary route key** — Host-only, MAC-only, or Host with MAC cross-check (lean: support both; MAC always available on the wire).  
5. **Solo** — Skip proxy; phone → instance directly (M3 solo).  
6. **Stack for home listener** — PHP parity with SARK vs rewrite; behaviour first.

---

## 12. Verify later (acceptance sketch)

- Phone with known MAC via `https://{tenant-fqdn}/…` receives config; unknown MAC → 404.  
- DNS for tenant name → **proxy**; SIP REGISTER still via **SBC** (not provision IP).  
- Move tenant home → update proxy map only → same phone URL still works; **no** DNS change.  
- Proxy or home provision down → existing registrations unaffected.  
- Instance Commit still owns Asterisk; provisioner does not write PJSIP.  
- Secret only read from home `ipphone` at render time.
