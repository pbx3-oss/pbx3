# Side Project: SQLite CHECK Constraints for Canonical Data

## Goal
Add SQLite `NOT NULL` + `CHECK` constraints (and, if needed, small schema tweaks) so that migrated data always uses **canonical literal values** expected by `pbx3cagi` at runtime.

This is prepared as a *separate side project* with the expectation that after it’s done, we can re-review `pbx3cagi` under the assumption that DB data is compliant.

## Key observations from our discussion
1. `pbx3cagi` frequently treats specific strings as **state/sentinels** (not “friendly names” for NULL).
   - Example pattern: `if (strcmp(rescols[i], "None")) { ... }`
   - Here, `"None"` is an explicit “disabled/absent” state; everything else is treated as “present/enabled”.

2. `pbx3cagi` uses `sqlQuery()` to read SQLite rows into `rescols[]`.
   - In `sqlQuery()`, when SQLite returns SQL `NULL`, it is stored into `rescols[i]` as an **empty string** (`""`), not the literal `"None"`.
   - Therefore, if a migrated/loaded row leaves sentinel columns as SQL `NULL`, runtime logic may misinterpret the state because `"" != "None"`.

3. The `cluster` table schema (from `sqlite_create_tenant.sql`) provides many `DEFAULT` values but does **not** generally enforce allowed domains via `CHECK` constraints.
   - Many relevant columns are plain `TEXT` and can still be `NULL` in legacy/migration scenarios unless the loader normalizes them.

4. We agreed this should be handled primarily by **data canonicalization at migration/load time**:
   - Since AGI is read-only, runtime safety can be achieved by ensuring the *loaded* DB contains only canonical literals.

## Why this is a DB/data problem (not an AGI write problem)
- The correctness hinges on exact string comparisons in `pbx3cagi`.
- If the DB allows `NULL` or non-canonical spellings, `sqlQuery()`’s `NULL -> ""` mapping can break the state machine.
- So the DB should be constrained so that the only values that can exist are the ones `pbx3cagi` expects.

## What SQLite supports
SQLite supports:
- `NOT NULL`
- `CHECK (col IN (...))` (and `... OR col IS NULL` if you intentionally keep NULL)

If the migration loader creates a *brand new DB*, enforcing constraints is safe because the loader can be made to emit only canonical values.

## Proposed “side project” process (separate exercise)
1. Identify the columns where `pbx3cagi` uses literal sentinel comparisons:
   - state enums like `"enabled"` / `"YES"`
   - sentinel absence like `"None"` (and any other explicit sentinel strings used)
2. Update the migration/SQL loader so it always writes canonical literals:
   - e.g. write `"None"` (literal) instead of SQL `NULL` for “no override”
   - e.g. write `"enabled"/"disabled"` consistently for `cfwd_*` and `allow_hash_xfer`
3. Apply schema constraints to the new DB:
   - add `NOT NULL` where empty string is not valid
   - add `CHECK` constraints enumerating allowed literals
4. Validate by running the usual load pipeline and ensuring no constraint violations.

## After constraints: re-review `pbx3cagi`
With canonical data guaranteed by the DB:
- we can simplify/strengthen `pbx3cagi` assumptions (remove defensive handling where safe)
- and re-run the specific call flows that were previously risky due to NULL/canonicalization issues.

## Industry axiom adopted
We follow the standard SQL semantics axiom: **SQLite `NULL` is “unknown” (tristate logic), not automatically `false`**.

So the recommendation is:
- Do not rely on “NULL behaves like 0/false” in SQL.
- Instead, enforce canonical values at the DB boundary so that `pbx3cagi` inputs never receive `NULL` (for constrained boolean/state-ish columns) and never receive the wrong sentinel spelling.

