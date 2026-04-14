import { sendCommand } from '../services/commands.js';

export default async function commandsRoutes(fastify) {
    const auth = { preHandler: fastify.authenticate };

    async function checkDeviceAccess(fastify, deviceId, userId) {
        const { rows } = await fastify.db.query(
            `SELECT 1 FROM devices d
             JOIN home_members hm ON hm.home_id = d.home_id
             WHERE d.id = $1 AND hm.user_id = $2`,
            [deviceId, userId]
        );
        return rows.length > 0;
    }

    fastify.post('/devices/:id/command', auth, async (request, reply) => {
        const deviceId = request.params.id;
        const userId = request.user.sub;
        const allowed = await checkDeviceAccess(fastify, deviceId, userId);
        if (!allowed) return reply.code(403).send({ error: 'Forbidden' });

        const { payload } = request.body || {};
        if (!payload || typeof payload !== 'object') return reply.code(400).send({ error: 'payload required' });

        const commandId = await sendCommand(fastify, deviceId, payload, userId);
        return reply.code(201).send({ command_id: commandId });
    });

    fastify.get('/devices/:id/commands', auth, async (request, reply) => {
        const deviceId = request.params.id;
        const userId = request.user.sub;
        const allowed = await checkDeviceAccess(fastify, deviceId, userId);
        if (!allowed) return reply.code(403).send({ error: 'Forbidden' });

        const limit = Math.min(parseInt(request.query.limit || '50'), 200);
        const offset = parseInt(request.query.offset || '0');

        const { rows } = await fastify.db.query(
            `SELECT id, payload, status, created_at, executed_at
             FROM commands WHERE device_id = $1
             ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
            [deviceId, limit, offset]
        );
        return rows;
    });
}
