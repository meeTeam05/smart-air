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
import { config } from '../config.js';

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
    const heartbeatMs = config.realtime.heartbeatMs;
    const maxClients = config.realtime.maxClients;
    const maxClientsPerIp = config.realtime.maxClientsPerIp;
    const replayLimit = config.realtime.replayLimit;
    let listener = null;
    let reconnectDelayMs = config.realtime.reconnectInitialDelayMs;
    let reconnectTimer = null;
    let closing = false;
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
        const clientIp = request.ip || request.raw?.socket?.remoteAddress || 'unknown';
        const lastEventId = parseLastEventId(
            request.headers['last-event-id'] ?? request.query?.lastEventId
        );
        if (lastEventId === null) {
            return reply.code(400).send({ error: 'Invalid Last-Event-ID' });
        }
        if (clients.size >= maxClients) {
            return reply.code(503).send({ error: 'Realtime capacity exceeded' });
        }
        const clientsForIp = [...clients].filter((client) => client.ip === clientIp).length;
        if (clientsForIp >= maxClientsPerIp) {
            return reply.code(429).send({ error: 'Realtime per-IP capacity exceeded' });
        }

        reply.hijack();
        reply.raw.writeHead(200, {
            'Content-Type': 'text/event-stream; charset=utf-8',
            'Cache-Control': 'no-cache, no-transform',
            Connection: 'keep-alive',
            'X-Accel-Buffering': 'no',
        });

        const client = {
            ip: clientIp,
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

    function handleNotification(message) {
        if (message.channel !== REALTIME_NOTIFY_CHANNEL || !message.payload) return;
        broadcastEventId(message.payload).catch((err) => {
            fastify.log.error({ err, eventId: message.payload }, 'realtime event broadcast failed');
        });
    }

    async function closeListener(currentListener, { unlisten = false } = {}) {
        if (!currentListener) return;

        currentListener.removeAllListeners('notification');
        currentListener.removeAllListeners('error');

        if (unlisten) {
            try {
                await currentListener.query(`UNLISTEN ${REALTIME_NOTIFY_CHANNEL}`);
            } catch (err) {
                fastify.log.warn({ err }, 'realtime listener unlisten failed during shutdown');
            }
        }

        currentListener.release();
    }

    function scheduleReconnect() {
        if (closing || reconnectTimer) return;

        const delayMs = reconnectDelayMs;
        reconnectDelayMs = Math.min(config.realtime.reconnectMaxDelayMs, delayMs * 2);
        reconnectTimer = setTimeout(() => {
            reconnectTimer = null;
            connectListener().catch((err) => {
                fastify.realtimeReadyAt = null;
                fastify.log.error({ err }, 'realtime listener reconnect failed');
                scheduleReconnect();
            });
        }, delayMs);
    }

    async function handleListenerError(currentListener, err) {
        if (closing || listener !== currentListener) return;

        listener = null;
        fastify.realtimeReadyAt = null;
        fastify.log.error({ err }, 'realtime listener connection error');

        try {
            await closeListener(currentListener);
        } catch (closeErr) {
            fastify.log.warn({ err: closeErr }, 'realtime listener release failed after connection error');
        }

        scheduleReconnect();
    }

    async function connectListener() {
        const currentListener = await fastify.db.connect();
        try {
            currentListener.on('notification', handleNotification);
            currentListener.on('error', (err) => {
                handleListenerError(currentListener, err).catch((error) => {
                    fastify.log.error({ err: error }, 'realtime listener recovery failed');
                });
            });
            await currentListener.query(`LISTEN ${REALTIME_NOTIFY_CHANNEL}`);
        } catch (err) {
            await closeListener(currentListener);
            throw err;
        }

        listener = currentListener;
        reconnectDelayMs = config.realtime.reconnectInitialDelayMs;
        fastify.realtimeReadyAt = Date.now();
    }

    await connectListener();

    fastify.decorate('realtime', {
        openStream,
        broadcastEventId,
        clientCount: () => clients.size,
    });

    fastify.addHook('onClose', async () => {
        closing = true;
        if (reconnectTimer) {
            clearTimeout(reconnectTimer);
            reconnectTimer = null;
        }
        for (const client of clients) {
            if (client.heartbeat) clearInterval(client.heartbeat);
            client.raw.end();
        }
        clients.clear();
        const currentListener = listener;
        listener = null;
        await closeListener(currentListener, { unlisten: true });
    });
}

export default fp(realtimePlugin);
