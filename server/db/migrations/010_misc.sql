-- Migration 010: misc schema improvements.
--   - error_message column on commands
--   - unique constraint on fcm_tokens.token
--   - CITEXT for case-insensitive email uniqueness

BEGIN;

ALTER TABLE commands
    ADD COLUMN IF NOT EXISTS error_message VARCHAR;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'fcm_tokens_token_unique'
    ) THEN
        ALTER TABLE fcm_tokens
            ADD CONSTRAINT fcm_tokens_token_unique UNIQUE(token);
    END IF;
EXCEPTION
    WHEN undefined_table THEN
        NULL; -- fcm_tokens table may not exist yet; skip silently
END $$;

CREATE EXTENSION IF NOT EXISTS citext;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'email'
          AND data_type <> 'USER-DEFINED'
    ) THEN
        ALTER TABLE users ALTER COLUMN email TYPE citext;
    END IF;
END $$;

COMMIT;
