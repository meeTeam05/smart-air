import fp from 'fastify-plugin';
import mqtt from 'mqtt';
import { updateReported, getShadow } from '../services/shadow.js';
import { flushPending } from '../services/commands.js';

async function mqttPlugin(fastify) {
    const client = mqtt.connect(process.env.EMQX_MQTT_URL || 'mqtt://emqx:1883', {
        username: process.env.EMQX_MQTT_USER || 'sa-server',
        password: process.env.EMQX_MQTT_PASSWORD || '',
        clientId: 'sa-api-bridge',
        clean: true,
    });

    client.on('connect', () => {
        fastify.log.info('MQTT bridge connected');
        client.subscribe('device/+/status', { qos: 1 });
        client.subscribe('device/+/telemetry', { qos: 1 });
        client.subscribe('device/+/response', { qos: 1 });
        client.subscribe('device/+/shadow/report', { qos: 1 });
        client.subscribe('device/+/ota/progress', { qos: 1 });
    });

    client.on('error', (err) => fastify.log.error({ err }, 'MQTT bridge error'));

    client.on('message', async (topic, buf) => {
        const parts = topic.split('/');
        const deviceId = parts[1];
        let payload;
        try {
            payload = JSON.parse(buf.toString());
        } catch {
            return;
        }

        try {
            if (parts[2] === 'status') {
                await fastify.db.query(
                    'UPDATE devices SET online = $1, last_seen = NOW() WHERE id = $2',
                    [payload.online === true, deviceId]
                );
                if (payload.online === true) {
                    await flushPending(fastify, deviceId);
                    // Push current desired state to device
                    const shadow = await getShadow(fastify, deviceId);
                    if (Object.keys(shadow.desired).length > 0) {
                        client.publish(
                            `device/${deviceId}/shadow/get_response`,
                            JSON.stringify({ desired: shadow.desired }),
                            { qos: 1 }
                        );
                    }
                }
            } else if (parts[2] === 'telemetry') {
                const ts = payload.ts ? new Date(payload.ts * 1000).toISOString() : new Date().toISOString();
                await fastify.db.query(
                    'INSERT INTO telemetry (device_id, ts, payload) VALUES ($1, $2, $3)',
                    [deviceId, ts, JSON.stringify(payload)]
                );
            } else if (parts[2] === 'response') {
                if (payload.command_id) {
                    await fastify.db.query(
                        'UPDATE commands SET status = $1, executed_at = NOW() WHERE id = $2',
                        [payload.status || 'done', payload.command_id]
                    );
                }
            } else if (parts[2] === 'shadow' && parts[3] === 'report') {
                await updateReported(fastify, deviceId, payload);
            } else if (parts[2] === 'ota' && parts[3] === 'progress') {
                await fastify.redis.set(`ota_progress:${deviceId}`, JSON.stringify(payload), 'EX', 600);
            }
        } catch (err) {
            fastify.log.error({ err, topic }, 'MQTT message handler error');
        }
    });

    fastify.decorate('mqttClient', client);
    fastify.addHook('onClose', async () => client.end());
}

export default fp(mqttPlugin);
