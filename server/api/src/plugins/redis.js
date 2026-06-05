import fp from 'fastify-plugin';
import Redis from 'ioredis';
import { config } from '../config.js';

async function redisPlugin(fastify) {
    const client = new Redis({
        host: config.redis.host,
        port: config.redis.port,
        password: config.redis.password,
    });

    await client.ping(); // verify connection on startup
    fastify.decorate('redis', client);
    fastify.addHook('onClose', async () => client.quit());
}

export default fp(redisPlugin);
