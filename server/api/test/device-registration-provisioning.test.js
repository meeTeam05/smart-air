import test from 'node:test';
import assert from 'node:assert/strict';

import Fastify from 'fastify';

import devicesRoutes from '../src/routes/devices.js';

const HOME_ID = '11111111-1111-4111-8111-111111111111';
const DEVICE_ID = 'aa:bb:cc:dd:ee:ff';

function installProvisioningFetchMock(handler) {
    const originalFetch = globalThis.fetch;
    const calls = [];
    globalThis.fetch = async (url, options = {}) => {
        calls.push({ url, options });
        return handler(url, options, calls.length);
    };
    return {
        calls,
        restore() {
            globalThis.fetch = originalFetch;
        },
    };
}

function createApp({ withTransaction, dbQuery, redisDel }) {
    const app = Fastify({ logger: false });
    app.decorate('authenticate', async (request) => {
        request.user = { sub: 'user-1' };
    });
    app.decorate('redis', {
        async del(...args) {
            return redisDel ? redisDel(...args) : 1;
        },
    });
    app.decorate('db', {
        async query(sql, params) {
            return dbQuery(sql, params);
        },
    });
    app.decorate('withTransaction', withTransaction);
    return app;
}

test('POST /devices provisions EMQX outside DB transactions and clears staged cleanup job on success', async () => {
    let inTransaction = false;
    let transactionCount = 0;
    const dbQueries = [];
    const fetchMock = installProvisioningFetchMock(async () => {
        assert.equal(inTransaction, false, 'EMQX admin API call must happen outside DB transaction');
        return { ok: true, status: 204, async text() { return ''; } };
    });

    const app = createApp({
        dbQuery: async (sql) => {
            dbQueries.push(sql);
            if (sql.includes('INSERT INTO external_cleanup_jobs')) {
                return { rows: [], rowCount: 1 };
            }
            if (sql.includes('DELETE FROM external_cleanup_jobs')) {
                return { rows: [], rowCount: 1 };
            }
            return { rows: [], rowCount: 0 };
        },
        withTransaction: async (fn) => {
            transactionCount += 1;
            inTransaction = true;
            try {
                const client = {
                    async query(sql) {
                        if (sql.includes('SELECT hm.role')) {
                            return { rows: [{ role: 'admin' }], rowCount: 1 };
                        }
                        if (sql.includes('SELECT 1 FROM devices WHERE id')) {
                            return { rows: [], rowCount: 0 };
                        }
                        if (sql.includes('SELECT COUNT(*)::int AS n FROM devices')) {
                            return { rows: [{ n: 0 }], rowCount: 1 };
                        }
                        if (sql.includes("SELECT id FROM device_types WHERE name = 'smart_air_v1'")) {
                            return { rows: [{ id: 'type-1' }], rowCount: 1 };
                        }
                        if (sql.includes('INSERT INTO devices')) {
                            return {
                                rows: [{
                                    id: DEVICE_ID,
                                    home_id: HOME_ID,
                                    room_id: null,
                                    type_id: 'type-1',
                                    owner_id: 'user-1',
                                    name: 'Bedroom Sensor',
                                    firmware_ver: null,
                                    online: false,
                                    last_seen: null,
                                    created_at: '2026-05-01T10:00:00.000Z',
                                }],
                                rowCount: 1,
                            };
                        }
                        return { rows: [], rowCount: 0 };
                    },
                };
                return await fn(client);
            } finally {
                inTransaction = false;
            }
        },
    });

    try {
        await app.register(devicesRoutes);
        const res = await app.inject({
            method: 'POST',
            url: '/devices',
            payload: {
                device_id: DEVICE_ID,
                name: 'Bedroom Sensor',
                home_id: HOME_ID,
            },
        });

        assert.equal(res.statusCode, 201);
        assert.equal(transactionCount, 2);
        assert.equal(fetchMock.calls.length, 2);
        assert.ok(dbQueries.some((sql) => sql.includes('next_attempt_at')));
        assert.ok(dbQueries.some((sql) => sql.includes('DELETE FROM external_cleanup_jobs')));
    } finally {
        fetchMock.restore();
        await app.close();
    }
});

test('POST /devices cleans up EMQX credentials when DB insert fails after provisioning', async () => {
    let transactionCount = 0;
    const dbQueries = [];
    const redisDeletes = [];
    const fetchMock = installProvisioningFetchMock(async (_url, _options, callNumber) => {
        return { ok: true, status: callNumber <= 2 ? 204 : 204, async text() { return ''; } };
    });

    const app = createApp({
        redisDel: async (...args) => {
            redisDeletes.push(args);
            return 1;
        },
        dbQuery: async (sql, params) => {
            dbQueries.push({ sql, params });
            if (sql.includes('INSERT INTO external_cleanup_jobs')) {
                return { rows: [], rowCount: 1 };
            }
            if (sql.includes('SELECT 1 FROM devices WHERE id = $1 LIMIT 1')) {
                return { rows: [], rowCount: 0 };
            }
            if (sql.includes('DELETE FROM external_cleanup_jobs')) {
                return { rows: [], rowCount: 1 };
            }
            return { rows: [], rowCount: 0 };
        },
        withTransaction: async (fn) => {
            transactionCount += 1;
            const client = {
                async query(sql) {
                    if (sql.includes('SELECT hm.role')) {
                        return { rows: [{ role: 'admin' }], rowCount: 1 };
                    }
                    if (sql.includes('SELECT 1 FROM devices WHERE id')) {
                        return { rows: [], rowCount: 0 };
                    }
                    if (sql.includes('SELECT COUNT(*)::int AS n FROM devices')) {
                        return { rows: [{ n: 0 }], rowCount: 1 };
                    }
                    if (sql.includes("SELECT id FROM device_types WHERE name = 'smart_air_v1'")) {
                        return { rows: [{ id: 'type-1' }], rowCount: 1 };
                    }
                    if (sql.includes('INSERT INTO devices')) {
                        const err = new Error('Device already registered');
                        err.statusCode = 409;
                        throw err;
                    }
                    return { rows: [], rowCount: 0 };
                },
            };
            return await fn(client);
        },
    });

    try {
        await app.register(devicesRoutes);
        const res = await app.inject({
            method: 'POST',
            url: '/devices',
            payload: {
                device_id: DEVICE_ID,
                name: 'Bedroom Sensor',
                home_id: HOME_ID,
            },
        });

        assert.equal(res.statusCode, 409);
        assert.deepEqual(res.json(), { error: 'Device already registered' });
        assert.equal(transactionCount, 2);
        assert.equal(fetchMock.calls.length, 4);
        assert.equal(redisDeletes.length, 1);
        assert.ok(dbQueries.some(({ sql }) => sql.includes('next_attempt_at')));
        assert.ok(dbQueries.some(({ sql }) => sql.includes('DELETE FROM external_cleanup_jobs')));
    } finally {
        fetchMock.restore();
        await app.close();
    }
});

test('POST /devices re-checks owner/admin role before final insert', async () => {
    let transactionCount = 0;
    const fetchMock = installProvisioningFetchMock(async () => {
        return { ok: true, status: 204, async text() { return ''; } };
    });

    const app = createApp({
        redisDel: async () => 1,
        dbQuery: async (sql) => {
            if (sql.includes('INSERT INTO external_cleanup_jobs')) {
                return { rows: [], rowCount: 1 };
            }
            if (sql.includes('SELECT 1 FROM devices WHERE id = $1 LIMIT 1')) {
                return { rows: [], rowCount: 0 };
            }
            if (sql.includes('DELETE FROM external_cleanup_jobs')) {
                return { rows: [], rowCount: 1 };
            }
            return { rows: [], rowCount: 0 };
        },
        withTransaction: async (fn) => {
            transactionCount += 1;
            const role = transactionCount === 1 ? 'admin' : null;
            const client = {
                async query(sql) {
                    if (sql.includes('SELECT hm.role')) {
                        return role
                            ? { rows: [{ role }], rowCount: 1 }
                            : { rows: [], rowCount: 0 };
                    }
                    if (sql.includes('SELECT 1 FROM devices WHERE id')) {
                        return { rows: [], rowCount: 0 };
                    }
                    if (sql.includes('SELECT COUNT(*)::int AS n FROM devices')) {
                        return { rows: [{ n: 0 }], rowCount: 1 };
                    }
                    if (sql.includes("SELECT id FROM device_types WHERE name = 'smart_air_v1'")) {
                        return { rows: [{ id: 'type-1' }], rowCount: 1 };
                    }
                    if (sql.includes('INSERT INTO devices')) {
                        throw new Error('final insert should not run after role loss');
                    }
                    return { rows: [], rowCount: 0 };
                },
            };
            return await fn(client);
        },
    });

    try {
        await app.register(devicesRoutes);
        const res = await app.inject({
            method: 'POST',
            url: '/devices',
            payload: {
                device_id: DEVICE_ID,
                name: 'Bedroom Sensor',
                home_id: HOME_ID,
            },
        });

        assert.equal(res.statusCode, 403);
        assert.deepEqual(res.json(), { error: 'Forbidden' });
        assert.equal(transactionCount, 2);
        assert.equal(fetchMock.calls.length, 4);
    } finally {
        fetchMock.restore();
        await app.close();
    }
});
