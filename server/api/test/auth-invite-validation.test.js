import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';
import cookie from '@fastify/cookie';

import authRoutes from '../src/routes/auth.js';
import homesRoutes from '../src/routes/homes.js';

const HOME_ID = '11111111-1111-4111-8111-111111111111';

test('auth refresh rejects non-string and empty refresh tokens without DB lookup', async () => {
    const app = Fastify({ logger: false });
    let transactionCalls = 0;

    app.decorate('authenticate', async () => {});
    app.decorate('jwt', { sign: () => 'access-token' });
    app.decorate('db', { async query() { return { rows: [] }; } });
    app.decorate('withTransaction', async () => {
        transactionCalls += 1;
        throw new Error('withTransaction should not run for malformed refresh tokens');
    });
    await app.register(cookie);
    await app.register(authRoutes);

    const objectToken = await app.inject({
        method: 'POST',
        url: '/auth/refresh',
        payload: { refreshToken: { token: 'bad' } },
    });
    assert.equal(objectToken.statusCode, 401);
    assert.deepEqual(objectToken.json(), { error: 'Invalid or expired refresh token' });

    const emptyToken = await app.inject({
        method: 'POST',
        url: '/auth/refresh',
        payload: { refreshToken: '   ' },
    });
    assert.equal(emptyToken.statusCode, 401);
    assert.deepEqual(emptyToken.json(), { error: 'Invalid or expired refresh token' });

    assert.equal(transactionCalls, 0);
    await app.close();
});

test('home invite validates email type and normalizes valid email lookup', async () => {
    const app = Fastify({ logger: false });
    const userLookups = [];

    app.decorate('authenticate', async (request) => {
        request.user = { sub: 'owner-1' };
    });
    app.decorate('withTransaction', async (fn) => fn(app.db));
    app.decorate('db', {
        async query(sql, params = []) {
            if (sql.includes('FROM home_members hm')) {
                return { rows: [{ role: 'owner' }], rowCount: 1 };
            }
            if (sql.includes('SELECT id FROM users')) {
                userLookups.push(params[0]);
                return { rows: [], rowCount: 0 };
            }
            return { rows: [], rowCount: 0 };
        },
    });
    await app.register(homesRoutes);

    const malformed = await app.inject({
        method: 'POST',
        url: `/homes/${HOME_ID}/invite`,
        payload: { email: { address: 'user@example.com' } },
    });
    assert.equal(malformed.statusCode, 400);
    assert.deepEqual(malformed.json(), { error: 'valid email required' });
    assert.deepEqual(userLookups, []);

    const missingUser = await app.inject({
        method: 'POST',
        url: `/homes/${HOME_ID}/invite`,
        payload: { email: ' User@Example.COM ' },
    });
    assert.equal(missingUser.statusCode, 200);
    assert.deepEqual(missingUser.json(), { success: true });
    assert.deepEqual(userLookups, ['user@example.com']);

    await app.close();
});
