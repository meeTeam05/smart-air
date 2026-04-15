export async function getShadow(fastify, deviceId) {
    const cached = await fastify.redis.get(`shadow:${deviceId}`);
    if (cached) return JSON.parse(cached);

    const { rows } = await fastify.db.query(
        'SELECT reported, desired, updated_at FROM device_shadows WHERE device_id = $1',
        [deviceId]
    );
    if (rows.length === 0) return { reported: {}, desired: {}, updatedAt: null };
    const row = rows[0];
    const shadow = { reported: row.reported, desired: row.desired, updatedAt: row.updated_at };
    await fastify.redis.set(`shadow:${deviceId}`, JSON.stringify(shadow), 'EX', 3600);
    return shadow;
}

export async function updateReported(fastify, deviceId, reported) {
    const shadow = await getShadow(fastify, deviceId);
    shadow.reported = reported;
    shadow.updatedAt = new Date().toISOString();
    await fastify.redis.set(`shadow:${deviceId}`, JSON.stringify(shadow), 'EX', 3600);
    await fastify.db.query(
        `INSERT INTO device_shadows (device_id, reported, updated_at)
         VALUES ($1, $2, NOW())
         ON CONFLICT (device_id) DO UPDATE SET reported = $2, updated_at = NOW()`,
        [deviceId, JSON.stringify(reported)]
    );
}

export async function setDesired(fastify, deviceId, desired) {
    const shadow = await getShadow(fastify, deviceId);
    shadow.desired = desired;
    shadow.updatedAt = new Date().toISOString();
    await fastify.redis.set(`shadow:${deviceId}`, JSON.stringify(shadow), 'EX', 3600);
    await fastify.db.query(
        `INSERT INTO device_shadows (device_id, desired, updated_at)
         VALUES ($1, $2, NOW())
         ON CONFLICT (device_id) DO UPDATE SET desired = $2, updated_at = NOW()`,
        [deviceId, JSON.stringify(desired)]
    );
}
