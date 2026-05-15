-- Migration 007: Telemetry referential integrity hardening
-- Strategy:
--   1) Remove existing orphan telemetry rows so FK creation is deterministic on real snapshots.
--   2) Enforce telemetry.device_id -> devices.id with ON DELETE CASCADE to prevent future orphans.
-- Operational caveat: orphan cleanup and FK validation can be expensive on large hypertables;
-- run during a low-traffic maintenance window for production-scale datasets.

BEGIN;

-- Support FK checks and cascade deletes by device_id (idempotent guard).
CREATE INDEX IF NOT EXISTS telemetry_device_id_idx
    ON telemetry (device_id);

DO $$
DECLARE
    orphan_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO orphan_count
    FROM telemetry t
    WHERE NOT EXISTS (
        SELECT 1
        FROM devices d
        WHERE d.id = t.device_id
    );

    IF orphan_count > 0 THEN
        RAISE NOTICE 'Migration 007: Deleting % orphan telemetry rows', orphan_count;
        
        DELETE FROM telemetry t
        WHERE NOT EXISTS (
            SELECT 1
            FROM devices d
            WHERE d.id = t.device_id
        );
    END IF;
END $$;

-- Add FK only when absent so re-runs remain safe in migration-runner recovery scenarios.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'telemetry_device_id_fkey'
          AND conrelid = 'telemetry'::regclass
    ) THEN
        ALTER TABLE telemetry
            ADD CONSTRAINT telemetry_device_id_fkey
                FOREIGN KEY (device_id)
                REFERENCES devices(id)
                ON DELETE CASCADE;
    END IF;
END $$;

COMMIT;
