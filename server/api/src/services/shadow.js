import { REDIS_TTL_SHADOW } from '../constants.js';

function deepEqual(left, right) {
    if (Object.is(left, right)) return true;
    if (left == null || right == null) return false;
    if (typeof left !== typeof right) return false;

    if (Array.isArray(left) || Array.isArray(right)) {
        if (!Array.isArray(left) || !Array.isArray(right)) return false;
        if (left.length !== right.length) return false;
        for (let i = 0; i < left.length; i += 1) {
            if (!deepEqual(left[i], right[i])) return false;
        }
        return true;
    }

    if (typeof left === 'object') {
        const leftKeys = Object.keys(left);
        const rightKeys = Object.keys(right);
        if (leftKeys.length !== rightKeys.length) return false;

        for (const key of leftKeys) {
            if (!Object.prototype.hasOwnProperty.call(right, key)) return false;
            if (!deepEqual(left[key], right[key])) return false;
        }
        return true;
    }

    return false;
}

export function computeDelta(current, desired) {
    const delta = {};
    for (const [key, value] of Object.entries(desired || {})) {
        if (!deepEqual(current?.[key], value)) {
            delta[key] = value;
        }
    }
    return delta;
}

function shadowKey(deviceId) {
    return `shadow:${deviceId}`;
}

async function readCachedShadow(fastify, deviceId) {
    const key = shadowKey(deviceId);
    let cached;
    try {
        cached = await fastify.redis.get(key);
    } catch (err) {
        fastify.log.warn({ err, deviceId }, 'Redis shadow cache read failed; falling back to DB');
        return null;
    }

    if (!cached) return null;

    try {
        return JSON.parse(cached);
    } catch (err) {
        fastify.log.warn({ err, deviceId }, 'malformed Redis shadow cache ignored');
        try {
            await fastify.redis.del(key);
        } catch (delErr) {
            fastify.log.warn({ err: delErr, deviceId }, 'failed to delete malformed Redis shadow cache');
        }
        return null;
    }
}

async function writeCachedShadow(fastify, deviceId, shadow) {
    try {
        await fastify.redis.set(shadowKey(deviceId), JSON.stringify(shadow), 'EX', REDIS_TTL_SHADOW);
    } catch (err) {
        fastify.log.warn({ err, deviceId }, 'Redis shadow cache write failed; DB remains source of truth');
    }
}

function shadowFromRow(row) {
    return {
        reported: row.reported ?? {},
        desired: row.desired ?? {},
        updatedAt: row.updated_at,
    };
}

async function readShadowFromDb(fastify, deviceId) {
    const { rows } = await fastify.db.query(
        'SELECT reported, desired, updated_at FROM device_shadows WHERE device_id = $1',
        [deviceId]
    );
    if (rows.length === 0) return null;
    return shadowFromRow(rows[0]);
}

export async function getShadow(fastify, deviceId) {
    const cached = await readCachedShadow(fastify, deviceId);
    if (cached) return cached;

    const shadow = await readShadowFromDb(fastify, deviceId);
    if (!shadow) return { reported: {}, desired: {}, updatedAt: null };
    await writeCachedShadow(fastify, deviceId, shadow);
    return shadow;
}

async function _updateField(fastify, deviceId, field, value) {
    if (field !== 'reported' && field !== 'desired') throw new Error(`Invalid shadow field: ${field}`);
    // Write DB first (atomic UPSERT), then write-through Redis cache
    // using the same canonical object returned by DB.
    const { rows } = await fastify.db.query(
        `INSERT INTO device_shadows (device_id, ${field}, updated_at)
         VALUES ($1, $2, NOW())
         ON CONFLICT (device_id) DO UPDATE
            SET ${field} = device_shadows.${field} || EXCLUDED.${field},
                updated_at = NOW()
         RETURNING reported, desired, updated_at`,
        [deviceId, JSON.stringify(value)]
    );

    const row = rows[0] || { reported: {}, desired: {}, updated_at: null };
    const shadow = shadowFromRow(row);

    await writeCachedShadow(fastify, deviceId, shadow);
    return shadow;
}

export async function updateReported(fastify, deviceId, data) {
    const reportTs = Number(data.ts);
    const { rows } = await fastify.db.query(
        `INSERT INTO device_shadows (device_id, reported, updated_at)
         VALUES ($1, $2, NOW())
         ON CONFLICT (device_id) DO UPDATE
            SET reported = device_shadows.reported || EXCLUDED.reported,
                updated_at = NOW()
         WHERE COALESCE(
            CASE
                WHEN jsonb_typeof(device_shadows.reported->'ts') = 'number'
                    THEN (device_shadows.reported->>'ts')::double precision
                ELSE NULL
            END,
            -1
         ) <= $3
         RETURNING reported, desired, updated_at`,
        [deviceId, JSON.stringify(data), reportTs]
    );

    const applied = rows.length > 0;
    const shadow = applied
        ? shadowFromRow(rows[0])
        : (await readShadowFromDb(fastify, deviceId)) ?? { reported: {}, desired: {}, updatedAt: null };
    await writeCachedShadow(fastify, deviceId, shadow);
    return { shadow, applied };
}

export const setDesired     = (f, id, data) => _updateField(f, id, 'desired', data);
