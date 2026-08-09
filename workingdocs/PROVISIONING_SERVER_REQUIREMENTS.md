# Provisioning server — requirements (sketch)

**Status:** Exploratory product question (**2026-08-06**). **Default bias: maybe do not build.** Spec captures co-located vs fleet provision shape **if** we ever need an in-house listener — not a commitment to ship one.  
**Line in the sand (2026-08-06):** Stopped for operator thinking. Co-located provision + PBX on one box works because they share one extension-row secret; fleet + S3 split makes secrets and HoR harder. Management options recorded in **§0.1** (M1–M5). Do not reopen design or implement until explicitly resumed.  
**Reference notes:** private prior co-located provisioner experiments (operator archives only — not part of the product tree).  
**Related:** **`pbx3spa/workingdocs/EXTENSION_PROVISIONING_*`** (instance extension authoring + Commit/genAst — **not** this server) · **`TLS_AND_CERTIFICATES.md` §0** · TODO open item *Provisioning server class*.

---

## 0. Build or not? (open — lean no)

Desk-phone HTTP provisioning is a crowded, mostly **solved** market:

| Who already does it | Examples |
|---------------------|----------|
| **Handset vendors** | Yealink / Snom / Poly / Fanvil RPS and redirect / cloud provision |
| **Reseller / MSP platforms** | Paid multi-vendor provisioning services many partners already sell |
| **Legacy PBX co-locate** | `device.php`-style listener on the PBX box |

**Implication:** An in-house pbx3 provisioning **server** is optional infrastructure, not a core differentiator. Many customers will never point phones at us for config HTTP.

| Path | When it makes sense |
|------|---------------------|
| **Don't build** (default lean) | Phones use vendor RPS / reseller provisioner; operator (or that service) gets SIP user/secret/registrar from pbx3 (export, API, or manual). pbx3 owns **extensions + Asterisk**, not config HTTP |
| **Thin export only** | Instance/Fleet can emit MAC + SIP identity + registrar fields (or a vendor CSV) for upload into someone else's RPS — no listener product |
| **Build in-house listener** | Lab/demo without third-party RPS; air-gapped / hostile-to-vendor-cloud sites; productized “we host provision too” SKU if demand appears |

**What we still need either way:** solid **extension + MAC + secret + Commit/PJSIP** on the instance (`EXTENSION_PROVISIONING_*`). That is independent of owning a provision HTTP server.

**If we never build the server:** keep this doc as the parked design (S3 MAC inventory, secrets options, §0.1 management paths) so a later SKU does not re-litigate from zero — or delete/archive when clearly won't ship.

### 0.1 How to manage this (parked options — 2026-08-06)

**Hard rule to preserve:** Asterisk and the **first place that embeds the SIP password into a phone config** should share **one secret HoR**. Co-location does that (same `ipphone` row). Fleet should either keep co-location for that step, or **not** embed the password in our stream (export / operator paste into third-party RPS).

| # | Path | Idea | Secrets | When |
|---|------|------|---------|------|
| **M1** | **Don't own HTTP** (default) | Vendor RPS / reseller provisioner delivers config. pbx3 owns extension + MAC + secret + registrar fields only | Stay on instance; leave via operator paste or controlled export | Most MSP / fleet customers |
| **M2** | **Thin export** | Instance or Fleet emits MAC + SIP identity + registrar (CSV/JSON / “copy for Yealink RPS”) for upload into someone else's service — **no** pbx3 listener product | Optional one-shot reveal in UI; not stored in S3 as inventory | Natural follow-on to M1 |
| **M3** | **Co-located mini-listener** | Provision HTTP **on the instance** (or solo/direct only). Same SQLite → same secret | Single HoR = extension row | Lab/demo; air-gap; customers who refuse vendor cloud |
| **M4** | **S3 = MAC directory only** | S3: `MAC → home / tenant / SIP domain / SBC`. Passwords **not** in S3. Any listener (ours or theirs) uses S3 for routing; fetch secret from home at render (was S2) | Instance only | If we need fleet-wide MAC map without a password store |
| **M5** | **Pre-rendered blob in S3** | On Commit, instance writes final vendor file bytes under MAC key; edge is a dumb GET | Secret inside blob in S3 | Only if we sell a thin “we host files” SKU and accept secrets-at-rest |

**Recommended near term (not locked — for when we resume):** **M1 + keep extension/MAC/Commit solid**; add **M2** when export is useful; add **M3** only if lab or a concrete refuse-RPS customer; revisit **M4/M5** only for an explicit “we host provision” SKU (prefer M4 over passwords in inventory JSON).

**Do not** build a separate fleet provisioning **server product** that re-splits secret HoR without choosing M3–M5 deliberately.

Provisioning (if built as a separate host) is a small HTTP(S) config-delivery service. Co-located designs put it on the PBX; a fleet-wide product server would **not** be bolted onto the home PBX or the SBC call plane — but see M3 if co-location is the chosen answer to secrets.

---

## 1. One-line purpose (if built)

Serve vendor phone config files keyed by **MAC** (and vendor “common” descriptors), embedding SIP identity and registrar/proxy so a desk phone can register without manual SIP setup.

---

## 2. Product class (if built)

| Concern | Lock |
|---------|------|
| **What it is** | Dedicated **provisioning server** product type (own package / host / LE name) |
| **What it is not** | Not an Asterisk node; not Gatekeeper; not SBC; not SPA; **not** required for fleet calls |
| **prior co-located PBX posture** | Lift **behaviour** from private archives `device.php` (MAC → template expand → text body). Do **not** require co-location with the PBX DB or Apache-on-PBX |
| **Call plane** | Phones **register / media** via normal fleet SIP path (SBC → instance). Provisioner is **config HTTP only** — never in the SIP/RTP path |
| **Directory / Rule 1** | Provisioner must not become a call-routing dependency. If it is down, **already-provisioned** phones keep working; new / re-provision requests fail until it returns |
| **Compete?** | Do **not** try to out-feature vendor/reseller RPS. In-house = thin, MAC→config, fleet-aware — or skip |

---

## 3. Happy path (phone)

```text
Phone discovers provision URL (DHCP opt66/114, PnP, or manual)
  → GET https://{provision-fqdn}/provisioning…  (MAC in query or path)
  → Lookup inventory by MAC (or Device descriptor for vendor common files)
  → Expand Device #INCLUDE stack + BLF/fkey lines
  → Substitute SIP host, ext, password, ports, …
  → text/plain vendor config
Phone applies config → SIP REGISTER to registrar/proxy from the file
```

**Discovery target for phones = provision FQDN only.**  
SIP registrar / outbound proxy / SIP domain come **inside** the rendered file from inventory + site policy — phones do not need a second operator-entered PBX URL for routine desk rollout.

| Name | Role |
|------|------|
| **Provision FQDN** | Public (or LAN) HTTPS host phones hit for config. Own LE cert. Stable ops name (e.g. `provision.{apex}` or per-fleet equivalent) |
| **SIP contact in file** | Fleet: typically **SBC** (and tenant SIP **domain string** where the vendor template needs it). Solo/direct: instance FQDN/IP as today. **Not** “always the provision host” (prior co-located PBX coincidence of co-location) |
| **Tenant FQDN** | Remains SIP domain string; **no public A** on SBC fleet (**`TLS_AND_CERTIFICATES.md` §0**) |

---

## 4. Responsibilities (v1 shape)

| Do | Notes |
|----|--------|
| HTTP(S) MAC / descriptor → vendor config | Same URL families as prior co-located PBX (`?mac=`, `/{mac}.cfg`, Yealink common, etc.) |
| Template expand | Device `#INCLUDE` stack; `$localip` / `$ext` / `$password` / `$desc` / ports; optional BLF from fkeys |
| Credential gating | prior co-located PBX `sndcreds` Always \| Once \| No — keep the idea (strip secrets when off) |
| Unknown / ambiguous MAC | **404** |
| Optional mTLS | prior co-located PBX `:41363` + manufacturer CA bundle — keep as **remote / hardened** option, not required for lab LAN |
| Optional static firmware/assets | Alias trees (snom/, Polycom helpers) — later if needed |
| Logging | Request URI, MAC, UA, success/404; no secrets in logs |

---

## 5. Inputs (data the server needs)

| Input | Source (prior co-located PBX) | pbx3 note |
|-------|---------------|-----------|
| Extension + MAC + secret + device/template stack | `IPphone` | **Authored** on instance; **published** to S3 inventory (§6) for the provisioner |
| Vendor templates | `Device` | Seed on provisioner and/or referenced from inventory; lift private archives subset |
| BLF / line keys | `IPphone_FKEY` | Include in MAC object when needed for rendered BLF |
| SIP host policy | `provisionwith` + `globals.FQDN` / `EDOMAIN` | Fleet: embed **SBC / domain policy** in the published object (not “local PBX IP”) |
| Provision URL host | Often same as PBX in prior co-located PBX | **Dedicated provision FQDN** |
| OUI → vendor | `manuf.txt` | Create-time helper on authoring UI; not required on every GET |
| Vendor client CAs | `3pcerts.pem` | Optional mTLS path |

---

## 6. Inventory home of record — **S3, keyed by MAC** (locked lean)

**Lock:** Phone inventory HoR for the provisioning server is **S3** (org / fleet bucket family), **keyed by phone MAC address**. The provisioner is a **read path** over that inventory — it does not own a second phone DB.

prior co-located PBX kept inventory in the PBX SQLite (same host as the listener). pbx3 separates them: instance still **authors** extensions / PJSIP; S3 holds the **MAC → provision payload** the HTTP listener needs.

### Shape (sketch — exact key layout later)

| Concern | Stance |
|---------|--------|
| **Key** | Normalized MAC (12 hex, lower-case, no separators) — e.g. `phones/{mac}.json` or `provisioning/phones/{mac}.json` under the org bucket |
| **Value** | Enough to render config: ext / shortuid, secret (or reference), device/template id or INCLUDE stack, tenant/home hints, SIP registrar/proxy/domain, optional BLF, `sndcreds` policy |
| **Lookup** | `GET /provisioning…` → normalize MAC → `GetObject` (or cached copy) → expand templates → body |
| **Unknown MAC** | Object missing → **404** (same as prior co-located PBX) |
| **Descriptors** | Vendor common files (Yealink `y000000…`) may be static on the provisioner or separate non-MAC keys — not MAC HoR |

### Authorship vs HoR

| Layer | Role |
|-------|------|
| **Instance** | Operator creates/edits extension + MAC; Commit builds Asterisk |
| **Publish to S3** | Product path writes/updates the MAC object (Gatekeeper or node→catalog push — exact writer TBD) |
| **Provisioner** | Reads S3 by MAC; serves HTTP; **no** routine write-back of inventory |
| **Move / rehome** | Update the MAC object’s home / SIP fields (durable job family if needed) — phone keeps same MAC key |

### Why this fits

- One MSP-visible inventory across instances (MAC is the natural phone identity).
- Matches existing fleet pattern: **S3 = catalog HoR**, workers project/read.
- Listener stays dumb and replaceable; no co-located SQLite lock issues.

### Secrets — dual consumer (open)

prior co-located PBX kept the SIP password on the **extension row**; Asterisk and `/provisioning` both read the same SQLite. Split architecture breaks that coincidence:

| Consumer | Needs the secret |
|----------|------------------|
| **Instance** | PJSIP auth (Commit / genAst) — always |
| **Provision stream** | Embed in vendor config when `sndcreds` allows — at phone GET time |

**Instance remains the place secrets are created/rotated** (extension panel). Question is only how the provisioner learns them.

| Option | Idea | Pros | Cons |
|--------|------|------|------|
| **S1. Secret in S3 MAC object** | Publish password with the inventory on save/Commit | Provisioner stays dumb (S3 only); works if home node is down | SIP secrets at rest in org bucket; IAM/encryption must be tight; two copies to keep in sync |
| **S2. Secret instance-only; provisioner fetches at render** | S3 has MAC → home + non-secret fields; provisioner calls home instance (fleet token) for passwd when building the body | Single secret HoR = extension row (prior co-located PBX-like); S3 has no SIP passwords | Home node (or API) must be up for **re-provision**; extra hop; cache carefully |
| **S3. Pre-rendered config blob in S3** | Instance (or Gatekeeper) writes the final vendor file bytes under the MAC key; provisioner is a file server | Listener trivial; templates stay on instance | Secret still in S3 (inside the blob); every template/BLF change republishes; harder multi-vendor common files |

**Lean instinct (not locked):** prefer **S2** if we want S3 as *routing/inventory* HoR without becoming a password store; prefer **S1** if we want the provisioner fully offline from instances (MSP shared box, home node asleep). **S3** is attractive only if we deliberately dumb-down the listener.

Do **not** invent a third place that operators edit passwords. Rotate on the instance → publish or invalidate cache.

### Still TBD (not blocking the MAC-key HoR lock)

- Exact prefix / JSON schema (non-secret fields first).
- **Secret path** — S1 / S2 / S3 above.
- Who may **put** MAC objects (fleet token vs instance IAM) — Rule 10 / Rule 9.
- Cache on the provisioner (optional) vs GetObject every request.
- Solo / non-fleet: same S3 shape with a small bucket, or a local fallback — decide when solo desk-phone story matters.

---

## 7. Non-goals

- Tenant create / installer / Mode 4 rebuild (“provision” overloaded elsewhere)
- Asterisk PJSIP generation / Commit / genAst (instance)
- SPA extension create/edit UI (instance — **`EXTENSION_PROVISIONING_*`**)
- SIP proxy, RTP, registrar, or SBC features on the provision host
- Browser holding ops IAM / AWS keys
- Requiring the directory or provisioner for **calls** once phones are configured
- Full vendor matrix on day one — start with the vendors we actually ship in lab (Snom / Yealink first), expand Device set as needed
- DHCP server product — may **document** opt66/114 pointing at provision FQDN; shipping dnsmasq-on-provisioner is optional later

---

## 8. Security (thin)

| Topic | Stance |
|-------|--------|
| Open GET by MAC | prior co-located PBX default on LAN; acceptable for lab. Treat MAC as weak capability |
| HTTPS | Required for any non-lab / remote path; provision FQDN gets its **own** LE cert |
| mTLS + vendor CAs | Optional hardened remote (prior co-located PBX 3pcerts pattern) |
| Secrets in body | Only when `sndcreds` allows; prefer Once for first boot |
| Writes from phones | Ignore PUT / vendor “security file” uploads (404/200 no-op as prior co-located PBX) |

---

## 9. Relationship to other tracks

| Track | Boundary |
|-------|----------|
| **Extension provisioning (SPA/API)** | Authors `ipphone` + Device INCLUDE + Commit → PJSIP on **instance** |
| **This server** | Delivers **phone config HTTP** from inventory |
| **Fleet DNS / LE** | Tenant domains stay SIP-only; provision host is a **named product FQDN** with A/AAAA + LE |
| **SBC** | Runtime SIP for desk phones; not the config HTTP listener |

---

## 10. Implementation map (when scheduled — not started)

| Slice | Likely home | Notes |
|-------|-------------|--------|
| Listener (MAC → config) | New package / small service | Port private archives `device.php` behaviour; stack choice open |
| Inventory in S3 (MAC keys) | Org bucket + Gatekeeper/node publish | Provisioner GetObject by MAC; schema TBD |
| Device template seed | Data from private archives `Device` | Subset OK |
| Provision FQDN + LE | Ops + installer for this class | Separate from instance Sync |
| SPA / Fleet UI | Later | Point phones / show provision URL; not required for listener v1 |
| DHCP helpers | Optional | Document opt66 → `https://{provision-fqdn}/provisioning` |

---

## 11. Open decisions

0. **Build at all?** — §0 / **§0.1** (M1–M5). Lean **M1** (+ M2 later); M3 if co-locate; M4/M5 only for explicit SKU.  
1. ~~**Inventory HoR**~~ — **if fleet listener:** S3 keyed by MAC (§6). Prefer no passwords in that object (align M4).  
1b. **Secrets** — S1 / S2 / S3 in §6; map to M3–M5. Dual consumer; instance remains author.  
2. **SIP host embedded in templates** for fleet — always SBC FQDN? outbound proxy + tenant domain? per-site override?  
3. **One provisioner per fleet vs per instance** — MSP shared vs co-tenant isolation (vs M3 on-box).  
4. **Stack** — keep PHP+Apache parity vs rewrite. Behaviour first; stack second.

---

## 12. Verify later (acceptance sketch)

- Phone with known MAC receives config; unknown MAC → 404.  
- Rendered file registers successfully on lab SBC path.  
- Provision host down → existing registrations unaffected.  
- No tenant public A records introduced for provisioning.  
- Instance Commit still owns Asterisk; provisioner does not write PJSIP.
