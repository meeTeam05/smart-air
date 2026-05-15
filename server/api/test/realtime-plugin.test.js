import test from 'node:test';
import assert from 'node:assert/strict';

import { sendRealtimeEventToClient } from '../src/plugins/realtime.js';

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
