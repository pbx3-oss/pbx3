# Fleet DID assignment — central registry vs inroutes-only

**Status:** Design (2026-07-09); **hop-1 authorship locked 2026-08-11** — see **`FLEET_DID_HOP1_LOCK.md`** (Fleet-only retarget under fleet; SBC must not offer `fleet=did` edit).  
**Audience:** Product, fleet implementers (control-plane, pbx3-directory, pbx3sbc, pbx3api)  
**Related:** **`FLEET_DID_HOP1_LOCK.md`**, **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §11.9–§11.10, **`FLEET_TRUNK_PEERING_DECISION.md`** §5.1, **`NUMBER_DIALECT_REQUIREMENTS.md`** (wire +E.164 / carrier dialects), **`schema/did-record.v0.json`**

---

## 1. Problem

Inbound PSTN needs two facts:

| Fact | Question | Typical change rate |
|------|----------|---------------------|
| **Assignment** | Which **tenant** owns this E.164? | Low — buy/allocate, then stable for years |
| **Homing** | Which **node** hosts that tenant? | Rare — tenant move |
| **Behaviour** | What happens to the call on the node? | Occasional — tenant admin edits `inroutes` |

**Delivery** to the right node is compiled: `DID → tenant → node → SBC setid`. **Behaviour** stays on the node (`inroutes.pkey` regex).

---

## 2. Customer analogue — “trunker”

Many MSP customers run a **trunker**: carrier delivers all DDIs to one concentrator; trunker `inroutes` distribute to **downstream peer** Asterisk boxes. Fleet **pbx3sbc** is the managed trunker; fleet **nodes** are downstream peers.

| Trunker | PBX3 fleet |
|---------|------------|
| Carrier → trunker IP | Carrier → SBC pool (SRV) |
| Trunker `inroutes` → downstream trunk | SBC `dr_rules` → dispatcher `setid` |
| Customer PBX `inroutes` → extension/IVR | Tenant `inroutes` on node (unchanged) |
| Repoint downstream peer on move | SBC repoint + re-project delivery rows |

See **`FLEET_TRUNK_PEERING_DECISION.md`** §5.1 for the two-layer split (delivery vs behaviour).

---

## 3. When to use central registry vs inroutes-only

**Default for v1 lean fleets:** derive SBC delivery from **tenant `inroutes`** + **`meta.json.instance_id`**. No `dids.json` required.

**Enable central registry** when a **reseller/trunker** persona allocates numbers before tenants configure routing, or when fleet ops need ownership audit independent of node DB.

| Criterion | **Inroutes-only** (Mode A) | **Central registry** (Mode B) |
|-----------|---------------------------|------------------------------|
| **Persona** | End-customer buys DIDs; tenant admin configures on node | Reseller/MSP allocates DIDs to tenants from a pool |
| **Who assigns ownership** | Tenant admin (`inroutes` panel) | Fleet / gatekeeper (`dids.json` or `assign-did`) |
| **DIDs before tenant routes** | Unusual — number and route created together | Common — number reserved, routing later |
| **Reconcile needs** | SBC `dr_rules` ≡ active tenant `inroutes` | Directory `dids` ≡ SBC ≡ (optionally) `inroutes` |
| **S3 objects** | None beyond existing `meta.json` | `tenants/{shortuid}/dids.json` (+ optional `catalog/did-index.json`) |
| **Change rate** | Low (fits both modes) | Bursty allocate batches, then stable |
| **v1 MVP** | **Yes** — sufficient for mobility once SBC peering ships | Deferred — schema ready; UI/registrar later |

**Rule:** One **active owner** per E.164 fleet-wide. In Mode A, ownership is implied by tenant `inroutes`; in Mode B, by `dids.json` / `catalog/dids/{e164_key}.json`.

Both modes use the **same SBC projection pipeline**; only the **compile input** differs.

---

## 4. S3 layout (Mode B)

| Object | Schema | Written by | Role |
|--------|--------|------------|------|
| `tenants/{shortuid}/dids.json` | **`did-inventory.v0.json`** | Gatekeeper only | Authored per-tenant DID list |
| `catalog/dids/{e164_key}.json` | **`did-record.v0.json`** (+ `tenant_shortuid`) | Gatekeeper only | Optional: conditional PUT assign (`If-None-Match`) |
| `catalog/did-index.json` | **`did-index.v0.json`** | Gatekeeper (compiled) | Fleet-wide rollup for one-shot SBC project + reconcile |
| `tenants/{shortuid}/meta.json` | `tenant-meta.v0.json` | Gatekeeper | **Homing** (`instance_id`) — already exists |

`e164_key` = E.164 digits only (no `+`), e.g. `442071234567`.

**Why S3 fits this workload:** assignment is **low rate** after initial buy/allocate; bursts are batch-friendly; runtime stays on SBC MySQL (`dr_rules`), not S3.

**Why not one giant file:** prefer per-tenant `dids.json` or per-DID objects for assign; compile to `did-index.json` when a fleet-wide view is needed.

---

## 5. Projection rules (SBC delivery)

Compiler input (pick mode):

- **Mode A:** scan tenant active `inroutes` where `technology` is DiD-like; extract matchable E.164 / patterns → resolve `tenant_shortuid` → read `meta.json.instance_id` → `instance-record.sbc_dispatcher_setid`.
- **Mode B:** read `dids.json` entries with `status: active` (and `porting` if cutover flag set) → same homing lookup.

**Output (SBC):** for each deliverable DID:

1. Default: one **`dr_rules`** row (groupid **1**), prefix = full E.164 digits, `gwlist` = Asterisk gateway for that `setid`.
2. Optional: collapse contiguous DIDs for same tenant → one prefix rule (optimisation only).

**On tenant move:** job updates `meta.json.instance_id`, re-runs projection for that tenant's DID set, calls `SbcFleetAdapter.repointTenant` — same transaction as phone `domain.setid`.

**Fail-safe:** SBC keeps last projected `dr_rules` if S3/gatekeeper is down; calls continue. Reconcile when control plane returns.

---

## 6. Behaviour on the node (both modes)

Tenant **`inroutes.pkey`** remains Asterisk **regex** — block, singleton, or split range in one mechanism. The SBC does not replicate dialplan semantics.

| Layer | Mechanism |
|-------|-----------|
| SBC | Which **node** receives the INVITE |
| Node `inroutes` | Where the call **goes** (ext, IVR, queue, open/closed) |

Mode B may **validate** tenant `inroutes` against `dids.json` (“cannot route a DID you do not own”) — warn-only in v1, enforce in reconcile job later.

---

## 7. Example objects

**`tenants/f34ck1/dids.json`** (`did-inventory.v0.json`):

```json
{
  "tenant_shortuid": "f34ck1",
  "updated_at": "2026-07-09T12:00:00Z",
  "dids": [
    { "e164": "+442071234567", "status": "active", "carrier": "gamma" },
    { "e164": "+441611234567", "status": "active", "carrier": "gamma" },
    { "e164": "+12125550100", "status": "reserved", "carrier": "bandwidth", "notes": "port-in pending" }
  ]
}
```

**`catalog/dids/442071234567.json`** (optional standalone assign):

```json
{
  "e164": "+442071234567",
  "tenant_shortuid": "f34ck1",
  "status": "active",
  "carrier": "gamma",
  "assigned_at": "2026-07-09T12:00:00Z",
  "updated_at": "2026-07-09T12:00:00Z"
}
```

Assign with `PUT` + `If-None-Match: *` to enforce single active owner.

---

## 8. Implementation order

1. **Mode A projector** — `inroutes` + `meta.json` → SBC `dr_rules` (peering Phase 4).
2. **Schemas** — `did-record`, `did-inventory`, `did-index` (done).
3. **Mode B registrar** — `assign-did.sh` / gatekeeper API writing `dids.json` + index compile.
4. **Reconcile job** — directory ≡ SBC ≡ `inroutes` (fleet ops dashboard).

---

## 9. References

| Document | Role |
|----------|------|
| **`schema/did-record.v0.json`** | Single DID row |
| **`schema/did-inventory.v0.json`** | `tenants/{shortuid}/dids.json` |
| **`schema/did-index.v0.json`** | Compiled `catalog/did-index.json` |
| **`TENANT_MOBILITY_FLEET_CONSOLE_DESIGN.md`** §11.9–11.10 | Author-once / derive; S3 home of record |
| **`FLEET_TRUNK_PEERING_DECISION.md`** | Trunk/peering placement; delivery vs behaviour |

---

## 10. Change log

| Date | Change |
|------|--------|
| 2026-07-09 | Initial design — Mode A vs B decision table; S3 layout; projection rules; schemas |
