# Provisioning — requirements

**Status:** Architecture **locked 2026-09-30** (discovery, solo/fleet shape, builder, security). **TLS / edge / MAC index locked same day:** **`provision.{apex}:41363`** + **reverse proxy** + **HTTP edge→home** (SBC-only) + **MAC canon** (§6).  
**Implementation plan:** **`PROVISIONING_IMPLEMENTATION_PLAN.md`** (phases A–D; **C9** migrator parked).  
**v1 direction:** **instance-local** HTTPS phone provisioner on each home (**41363**) first. Fleet edge = **SBC-colocated** nginx reverse **proxy** later (§0); map from **catalog MAC index** only (no secrets). Still **no** third-party certs SPA panel.  
**Discovery (locked 2026-09-29):** **Vendor / reseller redirect (RPS)** is the **primary** way phones find the provision URL in cloud deployments. DHCP opt66/114 and PnP multicast are **secondary** (on-prem / lab). See **§0.2**.  
**2026-08-25:** Instance **Device** template table / API / SPA **purged** (TODO #28). Extension `ipphone.device` remains a **vendor label** (e.g. Snom / Yealink), not a per-SKU catalogue. See **§4.4** — do **not** revive a per-model Device matrix.  
**2026-09-30:** Prior-PBX lesson locked — vendors share one provision stream per manufacturer (rare exceptions); old per-model names were kept only as legacy aliases for existing customers.  
**2026-09-30 (TLS / topology):** Rejected fleet **HTTP redirect** edge (phones must not learn home URLs — forward-compat with **topology hiding**). Locked phone-facing name **`provision.{apex}`**; route by **MAC**; edge terminates HTTPS; **edge→home = HTTP** with home firewall locked to **SBC(s)**. See **§0**, **§0.3**, **§8**.  
**2026-09-30 (MAC index):** **MAC is canon** for handset identity; **tenant** and **instance** are FKs on a fleet catalog MAC index (routing only — no secrets). Solo→fleet RPS flip = rare; migrator parked. Default provision **port 41363** (prior art). See **§6**.  
**2026-09-30 (#3 / #11 freeze):** Map transport = **static nginx `map` artifact** published from catalog (no live gatekeeper/S3 on GET). Edge **404** when URI has no routable MAC (Yealink `y000000*` etc.); home still serves common for solo; MAC streams `#INCLUDE` common. See **§11**.  
**Earlier (2026-08-10):** Preferred fleet shape was home-local listener + edge nginx provision proxy — deferred past instance-local v1.  
**Earlier (2026-08-06):** Explored fleet S3 MAC inventory + dedicated provision host; secrets/HoR split made that path hard.  
**Reference notes:** private prior co-located provisioner / previous PBX archives (operator only — not in product tree).  
**Related:** **`PROVISIONING_IMPLEMENTATION_PLAN.md`** · **`FLEET_DESK_PHONE_NAT.md`** · **`pbx3spa/workingdocs/EXTENSION_PROVISIONING_*`** · **`TLS_AND_CERTIFICATES.md` §0** · **`UFW_SHOREWALL_MIGRATION.md` §3** · **`DESIGN_RULES.md`** Rule 1 / 7 / 13 · **`TODO.md`** #23 / #28 / **0k**.

---

## 0. Preferred fleet shape (2026-08-10)

**Same idea as the SBC, for HTTP config instead of SIP.**

| Layer | Role |
|-------|------|
| **Edge provision proxy** | **Colocated with the SBC** (locked 2026-09-30) — nginx (or equivalent) **reverse proxy** on the **same edge entity / VIP** as SIP. Phone-facing name **`provision.{apex}:41363`** (locked — **§0.3**). Terminates **HTTPS**. Routes by **MAC** → current home via **catalog MAC index** (**§6**). **`proxy_pass` over HTTP** to home **41363** (**SBC-only**). **No secrets, no expand**. **Not** an HTTP 3xx redirect to the home. |
| **Home listener** | Co-located on the instance (tenant-aware). Reads **`ipphone`** (same secret HoR as Asterisk). Lift and polish existing **previous PBX / prior co-located** provision routines (`device.php`-class: MAC → template expand → body). **Fleet:** listen **HTTP** on **41363**, reachable **only from SBC(s)**. **Solo / direct:** **HTTPS** on **41363** (phone hits home). |
| **Phone** | Fleet RPS target = **`https://provision.{apex}:41363/…`** with **MAC** in query/path/body. DNS A/AAAA for `provision.{apex}` → **edge VIP** (not home). SIP REGISTER / media still **SBC** + tenant domain string — provision vhost ≠ SIP next hop; same machine/VIP OK. |

```text
Phone GET/POST https://provision.{apex}:41363/…  (MAC in query, path, or body)
  → DNS A/AAAA → SBC edge (provision vhost; stable; does not change on tenant move)
  → HTTPS terminate + optional vendor client-cert verify
  → nginx proxy_pass HTTP → current home :41363  (MAC index → home)
  → home listener expands vendor config from local SQLite (previous PBX lift)
  → phone applies config → SIP REGISTER via SBC (unchanged)
```

**Routing key (locked):**

| Key | Source | Notes |
|-----|--------|-------|
| **MAC** | Always on the request (GET query/path or POST body — vendor-dependent) | Lookup MAC → tenant → home from catalog map. Primary fleet route key under shared `provision.{apex}` Host |

Prefer **fail closed**: unknown MAC → 404/502; never guess across tenants.

**Tenant move:** update the proxy’s **backend map** (MAC→home) from catalog — same mobility events as SBC `setid` projection. **No** DNS change on move; **no** phone re-key of provision host; **no** vendor/reseller RPS re-point. Secrets never leave the home row for render.

**Why this works (operator stance):** One **edge entity** for phones (SIP + provision HTTP). Phones never learn home addresses — required if **topology hiding** (RTPproxy / media via edge) ships later. **Discovery** remains vendor/reseller **RPS** (§0.2); that redirect chain is intentional and **not** the same as an in-fleet redirect to homes. **Solo / singleton:** no proxy — RPS points at the instance directly (Rule 6).

### Edge placement (locked 2026-09-30)

| Concern | Stance |
|---------|--------|
| **Where it runs** | **On the SBC host(s)** — sibling nginx (or equivalent), not OpenSIPS, not gatekeeper phone-facing |
| **Why SBC** | One edge for desks; stable VIP already; functionally “phone finds the edge” for both SIP and config HTTP |
| **Map context** | **Catalog MAC index** only (`mac` → tenant + instance FKs — **§6**). **No** `ipphone` passwords, no home DB, no gatekeeper live calls on the request path |
| **HA / mirror** | Because the proxy is **stateless aside from the published map**, it **mirrors with the SBC** without drama — same map artifact on each edge node (or shared VIP backend). Refresh map on both when catalog changes |
| **Gatekeeper / control** | **Publishes** / refreshes the map from catalog (move/onboard jobs). Does **not** terminate phone provision GETs |
| **Rule 7** | Keep provision as a **separate unit** from OpenSIPS so an SBC software swap does not rewrite HTTP; still same *machine/VIP* is fine |
| **Rule 1** | Provision down ≠ calls down; don’t put expand/secrets on the edge |

### Relationship to `TLS_AND_CERTIFICATES.md` §0

§0 says tenant names are **SIP domain strings** and must **not** be public A records **aimed at homes** (SPA/API stay on instance DNS; SIP via SBC).

**Fleet provision (locked):** phone-facing name is **`provision.{apex}`** only — **one** A/AAAA → edge VIP; **one** edge server cert for that name. **No** tenant FQDN A records for provision; **no** wildcard/multi-SAN tenant Host scheme. Document `provision.{apex}` in TLS §0 when Phase C ships (cross-link). Tenant Host as provision URL **rejected** (creates §0/DNS/cert churn without benefit under MAC routing).

---

## 0.1 Build or not? / management options (retained)

Desk-phone HTTP provisioning remains a crowded market (vendor RPS, reseller platforms). In-house owns the **final config stream** when we want secrets on the home; we do **not** compete with vendors on the **redirect / discovery** layer.

| # | Path | Idea | Secrets | When |
|---|------|------|---------|------|
| **M1** | **Don't own final HTTP** | Vendor RPS / reseller **delivers the full config** (or never points at us) | Stay on instance for SIP only | MSP already on reseller RPS end-to-end |
| **M2** | **Thin export** | CSV/JSON / MAC list for someone else’s RPS enrollment | One-shot reveal; not S3 inventory | Feed reseller portals; follow-on to M3 |
| **M3 + RPS discovery** | **Default cloud path** | RPS redirects MAC → our provision URL; **home** (or §0 proxy) expands config | Single HoR = extension row | Production desk phones |
| **M3 + edge proxy** | **Preferred fleet polish** | RPS target = **`provision.{apex}`**; nginx **proxy** MAC→home (**§0**, **§0.3**) | Same | Zero-touch move including re-provision GET; topology-hiding ready |
| **M3 + edge redirect** | **Rejected** | Edge returns 3xx `Location` to home provision URL | Same | Phones learn home — breaks future topology hiding; do **not** build |
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

### Vendor provisioning docs (authoring aid)

Manufacturers publish **provisioning guides** online — use them when writing/lifting vendor-grain streams (§4.4–§4.6).

| Reality | |
|---------|--|
| **Most (§0.2)** | Downloadable / text manuals (PDF or similar) — last checked: usable offline reference |
| **Snom** | Guide is largely an **online UI only** (no clean text manual in the same sense) — awkward for agents and for diffable authoring; budget extra friction when doing Snom streams |
| **Hygiene** | Links rot; pin versions/dates in working notes when a stream is frozen; do not assume the UI tour is citable in git |

This is documentation ergonomics, not a product feature — but it affects how fast Yealink vs Snom templates get done.

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
| **Solo / Rule 6** | Instance provision URL (`https://{instance-fqdn}:41363/…`) | N/A |
| **Fleet v1 (instance-local only)** | **Current** home provision URL | **Re-point** MAC in vendor/reseller RPS to the new home URL (ops / API later), **or** phones never re-fetch and keep working on already-loaded config until next redirect-driven reprovision |
| **Fleet + §0 proxy** | **`https://provision.{apex}:41363/…`** (stable; MAC on request) | **No** RPS change; update **MAC index + proxy map** only (same mobility family as SBC `setid`) |

**SIP vs provision:** fleet desk templates still embed **SBC** as registrar/proxy in the config body. RPS discovers **HTTP config**; it does not replace SBC for REGISTER. Already-applied configs keep calling until the phone re-fetches — a move does not brick mid-day SIP; it affects the **next** provision GET if RPS still points at an old home and no proxy is in path.

### Product implications

- Ship **home HTTPS listener** first (solo/direct); operators enroll MACs in RPS pointing at that URL (document the URL shape in SPA/MkDocs when UI exists).  
- Automating RPS enrollment / re-point (vendor APIs, reseller APIs) is a **follow-on** — not a v1 blocker; v1 may be manual portal entry + docs.  
- Prefer **stable `provision.{apex}` in RPS** before advertising “tenant move with zero phone **and** zero RPS touch” for re-provision.  
- **M1** (reseller delivers full config) remains valid when the customer never points RPS at us.

---

## 0.3 Fleet TLS + proxy vs redirect (locked 2026-09-30)

| Lock | Stance |
|------|--------|
| **Edge mechanism** | **Reverse proxy** (`proxy_pass`). **Not** HTTP 3xx redirect to the home |
| **Why not redirect** | Phones already follow redirects for **vendor/reseller RPS** discovery — that is fine and stays primary (§0.2). An **in-fleet** redirect would expose the **home** provision URL to the handset. That is incompatible with future **topology hiding** (RTPproxy / media via edge): desks must never learn home addresses. Expect pushback (“RPS is redirects; why not one more?”) — answer: RPS is discovery; the edge is the lasting phone-facing surface (same story as SIP, later RTP) |
| **Phone-facing name** | **`provision.{apex}`** only. One DNS A/AAAA → SBC VIP. One server cert for that name (LE HTTP-01 or commercial). **Rejected:** tenant Host / wildcard `*.apex` / per-tenant SAN as the provision URL |
| **Route key** | **MAC** (always on the wire). Map MAC → home from catalog |
| **TLS legs** | **Phone → edge:** HTTPS (required off-lab). **Edge → home:** **HTTP**, with home firewall / SG allowing **only SBC(s)** to the provision port |
| **Solo / Phase A** | Unchanged: phone → **`https://{instance}.{apex}:41363/…`** with instance cert; no proxy |
| **mTLS** | Vendor client CA verify on the **edge** hop when CA available (§8); home does not re-do client cert for the proxy path |
| **Body / secrets** | Rendered only on home; edge must not log or store clear bodies (audit stays on home, obfuscated — §4.7). Cleartext on the private edge→home hop is accepted **because** the port is SBC-only |
| **Map sync** | Publish with setid job from **MAC index** (**§6**); **reconcile** extends catalog≡SBC sweeper (**C8**) — coupled, not perfectly synchronous |
| **Default port** | **41363** (prior-art provision port) — solo HTTPS and fleet edge HTTPS / home HTTP |
| **Home firewall (install)** | **Same path as fleet SIP.** Fleet UFW baseline (`ufw-apply-baseline.sh` **fleet**) allows **41363/tcp from SBC IP(s) only** — same `PBX3_UFW_SBC_IPS` / `PBX3_SBC_EGRESS_HOST` as 5060/5061. **Baked into instance install**, not ops folklore. Solo: **41363** from LAN CIDR (widen for cloud RPS). Law: **`UFW_SHOREWALL_MIGRATION.md` §3** |

---

## 1. One-line purpose

Serve vendor phone config files keyed by **MAC** (and vendor “common” descriptors), embedding SIP identity and registrar/proxy so a desk phone can register without manual SIP setup — with phones **finding** that URL primarily via **vendor/reseller RPS**, and **fleet mobility** that does not require phone-side URL changes when RPS targets stable **`provision.{apex}`** (edge proxy) or when solo uses the instance URL.

---

## 2. Product class

| Concern | Stance |
|---------|--------|
| **What it is** | Home provision listener (HTTPS solo; HTTP behind fleet proxy) + optional **edge reverse-proxy** for fleet MAC routing |
| **What it is not** | Not Asterisk; not Gatekeeper; not SBC call plane; not SPA; **not** a vendor-RPS replacement; **not** an HTTP redirect-to-home; **not** required for calls once phones are configured |
| **previous PBX lift** | Port behaviour from private archives / previous PBX `device.php` (MAC → expand → text). Polish auth, HTTPS (solo), multi-tenant pathing, sndcreds. **No** Device template table revival (#28) |
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
  → target URL = our provision base (instance v1, or provision.{apex} later)
  → GET https://…  (MAC in query, path, or body)
  → [fleet §0] DNS → provision.{apex} → HTTPS edge → HTTP proxy_pass → current home
  → [solo / fleet v1] straight to home listener (HTTPS)
  → home: MAC → expand from extension/handset data → body
Phone applies config → SIP REGISTER to SBC / domain from file (solo: instance)
```

**On-prem / lab (secondary):** DHCP opt66/114 or manual URL may set the same provision base without RPS.

| Name | Role |
|------|------|
| **RPS / reseller** | Enrolls MAC → next provision URL (discovery) |
| **Provision host in URL** | v1: instance FQDN + provision port. Fleet polish: **`provision.{apex}`** |
| **Provision proxy A/AAAA** | Stable edge IP(s); **does not move** with tenant (§0) |
| **Home backend** | Instance provision listener; secrets + expand here |
| **SIP contact in file** | Fleet: **SBC** + tenant domain string. Solo: instance FQDN/IP |

---

## 4. Responsibilities

### 4.1 Edge proxy (SBC-colocated)

| Do | Notes |
|----|-------|
| HTTPS terminate on **`provision.{apex}`** | One name, one cert (LE or commercial); A/AAAA → SBC VIP (**§0.3**) |
| `proxy_pass` **HTTP** → home provision port | Home **UFW fleet baseline**: **41363/tcp from SBC IP(s) only** (install — same as SIP). SG may mirror |
| Route by **MAC** → home | Map from **catalog/S3 only**; refresh on move/onboard |
| Extract MAC from request | Vendor forms: query `mac=`, path `/{mac}.cfg`, POST body — normalize 12-hex |
| Health / 502 when home unknown | Unknown MAC → 404/502; no cross-tenant leak |
| No secret render | Proxy does not read `ipphone` passwords; do not log clear bodies |
| Mirror with SBC HA | Same published map on each edge node; no local secret state |
| Vendor client cert verify | CA bundle on edge; require client cert for remote/fleet provision vhost (§8) |
| **Not** HTTP redirect to home | 3xx `Location` to instance URL is **rejected** (**§0.3**) |

### 4.2 Home listener

| Do | Notes |
|----|-------|
| MAC / descriptor → vendor config | Same URL families as previous PBX (`?mac=`, `/{mac}.cfg`, Yealink common, …) |
| Listen mode | **Solo / direct:** **HTTPS** (instance cert). **Fleet behind proxy:** **HTTP**, SBC-only |
| Template expand | **INCLUDE + parameter substitution** only (**§4.5**); **vendor-grain** streams (**§4.4**). **No BLF/fkey expand for now** |
| Credential gating | **`sndcreds` Always \| Once \| No** — see **§4.3** (ONCE preferred for secrets; industry-common) |
| Multi-tenant | Resolve tenant from MAC (and local cluster data); only that cluster’s phones |
| Unknown MAC | **404** |
| Logging | **Dedicated provision audit trail** — see **§4.7** (not Apache-only) |
| BLF / softkeys | **Out of v1** — see **§4.5**; hand-edit template if rare need |

### 4.3 Credential stanzas — Always / Once / No (locked)

Same idea as previous PBX **`sndcreds`** and as many **third-party / vendor cloud** provision platforms: sensitive lines in the config body (SIP password, phone admin/user passwords, LDAP bind secrets, …) are gated.

| Mode | Behaviour |
|------|-----------|
| **Always** | Secret stanzas included on **every** successful provision GET |
| **Once** | Secret stanzas included on the **next** successful GET only; then provision state flips so later GETs **omit** those stanzas (previous PBX: `Once` → `No` after send) |
| **No** | Secret stanzas omitted |

**Default lean:** prefer **Once** for SIP password and similar (first boot / enroll gets creds; daily re-poll does not re-emit password). Some vendors require Always — allow per-extension override.

**Prior PBX note (2026-09-30):** the live tree **dropped** the post-send flip (`Once` → `No`) — that update block was commented out. pbx3 **restores** the flip when implementing §4.3 (do not copy the disabled path). Use proper comparison (`==`), prepared statements.

**Factory reset / replace handset:** phone loses local config and needs secrets again. Operator must **reset provision state** for that extension/MAC (set back to **Once**) so the next GET re-sends ONCE stanzas. Resetting the phone **without** resetting provision state → phone boots, fetches config **without** password → register fails until state is cleared.

**Reset is server-side only (locked):** flip `sndcreds` (or equivalent) on the **home extension row** — no phone crypto. SPA **Reset provision state** next to **Last provisioned** (Phase **B1**). Also reset to **Once** on **SIP password regen**. Pain is operator forgetfulness, not engineering cost. Document in SPA/MkDocs; third-party RPS platforms use the same pattern.

**HoR:** provision state (`sndcreds` or equivalent) lives on the **home** extension row with the secret — not in S3 / edge MAC index.

### 4.4 Template grain — vendor, not per-SKU (locked 2026-09-30)

**Early assumption (previous PBX):** device **type/model** would drive different provision streams (e.g. snom300, snom500, snom700).

**What actually happened:** manufacturers used **the same config stream** across models within a vendor (one or two exceptions). The library collapsed to **vendor grain** — e.g. **`snom`**, **`yealink`**, … — which **vastly** reduced the Device table. Older per-model keys were retained only as **legacy aliases** for existing customers already pointing at them.

| Stance for pbx3 | |
|-----------------|--|
| **Do** | Author **one primary stream per vendor** of interest (§0.2); OUI / create-time label picks vendor |
| **Do not** | Rebuild a Device SPA/table of per-SKU templates (snom300 vs snomD785 vs …) as the product model — **#28 purge stands** |
| **Exceptions** | Rare model-specific overlays only when a vendor truly diverges — explicit, not a matrix by default |
| **Migrate / aliases** | If lifting old DBs, map legacy model names → vendor stream; keep read aliases only if needed for customer data, not as a growth path |
| **`ipphone.device`** | Vendor (or General SIP / WebRTC) label for expand + UI — not a foreign key into a fat Device catalogue |

Expand still comes from **extension data** + vendor stream — not a revived multi-hundred-row Device editor. **No** BLF/fkey machinery in v1 (**§4.5**).

### 4.5 Stream builder — INCLUDE + substitute; no BLF UI (locked 2026-09-30)

**In principle the expander is trivial:**

1. **`#INCLUDE` (or equivalent)** — pull named fragment (vendor common, transport/tls snippet, …) into the stack; loop-safe.  
2. **Parameter substitution** — replace placeholders from the extension row / globals (`$ext`, `$password` when sndcreds allows, `$desc`, registrar/proxy host, ports, …).

That is the whole engine for v1. No expression language, no per-model matrix, no Device SPA.

**BLF / softkeys / fkey expand — deferred**

| Stance | |
|--------|--|
| **Prior practice** | Fancy BLF-from-DB / UI **rarely used** in the field |
| **v1** | **Do not** build `IPphone_FKEY` expand, `$fkey` injection, or a softkey SPA |
| **Escape hatch** | If a site truly needs keys, **hand-code** lines into the vendor template / per-tenant overlay — good enough until a customer asks for UI |
| **Revisit** | Only when someone explicitly wants managed BLF provisioning |

Asterisk/PJSIP subscribe / named pickup groups remain separate from this HTTP stream builder.

### 4.6 Stream formats — line vs closed XML (note)

Most vendor streams are **line-oriented** (key=value / proprietary text): INCLUDE + substitute fits cleanly.

| Vendor | Format note |
|--------|-------------|
| **Yealink, Fanvil, …** | Typical line / flat profiles — straightforward substitute |
| **Poly** | **Pure XML** with **closing stanzas** — nuisance for naive line-include / partial rewrite; treat as its own stream family when/if Poly is in scope |
| **Snom** | Historically line-oriented; **moving toward closed XML** as well — watch when authoring/lifting Snom templates; may need XML-aware edit rules later, not a second engine day one |

Engine stays INCLUDE + substitute; **template authoring** absorbs XML closed-stanza pain, not a BLF-scale subsystem.

### 4.7 Provision audit trail (locked 2026-09-30)

Prior PBX mostly relied on **web server access logs** plus light syslog — workable for debugging, weak as an **audit** of who got what.

**Product intent:** a **dedicated provision audit log** on the home (and later a thin edge access/deny log on the SBC vhost). Apache/nginx access logs remain useful for ops; they are **not** the audit HoR.

| Field (home, per request) | Required | Notes |
|---------------------------|----------|-------|
| Timestamp (UTC) | Yes | |
| Outcome | Yes | `200` / `404` / error class |
| Client IP | Yes | |
| Request URI (path + query shape) | Yes | Truncate extremes |
| Normalized MAC | When known | |
| Extension / tenant id | When resolved | shortuid / cluster |
| Vendor label / UA (truncated) | Yes | |
| sndcreds mode applied | Yes | Always / Once / No |
| Secrets emitted? | Yes | boolean (`creds_sent=true/false`) |
| Descriptor / stream name | When used | e.g. yealink.Common |
| **Rendered stream (body sent)** | **Yes on success** | Config text as returned to the phone, **with password / secret values obfuscated** in the audit copy (e.g. replace SIP password, phone admin/user pass, LDAP bind secrets with a fixed mask like `********`). Structure and non-secret fields stay intact for investigation (“what did we send?” without retaining cleartext creds). Omit or empty on 404 |

| Stance | |
|--------|--|
| **Do** | Structured record per request (JSON object per line, or metadata + body artifact). Prefer one audit store operators can grep by MAC |
| **Obfuscate in audit copy** | Apply the same secret-line awareness as **§4.3** (`sndcreds` patterns): mask values for `$password` and vendor secret keys in the **logged** stream. The **wire response to the phone** is unchanged (cleartext when Once/Always). Never store cleartext SIP/phone passwords in the audit artifact |
| **Treat as still sensitive** | Obfuscated streams can still reveal extension ids, MAC, topology — mode **0600**; don’t world-publish |
| **Pragmatic threat** | Until desk SIP is widely **TLS**, cleartext passwords remain visible on **UDP signalling** — that does not excuse keeping cleartext in our audit files. Prefer Once; SIP-TLS remains the long-term wire fix |
| **Retention** | Follow instance log retention; rotate; fleet log-ship OK once obfuscated (still ACL like other instance logs) |
| **Edge (Phase C)** | Proxy logs Host/MAC → upstream + status; **does not** store home-rendered bodies (bodies stay on home audit, obfuscated) |
| **SPA** | **Last provisioned** timestamp on extension (§ below); optional later “view last stream” shows **obfuscated** audit copy only |

**last-seen / last-provisioned (investigation first stop)**

Often the **first** question in a desk-phone incident: “did this MAC ever get config, and when?” — then open the audit for **what** was sent.

| Stance | |
|--------|--|
| **HoR** | Persist on the **extension row** (`ipphone`) — e.g. `last_provisioned_at` (and optional `first_provisioned_at`) updated on **successful** config send (200 with body). Prior PBX had `firstseen`/`lastseen`; lift the idea, don’t leave it commented out |
| **Not a substitute for audit** | Row timestamp = fast UI/SQL check; **§4.7** log = full stream + request metadata |
| **404 / deny** | Do **not** bump last-provisioned on fail-closed (unknown MAC, etc.) |
| **SPA** | Show **Last provisioned** on extension detail early (Phase **B** lean — high value for support). Sort/filter later |
| **Timezone** | Store UTC; display per site TZ policy |

---

## 5. Inputs (home)

| Input | Source | Note |
|-------|--------|------|
| Extension + MAC + secret + vendor label | `ipphone` | Authored on instance; **HoR for secrets**. No Device table |
| last_provisioned_at (first optional) | `ipphone` | Updated on successful provision GET (§4.7); investigation first stop |
| BLF / line keys | — | **Not in v1 stream** (§4.5); optional hand-edit in template |
| SIP host policy | Fleet: embed **SBC** + tenant domain; not home public IP | Matches W1 / fleet desk path |
| OUI → vendor | `manuf.txt` helper | Create-time UI; not every GET |

---

## 6. Routing HoR — MAC index + proxy map (locked 2026-09-30)

### 6.1 MAC is canon

A physical phone can move between **tenants**, **instances**, or even **customers**. The durable identity is the **MAC**.

| Concern | Stance |
|---------|--------|
| **Canon key** | Normalized **MAC** (12-hex) — one active binding **fleet-wide** (or per org) |
| **Foreign keys** | **`tenant_id`** and **`instance_id`** (home) — current assignment only; change on reassign |
| **Not identity** | Tenant / instance are **not** part of the phone’s identity |
| **Secrets** | **Never** on the MAC index. SIP password / expand stay on home **`ipphone`** |
| **Directory Rule 13** | Catalog owns the MAC index; edge nginx map is a **projection** (same family as `setid`) |

### 6.2 Catalog MAC index (routing HoR)

| Field | Role |
|-------|------|
| **`mac`** | Primary key |
| **`tenant_id`** | FK — current tenant |
| **`instance_id`** | FK — current home (provision backend) |
| **`updated_at`** | Optional; reconcile / debug |

| Concern | Stance |
|---------|--------|
| **Map key (edge)** | Normalized **MAC** under `provision.{apex}` |
| **Map value** | Home provision base URL (`http://{home}:{41363}` for fleet proxy path — or chosen listen addr) |
| **Write path** | Extension MAC **assign / clear / reassign** (instance API or Commit hook) → **upsert / delete** catalog MAC row → enqueue or inline **map publish** (same job family as setid when move/onboard). **Tenant move:** bulk rewrite `instance_id` for that tenant’s MAC rows **with** `domain.setid` |
| **Conflict** | Second home claims same MAC → **reject** until operator clears the existing binding (no silent steal in v1) |
| **Home clear** | Clearing `ipphone.mac` deletes (or deactivates) the catalog row and republishes map |
| **Projection** | Regenerated **nginx `map` include** from the MAC index (**§11 #3**); optional S3 copy of the artifact for audit/HA seed; edge GET path uses **local** map file only — edge is not a second HoR |
| **Synchronicity** | **Not guaranteed.** Same job couples catalog + setid + provision map; brief skew possible |
| **Reconcile (C8)** | Extend fleet **catalog ≡ SBC** sweeper: **MAC index ≡ provision map** (+ consistency with tenant→node / setid). Spot-check: claimed home still has that MAC on `ipphone`. Flag drift; re-project. **Not** a second sweeper product |

### 6.3 Solo → fleet RPS flip

Rare in the field, but real: Phase A enrolls RPS at `https://{instance}:41363/…`; Phase C wants `https://provision.{apex}:41363/…`.

| Stance | |
|--------|--|
| **v1** | Docs + manual RPS re-point once (**B2**) — do not block A or C |
| **Parked** | **Migrator / converter** (plan **C9** / Phase E): bulk retarget enrolled MACs from instance URLs → `provision.{apex}` (+ checklist). Build when fleet polish has customers on instance RPS |

### 6.4 What this is not

**Not** the old M4 “S3 MAC inventory with secrets / secret-fetch.” Routing-only MAC index is fine under Rule 13. Putting `SIP_AUTH` (or full config) in the index remains **rejected**.

### Historical alternate — secretful S3 MAC inventory (parked)

Earlier lean locked “S3 keyed by MAC” for a dedicated fleet listener **including secret dual-consumer** (S1 password in S3 / S2 fetch from home / S3 blob). **§0 + §6.1 supersede that.** Keep S1–S3 only if M4/M5 is explicitly re-chosen later.

---

## 7. Non-goals

- Tenant create / installer / Mode 4 (“provision” overloaded elsewhere)
- Asterisk PJSIP / Commit / genAst (instance)
- SPA extension authoring (**`EXTENSION_PROVISIONING_*`**)
- SIP proxy, RTP, registrar on the provision proxy
- Browser holding ops IAM
- Requiring provisioner for **calls** once phones are configured
- BLF / softkey **UI or DB expand** in the provision stream (§4.5) — hand-edit template until demanded  
- Full vendor **config** matrix day one — subset of §0.2 interest list; expand streams iteratively  
- **Replacing** vendor/reseller **redirect / RPS** with an in-house discovery product
- Fleet edge as **HTTP 3xx redirect to home** (phones must not learn home URLs — **§0.3**)
- DHCP **server** as a product — document opt66 as secondary; optional lab helper later
- Reviving a **per-model Device catalogue** (#28 / §4.4) — vendor-grain streams only  
- No Device template table reintroduced as an operator-edited matrix
- Tenant FQDN / wildcard as the **phone-facing provision Host** (rejected — **§0.3**)

---

## 8. Security (thin)

| Topic | Stance |
|-------|--------|
| **MAC as locator** | MAC selects the extension row; it is **not** the sole authZ for remote/fleet |
| **Vendor client certs (primary remote harden)** | **Locked intent:** edge provision vhost uses **TLS client auth** against a **vendor CA bundle** (SARK `3pcerts` model — `SSLVerifyClient require` + concatenated manufacturer CAs). Request must present a cert chaining to an allowed phone vendor. **Not a panacea** (proves vendor/type family, not a specific MAC identity). Prior art: previous PBX `sark-prov-ssl` / port **41363** |
| **CA availability (research)** | Vendors often **claim** CAs are freely available; **practice is nuanced** (NDAs, partner portals, regional packs, silent changes). **In hand today:** **Snom** + **Yealink** example material from prior PBX. **Less clear:** Grandstream, Fanvil, Gigaset, Poly, others on §0.2. Treat full-matrix mTLS as **gated on a side exercise** — inventory which CAs we can lawfully obtain, ship, and renew — not as day-1 assumption for every interest vendor |
| **Where certs live** | Bundle on the **SBC edge** (with the provision nginx). Ops-managed file/artifact for v1 — **no** SPA “third-party certs panel” required to ship (panel remains won't-do / later; may revisit after CA inventory) |
| **Lab / LAN** | Open or weaker GET by MAC acceptable on private nets; do not use as the cloud default story. Remote without a vendor CA → document fallback (Once + network controls) rather than pretend mTLS for that brand |
| **HTTPS (phone-facing)** | Required off-lab. **Fleet:** edge terminates HTTPS on **`provision.{apex}`**. **Solo / direct:** home listener HTTPS on instance FQDN |
| **Edge→home** | **HTTP**; home provision port **SBC(s) only** via **UFW fleet baseline at install** (same SBC IP list as SIP — **`UFW_SHOREWALL_MIGRATION.md` §3**). SG may mirror. Accepted because the hop is private — not because secrets are unimportant |
| **Secrets in body** | Gated by **§4.3** (`Always` / `Once` / `No`); prefer **Once**. Factory reset ⇒ operator resets provision state so ONCE values send again |
| **Writes from phones** | Ignore PUT / vendor upload (404/no-op) |
| **Cross-tenant** | MAC must select exactly one home/tenant; never serve another cluster’s MAC |
| **Audit trail** | **§4.7** — dedicated provision log including **obfuscated** rendered stream; Apache alone is insufficient |

**Note:** Vendor client-cert check mitigates “anyone who knows a MAC can GET config.” It does **not** replace `sndcreds`, fail-closed routing, or keeping `SIP_AUTH` off S3.

---

## 9. Relationship to other tracks

| Track | Boundary |
|-------|----------|
| **Extension provisioning (SPA/API)** | Authors `ipphone` + Commit → PJSIP on **home** |
| **This track** | Delivers **phone config** over HTTPS to the phone; RPS points here; edge **proxy** routes; home renders |
| **Fleet DNS / LE §0** | SIP: no tenant A→home. Provision: **`provision.{apex}`** A→**edge VIP** only — **no** tenant A for provision (**§0.3**); update TLS §0 when shipping |
| **SBC** | Runtime SIP; same VIP family as provision edge |
| **Tenant move** | Catalog + SBC setid + **proxy map** (fleet polish) **or** **RPS re-point** to new home URL (fleet v1 without proxy) |
| **Vendor / reseller RPS** | **Discovery** (and optional full M1 config); not our secret HoR |

---

## 10. Implementation map (when scheduled)

| Slice | Likely home | Notes |
|-------|-------------|--------|
| Home listener | **pbx3** / **pbx3api** (or small co-located PHP) | Lift previous PBX `device.php` behaviour; MAC expand; HTTPS solo / HTTP behind proxy |
| Edge proxy | **SBC host** — sibling nginx (locked 2026-09-30) | **`provision.{apex}`**; MAC map; HTTP `proxy_pass`; mirror with SBC HA; **not** in SIP/OpenSIPS path |
| Map refresh | Gatekeeper / move + MAC assign hooks | Projects **MAC index** → edge map; same events as setid when moving |
| RPS enrollment | Ops docs first; APIs later | MAC → provision URL; re-point on move if no proxy; migrator parked (**C9**) |
| Expand inputs | Extension + vendor stream | INCLUDE + substitute only; **no** fkey/BLF expand (§4.5) |
| SPA | Later | Show provision URL + Last provisioned + **Reset Once** (+ regen → Once) |
| TLS §0 note | **`TLS_AND_CERTIFICATES.md`** | Document **`provision.{apex}`** → edge VIP (not tenant A) |

---

## 11. Open decisions (narrow)

0. **Schedule build?** — Plan exists (**`PROVISIONING_IMPLEMENTATION_PLAN.md`**); start at Phase **A1** when scheduled.  
1. ~~**Cert / hostname on proxy**~~ — **Locked 2026-09-30 (§0.3):** **`provision.{apex}`**; one cert; MAC routing; **proxy** not redirect; **HTTP** edge→home (SBC-only).  
2. ~~**Where proxy runs**~~ — **Locked 2026-09-30:** **SBC-colocated** nginx (or equivalent); map from catalog/S3 only; gatekeeper publishes map; mirrors with SBC HA. Not phone-facing on gatekeeper.  
3. ~~**Map transport**~~ — **Locked 2026-09-30:** Catalog MAC index = HoR. Gatekeeper publishes a **static nginx `map` include** (MAC → `http://{home}:41363`) on assign/clear/move (same job family as setid). Optional S3 copy of that artifact for audit/HA seed. **Edge GET path:** local map file only — **no** live gatekeeper, **no** per-request S3. **No lua** in v1 unless URI shapes force it later.  
4. ~~**Primary route key / MAC index**~~ — **Locked 2026-09-30 (§6):** MAC canon; tenant + instance FKs; conflict = reject; no secrets on index.  
5. **Solo** — Skip proxy; RPS (or lab) → instance directly (M3 solo).  
6. **Stack for home listener** — PHP parity with previous PBX vs rewrite; behaviour first.  
7. **RPS automation** — Manual portal vs vendor/reseller APIs for enroll/re-point; clearer §0.2 vendors first (**Yealink, Snom, Grandstream, Fanvil, Gigaset**). **Poly** deferred until Lens/ZTP post-HP is understood. Gigaset: confirm portal/API + PIN enrollment UX. Solo→fleet bulk migrator = parked **C9**.  
8. ~~**Provision listen port**~~ — **Locked 2026-09-30:** default **41363** (prior art); document for RPS (solo HTTPS; fleet edge HTTPS / home HTTP).  
9. **Poly discovery** — Confirm whether desk phones still expose a simple MAC→URL redirect usable by us, or only via Poly Lens / partner SKUs after HP.  
10. **Vendor CA / 3pcerts inventory (side exercise)** — For each §0.2 interest vendor: can we obtain client-auth CA(s), redistribute in our edge bundle, and keep them current? Start from known **Snom + Yealink**; document gaps for Grandstream / Fanvil / Gigaset / Poly. Outcome gates “mTLS for brand X” vs LAN/Once-only for that brand.  
11. ~~**Vendor common / no-MAC GETs at edge**~~ — **Locked 2026-09-30:** Edge **404** when the URI has no routable MAC (`y000000*.cfg`, bare paths, ignore-list). Home still serves Yealink common for **solo/lab**. Fleet phones get common via MAC stream **`#INCLUDE yealink.Common`** (already in the Yealink grain) — do not pick a home for no-MAC GETs.

---

## 12. Verify later (acceptance sketch)

- Phone with known MAC (via RPS → our URL, or lab direct) receives config; unknown MAC → 404.  
- Cloud happy path does **not** require DHCP opt66.  
- Fleet: SIP REGISTER still via **SBC** (not provision IP).  
- Move tenant home → either proxy map update from **MAC index** (**no** RPS change) **or** documented RPS re-point to new home URL.  
- Reconcile flags MAC-index ↔ provision-map drift; re-project clears (**§6** / **C8**).  
- Duplicate MAC claim → reject until clear.  
- Reset Once (SPA / password regen) restores secrets on next GET.  
- Proxy or home provision down → existing registrations unaffected.  
- Instance Commit still owns Asterisk; provisioner does not write PJSIP.  
- Secret only read from home `ipphone` at render time.  
- No per-SKU Device matrix; vendor-grain streams only (§4.4).  
- Stream builder = INCLUDE + substitute; no BLF/fkey expand (§4.5).
