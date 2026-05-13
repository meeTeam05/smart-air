import test from 'node:test';
import assert from 'node:assert/strict';

import { getShadow, setDesired, updateReported } from '../src/services/shadow.js';

const DEVICE_ID = 'aa:bb:cc:dd:ee:ff';

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

test('getShadow ignores malformed Redis JSON, deletes cache key, and falls back to DB', async () => {
    const log = createLogger();
    const deletedKeys = [];
    const fastify = {
        log,
        redis: {
            async get(key) {
                assert.equal(key, `shadow:${DEVICE_ID}`);
                return '{bad json';
            },
            async del(key) {
                deletedKeys.push(key);
                return 1;
            },
            async set() {},
        },
        db: {
            async query(sql, params) {
                assert.match(sql, /FROM device_shadows/);
                assert.deepEqual(params, [DEVICE_ID]);
                return {
                    rows: [{
                        reported: { temperature: 25 },
                        desired: { relay_1: true },
                        updated_at: new Date('2026-05-01T00:00:00Z'),
                    }],
                };
            },
        },
    };

    const shadow = await getShadow(fastify, DEVICE_ID);

    assert.deepEqual(shadow.reported, { temperature: 25 });
    assert.deepEqual(shadow.desired, { relay_1: true });
    assert.deepEqual(deletedKeys, [`shadow:${DEVICE_ID}`]);
    assert.equal(log.warnCalls.length, 1);
});

test('getShadow falls back to DB when Redis read fails', async () => {
    const log = createLogger();
    const fastify = {
        log,
        redis: {
            async get() {
                throw new Error('redis down');
            },
            async set() {
                throw new Error('redis still down');
            },
        },
        db: {
            async query() {
                return { rows: [] };
            },
        },
    };

    const shadow = await getShadow(fastify, DEVICE_ID);

    assert.deepEqual(shadow, { reported: {}, desired: {}, updatedAt: null });
    assert.equal(log.warnCalls.length, 1);
});

test('shadow DB updates succeed when Redis write-through cache fails', async () => {
    const log = createLogger();
    let updateCount = 0;
    const fastify = {
        log,
        redis: {
            async set() {
                throw new Error('redis write failed');
            },
        },
        db: {
            async query(sql, params) {
                updateCount += 1;
                assert.match(sql, /INSERT INTO device_shadows/);
                assert.equal(params[0], DEVICE_ID);
                return {
                    rows: [{
                        reported: { relay_1: false },
                        desired: { relay_1: true },
                        updated_at: new Date('2026-05-01T00:00:00Z'),
                    }],
                };
            },
        },
    };

    const desired = await setDesired(fastify, DEVICE_ID, { relay_1: true });
    const reported = await updateReported(fastify, DEVICE_ID, { relay_1: false });

    assert.equal(updateCount, 2);
    assert.deepEqual(desired.desired, { relay_1: true });
    assert.deepEqual(reported.reported, { relay_1: false });
    assert.equal(log.warnCalls.length, 2);
});
