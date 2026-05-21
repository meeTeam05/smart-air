import test from 'node:test';
import assert from 'node:assert/strict';

test('createDeviceUser forwards request id to EMQX admin calls', async () => {
    const originalFetch = globalThis.fetch;
    const seenHeaders = [];

    globalThis.fetch = async (url, options) => {
        seenHeaders.push(options.headers);

        if (url.includes('/authentication/password_based:built_in_database/users') && options.method === 'POST') {
            return { ok: true, status: 201, async text() { return ''; } };
        }
        if (url.includes('/authorization/sources/built_in_database/rules/users') && options.method === 'POST') {
            return { ok: true, status: 201, async text() { return ''; } };
        }
        throw new Error(`Unexpected fetch ${options.method} ${url}`);
    };

    try {
        const { createDeviceUser } = await import(`../src/services/emqx.js?request-id=${Date.now()}`);
        await createDeviceUser('aa:bb:cc:dd:ee:ff', 'secret-key', null, 'req-123');

        assert.equal(seenHeaders.length, 2);
        for (const headers of seenHeaders) {
            assert.equal(headers['X-Request-Id'], 'req-123');
        }
    } finally {
        globalThis.fetch = originalFetch;
    }
});

test('checkEmqxApiHealth forwards request id to EMQX status checks', async () => {
    const originalFetch = globalThis.fetch;
    const seenHeaders = [];

    globalThis.fetch = async (url, options) => {
        seenHeaders.push(options.headers);

        if (url.endsWith('/status') && options.method === 'GET') {
            return { ok: true, status: 200, async text() { return ''; } };
        }
        throw new Error(`Unexpected fetch ${options.method} ${url}`);
    };

    try {
        const { checkEmqxApiHealth } = await import(`../src/services/emqx.js?health-request-id=${Date.now()}`);
        await checkEmqxApiHealth('req-health-1');

        assert.equal(seenHeaders.length, 1);
        assert.equal(seenHeaders[0]['X-Request-Id'], 'req-health-1');
    } finally {
        globalThis.fetch = originalFetch;
    }
});
