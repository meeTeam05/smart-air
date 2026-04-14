import { getShadow, setDesired } from '../services/shadow.js';
import { normalizeDeviceId } from '../utils/device-id.js';

export default async function shadowRoutes(fastify) {
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

    fastify.get('/devices/:id/shadow', auth, async (request, reply) => {
        const deviceId = normalizeDeviceId(request.params.id);
        const allowed = await checkDeviceAccess(fastify, deviceId, request.user.sub);
        if (!allowed) return reply.code(403).send({ error: 'Forbidden' });
        return getShadow(fastify, deviceId);
    });

    fastify.put('/devices/:id/shadow/desired', auth, async (request, reply) => {
        const deviceId = normalizeDeviceId(request.params.id);
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
