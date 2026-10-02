# Phone provisioning — implementation plan

**Status:** Phase **A** + **B1–B4** + **C2/C3/C5/C7/C8/C10** on tip/`main` path; **rehome soak** green (**2026-10-02**). **#3/#11 frozen**. **C5 lab green** + **B4** site fragments shipped. **C10** Provision access (UFW `:41363`) shipped. **Next:** tip B4/C10 on lab; optional **C4** HA / **D3**. Other brands (lab): manual provision URL.  
**Requirements (law):** **`PROVISIONING_SERVER_REQUIREMENTS.md`**  
**TODO:** **#23 / 0k** · related **#28** (Device purge — stands) · tip **B4** / **C10**  
**Related:** **`FLEET_DESK_PHONE_NAT.md`** · **`pbx3spa/workingdocs/EXTENSION_PROVISIONING_*`** · **`TLS_AND_CERTIFICATES.md` §0** · lab **`PROVISIONING_LAB_RECIPE.md`** · edge **`pbx3sbc/workingdocs/PROVISION_EDGE_PROXY.md`** · MkDocs **`pbx3-docs/docs/admin/phone-provisioning-rps.md`**

---

## 0. One-line goal

Serve vendor desk-phone config over HTTPS from the **home** (secrets stay on `ipphone`), with phones finding that URL via **vendor/reseller RPS**; fleet later adds an **SBC-colocated** nginx **reverse proxy** on **`provision.{apex}:41363`** that routes by **catalog MAC index** (MAC canon; tenant/instance FKs) over **HTTP** to homes (no secrets; no redirect-to-home).

---

## 1. Locked shape (do not re-litigate in build)

| Topic | Lock |
|-------|------|
| Discovery | RPS primary; opt66 / PnP secondary |
| Solo | RPS → `https://{instance}:41363/…`; no catalog/proxy |
| Fleet edge | SBC-colocated nginx **proxy** (not 3xx redirect); map from **catalog MAC index**; mirrors with SBC HA |
| Fleet name / TLS | Phone-facing **`provision.{apex}`**; edge terminates HTTPS; **edge→home = HTTP** (SBC-only on home firewall) |
| Port | **41363** default (prior art); **fleet UFW = SBC-only** on that port at install (same as SIP) |
| Route key | **MAC** canon → home; **tenant** + **instance** are FKs on catalog index (**§6**) |
| MAC conflict | Reject second claim until operator clears |
| Topology | Proxy chosen for forward-compat with **topology hiding** (phones must not learn home URLs) |
| Map sync | Publish on **same job as setid** / MAC assign; **C8** reconcile extends catalog≡SBC — coupled, not perfectly synchronous |
| Solo→fleet RPS | Rare; docs/manual v1; **C9** migrator parked |
| Secrets | Home `ipphone` only; never on MAC index / S3 |
| Builder | **INCLUDE + parameter substitute**; vendor-grain streams; **no BLF/fkey UI/expand** |
| Site fragments | **B4** / §4.8 — System vs Customer; additive INCLUDE; tenant miniDB |
| mTLS | Edge vendor-client CA verify; **lab green Snom + Yealink** (C5). Other brands: lab OK via **manual provision URL**; public mTLS waits on CAs |
| Provision access | **C10** — optional UFW lockdown on edge `:41363` (Filament sibling to Management access); default off |
| Once | Prefer Once; restore flip; **Reset Once** server-side (B1) + on password regen |
| Device table | **No** per-SKU Device matrix (#28) |

Full detail: requirements §§0–0.3, §4.3–4.8, §6, §8.

---

## 2. Non-goals (this program)

- Replacing vendor RPS  
- Fleet edge as **HTTP redirect to home** (rejected — topology hiding)  
- Fat discrete provision VM  
- SIP_AUTH (or full config) in S3  
- Device SPA / per-model templates  
- BLF softkey UI or DB expand  
- 3pcerts SPA panel (ops file bundle until inventory done)  
- DHCP server product  
- Firmware CDN (`/public` Poly images) in v1  
- Tenant Host / wildcard as phone-facing provision name 

---

## 3. Prerequisites (already mostly product)

| Prerequisite | Why | Owner track |
|--------------|-----|-------------|
| Extension create with MAC + vendor label + secret + Commit → PJSIP | Phone must have an `ipphone` row worth rendering | **`EXTENSION_PROVISIONING_*`** |
| Fleet desk SIP fields | Config body embeds **SBC** + tenant domain, not home public IP | **`FLEET_DESK_PHONE_NAT.md`** |
| `sndcreds` / `provision` / `provisionwith` columns | Gating + stack storage | Schema already sketched in extension provisioning DB docs — verify on golden |

Do **not** block HTTP listener on “perfect” SPA enrollment UX.

---

## 4. Phases

### Phase A — Home listener (solo / lab) — **v1 ship target**

**Outcome:** Phone (or curl) GETs config from the instance; unknown MAC → 404.

| Slice | Work | Repo(s) |
|-------|------|---------|
| **A1** | Port kernel of prior `device.php` + `cleanConfig`: URI/MAC parse, Yealink ignore list, INCLUDE + substitute, fail-closed | **pbx3** (and/or thin **pbx3api** route — decide in A1 spike) |
| **A2** | Vendor-grain **file** fragments (not Device table): start **Yealink**, then **Snom** | **pbx3** package paths |
| **A3** | Placeholder policy: **`$sipdomain`** = tenant FQDN; **`$outbound`** = SBC when fleet (proxy on); solo = domain/IP, proxy off | **pbx3** |
| **A4** | `sndcreds` Always/Once/No + **restore Once→No flip** after successful send; secret-line list **without** treating `$ext` as password | **pbx3** |
| **A5** | HTTPS listener on **41363**; instance cert; **UFW:** extend `ufw-apply-baseline.sh` — fleet **41363/tcp from SBC IP(s)** (same list as SIP); solo **41363 from LAN**; installer already applies baseline — do not leave as ops folklore. Document URL for RPS | **pbx3** + **`UFW_SHOREWALL_MIGRATION.md` §3** |
| **A6** | Lab prove: Yealink (or Snom) RPS or manual URL → golden; register via normal SIP path | ops lab — **curl + Once + Reset green on golden 2026-09-30** (401 Snom, 402 Yealink) |
| **A7** | **Automated tests** for parse / INCLUDE / substitute / sndcreds / fail-closed — **required to exit A** (§7) | **pbx3** |
| **A8** | **Provision audit trail** (§4.7) — log rendered stream with **passwords obfuscated**; 0600; rotate | **pbx3** |
| **A9** | Persist **`last_provisioned_at`** (optional `first_provisioned_at`) on successful send; schema + update path | **pbx3** |

**A1 stack decision (open #6):** prefer **PHP lift** of the kernel for speed/parity; rewrite only if packaging forces it. Behaviour first.

**Exit A:** MkDocs/operator note: “provision URL = `https://{instance}:41363/…`”; SPA may show the URL later.

### Phase B — Operator hygiene (thin)

| Slice | Work | Repo(s) |
|-------|------|---------|
| **B1** | SPA: show provision URL + **Last provisioned**; **Reset provision state** (set Once) — also on **password regen**; **Provision stream** textarea | **pbx3spa** / **pbx3api** — **on `main`** (lab-proven) |
| **B2** | Docs: RPS enroll (Yealink, Snom); Gigaset MAC+PIN; solo→fleet “change RPS target once” (migrator = **C9**) | **pbx3-docs** |
| **B3** | M1 coexistence one-pager: “reseller delivers full config” supported without our HTTP | **pbx3-docs** |
| **B4** | **Site fragment CRUD** — design **§4.8**; sub-slices below | **pbx3** / **pbx3api** / **pbx3spa** |
| **B4a** | Schema `provision_stream` (tenant, `UNIQUE(cluster,pkey)`) + apply script; add to **`backupClusters.php`** / tenant export list | **pbx3** |
| **B4b** | Kernel: resolve `(cluster,name)` site → stock; audit `include_miss`; tests | **pbx3** |
| **B4c** | API tenant-scoped CRUD + copy-from-stock; reject stock-name collision; DELETE refcount | **pbx3api** |
| **B4d** | SPA Provision streams (tenant); stock RO; empty/delete confirms | **pbx3spa** |
| **B4e** | Extension help + MkDocs: System/Customer, last-wins + vendor flexibility, `$` secrets | **pbx3spa** / **pbx3-docs** |

### Phase C — Fleet edge proxy

**Outcome:** RPS points at stable **`provision.{apex}:41363`**; MAC index drives map; phones never see home URLs; drift swept; solo→fleet migrator parked.

**Entry (2026-09-30):** Home listener + Once/Reset proven on golden. Operator may use temporary `:41363` allow for eyeballing (**`PROVISIONING_LAB_RECIPE.md`** §0). Standing fleet policy remains SBC-only.

**Suggested first slices:**
1. **C3** — Catalog MAC index schema + upsert on MAC assign/clear (gatekeeper) — unblocks map publish.  
2. **C2** — SBC nginx vhost + `proxy_pass` HTTP → home (freeze open **#11** common/no-MAC GETs with it).  
3. **C7** tests + **C8** reconcile early enough to catch drift.  
4. **C5** mTLS after **D1** CA inventory for Snom/Yealink.  
5. **B2** MkDocs RPS can parallel (not on critical path for C code).

**Frozen 2026-09-30:** **#3** static nginx `map` artifact (local GET path; optional S3 seed); **#11** edge 404 no-MAC (home common solo-only; MAC `#INCLUDE`).

| Slice | Work | Repo(s) |
|-------|------|---------|
| **C1** | ~~Hostname / port~~ — **locked:** **`provision.{apex}:41363`** + MAC index + HTTP edge→home (**§0.3**, **§6**) | done |
| **C2** | nginx vhost on **SBC**; HTTPS terminate; MAC extract; **`proxy_pass` HTTP** to home `:41363`; fail-closed; **no** 3xx-to-home; **404** no-MAC (**#11**) — **templates + install/sync scripts** (`pbx3sbc` `PROVISION_EDGE_PROXY.md`); lab DNS/LE/UFW when scheduled | **pbx3sbc** |
| **C3** | **Catalog MAC index** + upsert/clear/move rewrite + static nginx map (**#3**) + instance claim hook — **code on feature branches** | **pbx3-directory** + **pbx3api** |
| **C4** | Mirror map on SBC HA pair; version/health optional | **pbx3sbc** |
| **C5** | ~~Vendor client-cert verify~~ — **lab green 2026-10-02:** ops CA PEM + `PROVISION_MTLS=optional` (lab) / `require`→`on` (harden). Yealink SUCCESS; bare curl NONE vs 400 | **pbx3sbc** + ops CA bundle |
| **C6** | TLS §0 cross-link: **`provision.{apex}`** A→edge VIP (not tenant A) | **`TLS_AND_CERTIFICATES.md`** — present; amend mTLS note |
| **C10** | ~~**Provision access**~~ — **shipped 2026-10-02:** Filament + `apply-provision-access-ufw.sh`; default off; complements mTLS. Spec **`SBC_PROVISION_ACCESS_REQUIREMENTS.md`** | **pbx3sbc-admin** / **pbx3sbc** |
| **C7** | **Automated tests** for MAC index → map publisher (+ no secrets) — **required to exit C** (§7) | gatekeeper / edge tooling |
| **C8** | **Reconcile / sweeper** — extend catalog≡SBC: **MAC index ≡ provision map** (+ setid family; spot-check home `ipphone.mac`). Flag drift; re-project. **Required to exit C** | **pbx3-directory** / existing reconcile job |
| **C9** | **Parked:** solo→fleet **RPS migrator** (bulk retarget instance URLs → `provision.{apex}`) + checklist — not required to exit C; docs cover rare manual flip (**B2**) | gatekeeper / ops tools later |

**Exit C:** Move Aelintra Golden→Kildare → SIP via SBC OK; next provision GET hits Kildare without RPS edit; MAC assign updates map; reconcile flags/clears intentional drift in lab.

### Phase D — Side exercises (parallel, non-blocking for A)

| ID | Exercise | Exit |
|----|----------|------|
| **D1** | **3pcerts / vendor CA inventory** for §0.2 brands | **Enough for C5 now:** Snom + Yealink in ops-held `3pcerts.pem`. Pack also has Panasonic/Fanvil; Poly = public PKI. **GS/Gigaset CAs:** not blocking lab — use **manual provision URL** on those phones. Public-edge mTLS for GS/Gigaset still needs vendor CAs later. Research: **`~/GiT/pbx3-ops/devdocs/provisioning/VENDOR_CLIENT_CA_INVENTORY.md`**. |
| **D2** | **Poly** Lens/ZTP post-HP path | **Sub-project (parked):** **`POLY_PROVISION_SUBPROJECT.md`**. Classic UCS CFG dialect assumed stable; discovery (Lens) still uncertain. Manual URL for lab |
| **D3** | Grandstream / Fanvil / Gigaset / **Poly** stream + RPS notes | **Fanvil** · **Grandstream** · **Poly** parked sub-projects. Fanvil seed streams on `main`; GS/Poly streams when mule. Gigaset separate when started. Manual URL until RPS/mTLS; vendor-cloud-only OK where free |
| **D4** | Snom online-UI docs workaround (screenshots / pinned export) | Authoring aid in ops `devdocs` if needed |

---

## 5. Suggested build order (summary)

```text
A1 kernel → A7 tests skeleton (can start as soon as expand exists)
  → A2 Yealink stream → A4 sndcreds (+ tests) → A8 audit log (+ tests)
  → A5 HTTPS
  → A6 lab phone  (A7+A8+A9 green required to exit A)
  → B2 / B1
  → C1 … C5 → C7 map tests → **C8 reconcile**
  → D* parallel
```

Do **not** start C before A lab-green unless a fleet customer forces stable URL day one (then still need A behind the proxy). **Do not** exit A on lab alone — **A7 + A8 required**. **Do not** exit C without **C7 + C8**.

---

## 6. Repo / ownership map

| Concern | Primary repo |
|---------|----------------|
| Listener + streams + Once flip | **pbx3** |
| Optional Sanctum-adjacent health only if needed | **pbx3api** (prefer provision **off** Sanctum admin port) |
| Provision URL / reset Once UI | **pbx3spa** |
| Edge nginx + CA bundle path | **pbx3sbc** (+ admin only if ops UI later) |
| Catalog map publish / move hook | **pbx3** `pbx3-directory` / gatekeeper |
| Operator docs | **pbx3-docs** |
| Private research (CA hunt, Snom UI captures) | **`aelintra/pbx3-ops`** `devdocs/` |

---

## 7. Automated testing (**required**)

Lab/phone soak remains necessary; it is **not** a substitute for regression tests on the expander and map publisher. **Phase A does not exit without automated coverage of the stream kernel.**

### 7.1 What must be automated

| Area | Phase | Kind | Examples |
|------|-------|------|----------|
| **URI / MAC parse + ignore list** | **A** | Unit / table-driven | `?mac=`, path `/{mac}.cfg`, Yealink `y000000*.cfg` → common, `*_Security.enc` / `.boot` → 404, PUT → 200/no-op |
| **INCLUDE + substitute** | **A** | Unit + fixtures | Nested INCLUDE, loop detection, `$ext` / `$password` / registrar placeholders from fixture `ipphone` + fragment files |
| **sndcreds Once / Always / No** | **A** | Unit | Secret lines present/absent; **Once → No flip** after successful render; Reset state restores Once |
| **Audit trail** | **A** | Unit | Success records include rendered stream; known password substrings **absent** (masked); phone response still contains cleartext when Once/Always; 404 has no body artifact |
| **last_provisioned_at** | **A** | Unit | Success bumps timestamp; 404 does not |
| **Fail-closed** | **A** | Unit | Unknown MAC → 404; duplicate MAC → 404 |
| **No BLF path** | **A** | Unit / smoke | Builder does not require fkey tables; no `$fkey` expand |
| **Map artifact** | **C** | Unit | MAC index fixture → nginx/map file; assign/clear/move changes backend; no secrets; duplicate MAC rejected |
| **Map + setid coupling** | **C** | Integration or contract test | Move-job hook rewrites MAC FKs + publishes map when setid updates |
| **Map reconcile** | **C** | Unit / contract | MAC index ≡ map; drift flagged; re-project clears; extends catalog≡SBC |

Prefer **fixture SQLite + file fragments** over live Asterisk. Run in **pbx3** package test path (PHPUnit or project norm); map tests beside gatekeeper/move tooling.

### 7.2 What stays manual / soak (not CI)

- Real handset + vendor **RPS** enroll  
- Vendor **client-cert** against hardware  
- Full fleet **tenant move** on lab (SIP + next provision GET)  
- LE / firewall / VIP behaviour on golden or SBC  

Document a short **lab recipe** (A6 / C exit) next to the automated suite — soak proves vendors; CI proves we didn’t break INCLUDE/Once.

### 7.3 Slices (add to build)

| Slice | Work | Gate |
|-------|------|------|
| **A7** | Test harness + fixtures for parse / INCLUDE / substitute / sndcreds / 404 | **Required to exit Phase A** (alongside A6 lab) |
| **A8** | Audit log with **obfuscated** stream on success; hardened perms | **Required to exit Phase A** |
| **A9** | `last_provisioned_at` on successful send | **Required to exit Phase A** |
| **C7** | MAC-index map publisher tests + “no secret in map” + conflict reject | **Required to exit Phase C** |
| **C8** | Extend fleet reconcile: MAC index ≡ provision map (+ setid family); drift flag + re-project | **Required to exit Phase C** |
| **C9** | Solo→fleet RPS migrator (parked) | **Not** required to exit C |

### 7.4 Effort (additive)

| Work | Focused |
|------|---------|
| **A7** | **~2–4 days** (budget **~0.5–1 week** with polish/CI wiring) |
| **A8** | **~1–2 days** (logger + obfuscate-for-audit + rotate + tests) |
| **A9** | **~0.5–1 day** (column + update + test) |
| **C7** | **~1–2 days** |
| **C8** | **~1–2 days** (wire into existing reconcile; less if harness already exists) |

Revise Phase A roll-up: lab-useful solo ≈ prior estimate **+ ~1–1.5 weeks** when **A7 + A8** are on the critical path (correct — do not skip).

### 7.5 Build order (updated)

```text
A1 kernel → A7 tests skeleton (can start as soon as expand exists)
  → A2 Yealink stream → A4 sndcreds (+ tests) → A8 audit log (+ tests) → A9 last_provisioned_at
  → A5 HTTPS → A6 lab phone  (A7+A8+A9 green required to exit A)
  → B2 / B1
  → C1 … C5 → C7 map tests → **C8 reconcile**
  → D* parallel
```

---

## 8. Acceptance (program)

### Phase A
- [x] Known MAC → vendor config body; unknown → 404 *(unit + code)*  
- [x] INCLUDE expands; substitutes ext/password (when Once/Always)/registrar  
- [x] Once sends secrets once then omits; Reset state = set `sndcreds` Once *(SPA Reset = B1)*  
- [x] No Device table; no BLF expand  
- [x] HTTPS on **41363** (solo nginx); fleet home HTTP template; install script  
- [x] **Fleet UFW:** **41363/tcp from SBC IP(s) only** in install baseline; solo LAN  
- [x] Commit/PJSIP unchanged by provision GET *(design + lab curl without Commit)*  
- [x] **A7 automated suite green**  
- [x] **A8 audit trail** (obfuscated)  
- [x] **A9** — `last_provisioned_at` / `first_provisioned_at`  
- [x] **A6** handset/curl lab — **`PROVISIONING_LAB_RECIPE.md`** *(golden 401/402 2026-09-30)*  

### Phase B
- [x] Extension UI shows **Last provisioned** (+ provision URL) + **Provision stream** editor  
- [x] **Reset Once** works; **password regen** resets to Once  
- [x] **B2** RPS / solo→fleet docs — **`pbx3-docs/docs/admin/phone-provisioning-rps.md`**  
- [x] **B3** M1 coexistence one-pager — MkDocs **`admin/phone-provisioning-m1`**  
- [x] **B4** Site fragments (§4.8) — tenant `provision_stream`; additive last-wins; no stock replacement; refcount/miss; miniDB  
- [x] **B4a–B4e** per plan table  

### Phase C
- [x] RPS → **`provision.{apex}:41363`**; MAC index → map → current home *(lab: provision.pbx3.com LE; Yealink 402 + Snom 401)*  
- [x] MAC assign/clear updates index + map; tenant move rewrites FKs **with** setid *(claim/clear/project + move hook; api tip)*  
- [x] Duplicate MAC claim **rejected** until clear *(409 lab + unit)*  
- [x] Proxy has no passwords; edge→home is **HTTP** (SBC-only)  
- [x] **No** HTTP redirect exposing home URLs  
- [ ] Existing registrations survive proxy/home provision outage  
- [x] **C5** mTLS — **lab green 2026-10-02:** tip ops Snom+Yealink PEM; `optional` live; Yealink T31P **SUCCESS**+200; bare curl NONE/200 (`optional`) / **400** (`require`). Access log `provision_mtls` (`$ssl_client_verify`). Other brands: manual URL  
- [x] **C6** TLS §0 note — `provision.{apex}` → edge VIP (see **`TLS_AND_CERTIFICATES.md`**; mTLS on edge)  
- [x] **C10** Provision access allowlist — Filament **Provision access** + UFW `:41363` (`pbx3sbc-prov` tags); MkDocs **`admin/phone-provisioning-access`**
- [x] **C7** map publisher tests green (artifact + no secrets + conflict)  
- [x] **C8** reconcile — MAC index ≡ map; drift flagged; re-project clears (`GET /mac-index/reconcile`; folded into `GET /reconcile`)  
- [x] Edge provision access/deny visible in edge logs (MAC → home)  
- [x] **C9** migrator parked; **B2** docs cover rare manual solo→fleet flip  

### Always
- [ ] Cloud path does not require DHCP opt66  

---

## 9. Open decisions to freeze before/during build

| # | Decision | Freeze by |
|---|----------|-----------|
| 1 / 4 / 8 | ~~Hostname / MAC index / port~~ | **Locked** — `provision.{apex}:41363` + §6 |
| 6 | PHP lift vs rewrite | A1 spike (≤1 day) |
| 3 | ~~Map transport~~ | **Locked** — static nginx map artifact (#3) |
| 10 | ~~CA inventory (Snom/Yealink)~~ | **Enough for C5** — tip now; GS/Gigaset CAs not required for lab manual-URL soaks |
| 11 | ~~Vendor common / no-MAC GETs~~ | **Locked** — edge 404 no-MAC (#11) |
| Test harness | Test runner / layout in **pbx3** | A7 start |

Track live list in requirements **§11**.

---

## 10. Risk register (severity with phone behaviour)

| Risk | Severity | Note |
|------|----------|------|
| MAC index write-path incomplete | **High** for C | C3 must own assign/clear/move upserts — not “optional MAC” |
| Map lag after move | Low for calls; medium for new/reset phones | Same job as setid; **C8** sweeper |
| Solo→fleet RPS flip | Low (rare) | B2 docs; **C9** migrator parked |
| Home listen mode split | Medium | Fleet HTTP+SBC-only vs solo HTTPS — **A5 UFW baseline** must ship with listener |
| Fleet :41363 left open | **High** | Must match SIP: install baseline SBC-only; never phone-facing on fleet |
| Wrong RPS URL | Ops | Docs + stable `provision.{apex}:41363` |
| Missing vendor CA | Per-brand | Lab: manual provision URL on phone; public mTLS: wait on CA / Once + network controls |
| Closed XML (Poly / future Snom) | Template authoring | §4.6; not engine scope |
| Regress Once/INCLUDE without CI | High over time | **A7 required** |

---

## 11. First concrete next step

1. ~~Merge requirements + plan PR~~ · ~~Phase A–B1~~ · ~~C2/C3~~ · ~~B2~~ · ~~C7/C8~~ · Yealink+Snom lab · ~~rehome soak~~ · ~~C5 mTLS lab~~ · ~~C5 PRs~~  
2. **Tip lab:** B4 `apply-sqlite-add-provision-stream.sh` + C10 sudoers / Provision access panel on SBC.  
3. **Other brands (lab):** manual provision URL on phone. Later: **D3**; optional **C4** HA map mirror.
