import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';

import devicesRoutes from '../src/routes/devices.js';
import homesRoutes from '../src/routes/homes.js';

const HOME_ID = '11111111-1111-4111-8111-111111111111';
const DEVICE_ID = 'aa:bb:cc:dd:ee:ff';

function installFetchMock() {
    const originalFetch = globalThis.fetch;
    let calls = 0;
    globalThis.fetch = async () => {
        calls += 1;
        return { ok: true, status: 204, async text() { return ''; } };
    };
    return {
        get calls() {
            return calls;
        },
        restore() {
            globalThis.fetch = originalFetch;
        },
    };
}

test('DELETE /devices/:id relies on trigger-backed cleanup job and cleans up after commit', async () => {
    const fetchMock = installFetchMock();
    const app = Fastify({ logger: false });
    const transactionQueries = [];
    let transactionDone = false;
    let redisCleanupAfterCommit = false;

    app.decorate('authenticate', async (request) => {
        request.user = { sub: 'user-1' };
    });
    app.decorate('redis', {
        async del() {
            redisCleanupAfterCommit = transactionDone;
            return 1;
        },
    });
    app.decorate('db', {
        async query() {
            return { rows: [], rowCount: 1 };
        },
    });
    app.decorate('withTransaction', async (fn) => {
        const client = {
            async query(sql) {
                transactionQueries.push(sql);
                if (sql.includes('SELECT id, home_id FROM devices')) {
                    return { rows: [{ id: DEVICE_ID, home_id: HOME_ID }], rowCount: 1 };
                }
                if (sql.includes('SELECT hm.role')) {
                    return { rows: [{ role: 'admin' }], rowCount: 1 };
                }
                if (sql.includes('DELETE FROM devices')) {
                    return { rows: [], rowCount: 1 };
                }
                return { rows: [], rowCount: 0 };
            },
        };
        const result = await fn(client);
        transactionDone = true;
        return result;
    });

    try {
        await app.register(devicesRoutes);
        const res = await app.inject({ method: 'DELETE', url: `/devices/${DEVICE_ID}` });

        assert.equal(res.statusCode, 204);
        assert.equal(redisCleanupAfterCommit, true);
        assert.equal(fetchMock.calls, 2);
        assert.equal(transactionQueries.some((sql) => sql.includes('INSERT INTO external_cleanup_jobs')), false);
        assert.ok(transactionQueries.some((sql) => sql.includes('DELETE FROM devices')));
    } finally {
        fetchMock.restore();
        await app.close();
    }
});

test('DELETE /homes/:id captures device ids under home row lock before cascade delete', async () => {
    const fetchMock = installFetchMock();
    const app = Fastify({ logger: false });
    const transactionQueries = [];
    let transactionDone = false;
    let cleanupCountAfterCommit = 0;

    app.decorate('authenticate', async (request) => {
        request.user = { sub: 'user-1' };
    });
    app.decorate('redis', {
        async del() {
            if (transactionDone) cleanupCountAfterCommit += 1;
            return 1;
        },
    });
    app.decorate('db', {
        async query() {
            return { rows: [], rowCount: 1 };
        },
    });
    app.decorate('withTransaction', async (fn) => {
        const client = {
            async query(sql) {
                transactionQueries.push(sql);
                if (sql.includes('FROM homes h')) {
                    return { rows: [{ id: HOME_ID }], rowCount: 1 };
                }
                if (sql.includes('SELECT id FROM devices')) {
                    return {
                        rows: [
                            { id: DEVICE_ID },
                            { id: '11:22:33:44:55:66' },
                        ],
                        rowCount: 2,
                    };
                }
                if (sql.includes('DELETE FROM homes')) {
                    return { rows: [], rowCount: 1 };
                }
                return { rows: [], rowCount: 0 };
            },
        };
        const result = await fn(client);
        transactionDone = true;
        return result;
    });

    try {
        await app.register(homesRoutes);
        const res = await app.inject({ method: 'DELETE', url: `/homes/${HOME_ID}` });

        assert.equal(res.statusCode, 204);
        assert.equal(cleanupCountAfterCommit, 2);
        assert.equal(fetchMock.calls, 4);
        assert.ok(transactionQueries.some((sql) => sql.includes('FOR UPDATE OF h')));
        assert.ok(transactionQueries.some((sql) => sql.includes('DELETE FROM homes')));
        assert.equal(transactionQueries.some((sql) => sql.includes('INSERT INTO external_cleanup_jobs')), false);
    } finally {
        fetchMock.restore();
        await app.close();
    }
});
