export function registerNonOverlappingIntervalJob(
    fastify,
    {
        intervalMs,
        jobName = 'interval job',
        runImmediately = false,
        task,
    }
) {
    let running = false;

    const runOnce = async () => {
        if (running) return;
        running = true;
        const startedAt = Date.now();
        try {
            fastify.log.info({ jobName }, 'job sweep started');
            await task();
            fastify.log.info(
                { jobName, durationMs: Date.now() - startedAt },
                'job sweep completed'
            );
        } finally {
            running = false;
        }
    };

    const intervalId = setInterval(() => {
        void runOnce();
    }, intervalMs);

    if (runImmediately) {
        void runOnce();
    }

    fastify.addHook('onClose', async () => {
        clearInterval(intervalId);
    });
}
