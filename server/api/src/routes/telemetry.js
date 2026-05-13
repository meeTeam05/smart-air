import { normalizeDeviceId } from '../utils/device-id.js';
import { checkDeviceAccess } from '../utils/check-access.js';
import { TELEMETRY_DEFAULT_LIMIT, TELEMETRY_MAX_LIMIT, MS_PER_DAY, AGG_ALLOWED } from '../constants.js';
import { parseDateOr, parsePositiveInt } from '../utils/parse.js';

export default async function telemetryRoutes(fastify) {
    const auth = { preHandler: fastify.authenticate };

    fastify.get('/devices/:id/telemetry', auth, async (request, reply) => {
        const deviceId = normalizeDeviceId(request.params.id);
        const userId = request.user.sub;

        if (!deviceId) return reply.code(400).send({ error: 'Invalid device ID' });
        const allowed = await checkDeviceAccess(fastify, deviceId, userId);
        if (!allowed) return reply.code(403).send({ error: 'Forbidden' });

        const now = Date.now();
        const from = parseDateOr(request.query.from, new Date(now - MS_PER_DAY));
        const to   = parseDateOr(request.query.to,   new Date(now));
        if (!from || !to) return reply.code(400).send({ error: 'invalid from/to date (ISO8601 expected)' });
        if (from > to) return reply.code(400).send({ error: 'from must be <= to' });
        if (to - from > 90 * MS_PER_DAY) return reply.code(400).send({ error: 'range must be <= 90 days' });

        const limitRaw = parsePositiveInt(request.query.limit, TELEMETRY_DEFAULT_LIMIT, TELEMETRY_MAX_LIMIT);
        if (limitRaw === null) return reply.code(400).send({ error: 'limit must be a positive integer' });
        const limit = limitRaw;
        const agg = request.query.agg; // e.g. "1h", "30m", "1d"
        if (agg && !AGG_ALLOWED.has(agg)) {
            return reply.code(400).send({ error: `Invalid agg value. Allowed: ${[...AGG_ALLOWED].join(', ')}` });
        }

        if (agg) {
            const { rows } = await fastify.db.query(
                `SELECT time_bucket($1::interval, ts) AS ts,
                        AVG(CASE WHEN jsonb_typeof(payload->'temperature') = 'number' THEN (payload->>'temperature')::float ELSE NULL END) AS temperature,
                        AVG(CASE WHEN jsonb_typeof(payload->'humidity') = 'number' THEN (payload->>'humidity')::float ELSE NULL END) AS humidity,
                        AVG(CASE WHEN jsonb_typeof(payload->'co_ppm') = 'number' THEN (payload->>'co_ppm')::float ELSE NULL END) AS co_ppm,
                        AVG(CASE WHEN jsonb_typeof(payload->'no2_ppm') = 'number' THEN (payload->>'no2_ppm')::float ELSE NULL END) AS no2_ppm
                 FROM telemetry
                 WHERE device_id = $2 AND ts BETWEEN $3 AND $4
                 GROUP BY 1 ORDER BY 1 DESC LIMIT $5`,
                [agg, deviceId, from, to, limit]
            );
            return rows;
        }

        const { rows } = await fastify.db.query(
            `SELECT ts,
                    CASE WHEN jsonb_typeof(payload->'temperature') = 'number' THEN (payload->>'temperature')::float ELSE NULL END AS temperature,
                    CASE WHEN jsonb_typeof(payload->'humidity') = 'number' THEN (payload->>'humidity')::float ELSE NULL END AS humidity,
                    CASE WHEN jsonb_typeof(payload->'co_ppm') = 'number' THEN (payload->>'co_ppm')::float ELSE NULL END AS co_ppm,
                    CASE WHEN jsonb_typeof(payload->'no2_ppm') = 'number' THEN (payload->>'no2_ppm')::float ELSE NULL END AS no2_ppm,
                    payload->>'mode' AS mode
             FROM telemetry
             WHERE device_id = $1 AND ts BETWEEN $2 AND $3
             ORDER BY ts DESC LIMIT $4`,
            [deviceId, from, to, limit]
        );
        return rows;
    });
}
