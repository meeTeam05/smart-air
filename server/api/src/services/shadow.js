import { REDIS_TTL_SHADOW } from '../constants.js';

const SHADOW_CACHE_SET_SCRIPT = `
local existing = redis.call('GET', KEYS[1])
if existing then
    local ok, decoded = pcall(cjson.decode, existing)
    local existingVersion = nil
    if ok and decoded then
        if decoded.version then
            existingVersion = decoded.version
        elseif decoded.updatedAt then
            existingVersion = decoded.updatedAt
        elseif decoded.shadow and decoded.shadow.updatedAt then
            existingVersion = decoded.shadow.updatedAt
        end
    end
    if existingVersion and existingVersion > ARGV[2] then
        return 0
    end
end
redis.call('SET', KEYS[1], ARGV[1], 'EX', ARGV[3])
return 1
`;

const inflightShadowReads = new Map();
const SHADOW_DB_COLUMNS = `
    reported,
    desired,
    updated_at,
    to_char(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') AS cache_version
`;

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
        const decoded = JSON.parse(cached);
        if (
            decoded &&
            typeof decoded === 'object' &&
            !Array.isArray(decoded) &&
            decoded.shadow &&
            typeof decoded.version === 'string'
        ) {
            return decoded.shadow;
        }
        return decoded;
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

async function writeCachedShadow(fastify, deviceId, shadow, version = null) {
    const key = shadowKey(deviceId);
    const cacheVersion = version ?? (shadow.updatedAt ? new Date(shadow.updatedAt).toISOString() : '');
    const serialized = JSON.stringify({ shadow, version: cacheVersion });
    try {
        await fastify.redis.eval(
            SHADOW_CACHE_SET_SCRIPT,
            1,
            key,
            serialized,
            cacheVersion,
            String(REDIS_TTL_SHADOW)
        );
    } catch (err) {
        fastify.log.warn({ err, deviceId }, 'Redis shadow cache write failed; DB remains source of truth');
        try {
            await fastify.redis.del(key);
        } catch (delErr) {
            fastify.log.warn({ err: delErr, deviceId }, 'failed to clear shadow cache after write failure');
        }
    }
}

function shadowFromRow(row) {
    return {
        reported: row.reported ?? {},
        desired: row.desired ?? {},
        updatedAt: row.updated_at,
    };
}

function shadowCacheVersionFromRow(row) {
    if (typeof row?.cache_version === 'string' && row.cache_version !== '') {
        return row.cache_version;
    }
    return row?.updated_at ? new Date(row.updated_at).toISOString() : '';
}

async function readShadowRowFromDb(fastify, deviceId) {
    const { rows } = await fastify.db.query(
        `SELECT ${SHADOW_DB_COLUMNS}
         FROM device_shadows
         WHERE device_id = $1`,
        [deviceId]
    );
    return rows[0] ?? null;
}

async function readShadowFromDb(fastify, deviceId) {
    const row = await readShadowRowFromDb(fastify, deviceId);
    return row ? shadowFromRow(row) : null;
}

export async function getShadow(fastify, deviceId) {
    const cached = await readCachedShadow(fastify, deviceId);
    if (cached) return cached;

    const inflight = inflightShadowReads.get(deviceId);
    if (inflight) return inflight;

    const loadPromise = (async () => {
        const row = await readShadowRowFromDb(fastify, deviceId);
        if (!row) return { reported: {}, desired: {}, updatedAt: null };
        const shadow = shadowFromRow(row);
        await writeCachedShadow(fastify, deviceId, shadow, shadowCacheVersionFromRow(row));
        return shadow;
    })();

    inflightShadowReads.set(deviceId, loadPromise);
    try {
        return await loadPromise;
    } finally {
        if (inflightShadowReads.get(deviceId) === loadPromise) {
            inflightShadowReads.delete(deviceId);
        }
    }
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
         RETURNING ${SHADOW_DB_COLUMNS}`,
        [deviceId, JSON.stringify(value)]
    );

    const row = rows[0] || { reported: {}, desired: {}, updated_at: null, cache_version: '' };
    const shadow = shadowFromRow(row);

    await writeCachedShadow(fastify, deviceId, shadow, shadowCacheVersionFromRow(row));
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
         RETURNING ${SHADOW_DB_COLUMNS}`,
        [deviceId, JSON.stringify(data), reportTs]
    );

    const applied = rows.length > 0;
    const row = applied ? rows[0] : await readShadowRowFromDb(fastify, deviceId);
    const shadow = row ? shadowFromRow(row) : { reported: {}, desired: {}, updatedAt: null };
    await writeCachedShadow(
        fastify,
        deviceId,
        shadow,
        row ? shadowCacheVersionFromRow(row) : ''
    );
    return { shadow, applied };
}

export const setDesired     = (f, id, data) => _updateField(f, id, 'desired', data);
