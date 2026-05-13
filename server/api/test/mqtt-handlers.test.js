import test from 'node:test';
import assert from 'node:assert/strict';

import { handleShadowGet, handleStatus, handleTelemetry } from '../src/services/mqtt-handlers.js';

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
