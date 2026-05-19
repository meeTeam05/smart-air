export function registerNonOverlappingIntervalJob(
    fastify,
    {
        intervalMs,
        runImmediately = false,
        task,
    }
) {
    let running = false;

    const runOnce = async () => {
        if (running) return;
        running = true;
        try {
            await task();
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
