export default async function healthRoutes(fastify) {
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

        checks.mqtt = fastify.mqttClient.connected ? 'ok' : 'fail';
        if (!fastify.mqttClient.connected) healthy = false;

        return reply.code(healthy ? 200 : 503).send({
            status: healthy ? 'ok' : 'degraded',
            ts: Date.now(),
            checks,
        });
    });
}
