import test from 'node:test';
import assert from 'node:assert/strict';

import { registerNonOverlappingIntervalJob } from '../src/jobs/scheduler.js';

test('registerNonOverlappingIntervalJob skips overlapping interval ticks', async () => {
    const originalSetInterval = globalThis.setInterval;
    const originalClearInterval = globalThis.clearInterval;
    let intervalCallback;
    let clearedIntervalId;
    let resolveTask;
    let runCount = 0;

    globalThis.setInterval = (callback, ms) => {
        intervalCallback = callback;
        assert.equal(ms, 10);
        return 'interval-1';
    };
    globalThis.clearInterval = (intervalId) => {
        clearedIntervalId = intervalId;
    };

    try {
        const hooks = {};
        const fastify = {
            addHook(name, callback) {
                hooks[name] = callback;
            },
        };

        registerNonOverlappingIntervalJob(fastify, {
            intervalMs: 10,
            task: () => new Promise((resolve) => {
                runCount += 1;
                resolveTask = resolve;
            }),
        });

        intervalCallback();
        intervalCallback();
        await new Promise((resolve) => setImmediate(resolve));
        assert.equal(runCount, 1);

        resolveTask();
        await new Promise((resolve) => setImmediate(resolve));

        intervalCallback();
        await new Promise((resolve) => setImmediate(resolve));
        assert.equal(runCount, 2);

        await hooks.onClose();
        assert.equal(clearedIntervalId, 'interval-1');
    } finally {
        globalThis.setInterval = originalSetInterval;
        globalThis.clearInterval = originalClearInterval;
    }
});
