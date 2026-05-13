const DEFAULT_TIMEOUT_SECONDS = 60;
const DEFAULT_PENDING_TIMEOUT_SECONDS = 1800; // 30 min
const DEFAULT_SWEEP_INTERVAL_MS = 30_000;

function parsePositiveIntEnv(name, fallback) {
    const value = Number.parseInt(process.env[name] || '', 10);
    return Number.isInteger(value) && value > 0 ? value : fallback;
}

export function registerCommandTimeoutJob(fastify, options = {}) {
    const timeoutSeconds = options.timeoutSeconds ?? parsePositiveIntEnv('COMMAND_SENT_TIMEOUT_SECONDS', DEFAULT_TIMEOUT_SECONDS);
    const pendingTimeoutSeconds = options.pendingTimeoutSeconds ?? parsePositiveIntEnv('COMMAND_PENDING_TIMEOUT_SECONDS', DEFAULT_PENDING_TIMEOUT_SECONDS);
    const sweepIntervalMs = options.sweepIntervalMs ?? parsePositiveIntEnv('COMMAND_TIMEOUT_SWEEP_INTERVAL_MS', DEFAULT_SWEEP_INTERVAL_MS);

    const runSweep = async () => {
        try {
            const result = await fastify.db.query(
                `UPDATE commands
                 SET status = 'timeout', executed_at = NOW()
                 WHERE (status = 'sent'    AND created_at < NOW() - ($1 * INTERVAL '1 second'))
                    OR (status = 'pending' AND created_at < NOW() - ($2 * INTERVAL '1 second'))`,
                [timeoutSeconds, pendingTimeoutSeconds]
            );

            if (result.rowCount > 0) {
                fastify.log.info(
                    { updated: result.rowCount, timeoutSeconds, pendingTimeoutSeconds },
                    'command timeout sweep updated stale commands'
                );
            }
        } catch (err) {
            fastify.log.error({ err }, 'command timeout sweep failed');
        }
    };

    const intervalId = setInterval(() => {
        runSweep();
    }, sweepIntervalMs);

    fastify.addHook('onClose', async () => {
        clearInterval(intervalId);
    });
}
