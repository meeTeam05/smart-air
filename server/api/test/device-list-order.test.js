import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';

import devicesRoutes from '../src/routes/devices.js';

test('GET /devices orders by created_at and id for stable pagination', async () => {
    const app = Fastify({ logger: false });
    let seenQuery = null;
    let seenParams = null;

    app.decorate('authenticate', async (request) => {
        request.user = { sub: 'user-1' };
    });
    app.decorate('db', {
        async query(sql, params = []) {
            seenQuery = sql;
            seenParams = params;
            return { rows: [], rowCount: 0 };
        },
    });

    await app.register(devicesRoutes);

    const res = await app.inject({
        method: 'GET',
        url: '/devices?limit=10&offset=5',
    });

    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.json(), []);
    assert.match(seenQuery, /ORDER BY d\.created_at,\s*d\.id LIMIT \$2 OFFSET \$3/);
    assert.deepEqual(seenParams, ['user-1', 10, 5]);

    await app.close();
});
