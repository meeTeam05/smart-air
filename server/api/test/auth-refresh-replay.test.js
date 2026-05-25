import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';

import Fastify from 'fastify';
import cookie from '@fastify/cookie';

import authRoutes from '../src/routes/auth.js';

function hashRefreshToken(token) {
    return crypto.createHash('sha256').update(token).digest('hex');
}

test('refresh token replay marker revokes active sessions on reuse', async () => {
    const app = Fastify({ logger: false });
    const token = 'old-refresh-token';
    const tokenHash = hashRefreshToken(token);
    const markers = new Map();
    let activeToken = {
        id: 'refresh-token-row',
        user_id: 'user-1',
        email: 'user@example.com',
        expires_at: new Date(Date.now() + 60_000),
    };
    let revokedAllSessions = false;

    const client = {
        async query(sql, params = []) {
            if (sql.includes('FROM refresh_tokens rt')) {
                return {
                    rows: activeToken && params[0] === tokenHash ? [activeToken] : [],
                };
            }
            if (sql.includes('INSERT INTO refresh_token_reuse_markers')) {
                markers.set(params[0], params[1]);
                return { rows: [], rowCount: 1 };
            }
            if (sql.includes('DELETE FROM refresh_tokens WHERE id')) {
                const matched = activeToken?.id === params[0];
                activeToken = null;
                return { rows: matched ? [{ id: params[0] }] : [], rowCount: matched ? 1 : 0 };
            }
            if (sql.includes('INSERT INTO refresh_tokens')) {
                return { rows: [], rowCount: 1 };
            }
            if (sql.includes('FROM refresh_token_reuse_markers')) {
                return {
                    rows: markers.has(params[0]) ? [{ user_id: markers.get(params[0]) }] : [],
                };
            }
            if (sql.includes('DELETE FROM refresh_tokens WHERE user_id')) {
                revokedAllSessions = true;
                activeToken = null;
                return { rows: [], rowCount: 1 };
            }
            return { rows: [], rowCount: 0 };
        },
    };

    app.decorate('db', { async query() { return { rows: [] }; } });
    app.decorate('withTransaction', async (fn) => fn(client));
    app.decorate('jwt', { sign: () => 'access-token' });
    app.decorate('authenticate', async () => {});
    await app.register(cookie);
    await app.register(authRoutes);

    const first = await app.inject({
        method: 'POST',
        url: '/auth/refresh',
        payload: { refreshToken: token },
    });
    assert.equal(first.statusCode, 200);
    assert.equal(markers.get(tokenHash), 'user-1');

    const replay = await app.inject({
        method: 'POST',
        url: '/auth/refresh',
        payload: { refreshToken: token },
    });
    assert.equal(replay.statusCode, 401);
    assert.equal(revokedAllSessions, true);

    await app.close();
});

test('recently consumed refresh token does not revoke newly rotated session', async () => {
    const app = Fastify({ logger: false });
    const token = 'old-refresh-token';
    const tokenHash = hashRefreshToken(token);
    const markers = new Map();
    let activeToken = {
        id: 'refresh-token-row',
        user_id: 'user-1',
        email: 'user@example.com',
        expires_at: new Date(Date.now() + 60_000),
    };
    let revokedAllSessions = false;

    const client = {
        async query(sql, params = []) {
            if (sql.includes('FROM refresh_tokens rt')) {
                return {
                    rows: activeToken && params[0] === tokenHash ? [activeToken] : [],
                };
            }
            if (sql.includes('INSERT INTO refresh_token_reuse_markers')) {
                markers.set(params[0], { user_id: params[1], consumed_at: new Date() });
                return { rows: [], rowCount: 1 };
            }
            if (sql.includes('DELETE FROM refresh_tokens WHERE id')) {
                const matched = activeToken?.id === params[0];
                activeToken = null;
                return { rows: matched ? [{ id: params[0] }] : [], rowCount: matched ? 1 : 0 };
            }
            if (sql.includes('INSERT INTO refresh_tokens')) {
                return { rows: [], rowCount: 1 };
            }
            if (sql.includes('FROM refresh_token_reuse_markers')) {
                return {
                    rows: markers.has(params[0]) ? [markers.get(params[0])] : [],
                };
            }
            if (sql.includes('DELETE FROM refresh_tokens WHERE user_id')) {
                revokedAllSessions = true;
                activeToken = null;
                return { rows: [], rowCount: 1 };
            }
            return { rows: [], rowCount: 0 };
        },
    };

    app.decorate('db', { async query() { return { rows: [] }; } });
    app.decorate('withTransaction', async (fn) => fn(client));
    app.decorate('jwt', { sign: () => 'access-token' });
    app.decorate('authenticate', async () => {});
    await app.register(cookie);
    await app.register(authRoutes);

    const first = await app.inject({
        method: 'POST',
        url: '/auth/refresh',
        payload: { refreshToken: token },
    });
    assert.equal(first.statusCode, 200);

    const concurrentRetry = await app.inject({
        method: 'POST',
        url: '/auth/refresh',
        payload: { refreshToken: token },
    });
    assert.equal(concurrentRetry.statusCode, 401);
    assert.equal(revokedAllSessions, false);

    await app.close();
});
