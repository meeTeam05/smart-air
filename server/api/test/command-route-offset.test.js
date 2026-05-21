import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';

import commandsRoutes from '../src/routes/commands.js';

const DEVICE_ID = 'aa:bb:cc:dd:ee:ff';

test('GET /devices/:id/commands clamps oversized offset to PostgreSQL-safe integer range', async () => {
    const app = Fastify({ logger: false });
    const dbCalls = [];

    app.decorate('authenticate', async (request) => {
        request.user = { sub: 'user-1' };
    });
    app.decorate('db', {
        async query(sql, params) {
            dbCalls.push({ sql, params });
            if (sql.includes('SELECT 1 FROM devices d')) {
                return { rows: [{ ok: 1 }], rowCount: 1 };
            }
            if (sql.includes('FROM commands WHERE device_id = $1')) {
                return { rows: [], rowCount: 0 };
            }
            throw new Error(`Unexpected SQL: ${sql}`);
        },
    });

    try {
        await app.register(commandsRoutes);

        const res = await app.inject({
            method: 'GET',
            url: `/devices/${DEVICE_ID}/commands?offset=999999999999999999999&limit=10`,
        });

        assert.equal(res.statusCode, 200);
        const commandQuery = dbCalls.find((call) => call.sql.includes('FROM commands WHERE device_id = $1'));
        assert.ok(commandQuery, 'commands query missing');
        assert.equal(commandQuery.params[1], 10);
        assert.equal(commandQuery.params[2], 2_147_483_647);
    } finally {
        await app.close();
    }
});
