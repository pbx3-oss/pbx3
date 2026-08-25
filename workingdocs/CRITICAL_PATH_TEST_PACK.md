# Critical-path test pack (thin)

**Purpose:** Small regression net for “production-shaped” confidence. Complements lab drills; does not replace them.  
**Policy:** **`TEST_CADENCE.md`**.  
**Started:** 2026-07-14. **Pack A finished:** 2026-07-14.

Status legend: **done** · **partial** · **todo** · **lab-only** (keep as recipe, not CI yet)

---

## Pack A — Offline / CI-friendly (priority)

| Area | Repo | Status | Notes |
|------|------|--------|-------|
| Number routes prefix classify / hint | **pbx3sbc-admin** | **done** | `tests/Unit/DrRulePrefixOverlapTest.php` |
| Gatekeeper user + session token lifecycle | **pbx3** / gatekeeper | **done** | `tests/UserStoreAuthTest.php` |
| Gatekeeper break-glass env token still accepted | **pbx3** / gatekeeper | **done** | `tests/AuthBreakGlassTest.php` |
| Snapshot retention math / max-count | **pbx3api** | **done** | `SnapshotRetention::planPrune` + `tests/Unit/SnapshotRetentionTest.php` |
| ExtLenPolicy / seed length namespace | **pbx3api** | **done** | `tests/Unit/ExtLenPolicyTest.php` · `SeedOutboundRouteOnTenantCreateTest.php` |
| Tenant wipe-list / orphan integrity | **pbx3api** | **done** | `tests/Unit/TenantWipeIntegrityTest.php` |
| Recordings list/stream contract (happy + 404) | **pbx3api** | **done** | `tests/Feature/RecordingHttpTest.php` (mocked index; Sanctum admin) |
| Fleet gatekeeper list API shape | **pbx3** gatekeeper | **done** | `tests/FleetListContractTest.php` + fixtures (no live S3) |
| SPA fleet token gate (login → storage → Authorization) | **pbx3spa** | **done** | `src/config/fleetGatekeeper.test.js` (Vitest) |
| UFW allow-list bootstrap (fleet vs solo Sources) | **pbx3** | **done** | `pbx3-1/opt/pbx3/scripts/tests/ufw-apply-baseline-test.sh` |
| Firewall allow-list `from`/port validation | **pbx3api** | **done** | `tests/Unit/FirewallAllowRuleTest.php` |
| Firewall SPA F11 admin-port warn helpers | **pbx3spa** | **done** | `src/utils/firewallAdminWarn.test.js` |

**How to run Pack A:**

```bash
# pbx3sbc-admin
cd pbx3sbc-admin && php vendor/bin/phpunit tests/Unit/DrRulePrefixOverlapTest.php

# gatekeeper
cd pbx3/pbx3-directory/gatekeeper
composer install   # require-dev phpunit; lock gitignored historically
composer test

# pbx3api (needs a local .env — copy .env.example and set APP_KEY if missing)
cd pbx3api && php vendor/bin/pest \
  tests/Unit/SnapshotRetentionTest.php \
  tests/Feature/RecordingHttpTest.php \
  tests/Unit/RecordingServicesTest.php \
  tests/Unit/FirewallAllowRuleTest.php

# pbx3spa
cd pbx3spa && npm test -- --run src/config/fleetGatekeeper.test.js src/utils/firewallAdminWarn.test.js

# pbx3 UFW bootstrap (no root)
bash pbx3/pbx3-1/opt/pbx3/scripts/tests/ufw-apply-baseline-test.sh
```

Repo-root `make test-critical` deferred until CI wiring is desired.

---

## Pack B — Lab recipes (keep documented; optional automation later)

| Recipe | Where | Status |
|--------|-------|--------|
| CAGI CFIM scenarios | **pbx3cagi** `make test` + `TEST_RECIPE.md` | **done** (golden-signed-off) |
| Call / SIP pathway + load strategy | **`CALL_TEST_STRATEGY.md`** · recipes **[sipplab](https://github.com/aelintra/sipplabs)** | **in progress** (`in-open-ext` green 2026-07-27; grow L1 matrix) |
| DB restore regression | **`DB_RESTORE_REGRESSION_CHECKLIST.md`** | **lab-only** |
| Phase A egress → SBC PSTN | Phase A notes / QUICK-START | **lab-only** |
| Peering inbound DID / alias | PEERING-PLAN + QUICK-START | **lab-only** |
| S8 rebuild drill | IMPLEMENTATION_PLAN / prior drill notes | **lab-only** |
| SBC install script smoke | `pbx3sbc` TESTING.md | **lab-only** |
| #4b wipe + #4c ext_len tip lab | **`TENANT_WIPE_AND_EXT_LEN_LAB.md`** | **todo** (run after tip-deploy) |

---

## Pack C — Deferred (after A is mostly green)

- Filament Number routes / Peers browser flows  
- SPA Playwright-style E2E for Fleet shell  
- OpenSIPS `dr_reload` / dialog MI integration tests  

---

## Definition of “pack green enough for production-shaped”

- Pack A: **every row either done or consciously deferred with a one-line reason** — **met 2026-07-14**  
- Pack B: CAGI green; at least one recent sign-off of DB restore checklist on a lab box  
- Pack C: not required  

Release / RC: re-run Pack A + note Pack B dates in the release notes / handoff — do not invent new suites in that window.
