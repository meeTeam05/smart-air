ALTER TABLE realtime_events
    ADD COLUMN IF NOT EXISTS idempotency_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS realtime_events_idempotency_key_idx
    ON realtime_events (idempotency_key)
    WHERE idempotency_key IS NOT NULL;
