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
    assert.equal(reported.applied, true);
    assert.deepEqual(reported.shadow.reported, { relay_1: false });
    assert.equal(log.warnCalls.length, 2);
});

test('updateReported guards stale shadow reports by payload ts', async () => {
    const redisWrites = [];
    let selectCount = 0;
    let upsertSql = null;
    const currentRow = {
        reported: { mode: 'off', relay_1: false, ts: 200 },
        desired: { relay_1: false },
        updated_at: new Date('2026-05-01T00:00:00Z'),
    };
    const fastify = {
        log: createLogger(),
        redis: {
            async set(key, value) {
                redisWrites.push({ key, value: JSON.parse(value) });
            },
        },
        db: {
            async query(sql, params) {
                if (sql.includes('INSERT INTO device_shadows')) {
                    upsertSql = sql;
                    assert.equal(params[0], DEVICE_ID);
                    assert.equal(params[2], 100);
                    return { rows: [], rowCount: 0 };
                }
                if (sql.includes('SELECT reported, desired, updated_at FROM device_shadows')) {
                    selectCount += 1;
                    assert.deepEqual(params, [DEVICE_ID]);
                    return { rows: [currentRow] };
                }
                throw new Error(`Unexpected SQL: ${sql}`);
            },
        },
    };

    const result = await updateReported(fastify, DEVICE_ID, { mode: 'on', relay_1: true, ts: 100 });

    assert.match(upsertSql, /WHERE COALESCE\(/);
    assert.equal(selectCount, 1);
    assert.equal(result.applied, false);
    assert.deepEqual(result.shadow.reported, currentRow.reported);
    assert.equal(redisWrites.length, 1);
    assert.deepEqual(redisWrites[0].value.reported, currentRow.reported);
});
