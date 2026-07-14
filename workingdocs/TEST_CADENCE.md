# Test cadence (settled 2026-07-14)

**Status:** Settled product/engineering practice — not TDD dogma, not “save everything for pre-release.”

We will **not** rewrite history as test-first. Lab validation (SIP, EC2, golden drills) remains first-class proof for integration. What we lacked was a **regression net** so settled behaviour does not silently break.

## Cadence

| When | What |
|------|------|
| **Ongoing** | When you touch pure logic or an HTTP/API contract, leave a unit/contract test next to it in that PR. |
| **Before production-shaped** | Build and green the thin **critical-path pack** — enough that a merge can fail CI / a local `make`/`phpunit`/`pest` run. |
| **Release / RC gate** | **Run** that pack (plus existing lab recipes / checklists). Do not invent the pack under release pressure. |

## Investment order

1. **Pure PHP / TS helpers** (classifiers, auth stores, retention math, URL builders).  
2. **HTTP / API contracts** (gatekeeper auth, pbx3api recordings/snapshots, fleet list).  
3. **Documented lab recipes** (manual or semi-auto — already strong for CAGI / peering / rebuild).  
4. **UI E2E last** (Filament / SPA click-through) — high cost, weak SIP coverage.

## Explicit non-goals (for now)

- Full OpenSIPS / Asterisk media path in CI.  
- Filament browser E2E as a merge gate.  
- Back-filling tests for every historical feature before any new work.

## Where the inventory lives

→ **`CRITICAL_PATH_TEST_PACK.md`**

Existing anchors to keep (do not replace):

- **pbx3cagi** — `make test`, `TEST_HARNESS.md`, `TEST_RECIPE.md`  
- **DB restore** — `DB_RESTORE_REGRESSION_CHECKLIST.md`  
- **SBC install/lab** — `pbx3sbc/docs/guides/TESTING.md` and deployment checklists  

## Agent / PR habit

When landing logic that can fail offline:

1. Prefer a unit test over “verified on the box only.”  
2. Mark the corresponding row in **`CRITICAL_PATH_TEST_PACK.md`** when a pack item gains coverage.  
3. Do not open UI E2E tickets unless the critical-path pack is already mostly green.
