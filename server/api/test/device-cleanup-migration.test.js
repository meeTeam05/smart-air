import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const migrationPath = path.resolve(__dirname, '../../db/migrations/012_device_cleanup_outbox_trigger.sql');

test('device cleanup migration creates an AFTER DELETE outbox trigger', async () => {
    const sql = await readFile(migrationPath, 'utf8');

    assert.match(sql, /CREATE OR REPLACE FUNCTION enqueue_emqx_device_cleanup_job\(\)/);
    assert.match(sql, /CREATE TRIGGER devices_enqueue_emqx_cleanup\s+AFTER DELETE ON devices/i);
    assert.match(sql, /INSERT INTO external_cleanup_jobs \(kind, resource_id\)/);
    assert.match(sql, /'emqx_device_user', OLD\.id/);
    assert.match(sql, /ON CONFLICT \(kind, resource_id\) DO UPDATE/i);
});
