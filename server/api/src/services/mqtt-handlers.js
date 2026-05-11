import { updateReported, getShadow } from './shadow.js';
import { flushPending } from './commands.js';
import { REDIS_TTL_ANNOUNCE, REDIS_TTL_OTA } from '../constants.js';

export async function handleStatus(fastify, deviceId, payload) {
    await fastify.db.query(
        'UPDATE devices SET online = $1, last_seen = NOW() WHERE id = $2',
        [payload.online === true, deviceId]
    );
    if (payload.online === true) {
        await fastify.redis.set(`announce:${deviceId}`, '1', 'EX', REDIS_TTL_ANNOUNCE);
        await flushPending(fastify, deviceId);
        const shadow = await getShadow(fastify, deviceId);
        if (Object.keys(shadow.desired).length > 0) {
            fastify.mqttClient.publish(
                `device/${deviceId}/shadow/get_response`,
                JSON.stringify({ desired: shadow.desired }),
                { qos: 1 }
            );
        }
    }
}

export async function handleTelemetry(fastify, deviceId, payload) {
    const ts = payload.ts ? new Date(payload.ts * 1000).toISOString() : new Date().toISOString();
    await fastify.db.query(
        'INSERT INTO telemetry (device_id, ts, payload) VALUES ($1, $2, $3)',
        [deviceId, ts, JSON.stringify(payload)]
    );
}

const VALID_COMMAND_STATUS = new Set(['done', 'failed']);

export async function handleResponse(fastify, deviceId, payload) {
    if (payload.command_id) {
        const status = VALID_COMMAND_STATUS.has(payload.status) ? payload.status : 'done';
        await fastify.db.query(
            'UPDATE commands SET status = $1, executed_at = NOW() WHERE id = $2',
            [status, payload.command_id]
        );
    }
}

export async function handleOtaProgress(fastify, deviceId, payload) {
    await fastify.redis.set(`ota_progress:${deviceId}`, JSON.stringify(payload), 'EX', REDIS_TTL_OTA);
}
