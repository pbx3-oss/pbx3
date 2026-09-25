-- queue.caller_timeout: Caller Max Wait (Queue() dialplan 5th arg).
-- NULL/0 = unlimited (current behaviour). Agent ring stays queue.timeout.
-- SQLite has no ADD COLUMN IF NOT EXISTS — apply script uses PRAGMA.

ALTER TABLE queue ADD COLUMN caller_timeout INTEGER;
