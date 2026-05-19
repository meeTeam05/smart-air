import test from 'node:test';
import assert from 'node:assert/strict';

import { commandMessage, flushPending, sendCommand } from '../src/services/commands.js';

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
        async query(sql, params) {
            queryLog.push(sql);
            if (sql.includes('pg_try_advisory_lock')) return { rows: [{ locked: true }] };
            if (sql.includes('SELECT id, payload')) {
                return { rows: commandRows.length > 0 ? [commandRows.shift()] : [] };
            }
            if (sql.includes('INSERT INTO realtime_events')) {
                return {
                    rows: [{
                        id: '42',
                        type: 'command.updated',
                        device_id: params[1],
                        occurred_at: new Date('2026-05-15T10:00:00Z'),
                        payload: JSON.parse(params[3]),
                    }],
                };
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

test('flushPending derives advisory lock keys from device IDs without hashtext', async () => {
    const lockCalls = [];
    const client = {
        released: false,
        async query(sql, params) {
            if (sql.includes('pg_try_advisory_lock') || sql.includes('pg_advisory_unlock')) {
                lockCalls.push({ sql, params });
            }
            if (sql.includes('pg_try_advisory_lock')) return { rows: [{ locked: true }] };
            if (sql.includes('SELECT id, payload')) return { rows: [] };
            return { rows: [], rowCount: 1 };
        },
        release() {
            this.released = true;
        },
    };
    const fastify = {
        db: {
            async connect() {
                return client;
            },
        },
        log: createLogger(),
    };

    await flushPending(fastify, 'aa:bb:cc:dd:ee:ff');

    assert.deepEqual(lockCalls, [
        {
            sql: 'SELECT pg_try_advisory_lock($1::bigint) AS locked',
            params: [BigInt('0xaabbccddeeff').toString()],
        },
        {
            sql: 'SELECT pg_advisory_unlock($1::bigint)',
            params: [BigInt('0xaabbccddeeff').toString()],
        },
    ]);
    assert.ok(client.released);
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

test('flushPending commits sent status before MQTT publish', async () => {
    const steps = [];
    const commandRows = [{
        id: 'cmd-1',
        payload: { type: 'set_time', ts: 1777631761 },
        pending_expired: false,
    }];
    const client = {
        released: false,
        async query(sql, params) {
            steps.push(sql);
            if (sql.includes('pg_try_advisory_lock')) return { rows: [{ locked: true }] };
            if (sql.includes('SELECT id, payload')) {
                return { rows: commandRows.length > 0 ? [commandRows.shift()] : [] };
            }
            if (sql.includes('INSERT INTO realtime_events')) {
                return {
                    rows: [{
                        id: '42',
                        type: 'command.updated',
                        device_id: params[1],
                        occurred_at: new Date('2026-05-15T10:00:00Z'),
                        payload: JSON.parse(params[3]),
                    }],
                };
            }
            return { rows: [], rowCount: 1 };
        },
        release() {
            this.released = true;
        },
    };
    const fastify = {
        log: createLogger(),
        db: {
            async connect() {
                return client;
            },
        },
        async mqttPublish() {
            steps.push('MQTT_PUBLISH');
        },
    };

    await flushPending(fastify, 'aa:bb:cc:dd:ee:ff');

    assert.ok(steps.indexOf('COMMIT') < steps.indexOf('MQTT_PUBLISH'));
});

test('sendCommand emits command.updated for pending command state', async () => {
    const calls = [];
    const fastify = {
        db: {
            async query(sql, params) {
                calls.push({ sql, params });
                if (sql.includes('INSERT INTO commands')) {
                    return { rows: [{ id: 'cmd-1' }] };
                }
                if (sql.includes('INSERT INTO realtime_events')) {
                    return {
                        rows: [{
                            id: '41',
                            type: 'command.updated',
                            device_id: params[1],
                            occurred_at: new Date('2026-05-15T10:00:00Z'),
                            payload: JSON.parse(params[3]),
                        }],
                    };
                }
                return { rows: [], rowCount: 1 };
            },
        },
        mqttIsReady() {
            return false;
        },
    };

    const commandId = await sendCommand(
        fastify,
        'aa:bb:cc:dd:ee:ff',
        { type: 'relay_set', relay: 1, state: true },
        'user-1'
    );

    assert.equal(commandId, 'cmd-1');
    const realtimeCall = calls.find((call) => call.sql.includes('INSERT INTO realtime_events'));
    assert.ok(realtimeCall, 'realtime event insert missing');
    assert.equal(realtimeCall.params[0], 'command.updated');
    assert.deepEqual(JSON.parse(realtimeCall.params[3]), {
        command_id: 'cmd-1',
        status: 'pending',
        payload: { type: 'relay_set', relay: 1, state: true },
    });
});

test('flushPending emits command.updated after command is sent', async () => {
    const queryLog = [];
    const published = [];
    const commandRows = [{
        id: 'cmd-1',
        payload: { type: 'set_time', ts: 1777631761 },
        pending_expired: false,
    }];
    const client = {
        released: false,
        async query(sql, params) {
            queryLog.push({ sql, params });
            if (sql.includes('pg_try_advisory_lock')) return { rows: [{ locked: true }] };
            if (sql.includes('SELECT id, payload')) {
                return { rows: commandRows.length > 0 ? [commandRows.shift()] : [] };
            }
            if (sql.includes('INSERT INTO realtime_events')) {
                return {
                    rows: [{
                        id: '42',
                        type: 'command.updated',
                        device_id: params[1],
                        occurred_at: new Date('2026-05-15T10:00:00Z'),
                        payload: JSON.parse(params[3]),
                    }],
                };
            }
            return { rows: [], rowCount: 1 };
        },
        release() {
            this.released = true;
        },
    };
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
    const realtimeCall = queryLog.find((call) => call.sql.includes('INSERT INTO realtime_events'));
    assert.ok(realtimeCall, 'realtime event insert missing');
    assert.equal(realtimeCall.params[0], 'command.updated');
    assert.deepEqual(JSON.parse(realtimeCall.params[3]), {
        command_id: 'cmd-1',
        status: 'sent',
        payload: { type: 'set_time', ts: 1777631761 },
    });
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
            async query(sql, params) {
                queryLog.push(sql);
                if (sql.includes('INSERT INTO realtime_events')) {
                    return {
                        rows: [{
                            id: '43',
                            type: 'command.updated',
                            device_id: params[1],
                            occurred_at: new Date('2026-05-15T10:00:01Z'),
                            payload: JSON.parse(params[3]),
                        }],
                    };
                }
                return { rows: [], rowCount: 1 };
            },
        },
        async mqttPublish() {
            throw new Error('publish failed');
        },
    };

    await flushPending(fastify, 'aa:bb:cc:dd:ee:ff');

    assert.ok(queryLog.some((sql) => sql.includes("SET status = 'sent'")));
    assert.ok(
        queryLog.some((sql) => sql.includes("SET status = 'pending'")),
        'publish failure should revert command to pending'
    );
});
