# Dial cohort — destination routing prefix

**Status:** Design locked 2026-08-06 (§11); **C0 done**; C1–C6 not coded.  
**Release stopper:** **First product release blocked** until Site Group (dial cohort) lab-green (C1–C5). Hand-entered per-sender prefixes = **lab only** — must not ship as the wild operator model.  
**Builds on:** [`TENANT_SHORT_DIAL_REQUIREMENTS.md`](TENANT_SHORT_DIAL_REQUIREMENTS.md) (call path A–E lab green).  
**Policy:** Rule **1** (no live directory in call path) · Rule **10** (S3 HoR) · Rule **14** (durable jobs) · [`DESIGN_RULES.md`](../pbx3-directory/docs/DESIGN_RULES.md).

**Product names (v1):**

| Term | Meaning |
|------|---------|
| **Routing prefix** | Destination-owned digit code (property of the tenant / network routing) |
| **Dial cohort** (UI: **Site Group**) | Explicit membership set; full mesh among members |
| **Projected dial prefix** | Node-local `dialalias` row materialised from cohort — not inventor by the sender |

---

## 1. Why

### 1.1 Pain

Hand-entered prefixes on the **calling** tenant:

- Join cost for a full bidirectional mesh ≈ **\(2k\)** new rows when adding the \((k+1)\)-th member.
- At ~**50** sisters (real SARK-scale clients) → ~**2 450** rows; codes invented independently per sender.
- Fixing that model after customers rely on it is painful.

### 1.2 Fleet shape that forces an explicit cohort

Same fleet (often same instance) mixes:

| Population | Need |
|------------|------|
| **Large sisterhood** | Everyone dials everyone with stable shared site codes |
| **Many tiny isolates** (≤5 phones, separate small businesses) | **No** cross-talk; co-tenancy must not imply reachability |

Implicit “all tenants with a code” is unsafe: allocating a code must not silently join the mesh. Membership is a **product cut**.

### 1.3 Misdial policy

| Case | Product |
|------|---------|
| Intra-cohort `45` vs `46` | Unavoidable — wrong sister possible; intention unknown |
| Inter-cohort / isolate | **Must fail closed** — no short-dial route |

---

## 2. Locked principles (2026-08-06)

1. **Routing prefix is a property of the destination tenant** (network routing identity), not a sender-private nickname.  
2. **Same digits everywhere** in the cohort: every member dials `{routing_prefix}{ext}` for that destination.  
3. **Cohort membership authorises** connection; projection installs only member→member rows.  
4. **Call path unchanged:** local row → `INVITE sip:{ext}@{tenant_fqdn}` → SBC miss→dispatcher (Rule 1).  
5. **HoR in catalog** (cohort + routing prefix); **node tables are projections**.  
6. **Rule 14 job** materialises / reconciles; Sanctum must not casually punch holes.  
7. **v1:** one cohort per tenant (no multi-cohort membership).  
8. **Current hand CRUD** = lab only until this ships; not the wild product.

---

## 3. Objects

### 3.1 Tenant — routing prefix (HoR)

**Path (locked):** `tenants/{shortuid}/meta.json` — extend `tenant-meta.v0`.

| Field | Notes |
|-------|--------|
| `routing_prefix` | Digits, fixed width per fleet policy (default **2**, allow 2–4) |
| `routing_prefix_width` | Optional; else fleet / cohort default |
| `dial_cohort_id` | Back-pointer to active cohort KSUID, or omit/null when isolate |

**Uniqueness:** unique among tenants that have a non-empty `routing_prefix` **within the fleet** (v1 simple). Isolates leave `routing_prefix` empty and `dial_cohort_id` unset.

**Allocation:** set when joining a cohort (required) or operator assigns before join. Changing a prefix → reconcile job rewrites all projections that target this tenant.

### 3.2 Dial cohort (HoR)

**Paths (locked 2026-08-06):**

| Object | S3 key |
|--------|--------|
| Cohort document | `catalog/dial-cohorts/{cohort_id}.json` |
| Fleet list rollup | `catalog/dial-cohort-index.json` |
| Materialise job | `catalog/dial-cohorts/{cohort_id}/jobs/{job_id}.json` |

Do **not** use a single org-meta blob or hang the cohort under one tenant prefix.

| Field | Notes |
|-------|--------|
| `id` | KSUID |
| `name` | Operator label (e.g. `Acme offices`) |
| `members[]` | Tenant shortuids (active) |
| `prefix_width` | Default for members missing width |
| `status` | `active` / `decommissioned` |
| `updated_at` / `updated_by` | Audit |

**v1 mesh:** full bidirectional among members.  
**v1 membership:** a tenant is in **at most one** active cohort.

### 3.3 Projected dial prefix (node)

Existing `dialalias` row on the **calling** tenant:

| Column / flag | Role |
|---------------|------|
| `pkey` | = destination’s `routing_prefix` |
| `target_fqdn` | destination tenant FQDN |
| `target_cluster` | optional shortuid pin |
| **`managed` / `source=cohort`** | Owned by Gatekeeper job — instance UI read-only (or delete blocked) |
| `cohort_id` | Optional pin for reconcile |

Manual (unmanaged) rows: **lab / break-glass only**. **Wild (locked 2026-08-06):** Sanctum **forbids** create/update/delete of dial prefixes that target another tenant when the fleet cohort feature is on (403; point operator to Fleet → Site Groups). Managed (`source=cohort`) rows are always instance **read-only**. Soft-warn is rejected.

---

## 4. What it looks like (operator UX)

### 4.1 Fleet → Site Groups (list)

```text
┌─ Fleet / Site Groups ──────────────────────────────────────┐
│  [ Create site group ]                                      │
│                                                            │
│  Name              Members   Prefixes ready   Updated      │
│  Acme offices         12          12/12        2h ago      │
│  North campus          4           4/4         yesterday   │
└────────────────────────────────────────────────────────────┘
```

Tiny MSP tenants do **not** appear here unless someone adds them (don’t).

### 4.2 Site Group detail

```text
┌─ Acme offices ────────────────────────────────────────────┐
│  Members (12)                    [ Add tenant ]            │
│                                                            │
│  Name          Shortuid   Home        Routing prefix       │
│  HQ            9wvvnb     Golden      81                   │
│  Warehouse     dhbm8x     Labtest-B   82                   │
│  Retail East   ……         Kildare     83                   │
│  …                                                         │
│                                                            │
│  Last sync job: completed · 2h ago · [ View job ]          │
│  [ Sync now ]  (reconcile projections)                     │
└────────────────────────────────────────────────────────────┘
```

**Add tenant** flow:

1. Pick tenant (not already in a cohort; preferably no accidental isolate).  
2. Require / assign **routing prefix** (validate fleet-unique + local collision hints).  
3. Confirm → create **Rule 14 job** → materialise.

**Remove tenant:** job deletes this tenant’s outbound peer rows **and** every other member’s row targeting this tenant.

### 4.3 Tenant card (Fleet → Tenants)

```text
┌─ Warehouse (dhbm8x) ──────────────────────────────────────┐
│  Name: Warehouse                                           │
│  FQDN:  dhbm8x.pbx3.com                                    │
│  Routing prefix:  82                                       │
│  Site group:       Acme offices                             │
│  Dial peers:      11 projected (managed)                   │
└────────────────────────────────────────────────────────────┘
```

### 4.4 Instance UI — Dial prefixes (member tenant)

```text
┌─ Dial prefixes ───────────────────────────────────────────┐
│  Managed by site group “Acme offices” — edit in Fleet       │
│                                                            │
│  Prefix   Destination              Source                  │
│  81       HQ (9wvvnb.pbx3.com)     Site group (read-only)   │
│  83       Retail East (…)          Site group (read-only)   │
│  …                                                         │
│                                                            │
│  (No “Add prefix” for managed mesh when feature on)        │
└────────────────────────────────────────────────────────────┘
```

Phone user mental model (unchanged): dial **`821000`** → Warehouse’s view of HQ is **`811000`** — same HQ code **81** everywhere.

### 4.5 Join cost (operator-visible)

Adding member \(k+1\) with routing prefix already set:

- Job writes **\(k\)** rows on the newcomer (one per existing peer).  
- Job writes **\(1\)** row on each of \(k\) existing members → **\(2k\)** row ops, **zero** per-site invent-a-code meetings.

---

## 5. Mechanical flow

```text
                    ┌─────────────────────────┐
                    │ Catalog HoR             │
                    │  tenant.routing_prefix  │
                    │  cohort.members[]       │
                    └───────────┬─────────────┘
                                │ Rule 14 job
                                ▼
         ┌──────────────────────────────────────────┐
         │ For each member M, for each peer P ≠ M:  │
         │   upsert dialalias on M’s home:          │
         │     pkey = P.routing_prefix              │
         │     target_fqdn = P.fqdn                 │
         │     managed = true                       │
         │ Remove stale managed rows not in set     │
         └───────────────────┬──────────────────────┘
                             │
                             ▼
         Phone @ M dials {P.routing_prefix}{ext}
                             │
                             ▼
         Existing PrefixDial / CAGI / SBC path
         INVITE ext@P.fqdn  (Rule 1 — no live GK)
```

**Inter-cohort block:** caller’s table has no row for foreign codes → congestion + hangup (existing deny).

---

## 6. Jobs (Rule 14)

| Trigger | Job |
|---------|-----|
| Create cohort / add member / remove member | Materialise / prune |
| Change `routing_prefix` on a member | Rewrite all projections targeting that tenant + row pkey on others |
| Tenant move (home instance change) | Re-project that tenant’s **outbound** managed rows on **new** home; prune old home if needed (move job hook or follow-on) |
| Tenant delete | Remove from cohort + prune peers (hook delete job) |
| Manual **Sync now** | Full reconcile for one cohort (incl. prune unmanaged on members) |

**Shape:** same family as tenant-delete / move — `pending → running → completed|failed`, retry, audit `updated_by`. Confirm gate only if we treat mass rewrite as destructive enough (v1: add/remove can run with ordinary fleet ability; optional typed confirm for “remove from site group”).

**Node API:** fleet-token endpoints to upsert/delete **managed** dialaliases, then **one genAst + reload per home per job step** (fail step if commit fails). Sanctum: no edit/delete of `managed=true` rows (403).

---

## 7. Safety checklist

- [ ] Isolates never get cohort membership by default.  
- [ ] Projection set = cohort members only.  
- [ ] Leave/remove prunes both directions.  
- [ ] Managed rows not editable on instance SPA.  
- [ ] Unknown prefix → deny (existing).  
- [ ] Prefix uniqueness validated at assign / join.  
- [ ] Local collision guidance (ext / OutRoute) — warn or block at assign.  
- [ ] v1 single cohort per tenant.  
- [ ] **Lab remedial:** on join / Sync, **remove unmanaged** cross-tenant `dialalias` rows for that tenant (or replace with managed). No dual source of truth. **Not** an SBC cleanup — prefixes are node-local only.

---

## 8. Relation to today’s short dial

| Layer | Today (lab) | Cohort release |
|-------|-------------|----------------|
| Call path | Done | **Reuse** |
| Operator source of truth | Sender invents prefix | Destination `routing_prefix` + cohort |
| Reverse | Manual second row | Automatic via mesh project |
| Wild ship | **No** | **Yes** (this) |

Legacy InterSARK migrate recipe ([`DIAL_PREFIX_LEGACY_MIGRATE.md`](DIAL_PREFIX_LEGACY_MIGRATE.md)) stays separate (SARK → prefixes). **No** product migrate from hand-invented wild meshes — that model is not shipping; nothing to convert. **Deferred:** any SARK→Site Group import/assist when a real migration customer needs it — not in C1–C6.

---

## 9. Implementation slices (suggested)

| Slice | Deliverable | Est. |
|-------|-------------|------|
| **C0** | Spec + §11 locks (`routing_prefix`, cohort JSON paths, dialalias `managed`, UI Site Group) | **done** 2026-08-06 |
| **C1** | Catalog + Gatekeeper CRUD (cohort, set prefix) — no materialise yet | ~1–2 d |
| **C2** | Node fleet managed dialalias upsert/delete + Sanctum guards | ~1–2 d |
| **C3** | Materialise job (add/remove/sync) + retry; **prune unmanaged** cross-tenant dialalias on touched members | ~3–5 d |
| **C4** | Fleet SPA Site Groups + tenant card fields; instance dial-prefix read-only for managed | ~2–3 d |
| **C5** | Lab: 3–4 tenants, two homes, isolate on same instance, join/leave, misdial inter-cohort; **prune unmanaged dialalias** on members (node SQLite — not SBC) | ~1–2 d |
| **C6** | Docs / MkDocs: short-dial interim (lab) vs Site Group release; no legacy migrate pointer | ~0.5 d |

**Thin vertical lab-green:** C1–C5 ≈ **1½–2½ weeks** focused.  
**Call-path / GenAst / SBC:** expect **no** change if projections are normal dialalias rows.

---

## 10. Non-goals (v1)

- Multi-cohort membership per tenant  
- Partial mesh / hub-and-spoke inside a cohort (full mesh only)  
- Live SBC or Gatekeeper lookup of routing prefix at dial time  
- Globally unique extensions (still rejected)  
- Auto-dial between isolates  
- Shipping hand-invented sender prefixes as the supported wild UX  

---

## 11. Open points (resolve in C0 accept / C1)

1. **Exact catalog paths** — **locked 2026-08-06:** `tenants/{suid}/meta.json` (`routing_prefix`, `dial_cohort_id`); `catalog/dial-cohorts/{id}.json`; `catalog/dial-cohort-index.json`; jobs `catalog/dial-cohorts/{id}/jobs/{job_id}.json`.  
2. **Fleet ability** — **locked 2026-08-06:** new ability **`fleet_dial_cohorts`** (cohort CRUD, routing prefix, materialise/sync). Do **not** fold into `fleet_instances`. Break-glass may hold both.  
3. **Unmanaged rows in wild** — **locked 2026-08-06:** **forbid** Sanctum create/update/delete of dial prefixes that target another tenant when cohort feature is on (403 → Fleet → Site Groups). Managed rows always instance read-only. Lab/break-glass escape only — not a soft warn.  
4. **Prefix width default** — **locked 2026-08-06:** fleet/cohort default **2** digits; allowed range **2–4**; **one `prefix_width` per cohort** (no mixed widths in a mesh). Ops upgrade to 3 when namespace tight — not silent per-tenant mix.  
5. **genAst trigger** — **locked 2026-08-06:** after all managed upserts/deletes for a home in a job step, **one** genAst + reload on that node; fail the step if commit fails (retryable). Never per-row genAst; never “rows only” success.  
6. **Name in UI** — **locked 2026-08-06:** product UI **Site Group** / **Site Groups** (nav, buttons, copy). Specs/APIs/S3 stay **dial cohort** (`dial-cohorts`, `fleet_dial_cohorts`). **Sisterhood** rejected (PC overtones). **Cohort** = tech term only (not primary UI). Not **cluster** (already means tenant in schema).

---

## 12. Acceptance (lab)

1. Cohort of 3 across ≥2 instances; each dials `{peer_prefix}{ext}` both ways with **identical** peer prefixes.  
4th tenant on same instance as one member, **not** in cohort: short dial to/from cohort **fails**.  
2. Add 4th member: job completes; \(2×3\) projections; dial works; no hand edits.  
3. Remove one member: both directions gone; isolate again.  
4. Change one routing prefix: peers dial new digits; old digits deny.  
5. Instance UI shows managed rows read-only.  
6. After join/Sync: **no leftover unmanaged** cross-tenant dialalias on members (hand lab rows gone or converted); dialplan matches managed set only.

---

**Visual companion:** Cursor canvas `dial-cohort-plan.canvas.tsx` (UX + flow).  
**Tracked:** [`TODO.md`](TODO.md).
