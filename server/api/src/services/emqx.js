const EMQX_API_URL = process.env.EMQX_API_URL || 'http://emqx:18083';
const DEFAULT_EMQX_API_TIMEOUT_MS = 5_000;

function parsePositiveIntEnv(name, fallback) {
    const value = Number.parseInt(process.env[name] || '', 10);
    return Number.isInteger(value) && value > 0 ? value : fallback;
}

const EMQX_API_TIMEOUT_MS = parsePositiveIntEnv('EMQX_API_TIMEOUT_MS', DEFAULT_EMQX_API_TIMEOUT_MS);

function authHeader() {
    const key = process.env.EMQX_API_KEY || '';
    const secret = process.env.EMQX_API_SECRET || '';
    return 'Basic ' + Buffer.from(`${key}:${secret}`).toString('base64');
}

async function emqxFetch(path, method, body, options = {}) {
    const timeout = AbortSignal.timeout(EMQX_API_TIMEOUT_MS);
    let res;
    try {
        res = await fetch(`${EMQX_API_URL}${path}`, {
            method,
            headers: { 'Content-Type': 'application/json', Authorization: authHeader() },
            body: body ? JSON.stringify(body) : undefined,
            signal: timeout,
        });
    } catch (err) {
        if (err?.name === 'TimeoutError' || err?.name === 'AbortError') {
            throw new Error(`EMQX API ${method} ${path} timed out after ${EMQX_API_TIMEOUT_MS}ms`, { cause: err });
        }
        throw err;
    }
    const okStatuses = new Set(options.okStatuses || []);
    if (!res.ok && !okStatuses.has(res.status)) {
        await res.text();
        throw new Error(`EMQX API ${method} ${path} failed with status ${res.status}`);
    }
    return res;
}

async function createAuthUser(userId, password) {
    return emqxFetch(
        '/api/v5/authentication/password_based:built_in_database/users',
        'POST',
        { user_id: userId, password, is_superuser: false },
        { okStatuses: [409] }
    );
}

async function updateAuthUser(userId, password) {
    return emqxFetch(
        `/api/v5/authentication/password_based:built_in_database/users/${encodeURIComponent(userId)}`,
        'PUT',
        { password, is_superuser: false }
    );
}

async function clearAuthorizationCache() {
    await emqxFetch('/api/v5/authorization/cache', 'DELETE', undefined, { okStatuses: [404] });
}

async function upsertUserRules(username, rules) {
    const body = { username, rules };
    const createRes = await emqxFetch(
        '/api/v5/authorization/sources/built_in_database/rules/users',
        'POST',
        [body],
        { okStatuses: [409] }
    );
    if (createRes.status === 409) {
        await emqxFetch(
            `/api/v5/authorization/sources/built_in_database/rules/users/${encodeURIComponent(username)}`,
            'PUT',
            body
        );
    }
}

function deviceRules(deviceId) {
    return [
        { topic: `device/${deviceId}/status`, action: 'publish', permission: 'allow' },
        { topic: `device/${deviceId}/telemetry`, action: 'publish', permission: 'allow' },
        { topic: `device/${deviceId}/response`, action: 'publish', permission: 'allow' },
        { topic: `device/${deviceId}/shadow/report`, action: 'publish', permission: 'allow' },
        { topic: `device/${deviceId}/shadow/get`, action: 'publish', permission: 'allow' },
        { topic: `device/${deviceId}/ota/progress`, action: 'publish', permission: 'allow' },
        { topic: `device/${deviceId}/command`, action: 'subscribe', permission: 'allow' },
        { topic: `device/${deviceId}/shadow/get_response`, action: 'subscribe', permission: 'allow' },
        { topic: `device/${deviceId}/ota/update`, action: 'subscribe', permission: 'allow' },
    ];
}

function bridgeRules() {
    return [
        { topic: 'device/+/status', action: 'subscribe', permission: 'allow' },
        { topic: 'device/+/telemetry', action: 'subscribe', permission: 'allow' },
        { topic: 'device/+/response', action: 'subscribe', permission: 'allow' },
        { topic: 'device/+/shadow/report', action: 'subscribe', permission: 'allow' },
        { topic: 'device/+/shadow/get', action: 'subscribe', permission: 'allow' },
        { topic: 'device/+/ota/progress', action: 'subscribe', permission: 'allow' },
        { topic: 'device/+/command', action: 'publish', permission: 'allow' },
        { topic: 'device/+/shadow/get_response', action: 'publish', permission: 'allow' },
    ];
}

export async function ensureBridgeUser() {
    const username = process.env.EMQX_MQTT_USER || 'sa-server';
    const password = process.env.EMQX_MQTT_PASSWORD || '';
    if (!password) throw new Error('EMQX_MQTT_PASSWORD is required to provision bridge user');
    const userRes = await createAuthUser(username, password);
    if (userRes.status === 409) {
        await updateAuthUser(username, password);
    }
    await upsertUserRules(username, bridgeRules());
    await clearAuthorizationCache();
}

export async function checkEmqxApiHealth() {
    await emqxFetch('/status', 'GET');
}

export async function createDeviceUser(deviceId, secretKey) {
    const userRes = await createAuthUser(deviceId, secretKey);

    const userCreated = userRes.status !== 409;
    if (!userCreated) return { userCreated: false };

    try {
        await upsertUserRules(deviceId, deviceRules(deviceId));
    } catch (err) {
        // Compensation: delete user if ACL creation failed and user was just created
        if (userCreated) {
            try {
                await emqxFetch(
                    `/api/v5/authentication/password_based:built_in_database/users/${encodeURIComponent(deviceId)}`,
                    'DELETE',
                    undefined,
                    { okStatuses: [404] }
                );
            } catch (delErr) {
                // Log compensation failure but throw original ACL error
                console.error(`EMQX compensation failed for ${deviceId}: ${delErr.message}`);
            }
        }
        throw err;
    }

    return { userCreated };
}

export async function deleteDeviceUser(deviceId) {
    await emqxFetch(
        `/api/v5/authentication/password_based:built_in_database/users/${encodeURIComponent(deviceId)}`,
        'DELETE',
        undefined,
        { okStatuses: [404] }
    );
    await emqxFetch(
        `/api/v5/authorization/sources/built_in_database/rules/users/${encodeURIComponent(deviceId)}`,
        'DELETE',
        undefined,
        { okStatuses: [404] }
    );
}
