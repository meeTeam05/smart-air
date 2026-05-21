import { createHash } from 'node:crypto';
import { getShadow, computeDelta, updateReported } from './shadow.js';
import { flushPending } from './commands.js';
import { createRealtimeEvent } from './realtime-events.js';
import { REDIS_TTL_ANNOUNCE, REDIS_TTL_OTA } from '../constants.js';

const SENSOR_FIELDS = Object.freeze(['temperature', 'humidity', 'co_ppm', 'no2_ppm']);
const RELAY_FIELDS = Object.freeze(['relay_1', 'relay_2', 'relay_3']);
const MAX_SHADOW_REPORT_BYTES = 16_384;
const MAX_TELEMETRY_PAYLOAD_BYTES = 4_096;
const MAX_UNIX_SECONDS = 4_294_967_295;

function isPlainObject(value) {
    return value && typeof value === 'object' && !Array.isArray(value);
}

function isFiniteUnixSeconds(value) {
    return typeof value === 'number'
        && Number.isFinite(value)
        && value > 0
        && value <= MAX_UNIX_SECONDS;
}

function validSensorValue(value) {
    return value === null || (typeof value === 'number' && Number.isFinite(value));
}

export function payloadByteLength(payload, rawByteLength = null) {
    if (Number.isInteger(rawByteLength) && rawByteLength >= 0) {
        return rawByteLength;
    }
    return Buffer.byteLength(JSON.stringify(payload), 'utf8');
}

function validateTelemetryPayload(deviceId, payload, rawByteLength = null) {
    if (!isPlainObject(payload)) return 'payload must be a plain JSON object';
    if (payloadByteLength(payload, rawByteLength) > MAX_TELEMETRY_PAYLOAD_BYTES) {
        return 'payload exceeds telemetry size limit';
    }
    if (typeof payload.device_id === 'string' && payload.device_id !== deviceId) {
        return 'device_id does not match topic';
    }
    if (payload.mode !== 'on' && payload.mode !== 'off') {
        return 'mode must be on or off';
    }
    if (!isFiniteUnixSeconds(payload.ts)) {
        return 'ts must be a finite Unix timestamp in seconds';
    }

    for (const field of SENSOR_FIELDS) {
        if (Object.hasOwn(payload, field) && !validSensorValue(payload[field])) {
            return `${field} must be number or null`;
        }
    }

    return null;
}

function validateShadowReportPayload(payload, rawByteLength = null) {
    if (!isPlainObject(payload)) return 'payload must be a plain JSON object';
    if (payloadByteLength(payload, rawByteLength) > MAX_SHADOW_REPORT_BYTES) {
        return 'payload exceeds shadow report size limit';
    }
    if (Object.hasOwn(payload, 'mode') && payload.mode !== 'on' && payload.mode !== 'off') {
        return 'mode must be on or off';
    }
    if (Object.hasOwn(payload, 'ts') && !isFiniteUnixSeconds(payload.ts)) {
        return 'ts must be a finite Unix timestamp in seconds';
    }

    for (const field of RELAY_FIELDS) {
        if (Object.hasOwn(payload, field) && typeof payload[field] !== 'boolean') {
            return `${field} must be boolean`;
        }
    }

    for (const field of SENSOR_FIELDS) {
        if (Object.hasOwn(payload, field) && !validSensorValue(payload[field])) {
            return `${field} must be number or null`;
        }
    }

    return null;
}

async function ensureDeviceExists(fastify, deviceId, handler) {
    const { rows } = await fastify.db.query('SELECT 1 FROM devices WHERE id = $1', [deviceId]);
    if (rows.length === 0) {
        fastify.log.warn({ deviceId, handler }, 'unknown device input ignored');
        return false;
    }

    return true;
}

const MIN_TELEMETRY_TS_SEC = 946684800;

function telemetryEventPayload(payload, ts) {
    return {
        ts,
        temperature: Object.hasOwn(payload, 'temperature') ? payload.temperature : null,
        humidity: Object.hasOwn(payload, 'humidity') ? payload.humidity : null,
        co_ppm: Object.hasOwn(payload, 'co_ppm') ? payload.co_ppm : null,
        no2_ppm: Object.hasOwn(payload, 'no2_ppm') ? payload.no2_ppm : null,
        mode: payload.mode,
    };
}

function telemetryMessageId(packet) {
    if (packet?.qos !== 1) return null;
    const messageId = Number(packet.messageId);
    return Number.isInteger(messageId) && messageId > 0 ? messageId : null;
}

function payloadHash(payload) {
    return createHash('sha256').update(JSON.stringify(payload)).digest('hex');
}

export async function publishShadowGetResponse(fastify, deviceId, shadow, logMessage = 'shadow get_response publish failed') {
    try {
        await fastify.mqttPublish(
            `device/${deviceId}/shadow/get_response`,
            JSON.stringify({
                desired: shadow.desired ?? {},
                delta: computeDelta(shadow.reported ?? {}, shadow.desired ?? {}),
                ts: Math.floor(Date.now() / 1000),
            }),
            { qos: 1 }
        );
    } catch (err) {
        fastify.log.warn({ err, deviceId }, logMessage);
        throw err;
    }
}

export async function handleStatus(fastify, deviceId, payload) {
    if (!isPlainObject(payload) || typeof payload.online !== 'boolean') {
        fastify.log.warn({ deviceId, payload }, 'invalid status payload ignored');
        return;
    }

    if (!await ensureDeviceExists(fastify, deviceId, 'status')) {
        return;
    }

    await fastify.db.query(
        'UPDATE devices SET online = $1, last_seen = NOW() WHERE id = $2',
        [payload.online, deviceId]
    );
    await createRealtimeEvent(fastify, {
        type: 'device.status',
        deviceId,
        payload: {
            online: payload.online,
            firmware: typeof payload.firmware === 'string' ? payload.firmware : null,
        },
    });
    if (payload.online) {
        await fastify.redis.set(`announce:${deviceId}`, '1', 'EX', REDIS_TTL_ANNOUNCE);
        try {
            await flushPending(fastify, deviceId);
        } catch (e) {
            fastify.log.error({ err: e, deviceId }, 'flushPending failed on device online');
        }
        const shadow = await getShadow(fastify, deviceId);
        if (Object.keys(shadow.desired).length > 0) {
            try {
                await publishShadowGetResponse(fastify, deviceId, shadow, 'shadow sync publish failed after status online');
            } catch {
                // Status handling should still ACK; the device can request shadow/get again.
            }
        }
    }
}

export async function handleTelemetry(fastify, deviceId, payload, packet = null, rawByteLength = null) {
    if (!await ensureDeviceExists(fastify, deviceId, 'telemetry')) {
        return;
    }

    const payloadBytes = isPlainObject(payload) ? payloadByteLength(payload, rawByteLength) : null;
    const invalidReason = validateTelemetryPayload(deviceId, payload, rawByteLength);
    if (invalidReason) {
        fastify.log.warn(
            { deviceId, invalidReason, payloadBytes },
            'invalid telemetry payload ignored'
        );
        return;
    }

    const messageId = telemetryMessageId(packet);
    try {
        const insertResult = await fastify.db.query(
            `WITH normalized AS (
                 SELECT CASE
                     WHEN $2 < $3 THEN to_timestamp($3)
                     WHEN $2 > EXTRACT(EPOCH FROM NOW()) + 300 THEN NOW()
                     ELSE to_timestamp($2)
                 END AS ts
             )
             INSERT INTO telemetry (device_id, ts, payload, mqtt_message_id)
             SELECT $1, normalized.ts, $4, $5
             FROM normalized
             ON CONFLICT DO NOTHING
             RETURNING ts`,
            [deviceId, payload.ts, MIN_TELEMETRY_TS_SEC, JSON.stringify(payload), messageId]
        );
        if (insertResult.rowCount === 0) return;
        const ts = new Date(insertResult.rows[0].ts).toISOString();
        if (payload.ts < MIN_TELEMETRY_TS_SEC) {
            fastify.log.warn({ deviceId, ts: payload.ts, normalizedTs: MIN_TELEMETRY_TS_SEC }, 'old telemetry ts clamped');
        } else {
            const normalizedSec = Math.floor(new Date(insertResult.rows[0].ts).getTime() / 1000);
            if (normalizedSec !== payload.ts) {
                fastify.log.warn({ deviceId, ts: payload.ts, normalizedTs: normalizedSec }, 'future telemetry ts clamped');
            }
        }
        await createRealtimeEvent(fastify, {
            type: 'telemetry.point',
            deviceId,
            occurredAt: ts,
            payload: telemetryEventPayload(payload, ts),
        });
    } catch (err) {
        if (err.code === '23514' && err.constraint === 'telemetry_payload_size_check') {
            fastify.log.warn({ deviceId, err, payloadBytes }, 'telemetry payload rejected by size constraint');
            return;
        }
        throw err;
    }
}

export async function handleShadowReport(fastify, deviceId, payload, rawByteLength = null) {
    if (!await ensureDeviceExists(fastify, deviceId, 'shadow/report')) {
        return;
    }

    const invalidReason = validateShadowReportPayload(payload, rawByteLength);
    if (invalidReason) {
        fastify.log.warn({ deviceId, invalidReason, payload }, 'invalid shadow report ignored');
        return;
    }

    const { shadow, applied } = await updateReported(fastify, deviceId, payload);
    if (!applied) {
        fastify.log.info({ deviceId, ts: payload.ts }, 'stale shadow report ignored');
        return;
    }
    await createRealtimeEvent(fastify, {
        type: 'shadow.reported',
        deviceId,
        payload: {
            reported: shadow.reported ?? {},
            patch: payload,
        },
        idempotencyKey: `shadow.reported:${deviceId}:${payload.ts}:${payloadHash(payload)}`,
    });
}

export async function handleShadowGet(fastify, deviceId, payload) {
    if (!await ensureDeviceExists(fastify, deviceId, 'shadow/get')) {
        return;
    }

    if (!isPlainObject(payload)) {
        fastify.log.warn({ deviceId }, 'invalid shadow get payload ignored');
        return;
    }

    const shadow = await getShadow(fastify, deviceId);
    await publishShadowGetResponse(fastify, deviceId, shadow, 'shadow get_response publish failed after shadow/get');
}

const VALID_COMMAND_STATUS = new Set(['done', 'error']);
const TERMINAL_COMMAND_STATUS = new Set(['done', 'error', 'timeout']);
const MAX_ERROR_MESSAGE_LENGTH = 512;

function cleanCommandErrorMessage(payload) {
    if (typeof payload?.reason !== 'string') return null;
    const trimmed = payload.reason.trim();
    if (!trimmed) return null;
    return trimmed.slice(0, MAX_ERROR_MESSAGE_LENGTH);
}

export async function handleResponse(fastify, deviceId, payload) {
    const isObjectPayload = payload && typeof payload === 'object' && !Array.isArray(payload);
    const commandId = isObjectPayload ? payload.command_id : undefined;
    const status = isObjectPayload ? payload.status : undefined;
    if (!commandId || typeof commandId !== 'string' || !VALID_COMMAND_STATUS.has(status)) {
        fastify.log.warn({ deviceId, payload }, 'malformed command response');
        return;
    }

    if (typeof payload.device_id === 'string' && payload.device_id !== deviceId) {
        fastify.log.warn(
            { deviceId, payloadDeviceId: payload.device_id, commandId },
            'command response device mismatch ignored'
        );
        return;
    }

    await fastify.db.query(
        `UPDATE commands
         SET status = 'sent',
             sent_at = COALESCE(sent_at, NOW())
         WHERE id = $1 AND device_id = $2 AND status = 'pending'`,
        [commandId, deviceId]
    );

    const updateResult = await fastify.db.query(
        `UPDATE commands
         SET status = $1, executed_at = NOW(), error_message = $4
         WHERE id = $2 AND device_id = $3 AND status = 'sent'
         RETURNING id, device_id, status, executed_at, error_message`,
        [status, commandId, deviceId, status === 'error' ? cleanCommandErrorMessage(payload) : null]
    );

    if (updateResult.rowCount > 0) {
        const command = updateResult.rows[0];
        await createRealtimeEvent(fastify, {
            type: 'command.updated',
            deviceId,
            occurredAt: command.executed_at ?? new Date(),
            payload: {
                command_id: command.id,
                status: command.status,
                error_message: command.error_message ?? null,
            },
            idempotencyKey: `command.updated:${command.id}:${command.status}`,
        });
        return;
    }

    const { rows } = await fastify.db.query(
        'SELECT status FROM commands WHERE id = $1 AND device_id = $2',
        [commandId, deviceId]
    );

    if (rows.length === 0) {
        fastify.log.warn({ deviceId, commandId }, 'command response for unknown command/device pair');
        return;
    }

    const currentStatus = rows[0].status;
    if (currentStatus === status) {
        fastify.log.info({ deviceId, commandId, status }, 'duplicate command response ignored');
        return;
    }

    if (TERMINAL_COMMAND_STATUS.has(currentStatus)) {
        fastify.log.warn(
            { deviceId, commandId, currentStatus, incomingStatus: status },
            'stale or conflicting terminal command response ignored'
        );
        return;
    }

    fastify.log.warn(
        { deviceId, commandId, currentStatus, incomingStatus: status },
        'command response ignored due to non-sent command state'
    );
}

export async function handleOtaProgress(fastify, deviceId, payload) {
    if (!await ensureDeviceExists(fastify, deviceId, 'ota')) {
        return;
    }

    await fastify.redis.set(`ota_progress:${deviceId}`, JSON.stringify(payload), 'EX', REDIS_TTL_OTA);
    await createRealtimeEvent(fastify, {
        type: 'ota.progress',
        deviceId,
        payload,
        idempotencyKey: Object.hasOwn(payload, 'ts')
            ? `ota.progress:${deviceId}:${payload.ts}:${payloadHash(payload)}`
            : null,
    });
}
