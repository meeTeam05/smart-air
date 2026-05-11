import { getShadow, setDesired } from '../services/shadow.js';
import { normalizeDeviceId } from '../utils/device-id.js';
import { checkDeviceAccess } from '../utils/check-access.js';

export default async function shadowRoutes(fastify) {
    const auth = { preHandler: fastify.authenticate };

    fastify.get('/devices/:id/shadow', auth, async (request, reply) => {
        const deviceId = normalizeDeviceId(request.params.id);
        if (!deviceId) return reply.code(400).send({ error: 'Invalid device ID' });
        const allowed = await checkDeviceAccess(fastify, deviceId, request.user.sub);
        if (!allowed) return reply.code(403).send({ error: 'Forbidden' });
        return getShadow(fastify, deviceId);
    });

    fastify.put('/devices/:id/shadow/desired', auth, async (request, reply) => {
        const deviceId = normalizeDeviceId(request.params.id);
        if (!deviceId) return reply.code(400).send({ error: 'Invalid device ID' });
        const allowed = await checkDeviceAccess(fastify, deviceId, request.user.sub);
        if (!allowed) return reply.code(403).send({ error: 'Forbidden' });

        const desired = request.body;
        if (!desired || typeof desired !== 'object') return reply.code(400).send({ error: 'body must be JSON object' });

        await setDesired(fastify, deviceId, desired);

        // If device is online, push desired state immediately
        const { rows } = await fastify.db.query('SELECT online FROM devices WHERE id = $1', [deviceId]);
        if (rows[0]?.online) {
            fastify.mqttClient.publish(
                `device/${deviceId}/shadow/get_response`,
                JSON.stringify({ desired }),
                { qos: 1 }
            );
        }

        return { success: true };
    });
}
