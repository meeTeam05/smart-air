import test from 'node:test';
import assert from 'node:assert/strict';

import { handleResponse, handleShadowGet, handleStatus, handleTelemetry } from '../src/services/mqtt-handlers.js';

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

test('handleTelemetry drops oversized payloads before DB insert', async () => {
    const log = createLogger();
    let insertCount = 0;
    const fastify = {
        log,
        db: {
            async query(sql) {
                if (sql.includes('FROM devices')) return { rows: [{}] };
                insertCount += 1;
                return { rows: [] };
            },
        },
    };

    await handleTelemetry(fastify, 'aa:bb:cc:dd:ee:ff', {
        device_id: 'aa:bb:cc:dd:ee:ff',
        mode: 'on',
        ts: 1777631761,
        temperature: 25,
        extra: 'x'.repeat(5000),
    });

    assert.equal(insertCount, 0);
    assert.equal(log.warnCalls.length, 1);
});

test('handleTelemetry acknowledges known telemetry size constraint failures', async () => {
    const log = createLogger();
    const fastify = {
        log,
        db: {
            async query(sql) {
                if (sql.includes('FROM devices')) return { rows: [{}] };
                const err = new Error('check violation');
                err.code = '23514';
                err.constraint = 'telemetry_payload_size_check';
                throw err;
            },
        },
    };

    await assert.doesNotReject(() => handleTelemetry(fastify, 'aa:bb:cc:dd:ee:ff', {
        device_id: 'aa:bb:cc:dd:ee:ff',
        mode: 'on',
        ts: 1777631761,
        temperature: 25,
    }));
});

test('handleTelemetry emits realtime event after telemetry insert succeeds', async () => {
    const calls = [];
    const fastify = {
        log: createLogger(),
        db: {
            async query(sql, params) {
                calls.push({ sql, params });
                if (sql.includes('FROM devices')) return { rows: [{}] };
                if (sql.includes('INSERT INTO telemetry')) return { rows: [], rowCount: 1 };
                if (sql.includes('INSERT INTO realtime_events')) {
                    return {
                        rows: [{
                            id: '42',
                            type: 'telemetry.point',
                            device_id: 'aa:bb:cc:dd:ee:ff',
                            occurred_at: new Date('2026-05-15T10:00:00Z'),
                            payload: JSON.parse(params[3]),
                        }],
                    };
                }
                return { rows: [], rowCount: 0 };
            },
        },
    };

    await handleTelemetry(fastify, 'aa:bb:cc:dd:ee:ff', {
        device_id: 'aa:bb:cc:dd:ee:ff',
        mode: 'on',
        ts: 1777631761,
        temperature: 25,
        humidity: 60,
    });

    const telemetryIndex = calls.findIndex((call) => call.sql.includes('INSERT INTO telemetry'));
    const realtimeIndex = calls.findIndex((call) => call.sql.includes('INSERT INTO realtime_events'));
    assert.ok(telemetryIndex >= 0, 'telemetry insert missing');
    assert.ok(realtimeIndex > telemetryIndex, 'realtime event must be inserted after telemetry insert');
    assert.equal(calls[realtimeIndex].params[0], 'telemetry.point');
    assert.deepEqual(JSON.parse(calls[realtimeIndex].params[3]), {
        ts: '2026-05-01T10:36:01.000Z',
        temperature: 25,
        humidity: 60,
        co_ppm: null,
        no2_ppm: null,
        mode: 'on',
    });
});

test('handleStatus ignores malformed status payloads without DB update', async () => {
    const log = createLogger();
    let queryCount = 0;
    const fastify = {
        log,
        db: {
            async query() {
                queryCount += 1;
                throw new Error('DB should not be touched for malformed status payloads');
            },
        },
    };

    await handleStatus(fastify, 'aa:bb:cc:dd:ee:ff', { online: 'true' });

    assert.equal(queryCount, 0);
    assert.equal(log.warnCalls.length, 1);
});

test('handleStatus updates online true and false payloads', async () => {
    const updates = [];
    const fastify = {
        log: createLogger(),
        redis: {
            async set() {},
            async get() {
                return null;
            },
        },
        db: {
            async query(sql, params) {
                if (sql.includes('FROM devices')) return { rows: [{}] };
                if (sql.includes('UPDATE devices SET online')) {
                    updates.push(params[0]);
                    return { rows: [], rowCount: 1 };
                }
                if (sql.includes('INSERT INTO realtime_events')) {
                    return {
                        rows: [{
                            id: String(updates.length),
                            type: 'device.status',
                            device_id: 'aa:bb:cc:dd:ee:ff',
                            occurred_at: new Date('2026-05-15T10:00:00Z'),
                            payload: JSON.parse(params[3]),
                        }],
                    };
                }
                if (sql.includes('FROM device_shadows')) return { rows: [] };
                return { rows: [], rowCount: 0 };
            },
        },
    };

    await handleStatus(fastify, 'aa:bb:cc:dd:ee:ff', { online: true });
    await handleStatus(fastify, 'aa:bb:cc:dd:ee:ff', { online: false });

    assert.deepEqual(updates, [true, false]);
});

test('handleShadowGet publishes desired and delta response', async () => {
    const published = [];
    const fastify = {
        log: createLogger(),
        redis: {
            async get() {
                return null;
            },
            async set() {},
        },
        db: {
            async query(sql) {
                if (sql.includes('FROM devices')) return { rows: [{}] };
                if (sql.includes('FROM device_shadows')) {
                    return {
                        rows: [{
                            reported: { relay_1: false },
                            desired: { relay_1: true },
                            updated_at: new Date('2026-05-01T00:00:00Z'),
                        }],
                    };
                }
                return { rows: [] };
            },
        },
        async mqttPublish(topic, payload, options) {
            published.push({ topic, payload: JSON.parse(payload), options });
        },
    };

    await handleShadowGet(fastify, 'aa:bb:cc:dd:ee:ff', { ts: 1777631761 });

    assert.equal(published.length, 1);
    assert.equal(published[0].topic, 'device/aa:bb:cc:dd:ee:ff/shadow/get_response');
    assert.deepEqual(published[0].payload.desired, { relay_1: true });
    assert.deepEqual(published[0].payload.delta, { relay_1: true });
    assert.deepEqual(published[0].options, { qos: 1 });
});

test('handleResponse emits command.updated when command transitions to terminal status', async () => {
    const calls = [];
    const fastify = {
        log: createLogger(),
        db: {
            async query(sql, params) {
                calls.push({ sql, params });
                if (sql.includes("UPDATE commands SET status = 'sent'")) {
                    return { rows: [], rowCount: 1 };
                }
                if (sql.includes('UPDATE commands') && sql.includes('executed_at')) {
                    return {
                        rows: [{
                            id: params[1],
                            device_id: params[2],
                            status: params[0],
                            executed_at: new Date('2026-05-15T10:00:01Z'),
                            error_message: params[3],
                        }],
                        rowCount: 1,
                    };
                }
                if (sql.includes('INSERT INTO realtime_events')) {
                    return {
                        rows: [{
                            id: '43',
                            type: 'command.updated',
                            device_id: 'aa:bb:cc:dd:ee:ff',
                            occurred_at: new Date('2026-05-15T10:00:01Z'),
                            payload: JSON.parse(params[3]),
                        }],
                    };
                }
                return { rows: [], rowCount: 0 };
            },
        },
    };

    await handleResponse(fastify, 'aa:bb:cc:dd:ee:ff', {
        command_id: 'cmd-1',
        status: 'done',
    });

    const realtimeCall = calls.find((call) => call.sql.includes('INSERT INTO realtime_events'));
    assert.ok(realtimeCall, 'realtime event insert missing');
    assert.equal(realtimeCall.params[0], 'command.updated');
    assert.deepEqual(JSON.parse(realtimeCall.params[3]), {
        command_id: 'cmd-1',
        status: 'done',
        error_message: null,
    });
});
