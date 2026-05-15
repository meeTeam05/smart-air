import test from 'node:test';
import assert from 'node:assert/strict';

test('EMQX admin API calls fail with a clear timeout error', async () => {
    const originalFetch = globalThis.fetch;
    const originalTimeout = process.env.EMQX_API_TIMEOUT_MS;
    process.env.EMQX_API_TIMEOUT_MS = '10';

    globalThis.fetch = async (url, options) => {
        return new Promise((resolve, reject) => {
            options.signal.addEventListener('abort', () => {
                reject(options.signal.reason ?? Object.assign(new Error('aborted'), { name: 'AbortError' }));
            }, { once: true });
        });
    };

    try {
        const { createDeviceUser } = await import(`../src/services/emqx.js?timeout=${Date.now()}`);

        await assert.rejects(
            () => createDeviceUser('aa:bb:cc:dd:ee:ff', 'secret-key'),
            /EMQX API POST .* timed out after 10ms/
        );
    } finally {
        globalThis.fetch = originalFetch;
        if (originalTimeout === undefined) {
            delete process.env.EMQX_API_TIMEOUT_MS;
        } else {
            process.env.EMQX_API_TIMEOUT_MS = originalTimeout;
        }
    }
});
