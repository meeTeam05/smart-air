import { sendCommand } from '../services/commands.js';
import { normalizeDeviceId } from '../utils/device-id.js';
import { checkDeviceAccess } from '../utils/check-access.js';
import { COMMANDS_MAX_LIMIT, RATE_LIMIT_COMMAND } from '../constants.js';

export default async function commandsRoutes(fastify) {
    const auth = { preHandler: fastify.authenticate };

    fastify.post('/devices/:id/command', { preHandler: fastify.authenticate, config: { rateLimit: RATE_LIMIT_COMMAND } }, async (request, reply) => {
        const deviceId = normalizeDeviceId(request.params.id);
        if (!deviceId) return reply.code(400).send({ error: 'Invalid device ID' });
        const userId = request.user.sub;
        const allowed = await checkDeviceAccess(fastify, deviceId, userId);
        if (!allowed) return reply.code(403).send({ error: 'Forbidden' });

        const { payload } = request.body || {};
        if (!payload || typeof payload !== 'object') return reply.code(400).send({ error: 'payload required' });

        const commandId = await sendCommand(fastify, deviceId, payload, userId);
        return reply.code(201).send({ command_id: commandId });
    });

    fastify.get('/devices/:id/commands', auth, async (request, reply) => {
        const deviceId = normalizeDeviceId(request.params.id);
        if (!deviceId) return reply.code(400).send({ error: 'Invalid device ID' });
        const userId = request.user.sub;
        const allowed = await checkDeviceAccess(fastify, deviceId, userId);
        if (!allowed) return reply.code(403).send({ error: 'Forbidden' });

        const limit = Math.min(parseInt(request.query.limit || '50'), COMMANDS_MAX_LIMIT);
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
