import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';

import healthRoutes from '../src/routes/health.js';

function createApp({ realtimeReadyAt }) {
    const app = Fastify({ logger: false });
    app.decorate('mqttReadyAt', Date.now());
    app.decorate('realtimeReadyAt', realtimeReadyAt);
    app.decorate('db', {
        async query() {
            return { rows: [{}] };
        },
    });
    app.decorate('redis', {
        async ping() {
            return 'PONG';
        },
    });
    return app;
}

test('readiness includes realtime listener status', async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => ({ ok: true, status: 200, async text() { return 'ok'; } });

    const app = createApp({ realtimeReadyAt: Date.now() });
    try {
        await app.register(healthRoutes);

        const res = await app.inject({ method: 'GET', url: '/health/ready' });

        assert.equal(res.statusCode, 200);
        assert.equal(res.json().checks.emqx, 'ok');
        assert.equal(res.json().checks.realtime, 'ok');
    } finally {
        globalThis.fetch = originalFetch;
        await app.close();
    }
});

test('readiness degrades when realtime listener is not ready', async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => ({ ok: true, status: 200, async text() { return 'ok'; } });

    const app = createApp({ realtimeReadyAt: null });
    try {
        await app.register(healthRoutes);

        const res = await app.inject({ method: 'GET', url: '/health/ready' });

        assert.equal(res.statusCode, 503);
        assert.equal(res.json().checks.realtime, 'fail');
    } finally {
        globalThis.fetch = originalFetch;
        await app.close();
    }
});

test('readiness degrades when EMQX admin API health probe fails', async () => {
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async () => ({ ok: false, status: 503, async text() { return 'down'; } });

    const app = createApp({ realtimeReadyAt: Date.now() });
    try {
        await app.register(healthRoutes);

        const res = await app.inject({ method: 'GET', url: '/health/ready' });

        assert.equal(res.statusCode, 503);
        assert.equal(res.json().checks.emqx, 'fail');
    } finally {
        globalThis.fetch = originalFetch;
        await app.close();
    }
});
