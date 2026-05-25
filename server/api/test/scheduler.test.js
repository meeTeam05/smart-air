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
        const infoCalls = [];
        const fastify = {
            log: {
                info(...args) {
                    infoCalls.push(args);
                },
                error() {},
            },
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
        assert.equal(infoCalls.length, 1);
        assert.equal(infoCalls[0][1], 'job sweep started');

        resolveTask();
        await new Promise((resolve) => setImmediate(resolve));
        assert.equal(infoCalls.length, 2);
        assert.equal(infoCalls[1][1], 'job sweep completed');

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

test('registerNonOverlappingIntervalJob logs rejected task runs and keeps scheduling', async () => {
    const originalSetInterval = globalThis.setInterval;
    const originalClearInterval = globalThis.clearInterval;
    let intervalCallback;
    const errorCalls = [];
    let runCount = 0;

    globalThis.setInterval = (callback) => {
        intervalCallback = callback;
        return 'interval-2';
    };
    globalThis.clearInterval = () => {};

    try {
        const fastify = {
            log: {
                info() {},
                error(...args) {
                    errorCalls.push(args);
                },
            },
            addHook() {},
        };

        registerNonOverlappingIntervalJob(fastify, {
            intervalMs: 10,
            task: async () => {
                runCount += 1;
                if (runCount === 1) {
                    throw new Error('job boom');
                }
            },
        });

        intervalCallback();
        await new Promise((resolve) => setImmediate(resolve));
        assert.equal(runCount, 1);
        assert.equal(errorCalls.length, 1);
        assert.equal(errorCalls[0][1], 'job sweep failed');

        intervalCallback();
        await new Promise((resolve) => setImmediate(resolve));
        assert.equal(runCount, 2);
    } finally {
        globalThis.setInterval = originalSetInterval;
        globalThis.clearInterval = originalClearInterval;
    }
});
