import {
    cleanupDeletedDevice,
    drainLegacyCleanupRetrySet,
    listDueDeviceCleanupJobs,
} from '../services/device-cleanup.js';

const DEFAULT_RETRY_INTERVAL_MS = 300_000;
const DEFAULT_RETRY_LIMIT = 100;

export async function runEmqxCleanupRetry(fastify, retryLimit = DEFAULT_RETRY_LIMIT) {
    try {
        await drainLegacyCleanupRetrySet(fastify);
    } catch (err) {
        fastify.log.warn({ err }, 'legacy EMQX cleanup retry drain failed; continuing with DB jobs');
    }

    try {
        const deviceIds = await listDueDeviceCleanupJobs(fastify, retryLimit);
        for (const deviceId of deviceIds) {
            await cleanupDeletedDevice(fastify, deviceId);
        }
    } catch (err) {
        fastify.log.error({ err }, 'EMQX cleanup retry job failed');
    }
}

export function registerEmqxCleanupRetryJob(fastify, options = {}) {
    const retryIntervalMs = options.retryIntervalMs ?? DEFAULT_RETRY_INTERVAL_MS;
    const retryLimit = options.retryLimit ?? DEFAULT_RETRY_LIMIT;

    const intervalId = setInterval(() => {
        runEmqxCleanupRetry(fastify, retryLimit);
    }, retryIntervalMs);
    runEmqxCleanupRetry(fastify, retryLimit);

    fastify.addHook('onClose', async () => {
        clearInterval(intervalId);
    });
}
