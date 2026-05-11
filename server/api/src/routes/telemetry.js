import { normalizeDeviceId } from '../utils/device-id.js';
import { checkDeviceAccess } from '../utils/check-access.js';
import { TELEMETRY_DEFAULT_LIMIT, TELEMETRY_MAX_LIMIT, MS_PER_DAY, AGG_ALLOWED } from '../constants.js';

export default async function telemetryRoutes(fastify) {
    const auth = { preHandler: fastify.authenticate };

    fastify.get('/devices/:id/telemetry', auth, async (request, reply) => {
        const deviceId = normalizeDeviceId(request.params.id);
        const userId = request.user.sub;

        if (!deviceId) return reply.code(400).send({ error: 'Invalid device ID' });
        const allowed = await checkDeviceAccess(fastify, deviceId, userId);
        if (!allowed) return reply.code(403).send({ error: 'Forbidden' });

        const now = Date.now();
        const from = request.query.from ? new Date(request.query.from) : new Date(now - MS_PER_DAY);
        const to = request.query.to ? new Date(request.query.to) : new Date(now);
        const limit = Math.min(parseInt(request.query.limit || String(TELEMETRY_DEFAULT_LIMIT)), TELEMETRY_MAX_LIMIT);
        const agg = request.query.agg; // e.g. "1h", "30m", "1d"
        if (agg && !AGG_ALLOWED.has(agg)) {
            return reply.code(400).send({ error: `Invalid agg value. Allowed: ${[...AGG_ALLOWED].join(', ')}` });
        }

        if (agg) {
            const { rows } = await fastify.db.query(
                `SELECT time_bucket($1::interval, ts) AS ts,
                        AVG((payload->>'temperature')::float) AS temperature,
                        AVG((payload->>'humidity')::float) AS humidity
                 FROM telemetry
                 WHERE device_id = $2 AND ts BETWEEN $3 AND $4
                 GROUP BY ts ORDER BY ts DESC`,
                [agg, deviceId, from, to]
            );
            return rows;
        }

        const { rows } = await fastify.db.query(
            `SELECT ts,
                    (payload->>'temperature')::float AS temperature,
                    (payload->>'humidity')::float AS humidity
             FROM telemetry
             WHERE device_id = $1 AND ts BETWEEN $2 AND $3
             ORDER BY ts DESC LIMIT $4`,
            [deviceId, from, to, limit]
        );
        return rows;
    });
}
