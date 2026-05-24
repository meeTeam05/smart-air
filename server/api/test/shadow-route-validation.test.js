import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';

import shadowRoutes from '../src/routes/shadow.js';

const DEVICE_ID = 'aa:bb:cc:dd:ee:ff';

function buildApp({ shadowRow = null } = {}) {
    const app = Fastify({ logger: false });

    app.decorate('authenticate', async (request) => {
        request.user = { sub: 'user-1' };
    });
    app.decorate('db', {
        async query(sql, params) {
            if (sql.includes('SELECT 1 FROM devices d')) {
                assert.deepEqual(params, [DEVICE_ID, 'user-1']);
                return { rows: [{ ok: 1 }], rowCount: 1 };
            }
            if (sql.includes('FROM device_shadows')) {
                assert.deepEqual(params, [DEVICE_ID]);
                return shadowRow
                    ? { rows: [shadowRow], rowCount: 1 }
                    : { rows: [], rowCount: 0 };
            }
            if (sql.includes('INSERT INTO device_shadows')) {
                assert.deepEqual(params, [DEVICE_ID, JSON.stringify({ mode: 'on', relay_1: true })]);
                return {
                    rows: [{
                        reported: {},
                        desired: { mode: 'on', relay_1: true },
                        updated_at: '2026-05-24T00:00:00.000Z',
                        cache_version: '2026-05-24T00:00:00.000000Z',
                    }],
                    rowCount: 1,
                };
            }
            if (sql.includes('SELECT online FROM devices')) {
                assert.deepEqual(params, [DEVICE_ID]);
                return { rows: [{ online: true }], rowCount: 1 };
            }
            throw new Error(`Unexpected SQL: ${sql}`);
        },
    });
    app.decorate('redis', {
        async get(key) {
            assert.equal(key, `shadow:${DEVICE_ID}`);
            return null;
        },
        async eval(_script, _keyCount, key) {
            assert.equal(key, `shadow:${DEVICE_ID}`);
            return 1;
        },
        async del() {
            return 1;
        },
    });
    app.decorate('mqttPublish', async (topic, payload) => {
        app.lastPublish = { topic, payload: JSON.parse(payload) };
    });

    return app;
}

test('PUT /devices/:id/shadow/desired accepts supported device keys', async () => {
    const app = buildApp();

    try {
        await app.register(shadowRoutes);
        const res = await app.inject({
            method: 'PUT',
            url: `/devices/${DEVICE_ID}/shadow/desired`,
            payload: {
                mode: 'on',
                relay_1: true,
            },
        });

        assert.equal(res.statusCode, 200);
        assert.deepEqual(res.json(), { success: true });
        assert.deepEqual(app.lastPublish, {
            topic: `device/${DEVICE_ID}/shadow/get_response`,
            payload: {
                desired: { mode: 'on', relay_1: true },
                delta: { mode: 'on', relay_1: true },
                ts: app.lastPublish.payload.ts,
            },
        });
        assert.equal(typeof app.lastPublish.payload.ts, 'number');
    } finally {
        await app.close();
    }
});

test('PUT /devices/:id/shadow/desired rejects unsupported keys before size validation', async () => {
    const app = buildApp();

    try {
        await app.register(shadowRoutes);
        const res = await app.inject({
            method: 'PUT',
            url: `/devices/${DEVICE_ID}/shadow/desired`,
            payload: {
                fan_speed: 3,
                notes: 'x'.repeat(5000),
            },
        });

        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.json(), {
            error: 'Unsupported desired keys: fan_speed, notes. Supported keys: mode, relay_1, relay_2, relay_3.',
        });
    } finally {
        await app.close();
    }
});

test('PUT /devices/:id/shadow/desired rejects relay=true when payload mode is off', async () => {
    const app = buildApp();

    try {
        await app.register(shadowRoutes);
        const res = await app.inject({
            method: 'PUT',
            url: `/devices/${DEVICE_ID}/shadow/desired`,
            payload: {
                mode: 'off',
                relay_1: true,
            },
        });

        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.json(), {
            error: 'relay_1 cannot be true when effective desired mode is off',
        });
    } finally {
        await app.close();
    }
});

test('PUT /devices/:id/shadow/desired rejects relay=true when stored mode is off', async () => {
    const app = buildApp({
        shadowRow: {
            reported: { mode: 'off', relay_1: false },
            desired: {},
            updated_at: '2026-05-24T00:00:00.000Z',
            cache_version: '2026-05-24T00:00:00.000000Z',
        },
    });

    try {
        await app.register(shadowRoutes);
        const res = await app.inject({
            method: 'PUT',
            url: `/devices/${DEVICE_ID}/shadow/desired`,
            payload: {
                relay_1: true,
            },
        });

        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.json(), {
            error: 'relay_1 cannot be true when effective desired mode is off',
        });
    } finally {
        await app.close();
    }
});
