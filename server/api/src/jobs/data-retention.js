const DEFAULT_COMMAND_RETENTION_DAYS = 30;
const DEFAULT_REFRESH_TOKEN_RETENTION_DAYS = 30;
const DEFAULT_SWEEP_INTERVAL_MS = 3_600_000;

function parsePositiveIntEnv(name, fallback) {
    const value = Number.parseInt(process.env[name] || '', 10);
    return Number.isInteger(value) && value > 0 ? value : fallback;
}

export async function runDataRetentionCleanup(
    fastify,
    {
        commandRetentionDays = DEFAULT_COMMAND_RETENTION_DAYS,
        refreshTokenRetentionDays = DEFAULT_REFRESH_TOKEN_RETENTION_DAYS,
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
        ?? parsePositiveIntEnv('COMMAND_RETENTION_DAYS', DEFAULT_COMMAND_RETENTION_DAYS);
    const refreshTokenRetentionDays = options.refreshTokenRetentionDays
        ?? parsePositiveIntEnv('REFRESH_TOKEN_RETENTION_DAYS', DEFAULT_REFRESH_TOKEN_RETENTION_DAYS);
    const sweepIntervalMs = options.sweepIntervalMs
        ?? parsePositiveIntEnv('DATA_RETENTION_SWEEP_INTERVAL_MS', DEFAULT_SWEEP_INTERVAL_MS);

    const intervalId = setInterval(() => {
        runDataRetentionCleanup(fastify, {
            commandRetentionDays,
            refreshTokenRetentionDays,
        });
    }, sweepIntervalMs);
    runDataRetentionCleanup(fastify, {
        commandRetentionDays,
        refreshTokenRetentionDays,
    });

    fastify.addHook('onClose', async () => {
        clearInterval(intervalId);
    });
}
