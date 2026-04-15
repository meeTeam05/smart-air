import fp from 'fastify-plugin';
import jwt from '@fastify/jwt';

async function authPlugin(fastify) {
    fastify.register(jwt, {
        secret: process.env.JWT_SECRET,
        sign: { expiresIn: process.env.JWT_EXPIRES_IN || '15m' },
    });

    fastify.decorate('authenticate', async function (request, reply) {
        try {
            await request.jwtVerify();
        } catch (err) {
            reply.code(401).send({ error: 'Unauthorized' });
        }
    });
}

export default fp(authPlugin);
