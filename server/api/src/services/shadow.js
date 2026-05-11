import { REDIS_TTL_SHADOW } from '../constants.js';

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
    await fastify.redis.set(`shadow:${deviceId}`, JSON.stringify(shadow), 'EX', REDIS_TTL_SHADOW);
    return shadow;
}

async function _updateField(fastify, deviceId, field, value) {
    if (field !== 'reported' && field !== 'desired') throw new Error(`Invalid shadow field: ${field}`);
    // Write DB first (atomic UPSERT), then invalidate cache.
    // Eliminates read-modify-write race — next getShadow() repopulates from DB.
    await fastify.db.query(
        `INSERT INTO device_shadows (device_id, ${field}, updated_at)
         VALUES ($1, $2, NOW())
         ON CONFLICT (device_id) DO UPDATE SET ${field} = $2, updated_at = NOW()`,
        [deviceId, JSON.stringify(value)]
    );
    await fastify.redis.del(`shadow:${deviceId}`);
}

export const updateReported = (f, id, data) => _updateField(f, id, 'reported', data);
export const setDesired     = (f, id, data) => _updateField(f, id, 'desired', data);
