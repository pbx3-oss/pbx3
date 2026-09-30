# Phone provisioning — implementation plan

**Status:** Plan drafted **2026-09-30** (architecture locked in requirements).  
**Requirements (law):** **`PROVISIONING_SERVER_REQUIREMENTS.md`**  
**TODO:** **#23 / 0k** · related **#28** (Device purge — stands)  
**Related:** **`FLEET_DESK_PHONE_NAT.md`** · **`pbx3spa/workingdocs/EXTENSION_PROVISIONING_*`** (extension MAC / Commit / PJSIP — prerequisite authoring) · **`TLS_AND_CERTIFICATES.md` §0**

---

## 0. One-line goal

Serve vendor desk-phone config over HTTPS from the **home** (secrets stay on `ipphone`), with phones finding that URL via **vendor/reseller RPS**; fleet later adds an **SBC-colocated** nginx that routes by catalog map (no secrets).

---

## 1. Locked shape (do not re-litigate in build)

| Topic | Lock |
|-------|------|
| Discovery | RPS primary; opt66 / PnP secondary |
| Solo | RPS → instance provision URL; no catalog/proxy |
| Fleet edge | SBC-colocated nginx; map from **catalog/S3 only**; mirrors with SBC HA |
| Secrets | Home `ipphone` only; never S3 |
| Builder | **INCLUDE + parameter substitute**; vendor-grain streams; **no BLF/fkey UI/expand** |
| mTLS | Intent = vendor client CA bundle on edge; **CA inventory** is a side exercise (Snom/Yealink known) |
| Once | Prefer Once; **restore** post-send flip (prior tree had dropped it) |
| Device table | **No** per-SKU Device matrix (#28) |

Full detail: requirements §§0–0.2, §4.3–4.6, §8.

---

## 2. Non-goals (this program)

- Replacing vendor RPS  
- Fat discrete provision VM  
- SIP_AUTH (or full config) in S3  
- Device SPA / per-model templates  
- BLF softkey UI or DB expand  
- 3pcerts SPA panel (ops file bundle until inventory done)  
- DHCP server product  
- Firmware CDN (`/public` Poly images) in v1  

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
| **A5** | HTTPS listener on dedicated **non-443** port; use instance cert story; document URL for RPS | **pbx3** + installer / shorewall-or-UFW note |
| **A6** | Lab prove: Yealink (or Snom) RPS or manual URL → golden; register via normal SIP path | ops lab |

**A1 stack decision (open #6):** prefer **PHP lift** of the kernel for speed/parity; rewrite only if packaging forces it. Behaviour first.

**Exit A:** MkDocs/operator note: “provision URL = `https://{instance}:{port}/…`”; SPA may show the URL later.

### Phase B — Operator hygiene (thin)

| Slice | Work | Repo(s) |
|-------|------|---------|
| **B1** | SPA or API: show provision URL; **Reset provision state** (set Once) on factory-reset / password regen | **pbx3spa** / **pbx3api** |
| **B2** | Docs: RPS enroll (Yealink, Snom); Gigaset MAC+PIN; solo→fleet “change RPS target once” | **pbx3-docs** |
| **B3** | M1 coexistence one-pager: “reseller delivers full config” supported without our HTTP | **pbx3-docs** |

### Phase C — Fleet edge proxy

**Outcome:** RPS points at stable edge URL; map updates with tenant move.

| Slice | Work | Repo(s) |
|-------|------|---------|
| **C1** | Decide hostname: lean **`provision.{apex}`** or tenant Host + wildcard (requirements open #1/#4/#8) | design freeze in requirements amendment |
| **C2** | nginx (or equiv) vhost on **SBC**; `proxy_pass` to home provision ports; fail-closed | **pbx3sbc** / edge package |
| **C3** | Map artifact from catalog (tenant→home; optional MAC→tenant→home); publish on onboard/move/**same job as setid** | **pbx3-directory** gatekeeper / move job |
| **C4** | Mirror map on SBC HA pair; version/health optional | **pbx3sbc** |
| **C5** | Vendor client-cert verify on edge vhost when CA present (Snom/Yealink first) | **pbx3sbc** + ops CA bundle |
| **C6** | TLS §0 cross-link: provision A→edge exception documented | **TLS_AND_CERTIFICATES.md** |

**Exit C:** Move Aelintra Golden→Kildare → SIP via SBC OK; next provision GET hits Kildare without RPS edit.

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
A1 kernel → A2 Yealink stream → A4 sndcreds → A5 HTTPS port
  → A6 lab phone
  → B2 RPS docs (can overlap A6)
  → B1 reset-state UX
  → C1 hostname freeze → C2–C5 proxy
  → D1–D4 anytime in parallel
```

Do **not** start C before A lab-green unless a fleet customer forces stable URL day one (then still need A behind the proxy).

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

## 7. Acceptance (program)

### Phase A
- [ ] Known MAC → vendor config body; unknown → 404  
- [ ] INCLUDE expands; substitutes ext/password (when Once/Always)/registrar  
- [ ] Once sends secrets once then omits; Reset state restores Once  
- [ ] No Device table; no BLF expand  
- [ ] HTTPS on non-443; RPS or manual URL works in lab  
- [ ] Commit/PJSIP unchanged by provision GET  

### Phase C
- [ ] RPS → edge URL; map → current home  
- [ ] Move updates **setid + provision map** together  
- [ ] Proxy has no passwords  
- [ ] Existing registrations survive proxy/home provision outage  
- [ ] mTLS for brands with CA; others documented fallback  

### Always
- [ ] Cloud path does not require DHCP opt66  

---

## 8. Open decisions to freeze before/during build

| # | Decision | Freeze by |
|---|----------|-----------|
| 1 / 8 | Edge hostname + home listen **port** | Before C1 / A5 |
| 4 | Host vs MAC vs both (lean: both; MAC always on wire) | C2 |
| 6 | PHP lift vs rewrite | A1 spike (≤1 day) |
| 3 | Map transport (static object from S3 preferred) | C3 |
| 10 | CA inventory results | Before claiming mTLS per brand |

Track live list in requirements **§11**.

---

## 9. Risk register (severity with phone behaviour)

| Risk | Severity | Note |
|------|----------|------|
| Map lag after move | Low for calls; medium for new/reset phones | Same job as setid |
| Wrong RPS URL | Ops | Docs + stable edge URL |
| Missing vendor CA | Per-brand | D1; Once + network controls |
| Closed XML (Poly / future Snom) | Template authoring | §4.6; not engine scope |
| Solo→fleet RPS retarget | Ops once | B2 |

---

## 10. First concrete next step

1. Merge requirements PR (architecture snapshot).  
2. Open build branch: **Phase A1** — skeleton listener + INCLUDE/substitute against golden `ipphone` (Yealink fragment stub).  
3. Parallel: kick **D1** CA inventory in ops `devdocs` (no product code).
