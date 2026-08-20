# Fleet naming lock — instance & tenant

**Status:** Locked 2026-08-06; **code + lab Name align done** (tenant label=pkey; Fleet-only instance Name; installer vanity reject; FQDN=`{suid}.{apex}`). Lab: **Golden** / **AEL Nodes** / **Labtest-B**. Vanity host debt (`kildare.pbx3.com`) remains until rebuild. **D6 FQDN rename cancelled** (Name edit covers rebrand).  
**Related:** [`NETWORK_SYSGLOBALS_OVERLAP.md`](../../pbx3spa/workingdocs/NETWORK_SYSGLOBALS_OVERLAP.md) (instance sitename↔label) · [`FLEET_TENANT_DELETE_REQUIREMENTS.md`](FLEET_TENANT_DELETE_REQUIREMENTS.md) · [`FLEET_TENANT_CREATE_REQUIREMENTS.md`](FLEET_TENANT_CREATE_REQUIREMENTS.md) · [`TODO.md`](TODO.md)

## Product rule (both classes)

| Role | Meaning | Mutable? |
|------|---------|----------|
| **shortuid** | Opaque processing / fleet / SIP identity key | **No** (immutable after mint) |
| **Name** | One short human-recognisable string | Yes (ordinary edit; not a Rule 14 job) |
| **Description** | Free-form what / where / function (notes) | Yes — **not** Name; never used as chooser/Home title |
| **FQDN** | Dialable / DNS / TLS hostname | **Derived:** always **`{shortuid}.{apex}`** — not independently renamed |

Do **not** invent a second friendly nickname. Description / notes are **not** Name. FQDN is **not** Name — it is the opaque host derived from shortuid + apex (`globals.domain` / tenant domain).

Schema may differ by class; **operator language** should not. Prefer UI **Name** (or “Site name” / “Tenant name”). Hide `pkey` / `label` / `sitename` jargon where practical.

### FQDN policy (locked 2026-08-06)

- **Always** `{shortuid}.{apex}` for **instances and tenants**.
- **No vanity hostnames** (e.g. `kildare.pbx3.com` when “Kildare” is a human Name). Lab **Kildare** node (`shortuid=kildare` / `kildare.pbx3.com`) is **policy debt** — do not repeat; Name may still be **Kildare**.
- **No per-object FQDN rename job (D6 cancelled).** Changing apex fleet-wide is a different mass/ops problem (not scheduled).
- Installers / create paths must mint **opaque** shortuid (idpwgen-style) and set FQDN from it — do not accept freeform `INSTANCE_FQDN=kildare.pbx3.com` as a product path (legacy override = debt).

## Instance

| Product | Storage | Example |
|---------|---------|---------|
| shortuid | `globals.shortuid` (+ catalog `id` = KSUID) | `08jzwn` (opaque) |
| **Name** | **`globals.sitename`** ≡ catalog **`label`** (must not drift) | `Kildare` or `golden` — **legal** |
| **Description** | Catalog **`notes`** (free form). **Not** Name. | `test` |
| FQDN | `globals.fqdn` = `{shortuid}.{apex}` | `08jzwn.pbx3.com` |

- **No instance `pkey` column.** Tenant `cluster.pkey` only. Instance **Name** is sitename≡label (product “pkey-like” role without that DB name).
- **Name** is the short recogniser (chooser, Home). **Description** elaborates; never promote notes into Name.
- **Edit surface (locked 2026-08-06):**
  - **Fleet node:** **Fleet → Instances** only. Gatekeeper PATCHes catalog `label` after **`PUT /api/fleet/sitename`** on the node and **`POST /fleet/sync-node-label`** on the SBC (Peer + dispatcher description) when provisioned — fail whole save if either push fails. **Network → Site Name is read-only.**
  - **Solo:** **Network → Site Name** only (no catalog).
- Display Name: `sitename || label || shortuid` (not FQDN, not notes).
- Lab (**done 2026-08-06**): `label === sitename` — **Golden**, **AEL Nodes**, **Labtest-B**. Vanity FQDN debt left as-is until rebuild.

Detail for sitename↔label: **`NETWORK_SYSGLOBALS_OVERLAP.md`**. Schema: **`instance-record.v0.json`** (`label`, `notes`).

## Tenant

| Product | Storage | Example |
|---------|---------|---------|
| shortuid | `cluster.shortuid` (+ catalog `shortuid`) | `dhbm8x` (opaque) |
| **Name** | **`cluster.pkey`** (canon) | `Kildare` / `acme` — **legal** |
| **Description** | `cluster.description` — free text only | `HQ pilot` |
| FQDN | `cluster.fqdn` = `{shortuid}.{apex}` | `dhbm8x.pbx3.com` |

Same split as instances: **Name** vs **Description**. Tenant description lives on the node; do not copy it to catalog as a competing Name (`label`).

### Locked correction (2026-08-06)

**Description → catalog `label` at Fleet Create is a mistake.** It invents a second friendly string (Fleet Name ≠ instance Name column).

| Do | Don’t |
|----|--------|
| Fleet / DID display Name = **`pkey`** | Seed or prefer catalog `label` from **description** |
| Keep description as notes on create/edit | Treat description as identity |
| Optional: catalog `label = pkey` as mirror only | Independent nickname in `label` |

Today: `TenantProvisioner::buildCatalogRecord` sets **`label = pkey`** (fixed 2026-08-06). SPA `listFleetTenants` prefers **pkey**. Older meta may still have description-as-label until refreshed.

## FQDN rename (D6) — cancelled

**Cancelled 2026-08-06.** No product use case when FQDN is always `{shortuid}.{apex}` and shortuid is immutable. Human rebrand = edit **Name** only. See delete requirements § D6 (cancelled note).

## Explicit non-goals

- Changing shortuid after mint
- Instance `pkey` column (use sitename≡label for Name)
- Vanity / freeform hostnames (`kildare.pbx3.com`-style)
- Per-tenant or per-instance FQDN rename job
- Using FQDN or shortuid as the human Name
- Two competing friendlies (sitename vs label; pkey vs description-as-label)
