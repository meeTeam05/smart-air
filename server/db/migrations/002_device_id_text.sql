ALTER TABLE device_shadows DROP CONSTRAINT IF EXISTS device_shadows_device_id_fkey;
ALTER TABLE commands DROP CONSTRAINT IF EXISTS commands_device_id_fkey;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'devices'
          AND column_name = 'id'
          AND data_type = 'uuid'
    ) THEN
        ALTER TABLE devices ALTER COLUMN id DROP DEFAULT;
        ALTER TABLE devices ALTER COLUMN id TYPE TEXT USING id::text;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'device_shadows'
          AND column_name = 'device_id'
          AND data_type = 'uuid'
    ) THEN
        ALTER TABLE device_shadows ALTER COLUMN device_id TYPE TEXT USING device_id::text;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'commands'
          AND column_name = 'device_id'
          AND data_type = 'uuid'
    ) THEN
        ALTER TABLE commands ALTER COLUMN device_id TYPE TEXT USING device_id::text;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'telemetry'
          AND column_name = 'device_id'
          AND data_type = 'uuid'
    ) THEN
        ALTER TABLE telemetry ALTER COLUMN device_id TYPE TEXT USING device_id::text;
    END IF;
END $$;

ALTER TABLE device_shadows
    ADD CONSTRAINT device_shadows_device_id_fkey
        FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE;

ALTER TABLE commands
    ADD CONSTRAINT commands_device_id_fkey
        FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE;
