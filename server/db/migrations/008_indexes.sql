-- Migration 008: hot-path indexes for user-scoped joins.

BEGIN;

CREATE INDEX IF NOT EXISTS home_members_user_id_idx
    ON home_members (user_id);

CREATE INDEX IF NOT EXISTS devices_home_id_idx
    ON devices (home_id);

CREATE INDEX IF NOT EXISTS refresh_tokens_user_id_idx
    ON refresh_tokens (user_id);

COMMIT;
