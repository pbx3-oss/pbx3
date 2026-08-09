# Dial prefixes — convert from InterSARK / INTERSITE (legacy trunks)

**Status:** Operator migrate recipe complete (short-dial slice **F**, 2026-08-04).  
**Audience:** Instance admins converting sister-site digit maps to pbx3 **Dial prefixes**.  
**Not:** Automatic DB rewrite; silent OutRoute/trunk deletion; product change that forces unique extensions.  
**Product requirements:** **`TENANT_SHORT_DIAL_REQUIREMENTS.md`** (this recipe owns §7 operational detail).

---

## 1. Why convert

| Legacy | What operators expected | Why it fails under multi-tenant |
|--------|-------------------------|--------------------------------|
| **Unique extensions** + bare dial of the other site’s `1000` | One global namespace | Same `1000` exists on many tenants |
| **InterSARK / SailToSail** trunks + extension CLIP | Distant desk rings; redial is bare ext | Extension CLIP is not a returnable AoR across namespaces |
| **`*_INTERSITE` OutRoutes** | Digit pattern → peer/trunk toward sister site | Node-local digit maps; not FQDN-native; hard to move with tenants |

**New product:** on each **calling** tenant, **Dial prefix** (2–4 digits) → **target tenant FQDN**. Dial `{prefix}{extension}` (digits only). Path always `sip:{ext}@{target_fqdn}` via SBC. Reverse is **not** automatic — configure on B as well.

**Rule 1:** prefix rows are **local to the home that hosts that tenant** (tenant miniDB). No Gatekeeper/directory on the dial path.

---

## 2. Prerequisites (before you start a site)

- [ ] Fleet instance with **SBC in path** (v1: singleton multi-tenant without SBC cannot use prefixes).  
- [ ] Packages with short dial: **pbx3 ≥ 0.0.4-6**, **pbx3cagi ≥ 1.0.0-11** (PrefixDial + GenAst patterns).  
- [ ] Magrathea (or fleet SBC): **usrloc miss → domain dispatcher** for `ext@tenant.fqdn` (slice B).  
- [ ] Sister site(s) live as **tenant FQDNs** on fleet (dispatcher setid correct).  
- [ ] You can log in as **instance admin** (Dial prefixes panel is admin-only).  
- [ ] Commit / genAst available after prefix CRUD on **each** home that hosts a calling tenant.

Do **not** start retire of InterSARK while package roll or Mag miss→home is incomplete.

---

## 3. Mental map (old → new)

```text
Legacy
  digit_map / seize pattern  →  InterSARK/SailToSail trunk  →  other site  (unique ext world)

pbx3 dial prefix
  tenant A dialalias:  81 → sister.pbx3.com
  phone dials 811003
       → PrefixDial → sip:1003@sister.pbx3.com via SBC
       → B's local 1003 rings
```

| Concept | Store as |
|---------|----------|
| “Site code” / sister handle | Calling-tenant **prefix** (`pkey`, 2–4 digits) |
| Sister site identity | **Tenant FQDN only** (`target_fqdn`) — never instance FQDN (`kildare.pbx3.com`, `08jzwn.pbx3.com`) |
| Optional inventory pin | `target_cluster` shortuid (label only; dial uses FQDN) |
| Who may call whom | **Active** prefix rows only (v1: all CoS classes) |

---

## 4. Inventory (per calling tenant)

Do this on **each** home that will keep sister-site short dial. One worksheet per calling tenant.

### 4.1 SQL / panel checks

On the node hosting the tenant (`/opt/pbx3/db/sqlite.db`; substitute `CLUSTER` = tenant **shortuid**):

```bash
# Outbound routes that look intersite (name patterns; adjust LIKE as needed)
sqlite3 /opt/pbx3/db/sqlite.db "
SELECT cluster, pkey, active, path1, path2, path3, path4, dialplan, description
FROM route
WHERE cluster = 'CLUSTER'
  AND (
    upper(pkey) LIKE '%INTERSITE%'
    OR upper(ifnull(description,'')) LIKE '%INTERSITE%'
    OR upper(ifnull(description,'')) LIKE '%INTERSARK%'
    OR upper(ifnull(cname,'')) LIKE '%SISTER%'
    OR upper(ifnull(cname,'')) LIKE '%INTER%'
  )
ORDER BY pkey;
"

# Trunks often used by those paths (instance / default owned — still list for dual-run)
# technology may be InterSARK or SailToSail on converted DBs
sqlite3 /opt/pbx3/db/sqlite.db "
SELECT cluster, pkey, active, technology, cname, description
FROM trunks
WHERE upper(ifnull(technology,'')) IN ('INTERSARK','SAILTOSAIL')
   OR upper(ifnull(pkey,'')) LIKE '%INTERSARK%'
   OR upper(ifnull(pkey,'')) LIKE '%SAILTOSAIL%'
   OR upper(ifnull(description,'')) LIKE '%INTERSITE%'
ORDER BY pkey;
"
```

SPA: **Outbound → Routes** and **Trunks** for the same tenant / default — note each seize digit string or dialplan fragment that meant “go there.”

### 4.2 Worksheet columns

| # | Calling tenant (shortuid / FQDN) | Legacy digits / route pkey | Peer trunk | Sister site (human) | Target **tenant** FQDN | Chosen prefix | Notes |
|---|----------------------------------|----------------------------|------------|---------------------|------------------------|---------------|-------|
| 1 | | | | | | | |

Fill **Target tenant FQDN** from SPA tenant list / fleet catalog `cname` — not from the PBX instance hostname.

### 4.3 Collision hygiene (prefix choice)

Chosen **2–4 digit** prefix must **not** collide with, on the **same** calling tenant:

- Local LepDial / extension ranges that would swallow `_prefixX.`  
- Existing OutRoute seize / dialplan patterns (including remaining INTERSITE)  
- Emergency / national access patterns commonly trained (e.g. `9`, `0` for PSTN — site policy)  
- Other dial prefixes already on that tenant  

Remainder after prefix is **digits only** — no feature codes through prefix path.

---

## 5. Build prefixes (dual-run default)

Work tenant A (caller) first; then B if bidirectional.

1. SPA (**instance admin**) → tenant A → **Outbound → Dial prefixes**.  
2. Add row: **prefix** = worksheet; **Target tenant** = restricted FQDN picker (or catalog).  
3. Active = YES.  
4. Save → **Commit / genAst** on A’s home so PrefixDial patterns emit.  
5. If B should dial back into A: repeat prefix row on B → A’s tenant FQDN; genAst on **B’s** home.

Do **not** remove INTERSITE / InterSARK yet.

### 5.1 Dual-run acceptance (keep legacy live)

On each direction you convert:

| Check | Pass |
|-------|------|
| New path | Desk or SIPp Domain dials `{prefix}{ext}` → correct sister extension rings |
| Station AoR | Still dial / ring local `shortuid@tenant.fqdn` path (no miss→dispatcher regression for registered contacts) |
| Legacy | Old INTERSITE / InterSARK seize **still** works until deliberately retired |
| PSTN | Local OutRoutes / Egress **unchanged** |

Lab L1 dual-host reference: sipplab **`docs/examples/site-dial-lab.md`**.

---

## 6. Train operators (before retire)

Explain three non-obvious points:

1. **Dial string** is prefix + sister’s **extension** — not sister shortuid and not “just 1000” site-wide.  
2. **Display CLIP** on ringing phone is usually the caller’s **local extension** (presentation); missed-call **redial** may need history URI / PAI `suid@fqdn` — handsets differ (**D** residual). Do **not** promise InterSARK “globally unique bare-ext redial.”  
3. **Tenant move** (same FQDN, new home): prefix rows **unchanged**. **Tenant FQDN rename**: re-save prefix `target_fqdn` on callers.

---

## 7. Retire legacy (operator-gated only)

Only after dual-run green **and** operator sign-off per worksheet row:

1. Set INTERSITE **route** `active=NO` (or remove that path only) for digits now served by a prefix. Prefer deactivate over delete for one audit cycle.  
2. Deactivate InterSARK / SailToSail **trunks** only when **no remaining route** references them.  
3. GenAst / Commit.  
4. Smoke: prefix dial still green; **PSTN** OutRoutes still green.  
5. Document what was retired (ticket / change log).

**Hard rules**

- **No** product automation that mass-deletes routes or PSTN trunks as part of prefix create.  
- **No** “clean convert” that drops failovers without ops eyes on.  
- Trunks are **instance-scoped** in fleet posture (see **`TRUNK_ROUTE_MULTITENANCY.md`**); retiring a shared InterSARK trunk can affect more than one tenant — inventory **all** consumers first.

---

## 8. Fleet / multi-node sisters

Sister sites almost always live on **different** instances.

| Case | Action |
|------|--------|
| Target on **another** node | Prefix `target_fqdn` = that tenant’s SIP domain; dial path is still SBC domain → dispatcher → far home. No need for far tenant in **local** `cluster` table. |
| Target **moves** home, FQDN same | No prefix change; fix SBC domain/dispatcher only. |
| Same shortuid appears on two FQDNs | Impossible product-wise for live home of record; never invent second FQDN in freeform (picker enforces known tenants). |

---

## 9. What not to do

| Anti-pattern | Why |
|--------------|-----|
| Use **instance** FQDN as target | Dial would follow wrong identity after multi-tenant moves |
| Auto-delete INTERSITE on prefix save | Breaks dual-run / rollback |
| Expect unique-ext bare dial forever | Model rejected |
| Feature codes after prefix (`81*…`) | Digits-only remainder (locked) |
| Gatekeeper lookup at dial | Rule 1 |
| Convert FreePBX site dial with this doc alone | Separate ETL; this recipe is **InterSARK / INTERSITE → dial prefixes** on pbx3 |

---

## 10. Acceptance (slice F)

- [x] Operator recipe documented (this file).  
- [x] Explicit dual-run then retire; no silent PSTN churn.  
- [x] Inventory SQL / worksheet; CLIP / coach notes; fleet FQDN rules.  
- [x] Linked from **`TENANT_SHORT_DIAL_REQUIREMENTS.md`** §7.

No application code required for F.

---

## 11. Related

| Doc | Role |
|-----|------|
| **`TENANT_SHORT_DIAL_REQUIREMENTS.md`** | Product locks, slices A–F |
| **`TRUNK_ROUTE_MULTITENANCY.md`** (pbx3spa workingdocs) | Trunk instance ownership vs tenant routes |
| sipplab **`docs/examples/site-dial-lab.md`** | L1 proof path |
| cagi `OutTrunk` | Still special-cases InterSARK/SailToSail for extension CLIP until operators retire those trunks |

---

## Changelog

| Date | Note |
|------|------|
| 2026-08-04 | Slice F: full operator migrate recipe (from §7 draft). |
