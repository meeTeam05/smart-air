export default async function realtimeRoutes(fastify) {
    const auth = { preHandler: fastify.authenticate };

    fastify.get('/realtime', auth, async (request, reply) => {
        return fastify.realtime.openStream(request, reply);
    });
}
