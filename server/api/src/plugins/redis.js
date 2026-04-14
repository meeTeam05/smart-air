import fp from 'fastify-plugin';
import Redis from 'ioredis';

async function redisPlugin(fastify) {
    const client = new Redis({
        host: process.env.REDIS_HOST || 'redis',
        port: parseInt(process.env.REDIS_PORT || '6379'),
        password: process.env.REDIS_PASSWORD,
    });

    await client.ping(); // verify connection on startup
    fastify.decorate('redis', client);
    fastify.addHook('onClose', async () => client.quit());
}

export default fp(redisPlugin);
