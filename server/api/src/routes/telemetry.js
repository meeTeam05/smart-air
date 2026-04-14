export default async function telemetryRoutes(fastify) {
    const auth = { preHandler: fastify.authenticate };

    fastify.get('/devices/:id/telemetry', auth, async (request, reply) => {
        const deviceId = request.params.id;
        const userId = request.user.sub;

        const { rows: accessRows } = await fastify.db.query(
            `SELECT 1 FROM devices d
             JOIN home_members hm ON hm.home_id = d.home_id
             WHERE d.id = $1 AND hm.user_id = $2`,
            [deviceId, userId]
        );
        if (accessRows.length === 0) return reply.code(403).send({ error: 'Forbidden' });

        const now = Date.now();
        const from = request.query.from ? new Date(request.query.from) : new Date(now - 86400000);
        const to = request.query.to ? new Date(request.query.to) : new Date(now);
        const limit = Math.min(parseInt(request.query.limit || '1000'), 5000);
        const agg = request.query.agg; // e.g. "1h", "30m", "1d"

        if (agg) {
            const { rows } = await fastify.db.query(
                `SELECT time_bucket($1::interval, ts) AS bucket,
                        AVG((payload->>'temperature')::float) AS temperature,
                        AVG((payload->>'humidity')::float) AS humidity
                 FROM telemetry
                 WHERE device_id = $2 AND ts BETWEEN $3 AND $4
                 GROUP BY bucket ORDER BY bucket DESC`,
                [agg, deviceId, from, to]
            );
            return rows;
        }

        const { rows } = await fastify.db.query(
            `SELECT ts, payload FROM telemetry
             WHERE device_id = $1 AND ts BETWEEN $2 AND $3
             ORDER BY ts DESC LIMIT $4`,
            [deviceId, from, to, limit]
        );
        return rows;
    });
}
