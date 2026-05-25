import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';
import bcrypt from 'bcryptjs';
import cookie from '@fastify/cookie';

async function loadAuthRoutesWithRefreshDays(refreshDays) {
    const envName = 'REFRESH_TOKEN_EXPIRES_DAYS';
    const previous = process.env[envName];

    if (refreshDays === undefined) {
        delete process.env[envName];
    } else {
        process.env[envName] = refreshDays;
    }

    try {
        const authUrl = new URL(`../src/routes/auth.js?refresh-days=${Date.now()}-${Math.random()}`, import.meta.url);
        const mod = await import(authUrl.href);
        return mod.default;
    } finally {
        if (previous === undefined) {
            delete process.env[envName];
        } else {
            process.env[envName] = previous;
        }
    }
}

test('auth routes fall back to 30-day refresh expiry when env is invalid', async () => {
    const authRoutes = await loadAuthRoutesWithRefreshDays('thirty');
    const app = Fastify({ logger: false });
    const password = 'hunter42!';
    const passwordHash = bcrypt.hashSync(password, 4);
    let insertedExpiry = null;

    app.decorate('db', {
        async query(sql, params = []) {
            if (sql.includes('FROM users WHERE email = $1')) {
                return {
                    rows: [{
                        id: 'user-1',
                        email: params[0],
                        password_hash: passwordHash,
                        full_name: 'User One',
                        is_active: true,
                    }],
                };
            }

            if (sql.includes('INSERT INTO refresh_tokens')) {
                insertedExpiry = params[2];
                return { rows: [], rowCount: 1 };
            }

            throw new Error(`Unexpected SQL: ${sql}`);
        },
    });
    app.decorate('jwt', { sign: () => 'access-token' });

    await app.register(cookie);
    await app.register(authRoutes);

    try {
        const before = Date.now();
        const res = await app.inject({
            method: 'POST',
            url: '/auth/login',
            payload: { email: 'user@example.com', password },
        });

        assert.equal(res.statusCode, 200);
        assert.ok(insertedExpiry instanceof Date);
        assert.ok(Number.isFinite(insertedExpiry.getTime()));
        assert.ok(insertedExpiry.getTime() > before);
        assert.match(res.headers['set-cookie'], /Max-Age=2592000/);
    } finally {
        await app.close();
    }
});
