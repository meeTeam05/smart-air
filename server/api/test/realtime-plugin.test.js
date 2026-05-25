import test from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';

import Fastify from 'fastify';

import realtimePlugin, { sendRealtimeEventToClient } from '../src/plugins/realtime.js';

function createEvent(id = '42') {
    return {
        id,
        type: 'telemetry.point',
        device_id: 'aa:bb:cc:dd:ee:ff',
        occurred_at: new Date('2026-05-15T10:00:00Z'),
        payload: { temperature: 27.4 },
    };
}

test('sendRealtimeEventToClient writes event only after current device authorization passes', async () => {
    const writes = [];
    const fastify = {
        db: {
            async query() {
                return { rows: [{}] };
            },
        },
        log: { warn() {} },
    };
    const client = {
        userId: 'user-1',
        lastSentEventId: '0',
        raw: {
            destroyed: false,
            write(chunk) {
                writes.push(chunk);
                return true;
            },
        },
    };

    await sendRealtimeEventToClient(fastify, client, createEvent());

    assert.equal(client.lastSentEventId, '42');
    assert.equal(writes.length, 1);
    assert.match(writes[0], /^id: 42\n/);
});

test('sendRealtimeEventToClient skips unauthorized device events', async () => {
    const writes = [];
    const fastify = {
        db: {
            async query() {
                return { rows: [] };
            },
        },
        log: { warn() {} },
    };
    const client = {
        userId: 'user-1',
        lastSentEventId: '0',
        raw: {
            destroyed: false,
            write(chunk) {
                writes.push(chunk);
                return true;
            },
        },
    };

    await sendRealtimeEventToClient(fastify, client, createEvent());

    assert.equal(client.lastSentEventId, '0');
    assert.equal(writes.length, 0);
});

test('sendRealtimeEventToClient does not resend old events after replay catches up', async () => {
    const writes = [];
    const fastify = {
        db: {
            async query() {
                return { rows: [{}] };
            },
        },
        log: { warn() {} },
    };
    const client = {
        userId: 'user-1',
        lastSentEventId: '42',
        raw: {
            destroyed: false,
            write(chunk) {
                writes.push(chunk);
                return true;
            },
        },
    };

    await sendRealtimeEventToClient(fastify, client, createEvent('42'));

    assert.equal(client.lastSentEventId, '42');
    assert.equal(writes.length, 0);
});

test('realtime plugin reconnects listener after connection error', async () => {
    const originalSetTimeout = globalThis.setTimeout;
    const originalClearTimeout = globalThis.clearTimeout;
    const scheduledDelays = [];

    function createListener() {
        const listener = new EventEmitter();
        listener.queries = [];
        listener.released = false;
        listener.query = async (sql) => {
            listener.queries.push(sql);
            return { rows: [] };
        };
        listener.release = () => {
            listener.released = true;
        };
        return listener;
    }

    const listeners = [createListener(), createListener()];
    let connectCount = 0;

    const app = Fastify({ logger: false });
    app.decorate('db', {
        async connect() {
            return listeners[connectCount++];
        },
        async query() {
            return { rows: [] };
        },
    });

    try {
        await app.register(realtimePlugin);
        globalThis.setTimeout = (fn, delay = 0, ...args) => {
            scheduledDelays.push(delay);
            Promise.resolve().then(() => fn(...args));
            return { delay };
        };
        globalThis.clearTimeout = () => {};
        listeners[0].emit('error', new Error('listener dropped'));
        await new Promise((resolve) => setImmediate(resolve));
        await new Promise((resolve) => setImmediate(resolve));

        assert.equal(connectCount, 2);
        assert.ok(scheduledDelays.length >= 1);
        assert.ok(listeners[0].released);
        assert.ok(listeners[1].queries.some((sql) => sql.startsWith('LISTEN ')));
        assert.ok(app.realtimeReadyAt);
    } finally {
        globalThis.setTimeout = originalSetTimeout;
        globalThis.clearTimeout = originalClearTimeout;
        await app.close();
    }
});

test('realtime plugin rejects new streams when max client capacity is reached', async () => {
    function createListener() {
        const listener = new EventEmitter();
        listener.query = async () => ({ rows: [] });
        listener.release = () => {};
        return listener;
    }

    const app = Fastify({ logger: false });
    app.decorate('db', {
        async connect() {
            return createListener();
        },
        async query() {
            return { rows: [] };
        },
    });

    process.env.REALTIME_MAX_CLIENTS = '1';

    const firstReply = {
        hijacked: false,
        raw: {
            destroyed: false,
            headers: null,
            writes: [],
            writeHead(statusCode, headers) {
                this.headers = { statusCode, headers };
            },
            write(chunk) {
                this.writes.push(chunk);
            },
            end() {},
        },
        hijack() {
            this.hijacked = true;
        },
    };
    const firstRequest = {
        ip: '127.0.0.1',
        user: { sub: 'user-1' },
        headers: {},
        query: {},
        raw: { on() {} },
    };

    const secondReply = {
        statusCode: null,
        payload: null,
        code(statusCode) {
            this.statusCode = statusCode;
            return this;
        },
        send(payload) {
            this.payload = payload;
            return payload;
        },
    };
    const secondRequest = {
        ip: '127.0.0.2',
        user: { sub: 'user-2' },
        headers: {},
        query: {},
        raw: { on() {} },
    };

    try {
        await app.register(realtimePlugin);

        await app.realtime.openStream(firstRequest, firstReply);
        const result = await app.realtime.openStream(secondRequest, secondReply);

        assert.equal(firstReply.hijacked, true);
        assert.equal(secondReply.statusCode, 503);
        assert.deepEqual(result, { error: 'Realtime capacity exceeded' });
        assert.equal(app.realtime.clientCount(), 1);
    } finally {
        delete process.env.REALTIME_MAX_CLIENTS;
        await app.close();
    }
});

test('realtime plugin rejects excess streams from the same IP before global capacity is hit', async () => {
    function createListener() {
        const listener = new EventEmitter();
        listener.query = async () => ({ rows: [] });
        listener.release = () => {};
        return listener;
    }

    const app = Fastify({ logger: false });
    app.decorate('db', {
        async connect() {
            return createListener();
        },
        async query() {
            return { rows: [] };
        },
    });

    process.env.REALTIME_MAX_CLIENTS = '5';
    process.env.REALTIME_MAX_CLIENTS_PER_IP = '1';

    const firstReply = {
        hijacked: false,
        raw: {
            destroyed: false,
            headers: null,
            writes: [],
            writeHead(statusCode, headers) {
                this.headers = { statusCode, headers };
            },
            write(chunk) {
                this.writes.push(chunk);
            },
            end() {},
        },
        hijack() {
            this.hijacked = true;
        },
    };
    const firstRequest = {
        ip: '127.0.0.1',
        user: { sub: 'user-1' },
        headers: {},
        query: {},
        raw: { on() {} },
    };

    const secondReply = {
        statusCode: null,
        payload: null,
        code(statusCode) {
            this.statusCode = statusCode;
            return this;
        },
        send(payload) {
            this.payload = payload;
            return payload;
        },
    };
    const secondRequest = {
        ip: '127.0.0.1',
        user: { sub: 'user-2' },
        headers: {},
        query: {},
        raw: { on() {} },
    };

    try {
        await app.register(realtimePlugin);

        await app.realtime.openStream(firstRequest, firstReply);
        const result = await app.realtime.openStream(secondRequest, secondReply);

        assert.equal(firstReply.hijacked, true);
        assert.equal(secondReply.statusCode, 429);
        assert.deepEqual(result, { error: 'Realtime per-IP capacity exceeded' });
        assert.equal(app.realtime.clientCount(), 1);
    } finally {
        delete process.env.REALTIME_MAX_CLIENTS;
        delete process.env.REALTIME_MAX_CLIENTS_PER_IP;
        await app.close();
    }
});
