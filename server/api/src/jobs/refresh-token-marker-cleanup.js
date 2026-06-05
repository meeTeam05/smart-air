import { registerNonOverlappingIntervalJob } from './scheduler.js';
import { config } from '../config.js';

export function registerRefreshTokenMarkerCleanupJob(fastify, options = {}) {
    const sweepIntervalMs = options.sweepIntervalMs
        ?? config.refreshTokens.reuseMarkerSweepIntervalMs;

    const runSweep = async () => {
        try {
            const result = await fastify.db.query(
                'DELETE FROM refresh_token_reuse_markers WHERE expires_at <= NOW()'
            );
            if (result.rowCount > 0) {
                fastify.log.info(
                    { deleted: result.rowCount },
                    'refresh token reuse marker cleanup removed expired markers'
                );
            }
        } catch (err) {
            fastify.log.error({ err }, 'refresh token reuse marker cleanup failed');
        }
    };

    registerNonOverlappingIntervalJob(fastify, {
        intervalMs: sweepIntervalMs,
        jobName: 'refresh token marker cleanup',
        runImmediately: true,
        task: runSweep,
    });
}
