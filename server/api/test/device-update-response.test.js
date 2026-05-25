import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';

import devicesRoutes from '../src/routes/devices.js';

const DEVICE_ID = 'aa:bb:cc:dd:ee:ff';

test('PUT /devices/:id returns the full public device model including created_at', async () => {
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
            if (sql.includes('UPDATE devices SET')) {
                assert.deepEqual(params, [true, 'Bedroom Sensor', false, null, DEVICE_ID]);
                assert.match(sql, /RETURNING .*created_at/i);
                return {
                    rows: [{
                        id: DEVICE_ID,
                        name: 'Bedroom Sensor',
                        home_id: '11111111-1111-4111-8111-111111111111',
                        room_id: '22222222-2222-4222-8222-222222222222',
                        online: true,
                        last_seen: new Date('2026-05-18T10:00:00.000Z'),
                        firmware_ver: '1.2.3',
                        created_at: new Date('2026-05-01T08:00:00.000Z'),
                    }],
                    rowCount: 1,
                };
            }
            throw new Error(`Unexpected SQL: ${sql}`);
        },
    });

    try {
        await app.register(devicesRoutes);
        const res = await app.inject({
            method: 'PUT',
            url: `/devices/${DEVICE_ID}`,
            payload: { name: 'Bedroom Sensor' },
        });

        assert.equal(res.statusCode, 200);
        assert.deepEqual(res.json(), {
            id: DEVICE_ID,
            name: 'Bedroom Sensor',
            home_id: '11111111-1111-4111-8111-111111111111',
            room_id: '22222222-2222-4222-8222-222222222222',
            online: true,
            last_seen: '2026-05-18T10:00:00.000Z',
            firmware_ver: '1.2.3',
            created_at: '2026-05-01T08:00:00.000Z',
        });
    } finally {
        await app.close();
    }
});
