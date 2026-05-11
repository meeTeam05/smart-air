export async function sendCommand(fastify, deviceId, payload, userId) {
    const { rows } = await fastify.db.query(
        `INSERT INTO commands (device_id, user_id, payload, status)
         VALUES ($1, $2, $3, 'pending') RETURNING id`,
        [deviceId, userId, JSON.stringify(payload)]
    );
    const commandId = rows[0].id;

    const { rows: deviceRows } = await fastify.db.query(
        'SELECT online FROM devices WHERE id = $1',
        [deviceId]
    );
    const online = deviceRows[0]?.online ?? false;

    if (online) {
        const msg = JSON.stringify({ command_id: commandId, ...payload });
        fastify.mqttClient.publish(`device/${deviceId}/command`, msg, { qos: 1 });
        await fastify.db.query(
            "UPDATE commands SET status = 'sent' WHERE id = $1",
            [commandId]
        );
    } else {
        const item = JSON.stringify({ command_id: commandId, payload });
        await fastify.redis.rpush(`pending_cmds:${deviceId}`, item);
    }

    return commandId;
}

export async function flushPending(fastify, deviceId) {
    const key = `pending_cmds:${deviceId}`;
    const tempKey = `${key}:flushing`;

    // Atomically rename the list — new RPUSHes go to a fresh key
    try {
        await fastify.redis.rename(key, tempKey);
    } catch (err) {
        if (err.message.includes('no such key')) return;
        throw err;
    }

    const items = await fastify.redis.lrange(tempKey, 0, -1);
    await fastify.redis.del(tempKey);

    for (const item of items) {
        const { command_id, payload } = JSON.parse(item);
        const msg = JSON.stringify({ command_id, ...payload });
        fastify.mqttClient.publish(`device/${deviceId}/command`, msg, { qos: 1 });
        await fastify.db.query(
            "UPDATE commands SET status = 'sent' WHERE id = $1",
            [command_id]
        );
    }
}
