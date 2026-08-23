# Extension named pickup groups

**Locked:** 2026-08-23  
**Asterisk:** [Call Pickup](https://docs.asterisk.org/Configuration/Features/Call-Pickup/)

## Product

- **Named only:** GenAst emits `named_call_group` / `named_pickup_group` only (no numeric `call_group` / `pickup_group`).
- **One SPA field** `named_groups` on Extension create/edit — sets both named_* the same. Asymmetric → `pjsip_overlay`.
- **Default `ALL`** until the operator changes it. Empty/`ALL` → GenAst substitutes **tenant shortuid (`$clst`)** so whole-tenant pickup stays isolated across tenants on one instance.
- Custom values (`sales`, `1,2`, …) replace the default. Digit tokens are fine (heritage SARK numerics as **named** strings).

## Schema / GenAst

- `ipphone.named_groups` TEXT DEFAULT `'ALL'`
- Template token `$named_groups` in `pjsip_phone.tmpl`
- Upgrade: `apply-sqlite-add-named-groups.sh`

## SARK migrate

Private ETL **`~/GiT/sark-to-pbx3`**: map old `callgroup` / `pickupgroup` (and sipiaxfriend lines) → `named_groups` with digit tokens as-is. See that repo’s `docs/REQUIREMENTS.md`.
