ALTER TABLE telemetry
    ADD COLUMN IF NOT EXISTS mqtt_message_id INTEGER;

CREATE UNIQUE INDEX IF NOT EXISTS telemetry_device_ts_message_id_uidx
    ON telemetry (device_id, ts, mqtt_message_id)
    WHERE mqtt_message_id IS NOT NULL;
