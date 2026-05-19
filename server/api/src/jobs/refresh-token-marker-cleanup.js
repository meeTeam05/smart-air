import { registerNonOverlappingIntervalJob } from './scheduler.js';

const DEFAULT_SWEEP_INTERVAL_MS = 3_600_000;

function parsePositiveIntEnv(name, fallback) {
    const value = Number.parseInt(process.env[name] || '', 10);
    return Number.isInteger(value) && value > 0 ? value : fallback;
}

export function registerRefreshTokenMarkerCleanupJob(fastify, options = {}) {
    const sweepIntervalMs = options.sweepIntervalMs
        ?? parsePositiveIntEnv('REFRESH_REUSE_MARKER_SWEEP_INTERVAL_MS', DEFAULT_SWEEP_INTERVAL_MS);

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
        runImmediately: true,
        task: runSweep,
    });
}
