import test from 'node:test';
import assert from 'node:assert/strict';

import { runRealtimeEventRetention } from '../src/jobs/realtime-event-retention.js';

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

test('runRealtimeEventRetention deletes realtime events older than retention window', async () => {
    const calls = [];
    const fastify = {
        log: createLogger(),
        db: {
            async query(sql, params) {
                calls.push({ sql, params });
                return { rows: [], rowCount: 3 };
            },
        },
    };

    await runRealtimeEventRetention(fastify, 48);

    assert.equal(calls.length, 1);
    assert.match(calls[0].sql, /DELETE FROM realtime_events/i);
    assert.match(calls[0].sql, /created_at < NOW\(\) - \(\$1 \* INTERVAL '1 hour'\)/i);
    assert.deepEqual(calls[0].params, [48]);
    assert.equal(fastify.log.infoCalls.length, 1);
});
