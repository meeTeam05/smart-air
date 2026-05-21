import { deleteDeviceUser } from './emqx.js';

const EMQX_CLEANUP_RETRY_KEY = 'emqx:cleanup:retry';
const CLEANUP_KIND_DEVICE_USER = 'emqx_device_user';
const MAX_LAST_ERROR_LENGTH = 1000;

function cleanupRetryDelaySeconds(attempts) {
    return Math.min(3600, Math.max(30, 30 * (2 ** Math.min(attempts, 6))));
}

function cleanErrorMessage(err) {
    return (err?.message || String(err)).slice(0, MAX_LAST_ERROR_LENGTH);
}

export async function enqueueDeviceCleanupJob(fastify, deviceId, client = fastify.db) {
    await client.query(
        `INSERT INTO external_cleanup_jobs (kind, resource_id)
         VALUES ($1, $2)
         ON CONFLICT (kind, resource_id) DO UPDATE
            SET updated_at = NOW()`,
        [CLEANUP_KIND_DEVICE_USER, deviceId]
    );
}

export async function scheduleDeviceCleanupJob(fastify, deviceId, delaySeconds) {
    await fastify.db.query(
        `INSERT INTO external_cleanup_jobs (kind, resource_id, next_attempt_at)
         VALUES ($1, $2, NOW() + ($3 * INTERVAL '1 second'))
         ON CONFLICT (kind, resource_id) DO UPDATE
            SET next_attempt_at = EXCLUDED.next_attempt_at,
                updated_at = NOW()`,
        [CLEANUP_KIND_DEVICE_USER, deviceId, delaySeconds]
    );
}

export async function clearDeviceCleanupJob(fastify, deviceId, client = fastify.db) {
    await client.query(
        'DELETE FROM external_cleanup_jobs WHERE kind = $1 AND resource_id = $2',
        [CLEANUP_KIND_DEVICE_USER, deviceId]
    );
}

async function failDeviceCleanupJob(fastify, deviceId, err) {
    await fastify.db.query(
        `INSERT INTO external_cleanup_jobs
            (kind, resource_id, attempts, last_error, next_attempt_at, updated_at)
         VALUES ($1, $2, 1, $3, NOW() + ($4 * INTERVAL '1 second'), NOW())
         ON CONFLICT (kind, resource_id) DO UPDATE
            SET attempts = external_cleanup_jobs.attempts + 1,
                last_error = EXCLUDED.last_error,
                next_attempt_at = NOW() + (
                    LEAST(3600, GREATEST(30, 30 * POWER(2, LEAST(external_cleanup_jobs.attempts + 1, 6))))
                    * INTERVAL '1 second'
                ),
                updated_at = NOW()`,
        [
            CLEANUP_KIND_DEVICE_USER,
            deviceId,
            cleanErrorMessage(err),
            cleanupRetryDelaySeconds(0),
        ]
    );
}

export async function listDueDeviceCleanupJobs(fastify, limit = 100) {
    const { rows } = await fastify.db.query(
        `SELECT resource_id
         FROM external_cleanup_jobs
         WHERE kind = $1 AND next_attempt_at <= NOW()
         ORDER BY next_attempt_at ASC, created_at ASC
         LIMIT $2`,
        [CLEANUP_KIND_DEVICE_USER, limit]
    );
    return rows.map((row) => row.resource_id);
}

export async function drainLegacyCleanupRetrySet(fastify) {
    const deviceIds = await fastify.redis.smembers(EMQX_CLEANUP_RETRY_KEY);
    for (const deviceId of deviceIds) {
        await enqueueDeviceCleanupJob(fastify, deviceId);
        await fastify.redis.srem(EMQX_CLEANUP_RETRY_KEY, deviceId);
    }
    if (deviceIds.length > 0) {
        fastify.log.info({ count: deviceIds.length }, 'drained legacy EMQX cleanup retry set into DB jobs');
    }
}

export async function cleanupDeletedDevice(fastify, deviceId) {
    const { rows: deviceRows } = await fastify.db.query(
        'SELECT 1 FROM devices WHERE id = $1 LIMIT 1',
        [deviceId]
    );
    if (deviceRows.length > 0) {
        await clearDeviceCleanupJob(fastify, deviceId);
        return;
    }

    try {
        await fastify.redis.del(
            `shadow:${deviceId}`,
            `pending_cmds:${deviceId}`,
            `pending_cmds_lock:${deviceId}`,
            `announce:${deviceId}`,
            `ota_progress:${deviceId}`
        );
    } catch (err) {
        fastify.log.warn({ err, deviceId }, 'Redis device cleanup failed; continuing with EMQX cleanup');
    }

    try {
        await deleteDeviceUser(deviceId);
        try {
            await clearDeviceCleanupJob(fastify, deviceId);
        } catch (err) {
            fastify.log.error({ err, deviceId }, 'failed to complete EMQX cleanup DB job after successful delete');
        }
    } catch (err) {
        fastify.log.warn({ err, deviceId }, 'EMQX user deletion failed; queued for retry');
        try {
            await failDeviceCleanupJob(fastify, deviceId, err);
        } catch (jobErr) {
            fastify.log.error({ err: jobErr, deviceId }, 'failed to persist EMQX cleanup retry job');
        }
    }
}
