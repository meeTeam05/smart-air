import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const appPath = path.resolve(__dirname, '../src/app.js');
const configPath = path.resolve(__dirname, '../src/config.js');

async function readAppSource() {
    return readFile(appPath, 'utf8');
}

async function readConfigSource() {
    return readFile(configPath, 'utf8');
}

test('startup guard lists required runtime environment variables', async () => {
    const source = await readConfigSource();

    const requiredVars = [
        'JWT_SECRET',
        'POSTGRES_PASSWORD',
        'REDIS_PASSWORD',
        'EMQX_API_KEY',
        'EMQX_API_SECRET',
        'EMQX_MQTT_PASSWORD',
    ];

    for (const varName of requiredVars) {
        assert.match(source, new RegExp(`'${varName}'`), `missing ${varName} in startup guard list`);
    }
});

test('startup guard check is declared before DB plugin registration', async () => {
    const source = await readAppSource();

    const guardIndex = source.indexOf('const missingRequiredEnvVars = getMissingRequiredEnvVars(REQUIRED_RUNTIME_ENV_VARS);');
    const dbPluginRegisterIndex = source.indexOf('await fastify.register(dbPlugin);');

    assert.notEqual(guardIndex, -1, 'missing startup guard evaluation');
    assert.notEqual(dbPluginRegisterIndex, -1, 'missing db plugin registration');
    assert.ok(guardIndex < dbPluginRegisterIndex, 'startup guard must evaluate before db plugin registration');
});
