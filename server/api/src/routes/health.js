export default async function healthRoutes(fastify) {
    fastify.get('/health', async () => {
        return { status: 'ok', ts: Date.now() };
    });
}
