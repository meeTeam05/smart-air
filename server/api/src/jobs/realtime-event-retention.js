import { registerNonOverlappingIntervalJob } from './scheduler.js';

const DEFAULT_RETENTION_HOURS = 24;
const DEFAULT_SWEEP_INTERVAL_MS = 3_600_000;

function parsePositiveIntEnv(name, fallback) {
    const value = Number.parseInt(process.env[name] || '', 10);
    return Number.isInteger(value) && value > 0 ? value : fallback;
}

export async function runRealtimeEventRetention(fastify, retentionHours = DEFAULT_RETENTION_HOURS) {
    try {
        const result = await fastify.db.query(
            `DELETE FROM realtime_events
             WHERE created_at < NOW() - ($1 * INTERVAL '1 hour')`,
            [retentionHours]
        );
        if (result.rowCount > 0) {
            fastify.log.info(
                { deleted: result.rowCount, retentionHours },
                'realtime event retention removed old events'
            );
        }
    } catch (err) {
        fastify.log.error({ err }, 'realtime event retention failed');
    }
}

export function registerRealtimeEventRetentionJob(fastify, options = {}) {
    const retentionHours = options.retentionHours
        ?? parsePositiveIntEnv('REALTIME_EVENT_RETENTION_HOURS', DEFAULT_RETENTION_HOURS);
    const sweepIntervalMs = options.sweepIntervalMs
        ?? parsePositiveIntEnv('REALTIME_EVENT_RETENTION_SWEEP_INTERVAL_MS', DEFAULT_SWEEP_INTERVAL_MS);

    registerNonOverlappingIntervalJob(fastify, {
        intervalMs: sweepIntervalMs,
        runImmediately: true,
        task: () => runRealtimeEventRetention(fastify, retentionHours),
    });
}
