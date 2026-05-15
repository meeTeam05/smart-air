-- Migration 006: Store device secrets as SHA-256 hash at rest

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE devices
    ADD COLUMN secret_key_hash VARCHAR;

UPDATE devices
SET secret_key_hash = encode(digest(secret_key, 'sha256'), 'hex')
WHERE secret_key IS NOT NULL;

DO $$
BEGIN
    -- Pre-check for duplicate hashes before adding UNIQUE constraint
    IF EXISTS (
        SELECT 1
        FROM devices
        WHERE secret_key_hash IS NOT NULL
        GROUP BY secret_key_hash
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Migration 006 failed: duplicate secret_key_hash values detected. UNIQUE constraint cannot be applied.';
    END IF;

    IF EXISTS (SELECT 1 FROM devices WHERE secret_key_hash IS NULL) THEN
        RAISE EXCEPTION 'Migration 006 failed: found devices rows without secret_key_hash after backfill';
    END IF;
END $$;

ALTER TABLE devices
    ALTER COLUMN secret_key_hash SET NOT NULL;

ALTER TABLE devices
    ADD CONSTRAINT devices_secret_key_hash_key UNIQUE (secret_key_hash);

ALTER TABLE devices
    DROP COLUMN secret_key;

COMMIT;
