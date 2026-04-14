const EMQX_API_URL = process.env.EMQX_API_URL || 'http://emqx:18083';
const EMQX_API_USER = process.env.EMQX_API_USER || 'admin';
const EMQX_API_PASSWORD = process.env.EMQX_API_PASSWORD || '';
const AUTH_HEADER = 'Basic ' + Buffer.from(`${EMQX_API_USER}:${EMQX_API_PASSWORD}`).toString('base64');

async function emqxFetch(path, method, body) {
    const res = await fetch(`${EMQX_API_URL}${path}`, {
        method,
        headers: { 'Content-Type': 'application/json', Authorization: AUTH_HEADER },
        body: body ? JSON.stringify(body) : undefined,
    });
    if (!res.ok && res.status !== 409) {
        const text = await res.text();
        throw new Error(`EMQX API ${method} ${path} → ${res.status}: ${text}`);
    }
    return res;
}

export async function createDeviceUser(deviceId, secretKey) {
    // Create MQTT user
    await emqxFetch(
        '/api/v5/authentication/password_based:built_in_database/users',
        'POST',
        { user_id: deviceId, password: secretKey, is_superuser: false }
    );

    // Create ACL rules — allow pub/sub on own topic prefix
    await emqxFetch(
        '/api/v5/authorization/sources/built_in_database/rules/users',
        'POST',
        {
            username: deviceId,
            rules: [
                { topic: `device/${deviceId}/#`, action: 'all', permission: 'allow' },
            ],
        }
    );
}

export async function deleteDeviceUser(deviceId) {
    await emqxFetch(
        `/api/v5/authentication/password_based:built_in_database/users/${encodeURIComponent(deviceId)}`,
        'DELETE'
    );
    await emqxFetch(
        `/api/v5/authorization/sources/built_in_database/rules/users/${encodeURIComponent(deviceId)}`,
        'DELETE'
    );
}
