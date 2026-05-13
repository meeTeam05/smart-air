import test from 'node:test';
import assert from 'node:assert/strict';

import { commandMessage, flushPending } from '../src/services/commands.js';

function createLogger() {
    return {
        warnCalls: [],
        info() {},
        error() {},
        warn(...args) {
            this.warnCalls.push(args);
        },
    };
}

function createClient({ commandRows, queryLog }) {
    return {
        released: false,
        async query(sql) {
            queryLog.push(sql);
            if (sql.includes('pg_try_advisory_lock')) return { rows: [{ locked: true }] };
            if (sql.includes('SELECT id, payload')) {
                return { rows: commandRows.length > 0 ? [commandRows.shift()] : [] };
            }
            return { rows: [], rowCount: 1 };
        },
        release() {
            this.released = true;
        },
    };
}

test('commandMessage serializes command_id with payload fields', () => {
    assert.equal(
        commandMessage('cmd-1', { type: 'set_time', ts: 1777631761 }),
        '{"command_id":"cmd-1","type":"set_time","ts":1777631761}'
    );
});

test('flushPending publishes pending DB commands once and marks sent', async () => {
    const queryLog = [];
    const published = [];
    const client = createClient({
        queryLog,
        commandRows: [{
            id: 'cmd-1',
            payload: { type: 'set_time', ts: 1777631761 },
            pending_expired: false,
        }],
    });
    const fastify = {
        log: createLogger(),
        db: {
            async connect() {
                return client;
            },
        },
        async mqttPublish(topic, payload, options) {
            published.push({ topic, payload: JSON.parse(payload), options });
        },
    };

    await flushPending(fastify, 'aa:bb:cc:dd:ee:ff');

    assert.equal(published.length, 1);
    assert.equal(published[0].topic, 'device/aa:bb:cc:dd:ee:ff/command');
    assert.deepEqual(published[0].payload, {
        command_id: 'cmd-1',
        type: 'set_time',
        ts: 1777631761,
    });
    assert.ok(queryLog.some((sql) => sql.includes("SET status = 'sent'")));
    assert.ok(client.released);
});

test('flushPending leaves command pending when publish fails', async () => {
    const queryLog = [];
    const client = createClient({
        queryLog,
        commandRows: [{
            id: 'cmd-1',
            payload: { type: 'set_time', ts: 1777631761 },
            pending_expired: false,
        }],
    });
    const fastify = {
        log: createLogger(),
        db: {
            async connect() {
                return client;
            },
        },
        async mqttPublish() {
            throw new Error('publish failed');
        },
    };

    await flushPending(fastify, 'aa:bb:cc:dd:ee:ff');

    assert.ok(queryLog.includes('ROLLBACK'));
    assert.equal(queryLog.some((sql) => sql.includes("SET status = 'sent'")), false);
});
