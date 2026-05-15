CREATE TABLE IF NOT EXISTS realtime_events (
    id          BIGSERIAL PRIMARY KEY,
    type        TEXT NOT NULL,
    device_id   TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    payload     JSONB NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS realtime_events_device_id_id_idx
    ON realtime_events (device_id, id DESC);

CREATE INDEX IF NOT EXISTS realtime_events_created_at_idx
    ON realtime_events (created_at);

