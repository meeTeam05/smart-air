-- Migration 012: enqueue durable EMQX cleanup jobs for every deleted device.

BEGIN;

CREATE OR REPLACE FUNCTION enqueue_emqx_device_cleanup_job()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO external_cleanup_jobs (kind, resource_id)
    VALUES ('emqx_device_user', OLD.id)
    ON CONFLICT (kind, resource_id) DO UPDATE
        SET updated_at = NOW();

    RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS devices_enqueue_emqx_cleanup ON devices;

CREATE TRIGGER devices_enqueue_emqx_cleanup
AFTER DELETE ON devices
FOR EACH ROW
EXECUTE FUNCTION enqueue_emqx_device_cleanup_job();

COMMIT;
