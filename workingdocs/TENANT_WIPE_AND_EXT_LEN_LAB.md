# Lab procedures — #4b tenant wipe integrity + #4c ext_len

**Status:** Procedures written **2026-08-10**. **Lab green on golden** same day (same-home prune §1.4; §2.1–2.5; disposable LabWipeA/B wiped).  
**Specs:** [`TENANT_DELETE_DATA_INTEGRITY.md`](TENANT_DELETE_DATA_INTEGRITY.md) (T1–T5) · [`TENANT_SHORT_DIAL_REQUIREMENTS.md`](TENANT_SHORT_DIAL_REQUIREMENTS.md) §3.8 / Q15 · UK seed [`SEED_OUTBOUND_ON_TENANT_CREATE.md`](SEED_OUTBOUND_ON_TENANT_CREATE.md) L7a.  
**Ops tips/hosts:** `~/GiT/pbx3-ops/TODO_OPS.md` (do not put SHAs here).

Use a **disposable** lab tenant (or Site Group member you are willing to wipe). Do **not** delete customer / golden demo tenants.

---

## 0. Preconditions

| Check | Expect |
|-------|--------|
| Tip includes #4b + #4c | pbx3api + gatekeeper + SPA tip; pbx3 GenAst; pbx3cagi with PrefixDial length check |
| SPA | `npm run dev` or tip Pages against golden |
| Fleet login | Gatekeeper token; can open Fleet → Tenants |
| Unit (optional, laptop) | `cd pbx3api && ./vendor/bin/pest tests/Unit/ExtLenPolicyTest.php tests/Unit/TenantWipeIntegrityTest.php tests/Unit/SeedOutboundRouteOnTenantCreateTest.php` |

**Pass gate for this doc:** all steps in §1–§2 green (or explicit skip noted). §3 is regression-only after Commit.

---

## 1. #4b — Tenant delete integrity (T1–T5)

### 1.1 Wipe-list / orphan tools (T4 / T5)

On a home node (golden is fine — read-only audits):

```bash
cd /opt/pbx3api   # or tip path
sudo -u www-data php artisan pbx3:tenant-wipe-list-check
sudo -u www-data php artisan pbx3:tenant-orphan-audit
```

| Expect |
|--------|
| Wipe-list check **exits 0** (list ⊇ tenant-schema `cluster` tables) |
| Orphan audit **0 orphans** on a clean lab DB (note any pre-existing junk; do not “fix” by deleting production data) |

JSON forms: add `--json` if scripting.

### 1.2 Preflight counts (T1)

1. Fleet → Tenants → pick a **disposable** tenant with known children (at least one extension or OutRoute).  
2. Start Delete; confirm UI shows **non-zero wipe counts** for tables that have rows (e.g. `ipphone`, `route`).  
3. Optional API (Gatekeeper→node): `GET …/fleet/tenants/{shortuid}/wipe-preflight` returns per-table counts.

| Expect |
|--------|
| Confirm screen lists counts before wipe |
| Cancel still works (no wipe) |

### 1.3 Mesh prune + wipe (T2 / T3) — preferred path

**Setup (same-home or two-home Site Group):**

1. Two tenants **A** (victim) and **B** (peer) in one Site Group (or hand dialalias on B targeting A’s FQDN).  
2. On B’s home DB, confirm a dialalias row with `target_fqdn` = A’s tenant FQDN.  
3. Fleet Delete **A** with confirm.

| Phase / check | Expect |
|---------------|--------|
| Job phase `pruning_mesh` | Completes or **warns** if a peer home unreachable (I7) |
| After success | A’s `cluster` + Class A children gone on A’s home |
| Peer B | Dialalias rows **targeting A** gone on reachable homes |
| Unreachable peer | Job warned; when home returns: Delete **retry** and/or Site Group **Sync now** clears remainder |
| Park | No leftover park AstDB / instances for A (parity with Sanctum) |

**Verify on node (A’s home):**

```bash
sqlite3 /opt/pbx3/db/sqlite.db "SELECT pkey FROM cluster WHERE shortuid='VICTIM_SHORTUID';"
# expect empty
sudo -u www-data php artisan pbx3:tenant-orphan-audit
# expect 0 new orphans from this wipe
```

**Verify on peer home (B):**

```bash
sqlite3 /opt/pbx3/db/sqlite.db \
  "SELECT pkey,cluster,target_fqdn FROM dialalias WHERE lower(target_fqdn)='victim.fqdn.example';"
# expect empty
```

### 1.4 Same-home sibling prune only (if no Site Group)

If A and B share one home without cohort: wipe A via Fleet (or Sanctum solo if not fleet-locked). Sibling dialaliases on B targeting A must still disappear (`destroyTenantData` same-home prune).

### 1.5 Acceptance map (#4b)

| Criterion ([§5](TENANT_DELETE_DATA_INTEGRITY.md)) | Lab proof |
|--------------------------------------------------|-----------|
| Wipe removes cluster + listed children | §1.3 DB check |
| Peer dialaliases targeting victim gone on reachable homes | §1.3 / §1.4 |
| Park cleanup | §1.3 |
| Orphan audit 0 after delete lab | §1.3 |
| Wipe-list drift fails check | §1.1 (+ CI unit) |

---

## 2. #4c — Enforce `ext_len` (digit-plan length namespaces)

Use a tenant with `ext_len = 3` (default) unless noted. API via SPA or curl+Sanctum.

### 2.1 Extension pkey length

| Step | Action | Expect |
|------|--------|--------|
| OK | Create extension `100` on `ext_len=3` tenant | **201** |
| Reject | Create extension `1000` (4 digits) | **422** `pkey` — exactly 3 digits |
| Reject | Create `10a` | **422** |
| Change `ext_len` | Set tenant `ext_len=4` while `100` exists | **422** `ext_len` (existing ext wrong length) |
| Change OK | Empty tenant or all exts already 4 digits → `ext_len=4` | **200**; new ext must be 4 digits |

SPA: Tenant edit shows **Extension length**; Create Extension validates against selected tenant’s length.

### 2.2 OutRoute dialplan min match `> ext_len`

| Step | Action | Expect |
|------|--------|--------|
| Reject | Save route dialplan `_0.` or `_9.` or `_XX` | **422** `dialplan` (min &lt; 3) |
| OK | `_XXX` / `_1XX` / `999 112` / `_00.` | **200** (SARK floor ≥ 3; any `ext_len`) |
| OK | `_0XXX. _00XX.` (UK seed) | **200** |
| OK | `_9XXXX` | **200** |

Instance Globals: saving `default_outbound_dialplan` = `_0. _00.` → **422**; `_0XXX. _00XX.` → **200**.

### 2.3 Seed on tenant create

| Step | Expect |
|------|--------|
| New tenant (solo path) with globals = UK seed | `MainOut` dialplan = `_0XXX. _00XX.` |
| Globals still `_0. _00.` (unmigrated) | Seed **skips** (log warning); no bad MainOut |

Apply script on node (optional):  
`sudo /opt/pbx3/scripts/apply-sqlite-add-default-outbound-dialplan.sh`  
migrates empty / exact `_0. _00.` → `_0XXX. _00XX.`.

### 2.4 Dial prefix length namespace

| Step | Action | Expect |
|------|--------|--------|
| OK | Prefix `81` → dest with `ext_len=3` on caller `ext_len=3` | Save OK (5 > 3) |
| Reject | Impossible combo (e.g. caller `ext_len=5`, prefix `12`, dest `ext_len=3` → total 5 ≰ 5) | **422** on dialalias / managed upsert |

### 2.5 GenAst PrefixDial pattern (after Commit)

On calling tenant home, after Commit:

```bash
grep -n 'PrefixDial' /etc/asterisk/extensions_pbx3*.conf
# or the generated context include for that tenant
```

| Expect |
|--------|
| Pattern like `_81XXX` for dest `ext_len=3` — **not** `_81X.` |
| No emit if prefix+dest_len ≤ caller `ext_len` |

### 2.6 CAGI / dial (optional, after tip + Commit)

| Step | Expect |
|------|--------|
| Dial `{prefix}{ext}` correct length | Completes as today (site-dial / desk) |
| Wrong length (if somehow in dialplan) | Congestion + hangup |

Unit coverage already locks policy math; this step is tip regression only.

### 2.7 Acceptance map (#4c)

| Lock | Lab proof |
|------|-----------|
| Ext pkeys = `ext_len` digits | §2.1 |
| OutRoute / globals min `> ext_len` | §2.2 |
| UK seed L7a-safe | §2.3 |
| Short-dial length namespace | §2.4 |
| GenAst fixed remainder | §2.5 |
| CAGI wrong-length deny | §2.6 (optional) |

---

## 3. Quick regression after tip (combined)

Keep short — run when rolling golden:

1. SPA login + Fleet tenants list.  
2. §1.1 wipe-list + orphan on golden.  
3. §2.1 reject one bad extension; §2.2 reject `_9.` once.  
4. Existing dial / DID smoke if time (**`PRE_RELEASE_SAFETY_DEBT.md`** golden smoke shape).

**Lab note:** Tenants still holding MainOut `_0. _00.` keep dialling until edited; next OutRoute save will 422 until patterns are lengthened. Prefer migrate globals + edit MainOut to `_0XXX. _00XX.` on lab nodes when tip-deploying #4c.

---

## 4. Explicit non-goals (this procedure)

- T6 DID policy / T7 Class B / T8 SQLite FK.  
- Full Site Group C0–C6 re-proof (already lab green).  
- Deleting golden demo tenants.  
- Package version bumps (schedule separately in `TODO_OPS`).
