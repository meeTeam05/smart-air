import {
    cleanupDeletedDevice,
    drainLegacyCleanupRetrySet,
    listDueDeviceCleanupJobs,
} from '../services/device-cleanup.js';
import { registerNonOverlappingIntervalJob } from './scheduler.js';
import { config } from '../config.js';

export async function runEmqxCleanupRetry(fastify, retryLimit = config.emqx.cleanupRetryLimit) {
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
    const retryIntervalMs = options.retryIntervalMs ?? config.emqx.cleanupRetryIntervalMs;
    const retryLimit = options.retryLimit ?? config.emqx.cleanupRetryLimit;

    registerNonOverlappingIntervalJob(fastify, {
        intervalMs: retryIntervalMs,
        jobName: 'emqx cleanup retry',
        runImmediately: true,
        task: () => runEmqxCleanupRetry(fastify, retryLimit),
    });
}
