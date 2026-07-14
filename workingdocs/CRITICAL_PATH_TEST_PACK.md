# Critical-path test pack (thin)

**Purpose:** Small regression net for “production-shaped” confidence. Complements lab drills; does not replace them.  
**Policy:** **`TEST_CADENCE.md`**.  
**Started:** 2026-07-14.

Status legend: **done** · **partial** · **todo** · **lab-only** (keep as recipe, not CI yet)

---

## Pack A — Offline / CI-friendly (priority)

| Area | Repo | Status | Notes |
|------|------|--------|-------|
| Number routes prefix classify / hint | **pbx3sbc-admin** | **done** | `tests/Unit/DrRulePrefixOverlapTest.php` (`phpunit`) |
| Gatekeeper user + session token lifecycle | **pbx3** / gatekeeper | **partial** | `pbx3-directory/gatekeeper/tests/UserStoreAuthTest.php` — create, login, me, revoke, bad password |
| Gatekeeper break-glass env token still accepted | **pbx3** / gatekeeper | **todo** | Keep behaviour; do not remove when polishing login |
| Snapshot retention math / max-count | **pbx3api** | **todo** | Pure logic around `SnapshotRetention` |
| Recordings list/stream contract (happy + 404) | **pbx3api** | **partial** | `tests/Unit/RecordingServicesTest.php` exists — extend toward HTTP contract |
| Fleet gatekeeper list API shape | **pbx3** gatekeeper | **todo** | Nodes/SBC JSON used by SPA Fleet |
| SPA fleet token gate (login → storage → Authorization) | **pbx3spa** | **todo** | Vitest unit of helpers / store; not full browser E2E |

**How to run (Pack A, as available):**

```bash
# pbx3sbc-admin
cd pbx3sbc-admin && php vendor/bin/phpunit tests/Unit/DrRulePrefixOverlapTest.php

# gatekeeper (no full app bootstrap)
cd pbx3/pbx3-directory/gatekeeper
composer install   # include require-dev (phpunit); lock is gitignored historically
composer test      # or: php vendor/bin/phpunit

# pbx3api
cd pbx3api && php vendor/bin/pest   # or phpunit per project default
```

Add a single repo-root or meta `make test-critical` **after** each row above has a stable command — not before.

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

- Pack A: **every row either done or consciously deferred with a one-line reason**  
- Pack B: CAGI green; at least one recent sign-off of DB restore checklist on a lab box  
- Pack C: not required  

Release / RC: re-run Pack A + note Pack B dates in the release notes / handoff — do not invent new suites in that window.
