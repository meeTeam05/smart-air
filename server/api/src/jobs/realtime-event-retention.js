import { registerNonOverlappingIntervalJob } from './scheduler.js';
import { config } from '../config.js';

export async function runRealtimeEventRetention(fastify, retentionHours = config.realtime.eventRetentionHours) {
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
        ?? config.realtime.eventRetentionHours;
    const sweepIntervalMs = options.sweepIntervalMs
        ?? config.realtime.eventRetentionSweepIntervalMs;

    registerNonOverlappingIntervalJob(fastify, {
        intervalMs: sweepIntervalMs,
        jobName: 'realtime event retention',
        runImmediately: true,
        task: () => runRealtimeEventRetention(fastify, retentionHours),
    });
}
