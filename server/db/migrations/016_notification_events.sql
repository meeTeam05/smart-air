CREATE TABLE IF NOT EXISTS notification_events (
    source_event_id BIGINT PRIMARY KEY REFERENCES realtime_events(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    device_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    device_name_snapshot VARCHAR NOT NULL,
    title VARCHAR NOT NULL,
    body VARCHAR NOT NULL,
    severity TEXT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS notification_events_device_id_event_idx
    ON notification_events (device_id, source_event_id DESC);

CREATE INDEX IF NOT EXISTS notification_events_occurred_at_idx
    ON notification_events (occurred_at DESC);
