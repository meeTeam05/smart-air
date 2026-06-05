import fp from 'fastify-plugin';
import jwt from '@fastify/jwt';
import { config } from '../config.js';

async function authPlugin(fastify) {
    fastify.register(jwt, {
        secret: config.jwt.secret,
        sign: { expiresIn: config.jwt.expiresIn },
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
