import test from 'node:test';
import assert from 'node:assert/strict';

const constantsUrl = new URL('../src/constants.js', import.meta.url);

async function importConstants(tag) {
    return import(`${constantsUrl.href}?case=${tag}`);
}

test('production rejects wildcard CORS origins', async () => {
    const previousNodeEnv = process.env.NODE_ENV;
    const previousCorsOrigins = process.env.CORS_ORIGINS;

    process.env.NODE_ENV = 'production';
    process.env.CORS_ORIGINS = '*';

    try {
        await assert.rejects(
            importConstants('wildcard-prod'),
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
        const { ALLOWED_ORIGINS } = await importConstants('https-prod');
        assert.deepEqual(ALLOWED_ORIGINS, ['https://minhnhat05.xyz', 'https://app.smart-air.local']);
    } finally {
        if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
        else process.env.NODE_ENV = previousNodeEnv;
        if (previousCorsOrigins === undefined) delete process.env.CORS_ORIGINS;
        else process.env.CORS_ORIGINS = previousCorsOrigins;
    }
});
