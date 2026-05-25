import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';
import bcrypt from 'bcryptjs';

import authRoutes from '../src/routes/auth.js';

test('auth register rejects full_name values longer than 255 characters', async () => {
    const app = Fastify({ logger: false });
    const originalHash = bcrypt.hash;
    let hashCalls = 0;
    let queryCalls = 0;

    app.decorate('db', {
        async query() {
            queryCalls += 1;
            return { rows: [], rowCount: 0 };
        },
    });

    bcrypt.hash = async () => {
        hashCalls += 1;
        return 'hashed-password';
    };

    try {
        await app.register(authRoutes);

        const res = await app.inject({
            method: 'POST',
            url: '/auth/register',
            payload: {
                email: 'user@example.com',
                password: 'hunter42!',
                full_name: 'a'.repeat(256),
            },
        });

        assert.equal(res.statusCode, 400);
        assert.deepEqual(res.json(), { error: 'full_name must be 255 characters or less' });
        assert.equal(hashCalls, 0);
        assert.equal(queryCalls, 0);
    } finally {
        bcrypt.hash = originalHash;
        await app.close();
    }
});
