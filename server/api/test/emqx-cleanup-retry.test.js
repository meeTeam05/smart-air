import test from 'node:test';
import assert from 'node:assert/strict';

import { runEmqxCleanupRetry } from '../src/jobs/emqx-cleanup-retry.js';

const DEVICE_ID = 'aa:bb:cc:dd:ee:ff';

function createLogger() {
    return {
        warnCalls: [],
        errorCalls: [],
        info() {},
        warn(...args) {
            this.warnCalls.push(args);
        },
        error(...args) {
            this.errorCalls.push(args);
        },
    };
}

test('legacy Redis cleanup drain failure does not block DB-backed cleanup jobs', async () => {
    const originalFetch = globalThis.fetch;
    const log = createLogger();
    let emqxDeleteCalls = 0;
    const dbQueries = [];

    globalThis.fetch = async () => {
        emqxDeleteCalls += 1;
        return { ok: true, status: 204, async text() { return ''; } };
    };

    const fastify = {
        log,
        redis: {
            async smembers() {
                throw new Error('redis smembers failed');
            },
            async del() {
                return 1;
            },
        },
        db: {
            async query(sql) {
                dbQueries.push(sql);
                if (sql.includes('FROM external_cleanup_jobs')) {
                    return { rows: [{ resource_id: DEVICE_ID }], rowCount: 1 };
                }
                if (sql.includes('DELETE FROM external_cleanup_jobs')) {
                    return { rows: [], rowCount: 1 };
                }
                return { rows: [], rowCount: 0 };
            },
        },
    };

    try {
        await runEmqxCleanupRetry(fastify, 10);

        assert.equal(log.warnCalls.length, 1);
        assert.equal(log.errorCalls.length, 0);
        assert.equal(emqxDeleteCalls, 2);
        assert.ok(dbQueries.some((sql) => sql.includes('FROM external_cleanup_jobs')));
        assert.ok(dbQueries.some((sql) => sql.includes('DELETE FROM external_cleanup_jobs')));
    } finally {
        globalThis.fetch = originalFetch;
    }
});
