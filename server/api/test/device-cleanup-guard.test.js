import test from 'node:test';
import assert from 'node:assert/strict';

import { cleanupDeletedDevice } from '../src/services/device-cleanup.js';

test('cleanupDeletedDevice clears staged cleanup job without deleting EMQX user when device row still exists', async () => {
    const originalFetch = globalThis.fetch;
    const dbQueries = [];
    let redisCalls = 0;
    let fetchCalls = 0;

    globalThis.fetch = async () => {
        fetchCalls += 1;
        return { ok: true, status: 204, async text() { return ''; } };
    };

    const fastify = {
        log: {
            warn() {},
            error() {},
        },
        redis: {
            async del() {
                redisCalls += 1;
                return 1;
            },
        },
        db: {
            async query(sql) {
                dbQueries.push(sql);
                if (sql.includes('SELECT 1 FROM devices WHERE id = $1 LIMIT 1')) {
                    return { rows: [{}], rowCount: 1 };
                }
                if (sql.includes('DELETE FROM external_cleanup_jobs')) {
                    return { rows: [], rowCount: 1 };
                }
                return { rows: [], rowCount: 0 };
            },
        },
    };

    try {
        await cleanupDeletedDevice(fastify, 'aa:bb:cc:dd:ee:ff');

        assert.equal(redisCalls, 0);
        assert.equal(fetchCalls, 0);
        assert.ok(dbQueries.some((sql) => sql.includes('DELETE FROM external_cleanup_jobs')));
    } finally {
        globalThis.fetch = originalFetch;
    }
});
