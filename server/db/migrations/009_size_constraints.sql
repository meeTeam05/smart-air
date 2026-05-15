-- Migration 009: JSONB payload size caps to prevent unbounded row growth.

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'device_shadows_reported_size_check'
    ) THEN
        ALTER TABLE device_shadows
            ADD CONSTRAINT device_shadows_reported_size_check
                CHECK (pg_column_size(reported) < 16384);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'device_shadows_desired_size_check'
    ) THEN
        ALTER TABLE device_shadows
            ADD CONSTRAINT device_shadows_desired_size_check
                CHECK (pg_column_size(desired) < 4096);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'commands_payload_size_check'
    ) THEN
        ALTER TABLE commands
            ADD CONSTRAINT commands_payload_size_check
                CHECK (pg_column_size(payload) < 4096);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'telemetry_payload_size_check'
    ) THEN
        ALTER TABLE telemetry
            ADD CONSTRAINT telemetry_payload_size_check
                CHECK (pg_column_size(payload) < 4096) NOT VALID;
    END IF;
END $$;

COMMIT;
