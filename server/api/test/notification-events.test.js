import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

import { createRealtimeEvent } from '../src/services/realtime-events.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const migrationPath = path.resolve(__dirname, '../../db/migrations/016_notification_events.sql');

test('notification events migration creates durable projection table', async () => {
    const sql = await readFile(migrationPath, 'utf8');

    assert.match(sql, /CREATE TABLE IF NOT EXISTS notification_events/i);
    assert.match(sql, /source_event_id\s+BIGINT\s+PRIMARY KEY/i);
    assert.match(sql, /REFERENCES realtime_events\(id\) ON DELETE CASCADE/i);
    assert.match(sql, /device_name_snapshot\s+VARCHAR NOT NULL/i);
    assert.match(sql, /severity\s+TEXT NOT NULL/i);
    assert.match(sql, /payload\s+JSONB NOT NULL/i);
});

test('createRealtimeEvent projects terminal command updates into notification history', async () => {
    const calls = [];
    const occurredAt = new Date('2026-05-24T13:55:00Z');
    const db = {
        async query(sql, params) {
            calls.push({ sql, params });
            if (/INSERT INTO realtime_events/i.test(sql)) {
                return {
                    rows: [{
                        id: '42',
                        type: 'command.updated',
                        device_id: 'aa:bb:cc:dd:ee:ff',
                        occurred_at: occurredAt,
                        payload: {
                            command_id: 'cmd-1',
                            status: 'done',
                            payload: {
                                type: 'relay_set',
                                relay: 1,
                                state: true,
                            },
                        },
                    }],
                };
            }
            if (/SELECT name FROM devices WHERE id = \$1/i.test(sql)) {
                return { rows: [{ name: 'Living Room Air' }] };
            }
            if (/INSERT INTO notification_events/i.test(sql)) {
                return { rows: [] };
            }
            if (/SELECT pg_notify/i.test(sql)) {
                return { rows: [] };
            }
            throw new Error(`Unexpected SQL: ${sql}`);
        },
    };

    await createRealtimeEvent(db, {
        type: 'command.updated',
        deviceId: 'aa:bb:cc:dd:ee:ff',
        occurredAt,
        payload: {
            command_id: 'cmd-1',
            status: 'done',
            payload: {
                type: 'relay_set',
                relay: 1,
                state: true,
            },
        },
    });

    const notificationInsert = calls.find(({ sql }) => /INSERT INTO notification_events/i.test(sql));
    assert.ok(notificationInsert, 'expected notification_events insert');
    assert.deepEqual(
        notificationInsert.params.slice(0, 7),
        [
            '42',
            'command.done',
            'aa:bb:cc:dd:ee:ff',
            'Living Room Air',
            'Relay 1 turned on',
            'Command completed successfully.',
            'success',
        ]
    );
});

test('createRealtimeEvent skips notification projection for telemetry points', async () => {
    const calls = [];
    const db = {
        async query(sql, params) {
            calls.push({ sql, params });
            if (/INSERT INTO realtime_events/i.test(sql)) {
                return {
                    rows: [{
                        id: '99',
                        type: 'telemetry.point',
                        device_id: 'aa:bb:cc:dd:ee:ff',
                        occurred_at: new Date('2026-05-24T13:55:00Z'),
                        payload: { temperature: 27.4 },
                    }],
                };
            }
            if (/SELECT pg_notify/i.test(sql)) {
                return { rows: [] };
            }
            throw new Error(`Unexpected SQL: ${sql}`);
        },
    };

    await createRealtimeEvent(db, {
        type: 'telemetry.point',
        deviceId: 'aa:bb:cc:dd:ee:ff',
        payload: { temperature: 27.4 },
    });

    assert.equal(
        calls.some(({ sql }) => /INSERT INTO notification_events/i.test(sql)),
        false
    );
});
