import test from 'node:test';
import assert from 'node:assert/strict';

test('EMQX compensation delete failure uses provided logger instead of console', async () => {
    const originalFetch = globalThis.fetch;
    const errorCalls = [];

    globalThis.fetch = async (url, options) => {
        if (url.includes('/authentication/password_based:built_in_database/users') && options.method === 'POST') {
            return { ok: true, status: 201, async text() { return ''; } };
        }
        if (url.includes('/authorization/sources/built_in_database/rules/users') && options.method === 'POST') {
            return { ok: false, status: 500, async text() { return 'acl failure'; } };
        }
        if (url.includes('/authentication/password_based:built_in_database/users/') && options.method === 'DELETE') {
            return { ok: false, status: 500, async text() { return 'delete failure'; } };
        }
        throw new Error(`Unexpected fetch ${options.method} ${url}`);
    };

    try {
        const { createDeviceUser } = await import(`../src/services/emqx.js?logger=${Date.now()}`);
        const logger = {
            error(...args) {
                errorCalls.push(args);
            },
        };

        await assert.rejects(
            () => createDeviceUser('aa:bb:cc:dd:ee:ff', 'secret-key', logger),
            /EMQX API POST .* failed with status 500/
        );

        assert.equal(errorCalls.length, 1);
        assert.equal(errorCalls[0][1], 'EMQX compensation delete failed after ACL setup error');
        assert.equal(errorCalls[0][0].deviceId, 'aa:bb:cc:dd:ee:ff');
    } finally {
        globalThis.fetch = originalFetch;
    }
});
