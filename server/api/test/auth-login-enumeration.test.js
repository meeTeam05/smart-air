import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';
import bcrypt from 'bcryptjs';

import authRoutes from '../src/routes/auth.js';

test('auth login compares against dummy hash when user is missing', async () => {
    const app = Fastify({ logger: false });
    const originalCompare = bcrypt.compare;
    const compareCalls = [];

    app.decorate('db', {
        async query() {
            return { rows: [], rowCount: 0 };
        },
    });

    bcrypt.compare = async (password, hash) => {
        compareCalls.push({ password, hash });
        return false;
    };

    try {
        await app.register(authRoutes);

        const res = await app.inject({
            method: 'POST',
            url: '/auth/login',
            payload: { email: 'user@example.com', password: 'hunter42!' },
        });

        assert.equal(res.statusCode, 401);
        assert.deepEqual(res.json(), { error: 'Invalid credentials' });
        assert.equal(compareCalls.length, 1);
        assert.equal(compareCalls[0].password, 'hunter42!');
        assert.match(compareCalls[0].hash, /^\$2a\$12\$/);
    } finally {
        bcrypt.compare = originalCompare;
        await app.close();
    }
});
