-- Migration 011: durable refresh-token replay markers and external cleanup jobs.

BEGIN;

CREATE TABLE IF NOT EXISTS refresh_token_reuse_markers (
    token_hash  VARCHAR PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at  TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS refresh_token_reuse_markers_expires_at_idx
    ON refresh_token_reuse_markers (expires_at);

CREATE TABLE IF NOT EXISTS external_cleanup_jobs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kind            VARCHAR NOT NULL,
    resource_id     TEXT NOT NULL,
    attempts        INTEGER NOT NULL DEFAULT 0,
    last_error      TEXT,
    next_attempt_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (kind, resource_id)
);

CREATE INDEX IF NOT EXISTS external_cleanup_jobs_due_idx
    ON external_cleanup_jobs (kind, next_attempt_at);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'external_cleanup_jobs_kind_check'
    ) THEN
        ALTER TABLE external_cleanup_jobs
            ADD CONSTRAINT external_cleanup_jobs_kind_check
                CHECK (kind IN ('emqx_device_user'));
    END IF;
END $$;

COMMIT;
