import { registerNonOverlappingIntervalJob } from './scheduler.js';
import { config } from '../config.js';

export async function runDataRetentionCleanup(
    fastify,
    {
        commandRetentionDays = config.dataRetention.commandRetentionDays,
        refreshTokenRetentionDays = config.dataRetention.refreshTokenRetentionDays,
    } = {}
) {
    try {
        const result = await fastify.db.query(
            'DELETE FROM refresh_tokens WHERE expires_at <= NOW()'
        );
        if (result.rowCount > 0) {
            fastify.log.info(
                { deleted: result.rowCount, retentionDays: refreshTokenRetentionDays },
                'data retention removed expired refresh tokens'
            );
        }
    } catch (err) {
        fastify.log.error({ err }, 'data retention refresh token cleanup failed');
    }

    try {
        const result = await fastify.db.query(
            `DELETE FROM commands
             WHERE created_at < NOW() - ($1 * INTERVAL '1 day')
               AND status IN ('done', 'error', 'timeout')`,
            [commandRetentionDays]
        );
        if (result.rowCount > 0) {
            fastify.log.info(
                { deleted: result.rowCount, retentionDays: commandRetentionDays },
                'data retention removed old terminal commands'
            );
        }
    } catch (err) {
        fastify.log.error({ err }, 'data retention command cleanup failed');
    }
}

export function registerDataRetentionJob(fastify, options = {}) {
    const commandRetentionDays = options.commandRetentionDays
        ?? config.dataRetention.commandRetentionDays;
    const refreshTokenRetentionDays = options.refreshTokenRetentionDays
        ?? config.dataRetention.refreshTokenRetentionDays;
    const sweepIntervalMs = options.sweepIntervalMs
        ?? config.dataRetention.sweepIntervalMs;

    registerNonOverlappingIntervalJob(fastify, {
        intervalMs: sweepIntervalMs,
        jobName: 'data retention',
        runImmediately: true,
        task: () => runDataRetentionCleanup(fastify, {
            commandRetentionDays,
            refreshTokenRetentionDays,
        }),
    });
}
