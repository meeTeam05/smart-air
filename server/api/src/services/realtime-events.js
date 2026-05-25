import { projectNotificationEvent } from './notification-events.js';

export const REALTIME_NOTIFY_CHANNEL = 'realtime_events';
export const DEFAULT_REALTIME_REPLAY_LIMIT = 1000;

function queryTarget(target) {
    if (target?.query) return target;
    if (target?.db?.query) return target.db;
    throw new TypeError('realtime event target must be a pg client or fastify instance with db');
}

function asIsoString(value) {
    if (value instanceof Date) return value.toISOString();
    return new Date(value).toISOString();
}

function normalizeEvent(row) {
    return {
        id: String(row.id),
        type: row.type,
        device_id: row.device_id,
        occurred_at: row.occurred_at,
        payload: row.payload ?? {},
    };
}

function replayLimit(value) {
    const parsed = Number.parseInt(String(value ?? ''), 10);
    if (!Number.isInteger(parsed) || parsed <= 0) return DEFAULT_REALTIME_REPLAY_LIMIT;
    return Math.min(parsed, DEFAULT_REALTIME_REPLAY_LIMIT);
}

export function formatRealtimeEventPayload(event) {
    return {
        id: String(event.id),
        type: event.type,
        device_id: event.device_id ?? event.deviceId,
        occurred_at: asIsoString(event.occurred_at ?? event.occurredAt ?? new Date()),
        payload: event.payload ?? {},
    };
}

export function formatSseEvent(event) {
    const payload = formatRealtimeEventPayload(event);
    return `id: ${payload.id}\n`
        + `event: ${payload.type}\n`
        + `data: ${JSON.stringify(payload)}\n\n`;
}

export function parseLastEventId(value) {
    if (value === undefined || value === null || value === '') return '0';
    const id = String(value).trim();
    return /^[0-9]+$/.test(id) ? id : null;
}

export async function createRealtimeEvent(target, { type, deviceId, occurredAt = new Date(), payload = {}, idempotencyKey = null }) {
    if (typeof type !== 'string' || type.trim() === '') {
        throw new TypeError('realtime event type is required');
    }
    if (typeof deviceId !== 'string' || deviceId.trim() === '') {
        throw new TypeError('realtime event deviceId is required');
    }

    const db = queryTarget(target);
    const { rows } = await db.query(
        `INSERT INTO realtime_events (type, device_id, occurred_at, payload, idempotency_key)
         VALUES ($1, $2, $3, $4::jsonb, $5)
         ON CONFLICT (idempotency_key) WHERE idempotency_key IS NOT NULL DO NOTHING
         RETURNING id::text, type, device_id, occurred_at, payload`,
        [type, deviceId, occurredAt, JSON.stringify(payload), idempotencyKey]
    );
    let inserted = rows.length > 0;
    let event = inserted ? normalizeEvent(rows[0]) : null;
    if (!event && idempotencyKey) {
        const existing = await db.query(
            `SELECT id::text, type, device_id, occurred_at, payload
             FROM realtime_events
             WHERE idempotency_key = $1`,
            [idempotencyKey]
        );
        if (existing.rows.length === 0) {
            throw new Error('realtime event duplicate key lookup failed');
        }
        event = normalizeEvent(existing.rows[0]);
        inserted = false;
    }

    if (!event) {
        throw new Error('realtime event insert returned no row');
    }

    await projectNotificationEvent(db, event);

    if (!inserted) {
        return event;
    }

    await db.query('SELECT pg_notify($1, $2)', [REALTIME_NOTIFY_CHANNEL, event.id]);
    return event;
}

export async function getRealtimeEventById(fastify, eventId) {
    const parsedId = parseLastEventId(eventId);
    if (parsedId === null || parsedId === '0') return null;

    const { rows } = await fastify.db.query(
        `SELECT id::text, type, device_id, occurred_at, payload
         FROM realtime_events
         WHERE id = $1`,
        [parsedId]
    );
    return rows[0] ? normalizeEvent(rows[0]) : null;
}

export async function listRealtimeEventsForUser(fastify, userId, { afterId = '0', limit } = {}) {
    const parsedAfterId = parseLastEventId(afterId);
    if (parsedAfterId === null) return null;

    const { rows } = await fastify.db.query(
        `SELECT e.id::text, e.type, e.device_id, e.occurred_at, e.payload
         FROM realtime_events e
         JOIN devices d ON d.id = e.device_id
         JOIN home_members hm ON hm.home_id = d.home_id
         JOIN users u ON u.id = hm.user_id
         WHERE hm.user_id = $1
           AND u.is_active = TRUE
           AND e.id > $2
         ORDER BY e.id ASC
         LIMIT $3`,
        [userId, parsedAfterId, replayLimit(limit)]
    );
    return rows.map(normalizeEvent);
}

export async function userCanReplayFromEventId(fastify, userId, eventId) {
    const parsedEventId = parseLastEventId(eventId);
    if (parsedEventId === null) return false;
    if (parsedEventId === '0') return true;

    const { rows } = await fastify.db.query(
        `SELECT 1
         FROM realtime_events e
         JOIN devices d ON d.id = e.device_id
         JOIN home_members hm ON hm.home_id = d.home_id
         JOIN users u ON u.id = hm.user_id
         WHERE hm.user_id = $1
           AND u.is_active = TRUE
           AND e.id = $2
         LIMIT 1`,
        [userId, parsedEventId]
    );
    return rows.length > 0;
}
