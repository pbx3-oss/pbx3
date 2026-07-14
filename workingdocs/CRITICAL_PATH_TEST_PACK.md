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
| Recordings list/stream contract (happy + 404) | **pbx3api** | **done** | `tests/Feature/RecordingHttpTest.php` (mocked index; Sanctum admin) |
| Fleet gatekeeper list API shape | **pbx3** gatekeeper | **done** | `tests/FleetListContractTest.php` + fixtures (no live S3) |
| SPA fleet token gate (login → storage → Authorization) | **pbx3spa** | **done** | `src/config/fleetGatekeeper.test.js` (Vitest) |

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
  tests/Unit/RecordingServicesTest.php

# pbx3spa
cd pbx3spa && npm test -- --run src/config/fleetGatekeeper.test.js
```

Repo-root `make test-critical` deferred until CI wiring is desired.

---

## Pack B — Lab recipes (keep documented; optional automation later)

| Recipe | Where | Status |
|--------|-------|--------|
| CAGI CFIM scenarios | **pbx3cagi** `make test` + `TEST_RECIPE.md` | **done** (golden-signed-off) |
| DB restore regression | **`DB_RESTORE_REGRESSION_CHECKLIST.md`** | **lab-only** |
| Phase A egress → SBC PSTN | Phase A notes / QUICK-START | **lab-only** |
| Peering inbound DID / alias | PEERING-PLAN + QUICK-START | **lab-only** |
| S8 rebuild drill | IMPLEMENTATION_PLAN / prior drill notes | **lab-only** |
| SBC install script smoke | `pbx3sbc` TESTING.md | **lab-only** |

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
