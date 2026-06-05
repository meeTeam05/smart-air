import test from 'node:test';
import assert from 'node:assert/strict';

test('ensureBridgeUser provisions bridge publish access for OTA update topic', async () => {
    const originalFetch = globalThis.fetch;
    let rulesPayload = null;

    globalThis.fetch = async (url, options) => {
        if (url.includes('/authentication/password_based:built_in_database/users') && options.method === 'POST') {
            return { ok: true, status: 201, async text() { return ''; } };
        }
        if (url.includes('/authorization/sources/built_in_database/rules/users') && options.method === 'POST') {
            rulesPayload = JSON.parse(options.body);
            return { ok: true, status: 201, async text() { return ''; } };
        }
        if (url.endsWith('/authorization/cache') && options.method === 'DELETE') {
            return { ok: true, status: 204, async text() { return ''; } };
        }
        throw new Error(`Unexpected fetch ${options.method} ${url}`);
    };

    try {
        const { ensureBridgeUser } = await import(`../src/services/emqx.js?bridge-rule=${Date.now()}`);
        process.env.EMQX_MQTT_PASSWORD = 'test-password';
        await ensureBridgeUser();

        assert.ok(Array.isArray(rulesPayload));
        const bridgeRules = rulesPayload[0]?.rules ?? [];
        assert.deepEqual(
            bridgeRules.find((rule) => rule.topic === 'device/+/ota/update'),
            { topic: 'device/+/ota/update', action: 'publish', permission: 'allow' }
        );
    } finally {
        globalThis.fetch = originalFetch;
    }
});
