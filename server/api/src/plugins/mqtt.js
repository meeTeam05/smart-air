import fp from 'fastify-plugin';
import mqtt from 'mqtt';
import { updateReported } from '../services/shadow.js';
import { handleStatus, handleTelemetry, handleResponse, handleOtaProgress } from '../services/mqtt-handlers.js';
import { normalizeDeviceId } from '../utils/device-id.js';

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
        const deviceId = normalizeDeviceId(parts[1]);
        if (!deviceId) return;
        let payload;
        try {
            payload = JSON.parse(buf.toString());
        } catch {
            return;
        }

        try {
            if (parts[2] === 'status') {
                await handleStatus(fastify, deviceId, payload);
            } else if (parts[2] === 'telemetry') {
                await handleTelemetry(fastify, deviceId, payload);
            } else if (parts[2] === 'response') {
                await handleResponse(fastify, deviceId, payload);
            } else if (parts[2] === 'shadow' && parts[3] === 'report') {
                await updateReported(fastify, deviceId, payload);
            } else if (parts[2] === 'ota' && parts[3] === 'progress') {
                await handleOtaProgress(fastify, deviceId, payload);
            }
        } catch (err) {
            fastify.log.error({ err, topic }, 'MQTT message handler error');
        }
    });

    fastify.decorate('mqttClient', client);
    fastify.addHook('onClose', async () => client.end());
}

export default fp(mqttPlugin);
