import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import {
    createRealtimeEvent,
    formatSseEvent,
    userCanReplayFromEventId,
} from '../src/services/realtime-events.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const migrationPath = path.resolve(__dirname, '../../db/migrations/013_realtime_events.sql');

test('realtime events migration creates durable outbox table and indexes', async () => {
    const sql = await readFile(migrationPath, 'utf8');

    assert.match(sql, /CREATE TABLE IF NOT EXISTS realtime_events/i);
    assert.match(sql, /id\s+BIGSERIAL\s+PRIMARY KEY/i);
    assert.match(sql, /device_id\s+TEXT\s+NOT NULL/i);
    assert.match(sql, /payload\s+JSONB\s+NOT NULL/i);
    assert.match(sql, /REFERENCES devices\(id\) ON DELETE CASCADE/i);
    assert.match(sql, /CREATE INDEX IF NOT EXISTS realtime_events_device_id_id_idx/i);
    assert.match(sql, /CREATE INDEX IF NOT EXISTS realtime_events_created_at_idx/i);
});

test('createRealtimeEvent inserts event row and notifies realtime channel', async () => {
    const calls = [];
    const occurredAt = new Date('2026-05-15T10:00:00Z');
    const db = {
        async query(sql, params) {
            calls.push({ sql, params });
            if (/INSERT INTO realtime_events/i.test(sql)) {
                return {
                    rows: [{
                        id: '42',
                        type: 'telemetry.point',
                        device_id: 'aa:bb:cc:dd:ee:ff',
                        occurred_at: occurredAt,
                        payload: { temperature: 27.4 },
                    }],
                };
            }
            return { rows: [] };
        },
    };

    const event = await createRealtimeEvent(db, {
        type: 'telemetry.point',
        deviceId: 'aa:bb:cc:dd:ee:ff',
        occurredAt,
        payload: { temperature: 27.4 },
    });

    assert.equal(event.id, '42');
    assert.equal(event.type, 'telemetry.point');
    assert.deepEqual(event.payload, { temperature: 27.4 });
    assert.match(calls[0].sql, /INSERT INTO realtime_events/i);
    assert.match(calls[1].sql, /pg_notify/i);
    assert.deepEqual(calls[1].params, ['realtime_events', '42']);
});

test('formatSseEvent serializes stable id event and json data fields', () => {
    const frame = formatSseEvent({
        id: '42',
        type: 'telemetry.point',
        device_id: 'aa:bb:cc:dd:ee:ff',
        occurred_at: new Date('2026-05-15T10:00:00Z'),
        payload: { temperature: 27.4 },
    });

    assert.equal(
        frame,
        'id: 42\n'
        + 'event: telemetry.point\n'
        + 'data: {"id":"42","type":"telemetry.point","device_id":"aa:bb:cc:dd:ee:ff","occurred_at":"2026-05-15T10:00:00.000Z","payload":{"temperature":27.4}}\n\n'
    );
});

test('userCanReplayFromEventId requires an accessible retained cursor event', async () => {
    const calls = [];
    const fastify = {
        db: {
            async query(sql, params) {
                calls.push({ sql, params });
                return { rows: params[1] === '42' ? [{}] : [] };
            },
        },
    };

    assert.equal(await userCanReplayFromEventId(fastify, 'user-1', '0'), true);
    assert.equal(await userCanReplayFromEventId(fastify, 'user-1', '42'), true);
    assert.equal(await userCanReplayFromEventId(fastify, 'user-1', '43'), false);
    assert.equal(await userCanReplayFromEventId(fastify, 'user-1', 'bad'), false);
    assert.equal(calls.length, 2);
});
