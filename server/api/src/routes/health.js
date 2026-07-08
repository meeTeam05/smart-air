import { checkEmqxApiHealth } from '../services/emqx.js';

async function getChecks(fastify, requestId) {
    const [postgres, redis, emqx] = await Promise.allSettled([
        fastify.db.query('SELECT 1'),
        fastify.redis.ping(),
        checkEmqxApiHealth(requestId),
    ]);

    return {
        postgres: postgres.status === 'fulfilled' ? 'ok' : 'fail',
        redis: redis.status === 'fulfilled' ? 'ok' : 'fail',
        emqx: emqx.status === 'fulfilled' ? 'ok' : 'fail',
        mqtt: fastify.mqttReadyAt ? 'ok' : 'fail',
        realtime: fastify.realtimeReadyAt ? 'ok' : 'fail',
    };
}

function isHealthy(checks) {
    return Object.values(checks).every((status) => status === 'ok');
}

export default async function healthRoutes(fastify) {
    async function sendReadiness(request, reply) {
        const checks = await getChecks(fastify, request.id);
        const healthy = isHealthy(checks);

        return reply.code(healthy ? 200 : 503).send({
            status: healthy ? 'ok' : 'degraded',
            ts: Date.now(),
            checks,
        });
    }

    // Liveness: server is up
    fastify.get('/health/live', async (request, reply) => {
        return reply.code(200).send({ status: 'ok', ts: Date.now() });
    });

    // Readiness: all backing services are connected and usable
    fastify.get('/health/ready', sendReadiness);

    // Backward-compatible alias that preserves JSON readiness behavior.
    fastify.get('/health', sendReadiness);
}
