import test from 'node:test';
import assert from 'node:assert/strict';

test('EMQX admin API failures do not leak raw response bodies', async () => {
    const originalFetch = globalThis.fetch;

    globalThis.fetch = async () => ({
        ok: false,
        status: 500,
        async text() {
            return 'upstream stack trace secret=abc123';
        },
    });

    try {
        const { createDeviceUser } = await import(`../src/services/emqx.js?sanitize=${Date.now()}`);

        await assert.rejects(
            () => createDeviceUser('aa:bb:cc:dd:ee:ff', 'secret-key'),
            (err) => {
                assert.match(err.message, /EMQX API POST .* failed with status 500/);
                assert.doesNotMatch(err.message, /stack trace|abc123/);
                return true;
            }
        );
    } finally {
        globalThis.fetch = originalFetch;
    }
});
