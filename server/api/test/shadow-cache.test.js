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
            async eval() {
                return 1;
            },
            async del(key) {
                deletedKeys.push(key);
                return 1;
            },
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
                        cache_version: '2026-05-01T00:00:00.000000Z',
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
    const deletedKeys = [];
    const fastify = {
        log,
        redis: {
            async eval() {
                throw new Error('redis write failed');
            },
            async del(key) {
                deletedKeys.push(key);
                return 1;
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
                        cache_version: '2026-05-01T00:00:00.000000Z',
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
    assert.deepEqual(deletedKeys, [`shadow:${DEVICE_ID}`, `shadow:${DEVICE_ID}`]);
});

test('updateReported guards stale shadow reports by payload ts', async () => {
    const redisWrites = [];
    let selectCount = 0;
    let upsertSql = null;
    const currentRow = {
        reported: { mode: 'off', relay_1: false, ts: 200 },
        desired: { relay_1: false },
        updated_at: new Date('2026-05-01T00:00:00Z'),
        cache_version: '2026-05-01T00:00:00.000000Z',
    };
    const fastify = {
        log: createLogger(),
        redis: {
            async eval(script, keyCount, key, value) {
                redisWrites.push({ script, keyCount, key, value: JSON.parse(value) });
                return 1;
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
                if (sql.includes('SELECT') && sql.includes('FROM device_shadows')) {
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
    assert.equal(redisWrites[0].keyCount, 1);
    assert.deepEqual(redisWrites[0].value.shadow.reported, currentRow.reported);
    assert.equal(redisWrites[0].value.version, currentRow.cache_version);
});

test('updateReported clamps future shadow report ts before storing or ordering', async () => {
    const realDateNow = Date.now;
    Date.now = () => new Date('2026-05-02T03:04:05.000Z').getTime();

    let upsertParams = null;
    const fastify = {
        log: createLogger(),
        redis: {
            async eval() {
                return 1;
            },
        },
        db: {
            async query(sql, params) {
                if (sql.includes('INSERT INTO device_shadows')) {
                    upsertParams = params;
                    return {
                        rows: [{
                            reported: { mode: 'on', relay_1: true, ts: 1777691045 },
                            desired: {},
                            updated_at: new Date('2026-05-02T03:04:05.000Z'),
                            cache_version: '2026-05-02T03:04:05.000000Z',
                        }],
                        rowCount: 1,
                    };
                }
                throw new Error(`Unexpected SQL: ${sql}`);
            },
        },
    };

    try {
        const result = await updateReported(
            fastify,
            DEVICE_ID,
            { mode: 'on', relay_1: true, ts: 4_102_444_800 }
        );

        assert.ok(upsertParams, 'shadow upsert missing');
        assert.equal(upsertParams[2], 1777691045);
        assert.equal(JSON.parse(upsertParams[1]).ts, 1777691045);
        assert.equal(result.applied, true);
        assert.equal(result.shadow.reported.ts, 1777691045);
    } finally {
        Date.now = realDateNow;
    }
});

test('shadow cache writes use updatedAt compare-and-set semantics', async () => {
    const evalCalls = [];
    const fastify = {
        log: createLogger(),
        redis: {
            async eval(script, keyCount, key, serialized, version, ttl) {
                evalCalls.push({ script, keyCount, key, serialized: JSON.parse(serialized), version, ttl });
                return 1;
            },
        },
        db: {
            async query(sql, params) {
                assert.match(sql, /INSERT INTO device_shadows/);
                assert.equal(params[0], DEVICE_ID);
                return {
                    rows: [{
                        reported: {},
                        desired: { relay_1: true },
                        updated_at: new Date('2026-05-02T03:04:05.000Z'),
                        cache_version: '2026-05-02T03:04:05.000123Z',
                    }],
                };
            },
        },
    };

    await setDesired(fastify, DEVICE_ID, { relay_1: true });

    assert.equal(evalCalls.length, 1);
    assert.match(evalCalls[0].script, /decoded\.version/);
    assert.equal(evalCalls[0].keyCount, 1);
    assert.equal(evalCalls[0].key, `shadow:${DEVICE_ID}`);
    assert.deepEqual(evalCalls[0].serialized.shadow.desired, { relay_1: true });
    assert.equal(evalCalls[0].version, '2026-05-02T03:04:05.000123Z');
    assert.equal(evalCalls[0].ttl, String(60 * 60));
});

test('getShadow deduplicates concurrent cache misses into one DB read', async () => {
    let dbReads = 0;
    const evalCalls = [];
    let releaseRead;
    const readGate = new Promise((resolve) => {
        releaseRead = resolve;
    });

    const fastify = {
        log: createLogger(),
        redis: {
            async get() {
                return null;
            },
            async eval(script, keyCount, key, serialized) {
                evalCalls.push({ script, keyCount, key, serialized: JSON.parse(serialized) });
                return 1;
            },
        },
        db: {
            async query(sql, params) {
                assert.match(sql, /FROM device_shadows/);
                assert.deepEqual(params, [DEVICE_ID]);
                dbReads += 1;
                await readGate;
                return {
                    rows: [{
                        reported: { temperature: 25 },
                        desired: { relay_1: true },
                        updated_at: new Date('2026-05-01T00:00:00Z'),
                        cache_version: '2026-05-01T00:00:00.000000Z',
                    }],
                };
            },
        },
    };

    const first = getShadow(fastify, DEVICE_ID);
    const second = getShadow(fastify, DEVICE_ID);
    releaseRead();

    const [left, right] = await Promise.all([first, second]);

    assert.equal(dbReads, 1);
    assert.deepEqual(left, right);
    assert.equal(evalCalls.length, 1);
    assert.equal(evalCalls[0].serialized.version, '2026-05-01T00:00:00.000000Z');
});

test('getShadow reads wrapped cache payloads without DB fallback', async () => {
    let dbReads = 0;
    const fastify = {
        log: createLogger(),
        redis: {
            async get() {
                return JSON.stringify({
                    version: '2026-05-01T00:00:00.123456Z',
                    shadow: {
                        reported: { temperature: 25 },
                        desired: { relay_1: true },
                        updatedAt: '2026-05-01T00:00:00.123Z',
                    },
                });
            },
        },
        db: {
            async query() {
                dbReads += 1;
                return { rows: [] };
            },
        },
    };

    const shadow = await getShadow(fastify, DEVICE_ID);

    assert.equal(dbReads, 0);
    assert.deepEqual(shadow, {
        reported: { temperature: 25 },
        desired: { relay_1: true },
        updatedAt: '2026-05-01T00:00:00.123Z',
    });
});
