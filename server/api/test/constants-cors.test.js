import test from 'node:test';
import assert from 'node:assert/strict';

const configUrl = new URL('../src/config.js', import.meta.url);

async function importConfig(tag) {
    return import(`${configUrl.href}?case=${tag}`);
}

test('production rejects wildcard CORS origins', async () => {
    const previousNodeEnv = process.env.NODE_ENV;
    const previousCorsOrigins = process.env.CORS_ORIGINS;

    process.env.NODE_ENV = 'production';
    process.env.CORS_ORIGINS = '*';

    try {
        const { config } = await importConfig('wildcard-prod');
        assert.throws(
            () => config.corsOrigins,
            /CORS_ORIGINS must contain explicit HTTPS origins in production/
        );
    } finally {
        if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
        else process.env.NODE_ENV = previousNodeEnv;
        if (previousCorsOrigins === undefined) delete process.env.CORS_ORIGINS;
        else process.env.CORS_ORIGINS = previousCorsOrigins;
    }
});

test('production accepts explicit HTTPS CORS origins', async () => {
    const previousNodeEnv = process.env.NODE_ENV;
    const previousCorsOrigins = process.env.CORS_ORIGINS;

    process.env.NODE_ENV = 'production';
    process.env.CORS_ORIGINS = 'https://minhnhat05.xyz, https://app.smart-air.local';

    try {
        const { config } = await importConfig('https-prod');
        assert.deepEqual(config.corsOrigins, ['https://minhnhat05.xyz', 'https://app.smart-air.local']);
    } finally {
        if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
        else process.env.NODE_ENV = previousNodeEnv;
        if (previousCorsOrigins === undefined) delete process.env.CORS_ORIGINS;
        else process.env.CORS_ORIGINS = previousCorsOrigins;
    }
});
