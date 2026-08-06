-- Dial cohort C2: managed dialalias projections (source + cohort_id).
-- Greenfield: columns included in sqlite_create_tenant / sqlite_add_dialalias_table.
-- Existing DBs: apply-sqlite-add-dialalias-cohort.sh (idempotent ALTER).

BEGIN;

-- No-op placeholder when applied via apply script (ALTER ADD COLUMN).
-- Documented columns:
--   source TEXT DEFAULT 'manual'   -- manual | cohort
--   cohort_id TEXT                 -- Gatekeeper dial cohort id when source=cohort

COMMIT;
