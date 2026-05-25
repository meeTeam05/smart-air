import test from 'node:test';
import assert from 'node:assert/strict';

import { handleResponse, handleShadowGet, handleShadowReport, handleStatus, handleTelemetry } from '../src/services/mqtt-handlers.js';

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

test('handleTelemetry uses raw payload byte length for oversized payload rejection', async () => {
    const log = createLogger();
    let insertCount = 0;
    const payload = {
        device_id: 'aa:bb:cc:dd:ee:ff',
        mode: 'on',
        ts: 1777631761,
        toJSON() {
            throw new Error('validation should not stringify payload when raw byte length is known');
        },
    };
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

    await assert.doesNotReject(() => handleTelemetry(
        fastify,
        'aa:bb:cc:dd:ee:ff',
        payload,
        null,
        5000
    ));

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
                if (sql.includes('INSERT INTO telemetry')) {
                    return { rows: [{ ts: new Date('2026-05-01T10:36:01.000Z') }], rowCount: 1 };
                }
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

test('handleTelemetry suppresses duplicate QoS1 redelivery by ts and messageId', async () => {
    const calls = [];
    let telemetryInsertCount = 0;
    let realtimeInsertCount = 0;
    const fastify = {
        log: createLogger(),
        db: {
            async query(sql, params) {
                calls.push({ sql, params });
                if (sql.includes('FROM devices')) return { rows: [{}] };
                if (sql.includes('INSERT INTO telemetry')) {
                    telemetryInsertCount += 1;
                    return {
                        rows: telemetryInsertCount === 1 ? [{ ts: new Date('2026-05-01T10:36:01.000Z') }] : [],
                        rowCount: telemetryInsertCount === 1 ? 1 : 0,
                    };
                }
                if (sql.includes('INSERT INTO realtime_events')) {
                    realtimeInsertCount += 1;
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
    const payload = {
        device_id: 'aa:bb:cc:dd:ee:ff',
        mode: 'on',
        ts: 1777631761,
        temperature: 25,
        humidity: 60,
    };

    await handleTelemetry(fastify, 'aa:bb:cc:dd:ee:ff', payload, { messageId: 7, qos: 1 });
    await handleTelemetry(fastify, 'aa:bb:cc:dd:ee:ff', payload, { messageId: 7, qos: 1 });

    const telemetryCall = calls.find((call) => call.sql.includes('INSERT INTO telemetry'));
    assert.ok(telemetryCall, 'telemetry insert missing');
    assert.equal(telemetryCall.params[1], 1777631761);
    assert.equal(telemetryCall.params[3], JSON.stringify(payload));
    assert.equal(telemetryCall.params[4], 7);
    assert.equal(realtimeInsertCount, 1);
});

test('handleTelemetry clamps future telemetry against database NOW()', async () => {
    const calls = [];
    const normalizedTs = new Date('2026-05-15T10:00:00Z');
    const fastify = {
        log: createLogger(),
        db: {
            async query(sql, params) {
                calls.push({ sql, params });
                if (sql.includes('FROM devices')) return { rows: [{}] };
                if (sql.includes('INSERT INTO telemetry')) {
                    return { rows: [{ ts: normalizedTs }], rowCount: 1 };
                }
                if (sql.includes('INSERT INTO realtime_events')) {
                    return {
                        rows: [{
                            id: '77',
                            type: 'telemetry.point',
                            device_id: 'aa:bb:cc:dd:ee:ff',
                            occurred_at: normalizedTs,
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
        ts: 4_102_444_800,
        temperature: 25,
    });

    const telemetryCall = calls.find((call) => call.sql.includes('INSERT INTO telemetry'));
    const realtimeCall = calls.find((call) => call.sql.includes('INSERT INTO realtime_events'));
    assert.ok(telemetryCall, 'telemetry insert missing');
    assert.match(telemetryCall.sql, /EXTRACT\(EPOCH FROM NOW\(\)\)/);
    assert.match(telemetryCall.sql, /to_timestamp\(\$2::double precision\)/);
    assert.match(telemetryCall.sql, /to_timestamp\(\$3::double precision\)/);
    assert.equal(telemetryCall.params[1], 4_102_444_800);
    assert.deepEqual(JSON.parse(realtimeCall.params[3]), {
        ts: '2026-05-15T10:00:00.000Z',
        temperature: 25,
        humidity: null,
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

test('handleStatus persists firmware version without clearing it when omitted', async () => {
    const updates = [];
    const fastify = {
        log: createLogger(),
        redis: {
            async set() {},
        },
        async mqttPublish() {
            throw new Error('handleStatus should not publish shadow/get_response on online status');
        },
        db: {
            async query(sql, params) {
                if (sql.includes('FROM devices')) return { rows: [{}] };
                if (sql.includes('UPDATE devices SET online')) {
                    updates.push({ sql, params });
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
                return { rows: [], rowCount: 0 };
            },
        },
    };

    await handleStatus(fastify, 'aa:bb:cc:dd:ee:ff', { online: true, firmware: '1.2.3' });
    await handleStatus(fastify, 'aa:bb:cc:dd:ee:ff', { online: false });

    assert.equal(updates.length, 2);
    assert.match(updates[0].sql, /firmware_ver = COALESCE\(\$2, firmware_ver\)/);
    assert.deepEqual(updates[0].params, [true, '1.2.3', 'aa:bb:cc:dd:ee:ff']);
    assert.deepEqual(updates[1].params, [false, null, 'aa:bb:cc:dd:ee:ff']);
});

test('handleShadowGet publishes desired and delta response', async () => {
    const published = [];
    const fastify = {
        log: createLogger(),
        redis: {
            async get() {
                return null;
            },
            async eval() {},
            async del() {},
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

test('handleShadowGet swallows shadow/get_response publish failures', async () => {
    const log = createLogger();
    let publishAttempts = 0;
    const fastify = {
        log,
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
        async mqttPublish() {
            publishAttempts += 1;
            throw new Error('MQTT bridge is not ready');
        },
    };

    await assert.doesNotReject(() => handleShadowGet(fastify, 'aa:bb:cc:dd:ee:ff', { ts: 1777631761 }));

    assert.equal(publishAttempts, 1);
    assert.ok(
        log.warnCalls.some((call) => call[1] === 'shadow get_response publish failed after shadow/get')
    );
});

test('handleShadowReport skips realtime event for stale payload ts', async () => {
    let realtimeCount = 0;
    const currentRow = {
        reported: { mode: 'off', relay_1: false, ts: 200 },
        desired: {},
        updated_at: new Date('2026-05-01T00:00:00Z'),
    };
    const fastify = {
        log: createLogger(),
        redis: {
            async set() {},
        },
        db: {
            async query(sql, params) {
                if (sql.includes('FROM devices')) return { rows: [{}] };
                if (sql.includes('INSERT INTO device_shadows')) {
                    assert.equal(params[2], 100);
                    return { rows: [], rowCount: 0 };
                }
                if (sql.includes('SELECT reported, desired, updated_at FROM device_shadows')) {
                    return { rows: [currentRow] };
                }
                if (sql.includes('INSERT INTO realtime_events')) {
                    realtimeCount += 1;
                    return {
                        rows: [{
                            id: '44',
                            type: 'shadow.reported',
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

    await handleShadowReport(fastify, 'aa:bb:cc:dd:ee:ff', { mode: 'on', relay_1: true, ts: 100 });

    assert.equal(realtimeCount, 0);
});

test('handleShadowReport uses idempotency key derived from payload ts and body', async () => {
    const calls = [];
    const fastify = {
        log: createLogger(),
        redis: {
            async set() {},
        },
        db: {
            async query(sql, params) {
                calls.push({ sql, params });
                if (sql.includes('FROM devices')) return { rows: [{}] };
                if (sql.includes('INSERT INTO device_shadows')) {
                    return {
                        rows: [{
                            reported: { mode: 'on', relay_1: true, ts: 1777631761 },
                            desired: {},
                            updated_at: new Date('2026-05-15T10:00:00Z'),
                        }],
                        rowCount: 1,
                    };
                }
                if (sql.includes('INSERT INTO realtime_events')) {
                    return {
                        rows: [{
                            id: '45',
                            type: 'shadow.reported',
                            device_id: 'aa:bb:cc:dd:ee:ff',
                            occurred_at: new Date('2026-05-15T10:00:00Z'),
                            payload: JSON.parse(params[3]),
                        }],
                    };
                }
                if (sql.includes('pg_notify')) return { rows: [] };
                return { rows: [], rowCount: 0 };
            },
        },
    };

    await handleShadowReport(fastify, 'aa:bb:cc:dd:ee:ff', { mode: 'on', relay_1: true, ts: 1777631761 });

    const realtimeCall = calls.find((call) => call.sql.includes('INSERT INTO realtime_events'));
    assert.ok(realtimeCall, 'realtime event insert missing');
    assert.match(realtimeCall.params[4], /^shadow\.reported:aa:bb:cc:dd:ee:ff:1777631761:/);
});

test('handleResponse emits command.updated when command transitions to terminal status', async () => {
    const calls = [];
    const fastify = {
        log: createLogger(),
        db: {
            async query(sql, params) {
                calls.push({ sql, params });
                if (sql.includes('UPDATE commands') && sql.includes('sent_at = COALESCE(sent_at, NOW())')) {
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
    assert.equal(realtimeCall.params[4], 'command.updated:cmd-1:done');
    assert.ok(
        calls.some((call) => call.sql.includes("status = 'sent'") && call.sql.includes('sent_at = COALESCE(sent_at, NOW())')),
        'response path should stamp sent_at when promoting pending commands'
    );
});
