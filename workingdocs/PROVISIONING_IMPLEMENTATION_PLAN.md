# Phone provisioning — implementation plan

**Status:** Phase **A** home listener implemented on branch **`feat/provision-a1-home-kernel`** (A1–A5, A7–A9). **A6** lab soak: **`PROVISIONING_LAB_RECIPE.md`**. TLS/edge polish + MAC index + port 41363 — requirements **§0.3**, **§6**.  
**Requirements (law):** **`PROVISIONING_SERVER_REQUIREMENTS.md`**  
**TODO:** **#23 / 0k** · related **#28** (Device purge — stands)  
**Related:** **`FLEET_DESK_PHONE_NAT.md`** · **`pbx3spa/workingdocs/EXTENSION_PROVISIONING_*`** (extension MAC / Commit / PJSIP — prerequisite authoring) · **`TLS_AND_CERTIFICATES.md` §0**

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
| mTLS | Intent = vendor client CA bundle on edge; **CA inventory** is a side exercise (Snom/Yealink known) |
| Once | Prefer Once; restore flip; **Reset Once** server-side (B1) + on password regen |
| Device table | **No** per-SKU Device matrix (#28) |

Full detail: requirements §§0–0.3, §4.3–4.6, §6, §8.

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
| **A3** | Placeholder policy: fleet-ready `$registrar` / proxy → SBC when fleet; solo → instance | **pbx3** |
| **A4** | `sndcreds` Always/Once/No + **restore Once→No flip** after successful send; secret-line list **without** treating `$ext` as password | **pbx3** |
| **A5** | HTTPS listener on **41363**; instance cert; **UFW:** extend `ufw-apply-baseline.sh` — fleet **41363/tcp from SBC IP(s)** (same list as SIP); solo **41363 from LAN**; installer already applies baseline — do not leave as ops folklore. Document URL for RPS | **pbx3** + **`UFW_SHOREWALL_MIGRATION.md` §3** |
| **A6** | Lab prove: Yealink (or Snom) RPS or manual URL → golden; register via normal SIP path | ops lab |
| **A7** | **Automated tests** for parse / INCLUDE / substitute / sndcreds / fail-closed — **required to exit A** (§7) | **pbx3** |
| **A8** | **Provision audit trail** (§4.7) — log rendered stream with **passwords obfuscated**; 0600; rotate | **pbx3** |
| **A9** | Persist **`last_provisioned_at`** (optional `first_provisioned_at`) on successful send; schema + update path | **pbx3** |

**A1 stack decision (open #6):** prefer **PHP lift** of the kernel for speed/parity; rewrite only if packaging forces it. Behaviour first.

**Exit A:** MkDocs/operator note: “provision URL = `https://{instance}:41363/…`”; SPA may show the URL later.

### Phase B — Operator hygiene (thin)

| Slice | Work | Repo(s) |
|-------|------|---------|
| **B1** | SPA: show provision URL + **Last provisioned**; **Reset provision state** (set Once) — also on **password regen** | **pbx3spa** / **pbx3api** |
| **B2** | Docs: RPS enroll (Yealink, Snom); Gigaset MAC+PIN; solo→fleet “change RPS target once” (migrator = **C9**) | **pbx3-docs** |
| **B3** | M1 coexistence one-pager: “reseller delivers full config” supported without our HTTP | **pbx3-docs** |

### Phase C — Fleet edge proxy

**Outcome:** RPS points at stable **`provision.{apex}:41363`**; MAC index drives map; phones never see home URLs; drift swept; solo→fleet migrator parked.

| Slice | Work | Repo(s) |
|-------|------|---------|
| **C1** | ~~Hostname / port~~ — **locked:** **`provision.{apex}:41363`** + MAC index + HTTP edge→home (**§0.3**, **§6**) | done |
| **C2** | nginx vhost on **SBC**; HTTPS terminate; MAC extract; **`proxy_pass` HTTP** to home `:41363` (SBC-only — home UFW already from A5/install); fail-closed; **no** 3xx-to-home; policy for vendor **common** GETs without MAC (open #11) | **pbx3sbc** / edge package |
| **C3** | **Catalog MAC index** (`mac` PK → `tenant_id`, `instance_id` FKs); upsert/delete on MAC assign/clear; bulk FK rewrite on tenant move **with** setid; project → nginx map; conflict = **reject** | **pbx3-directory** gatekeeper + instance hook |
| **C4** | Mirror map on SBC HA pair; version/health optional | **pbx3sbc** |
| **C5** | Vendor client-cert verify on edge vhost when CA present (Snom/Yealink first) | **pbx3sbc** + ops CA bundle |
| **C6** | TLS §0 cross-link: **`provision.{apex}`** A→edge VIP (not tenant A) | **`TLS_AND_CERTIFICATES.md`** |
| **C7** | **Automated tests** for MAC index → map publisher (+ no secrets) — **required to exit C** (§7) | gatekeeper / edge tooling |
| **C8** | **Reconcile / sweeper** — extend catalog≡SBC: **MAC index ≡ provision map** (+ setid family; spot-check home `ipphone.mac`). Flag drift; re-project. **Required to exit C** | **pbx3-directory** / existing reconcile job |
| **C9** | **Parked:** solo→fleet **RPS migrator** (bulk retarget instance URLs → `provision.{apex}`) + checklist — not required to exit C; docs cover rare manual flip (**B2**) | gatekeeper / ops tools later |

**Exit C:** Move Aelintra Golden→Kildare → SIP via SBC OK; next provision GET hits Kildare without RPS edit; MAC assign updates map; reconcile flags/clears intentional drift in lab.

### Phase D — Side exercises (parallel, non-blocking for A)

| ID | Exercise | Exit |
|----|----------|------|
| **D1** | **3pcerts / vendor CA inventory** for §0.2 brands | Table: obtainable / NDA / gap; gates mTLS per brand |
| **D2** | **Poly** Lens/ZTP post-HP path | In or out of interest for redirect |
| **D3** | Grandstream / Fanvil / Gigaset stream + RPS notes | Second-wave vendors after Yealink/Snom |
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
- [ ] Commit/PJSIP unchanged by provision GET *(A6 lab confirm)*  
- [x] **A7 automated suite green**  
- [x] **A8 audit trail** (obfuscated)  
- [x] **A9** — `last_provisioned_at` / `first_provisioned_at`  
- [ ] **A6** handset/curl lab — **`PROVISIONING_LAB_RECIPE.md`**

### Phase B
- [ ] Extension UI shows **Last provisioned** (+ provision URL)  
- [ ] **Reset Once** works; **password regen** resets to Once  

### Phase C
- [ ] RPS → **`provision.{apex}:41363`**; MAC index → map → current home  
- [ ] MAC assign/clear updates index + map; tenant move rewrites FKs **with** setid  
- [ ] Duplicate MAC claim **rejected** until clear  
- [ ] Proxy has no passwords; edge→home is **HTTP** (SBC-only)  
- [ ] **No** HTTP redirect exposing home URLs  
- [ ] Existing registrations survive proxy/home provision outage  
- [ ] mTLS for brands with CA; others documented fallback  
- [ ] **C7** map publisher tests green (artifact + no secrets + conflict)  
- [ ] **C8** reconcile — MAC index ≡ map; drift flagged; re-project clears  
- [ ] Edge provision access/deny visible in edge logs (MAC → home)  
- [ ] **C9** migrator parked or shipped later; B2 docs cover rare manual solo→fleet flip  

### Always
- [ ] Cloud path does not require DHCP opt66  

---

## 9. Open decisions to freeze before/during build

| # | Decision | Freeze by |
|---|----------|-----------|
| 1 / 4 / 8 | ~~Hostname / MAC index / port~~ | **Locked** — `provision.{apex}:41363` + §6 |
| 6 | PHP lift vs rewrite | A1 spike (≤1 day) |
| 3 | Map transport (static object from S3 preferred) | C3 |
| 10 | CA inventory results | Before claiming mTLS per brand |
| 11 | Vendor common / no-MAC GETs at edge | C2 with A2 |
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
| Missing vendor CA | Per-brand | D1; Once + network controls |
| Closed XML (Poly / future Snom) | Template authoring | §4.6; not engine scope |
| Regress Once/INCLUDE without CI | High over time | **A7 required** |

---

## 11. First concrete next step

1. ~~Merge requirements + plan PR~~ · ~~Phase A1–A5 / A7–A9 on build branch~~  
2. **Merge** `feat/provision-a1-home-kernel` → `main`.  
3. **A6** lab — follow **`PROVISIONING_LAB_RECIPE.md`** (curl then handset).  
4. Phase **B1** SPA Reset Once / Last provisioned; **B2** MkDocs RPS.  
5. Parallel: **D1** CA inventory in ops `devdocs`.  
6. Phase **C** when scheduled (edge proxy + MAC index).
