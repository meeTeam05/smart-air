import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { createHash } from 'node:crypto';

import Fastify from 'fastify';

import devicesRoutes from '../src/routes/devices.js';

const DEVICE_ID = 'aa:bb:cc:dd:ee:ff';
const USER_ID = 'user-1';

async function withTempOtaDir(files, run) {
    const dir = await mkdtemp(path.join(os.tmpdir(), 'smart-air-ota-'));
    const prevOtaDir = process.env.OTA_FILES_DIR;
    const prevBaseUrl = process.env.OTA_PUBLIC_BASE_URL;
    process.env.OTA_FILES_DIR = dir;
    process.env.OTA_PUBLIC_BASE_URL = 'https://updates.example.com';

    try {
        for (const [name, content] of Object.entries(files)) {
            await writeFile(path.join(dir, name), content);
        }
        await run(dir);
    } finally {
        if (prevOtaDir === undefined) {
            delete process.env.OTA_FILES_DIR;
        } else {
            process.env.OTA_FILES_DIR = prevOtaDir;
        }
        if (prevBaseUrl === undefined) {
            delete process.env.OTA_PUBLIC_BASE_URL;
        } else {
            process.env.OTA_PUBLIC_BASE_URL = prevBaseUrl;
        }
        await rm(dir, { recursive: true, force: true });
    }
}

function buildApp(overrides = {}) {
    const app = Fastify({ logger: false });
    app.decorate('authenticate', async (request) => {
        request.user = { sub: USER_ID };
    });
    app.decorate('db', overrides.db);
    app.decorate('mqttPublish', overrides.mqttPublish || (async () => {}));
    return app;
}

test('GET /devices/:id/ota/versions lists versions from ota-files and includes current device state', async () => {
    await withTempOtaDir(
        {
            '0.1.1.bin': 'older',
            '0.1.2.bin': 'newer',
            'README.txt': 'ignore me',
        },
        async () => {
            const app = buildApp({
                db: {
                    async query(sql, params) {
                        if (sql.includes('SELECT 1 FROM devices d')) {
                            assert.deepEqual(params, [DEVICE_ID, USER_ID]);
                            return { rows: [{ ok: 1 }], rowCount: 1 };
                        }
                        if (sql.includes('SELECT id, firmware_ver, online FROM devices')) {
                            assert.deepEqual(params, [DEVICE_ID]);
                            return {
                                rows: [{
                                    id: DEVICE_ID,
                                    firmware_ver: '0.1.1',
                                    online: true,
                                }],
                                rowCount: 1,
                            };
                        }
                        throw new Error(`Unexpected SQL: ${sql}`);
                    },
                },
            });

            try {
                await app.register(devicesRoutes);
                const res = await app.inject({
                    method: 'GET',
                    url: `/devices/${DEVICE_ID}/ota/versions`,
                });

                assert.equal(res.statusCode, 200);
                assert.deepEqual(res.json(), {
                    device_id: DEVICE_ID,
                    current_version: '0.1.1',
                    device_online: true,
                    versions: [
                        {
                            version: '0.1.2',
                            filename: '0.1.2.bin',
                            url: 'https://updates.example.com/ota/0.1.2.bin',
                        },
                        {
                            version: '0.1.1',
                            filename: '0.1.1.bin',
                            url: 'https://updates.example.com/ota/0.1.1.bin',
                        },
                    ],
                });
            } finally {
                await app.close();
            }
        }
    );
});

test('POST /devices/:id/ota rejects offline devices', async () => {
    await withTempOtaDir(
        {
            '0.1.2.bin': 'newer',
        },
        async () => {
            let published = false;
            const app = buildApp({
                db: {
                    async query(sql, params) {
                        if (sql.includes('SELECT 1 FROM devices d')) {
                            assert.deepEqual(params, [DEVICE_ID, USER_ID]);
                            return { rows: [{ ok: 1 }], rowCount: 1 };
                        }
                        if (sql.includes('SELECT id, firmware_ver, online FROM devices')) {
                            assert.deepEqual(params, [DEVICE_ID]);
                            return {
                                rows: [{
                                    id: DEVICE_ID,
                                    firmware_ver: '0.1.1',
                                    online: false,
                                }],
                                rowCount: 1,
                            };
                        }
                        throw new Error(`Unexpected SQL: ${sql}`);
                    },
                },
                mqttPublish: async () => {
                    published = true;
                },
            });

            try {
                await app.register(devicesRoutes);
                const res = await app.inject({
                    method: 'POST',
                    url: `/devices/${DEVICE_ID}/ota`,
                    payload: { version: '0.1.2' },
                });

                assert.equal(res.statusCode, 409);
                assert.deepEqual(res.json(), { error: 'device offline' });
                assert.equal(published, false);
            } finally {
                await app.close();
            }
        }
    );
});

test('POST /devices/:id/ota publishes the resolved OTA artifact url and sha256', async () => {
    const otaContent = Buffer.from('firmware-v0.1.2');
    const expectedSha256 = createHash('sha256').update(otaContent).digest('hex');

    await withTempOtaDir(
        {
            '0.1.1.bin': 'older',
            '0.1.2.bin': otaContent,
        },
        async () => {
            const published = [];
            const app = buildApp({
                db: {
                    async query(sql, params) {
                        if (sql.includes('SELECT 1 FROM devices d')) {
                            assert.deepEqual(params, [DEVICE_ID, USER_ID]);
                            return { rows: [{ ok: 1 }], rowCount: 1 };
                        }
                        if (sql.includes('SELECT id, firmware_ver, online FROM devices')) {
                            assert.deepEqual(params, [DEVICE_ID]);
                            return {
                                rows: [{
                                    id: DEVICE_ID,
                                    firmware_ver: '0.1.1',
                                    online: true,
                                }],
                                rowCount: 1,
                            };
                        }
                        throw new Error(`Unexpected SQL: ${sql}`);
                    },
                },
                mqttPublish: async (topic, payload, options) => {
                    published.push({ topic, payload, options });
                },
            });

            try {
                await app.register(devicesRoutes);
                const res = await app.inject({
                    method: 'POST',
                    url: `/devices/${DEVICE_ID}/ota`,
                    payload: { version: '0.1.2' },
                });

                assert.equal(res.statusCode, 202);
                assert.deepEqual(res.json(), {
                    device_id: DEVICE_ID,
                    version: '0.1.2',
                    filename: '0.1.2.bin',
                    status: 'accepted',
                });
                assert.deepEqual(published, [{
                    topic: `device/${DEVICE_ID}/ota/update`,
                    payload: JSON.stringify({
                        url: 'https://updates.example.com/ota/0.1.2.bin',
                        sha256: expectedSha256,
                    }),
                    options: { qos: 1, retain: false },
                }]);
            } finally {
                await app.close();
            }
        }
    );
});

test('POST /devices/:id/ota allows selecting an older listed version', async () => {
    await withTempOtaDir(
        {
            '0.1.1.bin': 'older',
            '0.1.2.bin': 'newer',
        },
        async () => {
            const published = [];
            const app = buildApp({
                db: {
                    async query(sql, params) {
                        if (sql.includes('SELECT 1 FROM devices d')) {
                            assert.deepEqual(params, [DEVICE_ID, USER_ID]);
                            return { rows: [{ ok: 1 }], rowCount: 1 };
                        }
                        if (sql.includes('SELECT id, firmware_ver, online FROM devices')) {
                            assert.deepEqual(params, [DEVICE_ID]);
                            return {
                                rows: [{
                                    id: DEVICE_ID,
                                    firmware_ver: '0.1.2',
                                    online: true,
                                }],
                                rowCount: 1,
                            };
                        }
                        throw new Error(`Unexpected SQL: ${sql}`);
                    },
                },
                mqttPublish: async (topic, payload) => {
                    published.push({ topic, payload });
                },
            });

            try {
                await app.register(devicesRoutes);
                const res = await app.inject({
                    method: 'POST',
                    url: `/devices/${DEVICE_ID}/ota`,
                    payload: { version: '0.1.1' },
                });

                assert.equal(res.statusCode, 202);
                assert.equal(res.json().version, '0.1.1');
                assert.match(published[0].payload, /0\.1\.1\.bin/);
            } finally {
                await app.close();
            }
        }
    );
});
