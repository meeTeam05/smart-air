import test from 'node:test';
import assert from 'node:assert/strict';

import { registerDataRetentionJob, runDataRetentionCleanup } from '../src/jobs/data-retention.js';

function createLogger() {
    return {
        infoCalls: [],
        errorCalls: [],
        info(...args) {
            this.infoCalls.push(args);
        },
        error(...args) {
            this.errorCalls.push(args);
        },
    };
}

test('runDataRetentionCleanup deletes expired refresh tokens and old terminal commands', async () => {
    const calls = [];
    const fastify = {
        log: createLogger(),
        db: {
            async query(sql, params) {
                calls.push({ sql, params });
                if (sql.includes('DELETE FROM refresh_tokens')) {
                    return { rows: [], rowCount: 4 };
                }
                if (sql.includes('DELETE FROM commands')) {
                    return { rows: [], rowCount: 7 };
                }
                throw new Error(`Unexpected SQL: ${sql}`);
            },
        },
    };

    await runDataRetentionCleanup(fastify, {
        commandRetentionDays: 30,
        refreshTokenRetentionDays: 30,
    });

    assert.equal(calls.length, 2);
    assert.match(calls[0].sql, /DELETE FROM refresh_tokens/i);
    assert.match(calls[0].sql, /expires_at <= NOW\(\)/i);
    assert.equal(calls[0].params, undefined);

    assert.match(calls[1].sql, /DELETE FROM commands/i);
    assert.match(calls[1].sql, /created_at < NOW\(\) - \(\$1 \* INTERVAL '1 day'\)/i);
    assert.match(calls[1].sql, /status IN \('done', 'error', 'timeout'\)/i);
    assert.deepEqual(calls[1].params, [30]);
    assert.equal(fastify.log.infoCalls.length, 2);
});

test('registerDataRetentionJob schedules cleanup and clears interval on close', async () => {
    const originalSetInterval = globalThis.setInterval;
    const originalClearInterval = globalThis.clearInterval;
    let intervalCallback;
    let clearedIntervalId;

    globalThis.setInterval = (callback, ms) => {
        intervalCallback = callback;
        assert.equal(ms, 10);
        return 'interval-1';
    };
    globalThis.clearInterval = (intervalId) => {
        clearedIntervalId = intervalId;
    };

    try {
        const calls = [];
        const hooks = {};
        const fastify = {
            log: createLogger(),
            db: {
                async query(sql, params) {
                    calls.push({ sql, params });
                    return { rows: [], rowCount: 0 };
                },
            },
            addHook(name, callback) {
                hooks[name] = callback;
            },
        };

        registerDataRetentionJob(fastify, {
            commandRetentionDays: 30,
            refreshTokenRetentionDays: 30,
            sweepIntervalMs: 10,
        });

        await new Promise((resolve) => setImmediate(resolve));
        assert.equal(calls.length, 2);
        assert.match(calls[0].sql, /DELETE FROM refresh_tokens/i);
        assert.match(calls[1].sql, /DELETE FROM commands/i);
        await intervalCallback();
        await new Promise((resolve) => setImmediate(resolve));
        assert.equal(calls.length, 4);
        assert.match(calls[2].sql, /DELETE FROM refresh_tokens/i);
        assert.match(calls[3].sql, /DELETE FROM commands/i);

        await hooks.onClose();
        assert.equal(clearedIntervalId, 'interval-1');
    } finally {
        globalThis.setInterval = originalSetInterval;
        globalThis.clearInterval = originalClearInterval;
    }
});
