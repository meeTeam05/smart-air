import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';

import notificationsRoutes from '../src/routes/notifications.js';

test('GET /notifications returns newest-first notification history for the authenticated user', async () => {
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
            return {
                rows: [{
                    id: '42',
                    type: 'command.done',
                    device_id: 'aa:bb:cc:dd:ee:ff',
                    device_name: 'Living Room Air',
                    title: 'Relay 1 turned on',
                    body: 'Command completed successfully.',
                    severity: 'success',
                    occurred_at: '2026-05-24T13:55:00.000Z',
                    payload: { relay: 1, state: true },
                }],
            };
        },
    });

    await app.register(notificationsRoutes);

    const res = await app.inject({
        method: 'GET',
        url: '/notifications?limit=10&before_id=99',
    });

    assert.equal(res.statusCode, 200);
    assert.deepEqual(res.json(), [{
        id: '42',
        type: 'command.done',
        device_id: 'aa:bb:cc:dd:ee:ff',
        device_name: 'Living Room Air',
        title: 'Relay 1 turned on',
        body: 'Command completed successfully.',
        severity: 'success',
        occurred_at: '2026-05-24T13:55:00.000Z',
        payload: { relay: 1, state: true },
    }]);
    assert.match(seenQuery, /FROM notification_events n/i);
    assert.match(seenQuery, /ORDER BY n\.source_event_id DESC/i);
    assert.deepEqual(seenParams, ['user-1', '99', 10]);

    await app.close();
});
