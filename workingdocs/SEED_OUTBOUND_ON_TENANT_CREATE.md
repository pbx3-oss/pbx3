# Seed outbound OutRoutes on tenant create — requirements (stub)

**Status:** **Implemented 2026-08-06** (API + SPA + schema apply); **UK seed amended 2026-08-10 (#4c / L7a)** to `_0XXX. _00XX.`. US string still operator-set (O4).  
**Spec / behaviour:** Instance `globals.default_outbound_dialplan` → copy to tenant `MainOut` OutRoute on create (`path1=Egress` when fleet/Egress exists). Time saver; editable after.  
**Related:** [`FLEET_TENANT_CREATE_REQUIREMENTS.md`](FLEET_TENANT_CREATE_REQUIREMENTS.md) · [`NUMBER_WIRE_POLICY.md`](../pbx3-directory/docs/NUMBER_WIRE_POLICY.md) · [`EGRESS_PLUS_E164_WIRE.md`](EGRESS_PLUS_E164_WIRE.md) · code `SeedOutboundRouteOnTenantCreate` · apply `apply-sqlite-add-default-outbound-dialplan.sh`

---

## 1. Problem

Today **tenant create** = `cluster` row (+ fleet catalog / SBC domain). Operator must still add **OutRoute(s)** with dialplan patterns and **`path1=Egress`**, then Commit, before PSTN outbound works.

Same product instinct as **DID open-seed**: create should leave the tenant **usable** for the common path without a blank dial plan.

---

## 2. Locked decisions (2026-08-06)

| # | Decision | Lock |
|---|----------|------|
| L1 | **Egress** is the default trunk on fleet nodes | Routes choose trunk; default / forced `path1=Egress`. No trunk invent on tenant create. |
| L2 | **Route dialplan** does digit routing | Patterns decide what seizes Egress (or another trunk on solo). |
| L3 | **Locale is unavoidable** | Short codes / feature codes / national shapes differ (BT vs NANP vs …). |
| L4 | **One tenant does not span locales** | No per-tenant locale picker at create. |
| L5 | **Instance owns the default dialplan string** | One character string on **instance `globals`** (same shape as OutRoute `dialplan`). Not a multi-row template system. |
| L6 | **Tenant create copies that string** into a tenant OutRoute | Snapshot into `route` with `path1=Egress` on fleet. **Time saver only** — operator may edit/add/remove routes after; nothing stops post-create changes. |
| L7 | **Reject iron-PBX-only shunt** as the product default | “Longer than `ext_len` → Egress” alone is not the seed string. Seed stays locale patterns (`_0XXX. _00XX.` / US pack). |
| L7a | **Length namespaces (2026-08-10)** | OutRoute patterns must have minimum match length **> tenant `ext_len`**. Compatible seize digit (e.g. long `_9…` + mangle strip) OK. Bare short seize (`_9.`) forbidden under this rule. See **`TENANT_SHORT_DIAL_REQUIREMENTS.md`** §3.8. |
| L8 | Carrier face stays on the SBC | Aligns with number wire policy; node Mangle (Phase 1) still turns habit → `+E.164` on Egress. |
| L9 | **Product framing** | Negates defining an OutRoute **by hand for every new tenant**. Not a live-linked policy; not multi-locale; not carrier dialect. |

```text
Instance globals.default_outbound_dialplan  (string)
        │
        ▼  tenant create (copy once)
Tenant OutRoute.dialplan + path1=Egress
        │
        ▼  operator may edit anytime
Commit / GenAst → OutRoute → Egress → SBC → Peer dialect
```

---

## 3. Layer ownership

| Concern | Owner |
|---------|--------|
| Serving locale / country of this PBX | **Instance** (ties to Egress transform / future `serving_cc`) |
| Default outbound dialplan **string** | **Instance `globals`** (copied on create only) |
| Per-tenant OutRoute rows after create | **Tenant** (editable; seed is a starting point) |
| Trunk toward PSTN (fleet) | **Egress** |
| Carrier R-URI / CLI shape | **SBC Peer dialect** |

---

## 4. Behaviour (target)

### 4.1 On tenant create (fleet + solo)

1. Read **instance globals** default outbound dialplan string (if empty: skip seed or fail soft — O5).  
2. Insert a **`route`** row on the new cluster: `dialplan` = that string; fleet **`path1=Egress`** (path2–4 empty).  
3. Do **not** invent trunks, Peers, or Egress rows.  
4. Copy is a **one-shot snapshot** — later edits to globals do **not** rewrite existing tenants; later edits to the tenant route do **not** write back to globals.  
5. Commit / GenAst: same as today (create may soft-prompt).

### 4.2 Analogy — DID open-seed

| DID create | Tenant create (this feature) |
|------------|------------------------------|
| Require open dest / seed profile | Seed a usable outbound dialplan string |
| Auto-build `route_profile` if empty | Auto-build OutRoute from globals string |
| Operator can edit after | Operator can edit after |

### 4.3 Non-goals

- Multi-locale tenants.  
- Per-create country picker (locale is instance).  
- Live-link from globals → existing tenants.  
- Replacing short dial / PrefixDial.  
- Auto-stealing patterns that collide with operator short-dial prefixes.  
- Phase-2 SBC habit-normalize (out of scope here).

---

## 5. Open before code

| # | Question | Options / lean |
|---|----------|----------------|
| O1 | **Where does the default string live?** | **Locked + shipped:** `globals.default_outbound_dialplan` |
| O2 | **How is instance locale / initial string chosen?** | UK install/upgrade seed `_0XXX. _00XX.`; operator edits in Instance Globals for US/etc. |
| O3 | **UK pack v1 contents** | **Locked (amended #4c):** `_0XXX. _00XX.` (national + IDD; L7a-safe for default `ext_len=3`). Was `_0. _00.` pre-#4c. |
| O4 | **US / other packs** | Operator sets globals string (no US auto-seed yet) |
| O5 | **Empty globals / re-provision** | **Locked:** skip if empty; skip if tenant already has any OutRoute |
| O6 | **Solo vs fleet** | Same copy; `path1=Egress` when fleet or Egress trunk exists |
| O7 | **SPA** | **Shipped:** Instance Globals → Outbound field |

---

## 6. Acceptance (when implemented)

1. New tenant on an instance with a non-empty globals default gets an OutRoute with that dialplan **after create** (and works after Commit) without manual route create.  
2. `path1=Egress` on fleet-seeded rows.  
3. Editing tenant A’s route does not change tenant B or globals.  
4. Editing globals does not mutate existing tenants.  
5. No carrier dialect on the node routes.

---

## 7. Implement order

1. ~~Lock O1–O3~~ **done**  
2. ~~Schema + apply script + postinst~~ **done** (`apply-sqlite-add-default-outbound-dialplan.sh`)  
3. ~~Tenant create hook~~ **done** (`SeedOutboundRouteOnTenantCreate` from `TenantController::save` / fleet store)  
4. ~~SPA globals field~~ **done**  
5. US string pack later (O4) — optional  

**Lab apply without new deb:**  
`sudo /opt/pbx3/scripts/apply-sqlite-add-default-outbound-dialplan.sh`  
(or deploy pbx3api; service `ensureSchema()` adds the column on first create if missing).
