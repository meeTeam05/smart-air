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

    const triggerRun = () => {
        runOnce().catch((err) => {
            fastify.log.error({ err, jobName }, 'job sweep failed');
        });
    };

    const intervalId = setInterval(() => {
        triggerRun();
    }, intervalMs);

    if (runImmediately) {
        triggerRun();
    }

    fastify.addHook('onClose', async () => {
        clearInterval(intervalId);
    });
}
