export default async function healthRoutes(fastify) {
    // Liveness: server is up
    fastify.get('/health/live', async (request, reply) => {
        return reply.code(200).send({ status: 'ok', ts: Date.now() });
    });

    // Readiness: all backing services are connected and usable
    fastify.get('/health/ready', async (request, reply) => {
        const checks = {};
        let healthy = true;

        try {
            await fastify.db.query('SELECT 1');
            checks.postgres = 'ok';
        } catch {
            checks.postgres = 'fail';
            healthy = false;
        }

        try {
            await fastify.redis.ping();
            checks.redis = 'ok';
        } catch {
            checks.redis = 'fail';
            healthy = false;
        }

        checks.mqtt = fastify.mqttReadyAt ? 'ok' : 'fail';
        if (!fastify.mqttReadyAt) healthy = false;

        return reply.code(healthy ? 200 : 503).send({
            status: healthy ? 'ok' : 'degraded',
            ts: Date.now(),
            checks,
        });
    });

    // Alias for backward compatibility — preserves JSON readiness behavior directly
    fastify.get('/health', async (request, reply) => {
        const checks = {};
        let healthy = true;

        try {
            await fastify.db.query('SELECT 1');
            checks.postgres = 'ok';
        } catch {
            checks.postgres = 'fail';
            healthy = false;
        }

        try {
            await fastify.redis.ping();
            checks.redis = 'ok';
        } catch {
            checks.redis = 'fail';
            healthy = false;
        }

        checks.mqtt = fastify.mqttReadyAt ? 'ok' : 'fail';
        if (!fastify.mqttReadyAt) healthy = false;

        return reply.code(healthy ? 200 : 503).send({
            status: healthy ? 'ok' : 'degraded',
            ts: Date.now(),
            checks,
        });
    });
}
