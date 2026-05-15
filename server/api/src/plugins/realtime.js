import fp from 'fastify-plugin';

import { checkDeviceAccess } from '../utils/check-access.js';
import {
    REALTIME_NOTIFY_CHANNEL,
    formatSseEvent,
    getRealtimeEventById,
    listRealtimeEventsForUser,
    parseLastEventId,
    userCanReplayFromEventId,
} from '../services/realtime-events.js';

const DEFAULT_HEARTBEAT_MS = 25_000;

function parsePositiveIntEnv(name, fallback) {
    const value = Number.parseInt(process.env[name] || '', 10);
    return Number.isInteger(value) && value > 0 ? value : fallback;
}

function eventIsNewer(eventId, lastSentEventId) {
    return BigInt(eventId) > BigInt(lastSentEventId || '0');
}

export async function sendRealtimeEventToClient(fastify, client, event) {
    if (!event || client.raw.destroyed || !eventIsNewer(event.id, client.lastSentEventId)) {
        return false;
    }

    const allowed = await checkDeviceAccess(fastify, event.device_id, client.userId);
    if (!allowed) {
        return false;
    }

    client.raw.write(formatSseEvent(event));
    client.lastSentEventId = String(event.id);
    return true;
}

async function realtimePlugin(fastify) {
    const clients = new Set();
    const heartbeatMs = parsePositiveIntEnv('REALTIME_HEARTBEAT_MS', DEFAULT_HEARTBEAT_MS);
    const replayLimit = parsePositiveIntEnv('REALTIME_REPLAY_LIMIT', 1000);
    const listener = await fastify.db.connect();
    fastify.decorate('realtimeReadyAt', null);

    async function broadcastEventId(eventId) {
        const event = await getRealtimeEventById(fastify, eventId);
        if (!event) return;

        await Promise.all([...clients].map(async (client) => {
            try {
                await sendRealtimeEventToClient(fastify, client, event);
            } catch (err) {
                fastify.log.warn({ err, userId: client.userId, eventId }, 'realtime client send failed');
            }
        }));
    }

    async function openStream(request, reply) {
        const lastEventId = parseLastEventId(
            request.headers['last-event-id'] ?? request.query?.lastEventId
        );
        if (lastEventId === null) {
            return reply.code(400).send({ error: 'Invalid Last-Event-ID' });
        }

        reply.hijack();
        reply.raw.writeHead(200, {
            'Content-Type': 'text/event-stream; charset=utf-8',
            'Cache-Control': 'no-cache, no-transform',
            Connection: 'keep-alive',
            'X-Accel-Buffering': 'no',
        });

        const client = {
            userId: request.user.sub,
            lastSentEventId: lastEventId,
            raw: reply.raw,
            heartbeat: null,
        };
        clients.add(client);

        const cleanup = () => {
            clients.delete(client);
            if (client.heartbeat) clearInterval(client.heartbeat);
        };
        request.raw.on('close', cleanup);

        client.heartbeat = setInterval(() => {
            if (client.raw.destroyed) {
                cleanup();
                return;
            }
            client.raw.write(': heartbeat\n\n');
        }, heartbeatMs);

        client.raw.write(': connected\n\n');

        try {
            const canReplay = await userCanReplayFromEventId(
                fastify,
                client.userId,
                lastEventId
            );
            if (!canReplay) {
                client.raw.write(formatSseEvent({
                    id: lastEventId,
                    type: 'replay.reset',
                    device_id: '',
                    occurred_at: new Date(),
                    payload: { reason: 'replay_unavailable' },
                }));
                return;
            }

            const replayEvents = await listRealtimeEventsForUser(fastify, client.userId, {
                afterId: lastEventId,
                limit: replayLimit,
            });
            for (const event of replayEvents ?? []) {
                await sendRealtimeEventToClient(fastify, client, event);
            }
        } catch (err) {
            fastify.log.error({ err, userId: client.userId }, 'realtime replay failed');
            client.raw.end();
            cleanup();
        }
    }

    listener.on('notification', (message) => {
        if (message.channel !== REALTIME_NOTIFY_CHANNEL || !message.payload) return;
        broadcastEventId(message.payload).catch((err) => {
            fastify.log.error({ err, eventId: message.payload }, 'realtime event broadcast failed');
        });
    });
    listener.on('error', (err) => {
        fastify.realtimeReadyAt = null;
        fastify.log.error({ err }, 'realtime listener connection error');
    });
    await listener.query(`LISTEN ${REALTIME_NOTIFY_CHANNEL}`);
    fastify.realtimeReadyAt = Date.now();

    fastify.decorate('realtime', {
        openStream,
        broadcastEventId,
        clientCount: () => clients.size,
    });

    fastify.addHook('onClose', async () => {
        for (const client of clients) {
            if (client.heartbeat) clearInterval(client.heartbeat);
            client.raw.end();
        }
        clients.clear();
        await listener.query(`UNLISTEN ${REALTIME_NOTIFY_CHANNEL}`);
        listener.release();
    });
}

export default fp(realtimePlugin);
