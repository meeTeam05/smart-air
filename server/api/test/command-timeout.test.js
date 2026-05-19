import test from 'node:test';
import assert from 'node:assert/strict';

import { registerCommandTimeoutJob } from '../src/jobs/command-timeout.js';

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

test('command timeout sweep emits command.updated events for timed-out commands', async () => {
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
        const queryLog = [];
        const client = {
            released: false,
            async query(sql, params = []) {
                queryLog.push({ sql, params });
                if (sql.includes('UPDATE commands')) {
                    return {
                        rowCount: 2,
                        rows: [
                            {
                                id: 'cmd-1',
                                device_id: 'aa:bb:cc:dd:ee:ff',
                                payload: { type: 'relay_set', relay: 1, state: true },
                            },
                            {
                                id: 'cmd-2',
                                device_id: '11:22:33:44:55:66',
                                payload: { type: 'device_mode', mode: 'off' },
                            },
                        ],
                    };
                }
                if (sql.includes('INSERT INTO realtime_events')) {
                    return {
                        rows: [{
                            id: '99',
                            type: 'command.updated',
                            device_id: params[1],
                            occurred_at: new Date('2026-05-15T10:00:00Z'),
                            payload: JSON.parse(params[3]),
                        }],
                    };
                }
                return { rows: [], rowCount: 0 };
            },
            release() {
                this.released = true;
            },
        };
        const hooks = {};
        const fastify = {
            log: createLogger(),
            db: {
                async connect() {
                    return client;
                },
            },
            addHook(name, callback) {
                hooks[name] = callback;
            },
        };

        registerCommandTimeoutJob(fastify, {
            timeoutSeconds: 5,
            pendingTimeoutSeconds: 30,
            sweepIntervalMs: 10,
        });

        await intervalCallback();

        const eventInserts = queryLog.filter((call) => call.sql.includes('INSERT INTO realtime_events'));
        assert.equal(eventInserts.length, 2);
        assert.deepEqual(JSON.parse(eventInserts[0].params[3]), {
            command_id: 'cmd-1',
            status: 'timeout',
            payload: { type: 'relay_set', relay: 1, state: true },
        });
        assert.equal(eventInserts[0].params[4], 'command.updated:cmd-1:timeout');
        assert.deepEqual(JSON.parse(eventInserts[1].params[3]), {
            command_id: 'cmd-2',
            status: 'timeout',
            payload: { type: 'device_mode', mode: 'off' },
        });
        assert.equal(eventInserts[1].params[4], 'command.updated:cmd-2:timeout');
        assert.ok(queryLog.some((call) => call.sql === 'COMMIT'));
        assert.equal(client.released, true);
        assert.equal(fastify.log.infoCalls.length, 1);

        await hooks.onClose();
        assert.equal(clearedIntervalId, 'interval-1');
    } finally {
        globalThis.setInterval = originalSetInterval;
        globalThis.clearInterval = originalClearInterval;
    }
});
