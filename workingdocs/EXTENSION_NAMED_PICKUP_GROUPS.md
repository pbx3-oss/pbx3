# Extension named call / pickup groups

**Locked:** 2026-08-24 (split fields; supersedes 2026-08-23 single-field `named_groups`)  
**Asterisk:** [Call Pickup](https://docs.asterisk.org/Configuration/Features/Call-Pickup/)

## Product

- **Named only:** GenAst emits `named_call_group` / `named_pickup_group` only (no numeric `call_group` / `pickup_group`).
- **Two SPA fields** on Extension create/edit:
  - **Named call groups** (`named_call_group`) — pools this phone **belongs to** (its ringing calls).
  - **Named pickup groups** (`named_pickup_group`) — pools this phone **can pick up from**.
- Fields are independent (asymmetric department pickup is first-class; no need for `pjsip_overlay`).
- **Default `ALL`** on both until the operator changes them. Empty/`ALL` → GenAst substitutes **tenant shortuid (`$clst`)** so whole-tenant pickup stays isolated across tenants on one instance.
- Custom values (`sales`, `1,2`, …) replace the default. Digit tokens are fine (heritage SARK numerics as **named** strings).

## Schema / GenAst

- `ipphone.named_call_group` TEXT DEFAULT `'ALL'`
- `ipphone.named_pickup_group` TEXT DEFAULT `'ALL'`
- Template tokens `$named_call_group` / `$named_pickup_group` in `pjsip_phone.tmpl` / `pjsip_webrtc.tmpl`
- Upgrade: `apply-sqlite-add-named-groups.sh` (also copies legacy `named_groups` → both; seeds help)
- Help: `tt_help_core` keys `named_call_group` / `named_pickup_group`

## SARK migrate

Private ETL **`~/GiT/sark-to-pbx3`**: map old `callgroup` → `named_call_group`, `pickupgroup` → `named_pickup_group` (and sipiaxfriend lines) with digit tokens as-is. Prefer existing `namedcallgroup` / `namedpickupgroup` if present. Empty → leave default **`ALL`**. See that repo’s `docs/REQUIREMENTS.md` **#11**.

## Lab acceptance (requirement)

**Status:** Requirement locked **2026-08-24** — harness in **sipplab**; **manual L3 pickup OK** on lab `.31`; **sipplab pack green pending**.

Named call/pickup groups are **not signed off** for release until the unattended pack below is green on a home with split fields deployed (`named_call_group` / `named_pickup_group` in schema, GenAst, Commit).

### Driver

**sipplab** `./run-pickup-pack.sh` — spec **`sipplab/workingdocs/PICKUP_PACK.md`**.  
Optional L2 preflight: `./run-soak.sh start` runs the pack when `SOAK_PICKUP_VALIDATE=1` and `GOLDEN_SSH` is set.

### v1 scenario IDs (must pass)

| ID | Proves |
|----|--------|
| `pickup-pjsip-config` | After Commit, victim + picker endpoints in `pjsip_ready_phones.conf` carry `named_call_group` / `named_pickup_group` (default **ALL** → tenant shortuid) |
| `pickup-directed-ok` | Caller rings victim (180 only) → third phone dials directed pickup **`*8{ext}`** → caller + picker channels **Up** (default whole-tenant groups) |
| `pickup-group-deny` | Victim `named_call_group=A`, picker `named_pickup_group=B` (≠ A) → directed pickup **fails** (no caller↔picker bridge); restore **ALL** after |

### Assertion model

1. **SIP** — three SIPp legs (victim UAS ring-only, caller INVITE, picker INVITE `*8{ext}`).
2. **CLI fingerprint** — `core show channels concise` on DUT via `GOLDEN_SSH` (bridge Up / no-bridge on deny).
3. **PJSIP config** — grep ready conf for named groups (config scenario).

Do **not** assert audio MOS. BLF SUBSCRIBE / hint state remains **manual L3** (phone key programming).

### Out of v1 (explicit non-requirements)

- Blind idle **`*8`** with no extension digits (no dialplan exten for bare `*8`; `pickupexten` is in-call feature only).
- Merge into Peer DID `./run-pack.sh` (separate pack, like feature shortcodes).

### Product cross-refs

- **`CALL_TYPE_INVENTORY.md`** — `maj-pickup`, `_*8XX.`
- **`CALL_TEST_STRATEGY.md`** — L1 pickup pack + soak preflight

### Manual L3 (lab `.31` / desks)

Operator matrix while automation is pending: baseline **ALL** pickup; asymmetric groups (e.g. victim `sales`, picker `sales,support` vs mismatch deny); BLF keys + `pjsip show subscriptions inbound` after Commit.

## Lab status (2026-08-24)

| Area | Status | Notes |
|------|--------|--------|
| **Named pickup** (`*8` / directed `*8{ext}`) | **Manual L3 OK** on lab **`.31`** | Operator sign-off: call pickup works with split fields + Commit. Formal release gate remains sipplab **`./run-pickup-pack.sh`** (not run yet). |
| **PJSIP named groups + GenAst** | **OK** | Ready conf / endpoint tokens behave as locked; tenant-scoped **ALL** → `$clst`. |
| **BLF (SUBSCRIBE + hints)** | **Partial** | **Snom:** BLF OK on lab. **Yealink:** not working yet — **treated as phone provisioning/config** (key type, SUBSCRIBE target, account index); **Asterisk/PJSIP side assumed OK** (`allow_subscribe`, `subscribe_context`, hints in tenant context). No product change until root cause known. |
| **sipplab L1 pack** | **Pending** | Harness requirement unchanged; run when convenient for unattended sign-off. |

**Yealink investigation (operator):** compare working Snom BLF key (URI, `dialog`-style vs `presence`, line vs BLF type) against Yealink auto-provision or manual key XML; confirm SUBSCRIBE reaches Asterisk (`pjsip show subscriptions inbound`).
