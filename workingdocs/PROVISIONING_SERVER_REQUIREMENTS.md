# Provisioning — requirements (sketch)

**Status:** **Reopened 2026-09-08** (supersedes won't-do 2026-08-23).  
**v1 direction:** **instance-local** HTTPS phone provisioner on each home (non-443) — independently, at least for now. Fleet edge provision proxy = **SBC-colocated** nginx later (§0); map from catalog/S3 only (no secrets). Still **no** third-party certs panel.  
**Discovery (locked 2026-09-29):** **Vendor / reseller redirect (RPS)** is the **primary** way phones find the provision URL in cloud deployments. DHCP opt66/114 and PnP multicast are **secondary** (on-prem / lab). See **§0.2**.  
**2026-08-25:** Instance **Device** template table / API / SPA **purged** (TODO #28). Extension `ipphone.device` remains a type label only. Revival must **not** reintroduce Device templates — retrofit previous PBX 6.5-style expand from extension/handset data.  
**Earlier (2026-08-10):** Preferred fleet shape was home-local listener + edge nginx provision proxy — deferred past instance-local v1.  
**Earlier (2026-08-06):** Explored fleet S3 MAC inventory + dedicated provision host; secrets/HoR split made that path hard.  
**Reference notes:** private prior co-located provisioner / previous PBX archives (operator only — not in product tree).  
**Related:** **`FLEET_DESK_PHONE_NAT.md`** · **`pbx3spa/workingdocs/EXTENSION_PROVISIONING_*`** (extension SIP fields / Commit) · **`TLS_AND_CERTIFICATES.md` §0** · **`DESIGN_RULES.md`** Rule 1 / 7 / 13 · **`TODO.md`** #23 / #28 / **0k**.

---

## 0. Preferred fleet shape (2026-08-10)

**Same idea as the SBC, for HTTP config instead of SIP.**

| Layer | Role |
|-------|------|
| **Edge provision proxy** | **Colocated with the SBC** (locked 2026-09-30) — nginx (or equivalent) on the **same edge entity / VIP** as SIP. Stable public A/AAAA (often the SBC VIP). Terminates HTTPS (wildcard / edge LE — detail TBD). Routes to the instance that currently homes the phone’s tenant — by **Host / SNI = tenant FQDN** and/or by **MAC**. **No secrets, no expand** — map context from **catalog / S3 only**. |
| **Home listener** | Co-located on the instance (tenant-aware). Reads **`ipphone`** (same secret HoR as Asterisk). Lift and polish existing **previous PBX / prior co-located** provision routines (`device.php`-class: MAC → template expand → body). |
| **Phone** | Provision URL uses the **tenant FQDN** (same string as SIP domain) *or* a stable provision hostname; request carries **MAC** in query/path/body. DNS for the phone-facing name points at the **edge** (SBC VIP / provision vhost), not at the home. SIP REGISTER / media still follow the normal fleet path (**SBC** + tenant domain string) — provision port/vhost ≠ SIP next hop, same host OK. |

```text
Phone GET/POST https://{tenant-or-provision-host}/…  (MAC in query, path, or body)
  → DNS A/AAAA → SBC edge (provision vhost; stable; does not change on tenant move)
  → nginx routes by Host/SNI and/or MAC → current home backend  (map from catalog/S3)
  → home listener expands vendor config from local SQLite (previous PBX lift)
  → phone applies config → SIP REGISTER via SBC (unchanged)
```

**Routing keys (either or both):**

| Key | Source | Notes |
|-----|--------|-------|
| **Tenant Host / SNI** | URL hostname = tenant FQDN | SBC-analogue; simple when phones are provisioned per-tenant URL |
| **MAC** | Always on the request (GET query/path or POST body — vendor-dependent) | Lookup MAC → tenant → home (catalog or home-published index). Useful when Host is a shared provision name, or as a cross-check |

Prefer **fail closed**: unknown Host and unknown MAC → 404/502; never guess across tenants. If both present and disagree, reject.

**Tenant move:** update the proxy’s **backend map** (and any MAC→home index) from catalog — same mobility events as SBC `setid` projection. **No** DNS change on move; **no** phone re-key of provision host; **no** vendor/reseller RPS re-point if the redirect target is the stable edge provision URL. Secrets never leave the home row for render.

**Why this works (operator stance):** One **edge entity** for phones (SIP + provision HTTP). Routing is the hard fleet bit; once Host and/or MAC → home is correct, the provision **application** stays on the home. **Discovery** is almost always **vendor/reseller RPS** (§0.2), not DHCP. **Solo / singleton:** no proxy — RPS points at the instance directly (Rule 6).

### Edge placement (locked 2026-09-30)

| Concern | Stance |
|---------|--------|
| **Where it runs** | **On the SBC host(s)** — sibling nginx (or equivalent), not OpenSIPS, not gatekeeper phone-facing |
| **Why SBC** | One edge for desks; stable VIP already; functionally “phone finds the edge” for both SIP and config HTTP |
| **Map context** | **Catalog / S3 only** (tenant→home, optional MAC→tenant/home). **No** `ipphone` passwords, no home DB, no gatekeeper live calls on the request path |
| **HA / mirror** | Because the proxy is **stateless aside from the published map**, it **mirrors with the SBC** without drama — same map artifact on each edge node (or shared VIP backend). Refresh map on both when catalog changes |
| **Gatekeeper / control** | **Publishes** / refreshes the map from catalog (move/onboard jobs). Does **not** terminate phone provision GETs |
| **Rule 7** | Keep provision as a **separate unit** from OpenSIPS so an SBC software swap does not rewrite HTTP; still same *machine/VIP* is fine |
| **Rule 1** | Provision down ≠ calls down; don’t put expand/secrets on the edge |

### Relationship to `TLS_AND_CERTIFICATES.md` §0

§0 says tenant names are **SIP domain strings** and must **not** be public A records **aimed at homes** (SPA/API stay on instance DNS; SIP via SBC).

**Deliberate provision exception:** tenant FQDN (or `*.apex`) **may** have A/AAAA that resolve to the **SBC edge provision vhost** (same VIP as SIP edge is OK). That is not “tenant → home” and must not be used as the SIP next hop. Document in TLS §0 when this ships (cross-link; do not silently contradict).

---

## 0.1 Build or not? / management options (retained)

Desk-phone HTTP provisioning remains a crowded market (vendor RPS, reseller platforms). In-house owns the **final config stream** when we want secrets on the home; we do **not** compete with vendors on the **redirect / discovery** layer.

| # | Path | Idea | Secrets | When |
|---|------|------|---------|------|
| **M1** | **Don't own final HTTP** | Vendor RPS / reseller **delivers the full config** (or never points at us) | Stay on instance for SIP only | MSP already on reseller RPS end-to-end |
| **M2** | **Thin export** | CSV/JSON / MAC list for someone else’s RPS enrollment | One-shot reveal; not S3 inventory | Feed reseller portals; follow-on to M3 |
| **M3 + RPS discovery** | **Default cloud path** | RPS redirects MAC → our provision URL; **home** (or §0 proxy) expands config | Single HoR = extension row | Production desk phones |
| **M3 + edge proxy** | **Preferred fleet polish** | RPS target = **stable** proxy URL; nginx Host and/or MAC→home (**§0**) | Same | Zero-touch move including re-provision GET |
| **M3 solo** | Co-located only | Phone hits instance directly (RPS → instance URL, or lab manual/opt66) | Same | Solo / lab / air-gap |
| **M4** | S3 MAC directory only | Route map in S3; secret fetch from home | Instance | Alternate; heavier |
| **M5** | Pre-rendered blob in S3 | Dumb file GET | Secret inside blob | Avoid unless explicit SKU |

**Hard rule:** Asterisk and the **first place that embeds the SIP password into a phone config** share **one secret HoR** (the extension row). §0 keeps that. Do **not** re-split secrets into a fleet provision DB without a deliberate S1–S3 choice from the old §6 sketch.

**Do not build:** a discrete fat “provisioning server” product meant to replace vendor/reseller **redirect**. That fights SRAPS / Yealink RPS / reseller platforms on discovery while still needing home secrets for render.

**What we still need either way:** solid **extension + MAC + secret + Commit/PJSIP** (`EXTENSION_PROVISIONING_*`).

---

## 0.2 Discovery — vendor / reseller redirect (locked 2026-09-29)

### Primary path (cloud)

Almost all major desk-phone vendors support a **redirect / RPS** service. Where the vendor does not, a **reseller** usually provides the same role. On startup the phone **calls home** (HTTP/HTTPS) to that service first; the service redirects (often via a reseller hop) to the **target provision URL**.

### Vendors of interest (redirect / ZTP platforms)

Product interest set for discovery + eventual enrollment docs/APIs. **Not** a promise to automate every portal in v1. Reseller hop may sit between vendor RPS and our URL.

| Vendor | Platform | Notes |
|--------|----------|-------|
| **Yealink** | **RPS** (Redirection and Provisioning Service) | Widely used; free for SPs/enterprises; can tie into **YMCS** (Yealink Management Cloud Service) |
| **Poly** (ex-Polycom) | **Poly Lens** / **ZTP** | **Uncertain (2026-09-29):** HP takeover left redirect / ZTP opaque — Lens vs legacy ZTP vs partner paths not bottomed out. Keep on interest list; **do not** schedule Poly-first automation or docs until verified. Research / lab spike only. |
| **Grandstream** | **GDMS** + **GAPS** | GDMS assigns templates or destination URLs by MAC; GAPS = Alignment and Provisioning System |
| **Snom** | **SRAPS** | Europe-hosted secure redirect; GDPR-oriented; API for SP automation |
| **Fanvil** | **FDMCS** | Free redirection / ZTP for desk, hotel, and intercom / door units |
| **Gigaset** | **Gigaset redirection server** | Vendor cloud redirect (same role as RPS/SRAPS). Enrollment needs **MAC + PIN** (PIN on device label). Third-party PBX docs (e.g. [Vodia](https://doc.vodia.com/docs/gigaset-provisioning)) describe using *Gigaset’s* redirect — not a Vodia-owned platform. Also supports LAN PnP / opt66 / manual URL. |

Other vendors: treat via **reseller redirect** or secondary path (opt66 / manual) until explicitly added here. **Poly** stays interest-only until the post-HP path is confirmed.

```text
Phone power-up
  → HTTPS to vendor redirect (Yealink RPS / Poly Lens / GDMS / SRAPS / FDMCS / …)
  → often → reseller redirect
  → 3xx / next-URL → our provision base URL
  → home listener (v1) or edge provision proxy (§0) expands config by MAC
  → phone applies config → SIP REGISTER (fleet: SBC; solo: instance)
```

| Concern | Stance |
|---------|--------|
| **How the phone finds us** | **MAC enrolled** in vendor and/or reseller RPS with **target = our provision URL** |
| **What we own** | Final **HTTPS config stream** on the home (v1) / via proxy (§0 later) — not the redirect product |
| **DHCP opt66 / 114** | **Secondary** — on-prem LAN, lab, or sites without RPS. Document; do not design the cloud spine around it |
| **PnP multicast** | **Secondary** — same-LAN only; optional later |
| **Manual URL** | Lab / break-glass |

### Target URL by deployment

| Deployment | RPS / redirect target should be | On tenant move |
|------------|----------------------------------|----------------|
| **Solo / Rule 6** | Instance provision URL (`https://{instance-fqdn}:{prov-port}/…`) | N/A |
| **Fleet v1 (instance-local only)** | **Current** home provision URL | **Re-point** MAC in vendor/reseller RPS to the new home URL (ops / API later), **or** phones never re-fetch and keep working on already-loaded config until next redirect-driven reprovision |
| **Fleet + §0 proxy** | **Stable** provision hostname (proxy A/AAAA) | **No** RPS change; update **proxy map** only (same mobility family as SBC `setid`) |

**SIP vs provision:** fleet desk templates still embed **SBC** as registrar/proxy in the config body. Redirect discovers **HTTP config**; it does not replace SBC for REGISTER. Already-applied configs keep calling until the phone re-fetches — a move does not brick mid-day SIP; it affects the **next** provision GET if the redirect still points at an old home and no proxy is in path.

### Product implications

- Ship **home HTTPS listener** first; operators enroll MACs in RPS pointing at that URL (document the URL shape in SPA/MkDocs when UI exists).  
- Automating RPS enrollment / re-point (vendor APIs, reseller APIs) is a **follow-on** — not a v1 blocker; v1 may be manual portal entry + docs.  
- Prefer **stable proxy URL in RPS** before advertising “tenant move with zero phone **and** zero RPS touch” for re-provision.  
- **M1** (reseller delivers full config) remains valid when the customer never points RPS at us.

---

## 1. One-line purpose

Serve vendor phone config files keyed by **MAC** (and vendor “common” descriptors), embedding SIP identity and registrar/proxy so a desk phone can register without manual SIP setup — with phones **finding** that URL primarily via **vendor/reseller RPS**, and **fleet mobility** that does not require phone-side URL changes when a **stable** provision host (proxy) or RPS re-point is in place.

---

## 2. Product class

| Concern | Stance |
|---------|--------|
| **What it is** | Home **HTTPS provision listener** + optional **edge reverse-proxy** for fleet Host routing |
| **What it is not** | Not Asterisk; not Gatekeeper; not SBC call plane; not SPA; **not** a vendor-RPS replacement; **not** required for calls once phones are configured |
| **previous PBX lift** | Port behaviour from private archives / previous PBX `device.php` (MAC → expand → text). Polish auth, HTTPS, multi-tenant pathing, sndcreds. **No** Device template table revival (#28) |
| **Call plane** | Phones **register / media** via normal fleet SIP (SBC → instance). Provision is **config HTTP only** |
| **Discovery** | **RPS primary** (§0.2); opt66 / PnP secondary |
| **Directory / Rule 1** | Proxy routing may **read** catalog home facts (projection). Provision must not become a call-routing dependency. Proxy/home down → already-provisioned phones keep working |
| **Rule 7** | Provision proxy is a **replaceable edge** sibling of the SBC (HTTP, not SIP). Prefer dumb nginx + map over a fat app on the edge |
| **Compete?** | Thin MAC→config on the home; **do not** out-feature or replace vendor/reseller **redirect** |

---

## 3. Happy path (phone)

**Cloud / production (primary):**

```text
Phone power-up → vendor RPS (± reseller redirect)
  → target URL = our provision base (instance v1, or stable proxy later)
  → GET https://{provision-host}:{port}/…  (MAC in query, path, or body)
  → [fleet §0] DNS → provision proxy → current home
  → [solo / fleet v1] straight to home listener
  → home: MAC → expand from extension/handset data → body
Phone applies config → SIP REGISTER to SBC / domain from file (solo: instance)
```

**On-prem / lab (secondary):** DHCP opt66/114 or manual URL may set the same provision base without RPS.

| Name | Role |
|------|------|
| **RPS / reseller** | Enrolls MAC → next provision URL (discovery) |
| **Provision host in URL** | v1: instance FQDN + provision port. Fleet polish: stable proxy hostname |
| **Provision proxy A/AAAA** | Stable edge IP(s); **does not move** with tenant (§0) |
| **Home backend** | Instance provision listener; secrets + expand here |
| **SIP contact in file** | Fleet: **SBC** + tenant domain string. Solo: instance FQDN/IP |

---

## 4. Responsibilities

### 4.1 Edge proxy (SBC-colocated)

| Do | Notes |
|----|-------|
| HTTPS terminate on SBC edge VIP / provision vhost | Own LE / wildcard story on the edge (detail TBD) |
| Route by Host / SNI and/or MAC → home | Map from **catalog/S3 only**; refresh on move/onboard |
| Extract MAC from request | Vendor forms: query `mac=`, path `/{mac}.cfg`, POST body — normalize 12-hex |
| Health / 502 when home unknown | Unknown tenant Host or unknown MAC → 404/502; no cross-tenant leak |
| No secret render | Proxy does not read `ipphone` passwords |
| Mirror with SBC HA | Same published map on each edge node; no local secret state |
| Vendor client cert verify | CA bundle on edge; require client cert for remote/fleet provision vhost (§8) |

### 4.2 Home listener

| Do | Notes |
|----|-------|
| HTTP(S) MAC / descriptor → vendor config | Same URL families as previous PBX (`?mac=`, `/{mac}.cfg`, Yealink common, …) |
| Template expand | From extension/handset data (previous PBX-style); **not** revived Device table (#28) |
| Credential gating | `sndcreds` Always \| Once \| No |
| Multi-tenant | Resolve tenant from Host / path; only that cluster’s phones |
| Unknown MAC | **404** |
| Logging | URI, MAC, UA, success/404; no secrets |

---

## 5. Inputs (home)

| Input | Source | Note |
|-------|--------|------|
| Extension + MAC + secret + expand inputs | `ipphone` (+ handset/fkey as needed) | Authored on instance; **HoR for secrets**. No Device table |
| BLF / line keys | fkey tables | As today / previous PBX |
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
- Full vendor **config** matrix day one — subset of §0.2 interest list; expand streams iteratively  
- **Replacing** vendor/reseller **redirect / RPS** with an in-house discovery product
- DHCP **server** as a product — document opt66 as secondary; optional lab helper later
- Reviving the purged **Device** template table (#28)

---

## 8. Security (thin)

| Topic | Stance |
|-------|--------|
| **MAC as locator** | MAC selects the extension row; it is **not** the sole authZ for remote/fleet |
| **Vendor client certs (primary remote harden)** | **Locked intent:** edge provision vhost uses **TLS client auth** against a **vendor CA bundle** (SARK `3pcerts` model — `SSLVerifyClient require` + concatenated manufacturer CAs). Request must present a cert chaining to an allowed phone vendor (Snom, Yealink, …). **Not a panacea** (proves vendor/type family, not a specific MAC identity), but blocks casual internet MAC scrape. Prior art: previous PBX `sark-prov-ssl` / port **41363** path for Snom + Yealink |
| **Where certs live** | Bundle on the **SBC edge** (with the provision nginx). Ops-managed file/artifact for v1 — **no** SPA “third-party certs panel” required to ship (panel remains won't-do / later) |
| **Lab / LAN** | Open or weaker GET by MAC acceptable on private nets; do not use as the cloud default story |
| **HTTPS** | Required off-lab; edge terminates for fleet proxy path; home listener HTTPS for solo / direct |
| **Secrets in body** | Only when `sndcreds` allows; prefer Once for first boot |
| **Writes from phones** | Ignore PUT / vendor upload (404/no-op) |
| **Cross-tenant** | Host must select exactly one tenant; never serve another cluster’s MAC |

**Note:** Vendor client-cert check mitigates “anyone who knows a MAC can GET config.” It does **not** replace `sndcreds`, fail-closed routing, or keeping `SIP_AUTH` off S3.

---

## 9. Relationship to other tracks

| Track | Boundary |
|-------|----------|
| **Extension provisioning (SPA/API)** | Authors `ipphone` + Commit → PJSIP on **home** |
| **This track** | Delivers **phone config HTTPS**; RPS points here; optional proxy routes; home renders |
| **Fleet DNS / LE §0** | SIP: no tenant A→home. Provision: tenant/wildcard A→**proxy** (exception — update TLS §0 when shipping) |
| **SBC** | Runtime SIP; model for Host/domain → home routing |
| **Tenant move** | Catalog + SBC setid + (**proxy map** *or* **RPS re-point** to new home URL) — one mobility story for SIP; discovery follows §0.2 |
| **Vendor / reseller RPS** | **Discovery** (and optional full M1 config); not our secret HoR |

---

## 10. Implementation map (when scheduled)

| Slice | Likely home | Notes |
|-------|-------------|--------|
| Home listener | **pbx3** / **pbx3api** (or small co-located PHP) | Lift previous PBX `device.php` behaviour; multi-tenant Host; HTTPS non-443 |
| Edge proxy | **SBC host** — sibling nginx (locked 2026-09-30) | Map from catalog/S3 only; mirror with SBC HA; **not** in SIP/OpenSIPS path |
| Map refresh | Gatekeeper / move job hook | Publishes map artifact to edge(s); same events as SBC domain repoint |
| RPS enrollment | Ops docs first; APIs later | MAC → provision URL; re-point on move if no proxy |
| Expand inputs | Extension / handset / fkey | **No** Device table (#28) |
| SPA | Later | Show provision URL + RPS enrollment hint |
| TLS §0 note | **`TLS_AND_CERTIFICATES.md`** | Document provision A→proxy exception |

---

## 11. Open decisions (narrow)

0. **Schedule build?** — Direction preferred; priority TBD (TODO #23 / 0k).  
1. **Cert on proxy** — Wildcard `*.apex` vs per-tenant SAN vs name `provision.{apex}` with path-based tenant (path would change phone URL shape — Host-based preferred).  
2. ~~**Where proxy runs**~~ — **Locked 2026-09-30:** **SBC-colocated** nginx (or equivalent); map from catalog/S3 only; gatekeeper publishes map; mirrors with SBC HA. Not phone-facing on gatekeeper.  
3. **Map transport** — Regenerated nginx conf vs lua (MAC extract from URI/body) vs pull of static map object from S3 (prefer no live gatekeeper on GET path).  
4. **Primary route key** — Host-only, MAC-only, or Host with MAC cross-check (lean: support both; MAC always available on the wire).  
5. **Solo** — Skip proxy; RPS (or lab) → instance directly (M3 solo).  
6. **Stack for home listener** — PHP parity with previous PBX vs rewrite; behaviour first.  
7. **RPS automation** — Manual portal vs vendor/reseller APIs for enroll/re-point; clearer §0.2 vendors first (**Yealink, Snom, Grandstream, Fanvil, Gigaset**). **Poly** deferred until Lens/ZTP post-HP is understood. Gigaset: confirm portal/API + PIN enrollment UX.  
8. **Provision listen port** — Pick stable non-443 default; document for RPS target URLs.  
9. **Poly discovery** — Confirm whether desk phones still expose a simple MAC→URL redirect usable by us, or only via Poly Lens / partner SKUs after HP.

---

## 12. Verify later (acceptance sketch)

- Phone with known MAC (via RPS → our URL, or lab direct) receives config; unknown MAC → 404.  
- Cloud happy path does **not** require DHCP opt66.  
- Fleet: SIP REGISTER still via **SBC** (not provision IP).  
- Move tenant home → either proxy map update (**no** RPS change) **or** documented RPS re-point to new home URL.  
- Proxy or home provision down → existing registrations unaffected.  
- Instance Commit still owns Asterisk; provisioner does not write PJSIP.  
- Secret only read from home `ipphone` at render time.  
- No Device template table reintroduced.
