import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';

import shadowRoutes from '../src/routes/shadow.js';

const DEVICE_ID = 'aa:bb:cc:dd:ee:ff';

test('PUT /devices/:id/shadow/desired prioritizes reserved key validation before size validation', async () => {
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
            throw new Error(`Unexpected SQL: ${sql}`);
        },
    });

    try {
        await app.register(shadowRoutes);
        const res = await app.inject({
            method: 'PUT',
            url: `/devices/${DEVICE_ID}/shadow/desired`,
            payload: {
                mode: 'on',
                notes: 'x'.repeat(5000),
            },
        });

        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.json(), {
            error: 'Reserved keys detected: mode. Use typed endpoints for device mode and relay control.',
        });
    } finally {
        await app.close();
    }
});
