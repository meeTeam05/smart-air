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
    const items = await fastify.redis.lrange(`pending_cmds:${deviceId}`, 0, -1);
    if (items.length === 0) return;
    await fastify.redis.del(`pending_cmds:${deviceId}`);
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
