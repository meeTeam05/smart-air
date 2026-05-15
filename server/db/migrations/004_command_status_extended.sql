-- Migration 004: Extend commands status CHECK for relay follow-up fixes
-- Backfill legacy "failed" rows to canonical "error" before replacing constraint.

BEGIN;

UPDATE commands
SET status = 'error'
WHERE status = 'failed';

ALTER TABLE commands DROP CONSTRAINT IF EXISTS commands_status_check;
ALTER TABLE commands ADD CONSTRAINT commands_status_check
    CHECK (status IN ('pending', 'sent', 'done', 'error', 'timeout'));

COMMIT;
