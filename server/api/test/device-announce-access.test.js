import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';

import devicesRoutes from '../src/routes/devices.js';

const DEVICE_ID = 'aa:bb:cc:dd:ee:ff';

function createApp({ userId = 'user-1', hasAccess = true, announcedValue = '1' } = {}) {
    const app = Fastify({ logger: false });
    let redisGets = 0;

    app.decorate('authenticate', async (request) => {
        request.user = { sub: userId };
    });
    app.decorate('db', {
        async query(sql, params) {
            if (sql.includes('SELECT 1 FROM devices d')) {
                assert.equal(params[0], DEVICE_ID);
                return { rows: hasAccess ? [{ ok: 1 }] : [], rowCount: hasAccess ? 1 : 0 };
            }
            throw new Error(`Unexpected SQL: ${sql}`);
        },
    });
    app.decorate('redis', {
        async get(key) {
            redisGets += 1;
            assert.equal(key, `announce:${DEVICE_ID}`);
            return announcedValue;
        },
    });

    return {
        app,
        async register() {
            await app.register(devicesRoutes);
        },
        get redisGets() {
            return redisGets;
        },
    };
}

test('GET /devices/announce/:mac returns announce state for authorized device member', async () => {
    const ctx = createApp({ hasAccess: true, announcedValue: 'online' });

    try {
        await ctx.register();
        const res = await ctx.app.inject({ method: 'GET', url: `/devices/announce/${DEVICE_ID}` });

        assert.equal(res.statusCode, 200);
        assert.deepEqual(res.json(), { announced: true });
        assert.equal(ctx.redisGets, 1);
    } finally {
        await ctx.app.close();
    }
});

test('GET /devices/announce/:mac rejects non-members before reading Redis', async () => {
    const ctx = createApp({ hasAccess: false });

    try {
        await ctx.register();
        const res = await ctx.app.inject({ method: 'GET', url: `/devices/announce/${DEVICE_ID}` });

        assert.equal(res.statusCode, 403);
        assert.deepEqual(res.json(), { error: 'Forbidden' });
        assert.equal(ctx.redisGets, 0);
    } finally {
        await ctx.app.close();
    }
});
