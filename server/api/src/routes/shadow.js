import { getShadow, setDesired, computeDelta } from '../services/shadow.js';
import { normalizeDeviceId } from '../utils/device-id.js';
import { checkDeviceAccess } from '../utils/check-access.js';

const MAX_DESIRED_SHADOW_BYTES = 4_096;

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
        const isPlainObject = (obj) => obj && typeof obj === 'object' && !Array.isArray(obj);
        if (!isPlainObject(desired)) return reply.code(400).send({ error: 'body must be a plain JSON object' });

        const reservedKeys = ['mode', 'relay_1', 'relay_2', 'relay_3'];
        const foundReserved = reservedKeys.filter((key) => Object.hasOwn(desired, key));
        if (foundReserved.length > 0) {
            return reply.code(400).send({
                error: `Reserved keys detected: ${foundReserved.join(', ')}. Use typed endpoints for device mode and relay control.`,
            });
        }
        if (Buffer.byteLength(JSON.stringify(desired), 'utf8') > MAX_DESIRED_SHADOW_BYTES) {
            return reply.code(400).send({ error: 'desired shadow payload exceeds size limit' });
        }

        const shadow = await getShadow(fastify, deviceId);

        let updatedShadow;
        try {
            updatedShadow = await setDesired(fastify, deviceId, desired);
        } catch (err) {
            if (err.code === '23514' && err.constraint === 'device_shadows_desired_size_check') {
                return reply.code(400).send({ error: 'desired shadow payload exceeds size limit' });
            }
            throw err;
        }

        // If device is online, push desired state immediately
        const { rows } = await fastify.db.query('SELECT online FROM devices WHERE id = $1', [deviceId]);
        if (rows[0]?.online) {
            const reported = updatedShadow?.reported ?? shadow.reported ?? {};
            const effectiveDesired = updatedShadow?.desired ?? desired;
            const delta = computeDelta(reported, effectiveDesired);
            try {
                await fastify.mqttPublish(
                    `device/${deviceId}/shadow/get_response`,
                    JSON.stringify({
                        desired: effectiveDesired,
                        delta,
                        ts: Math.floor(Date.now() / 1000),
                    }),
                    { qos: 1 }
                );
            } catch (err) {
                fastify.log.warn({ err, deviceId }, 'desired shadow saved but immediate MQTT publish failed');
            }
        }

        return { success: true };
    });
}
