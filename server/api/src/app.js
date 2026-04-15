import Fastify from 'fastify';
import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';
import cookie from '@fastify/cookie';

import dbPlugin from './plugins/db.js';
import redisPlugin from './plugins/redis.js';
import authPlugin from './plugins/auth.js';
import mqttPlugin from './plugins/mqtt.js';

import healthRoutes from './routes/health.js';
import authRoutes from './routes/auth.js';
import homesRoutes from './routes/homes.js';
import devicesRoutes from './routes/devices.js';
import shadowRoutes from './routes/shadow.js';
import commandsRoutes from './routes/commands.js';
import telemetryRoutes from './routes/telemetry.js';

const fastify = Fastify({ logger: true });

// ── Core plugins ────────────────────────────────────────────────
await fastify.register(cors, { origin: true });
await fastify.register(cookie);
await fastify.register(dbPlugin);
await fastify.register(redisPlugin);
await fastify.register(authPlugin);
await fastify.register(mqttPlugin);

// ── Rate limiting — applied globally, tighter on auth routes ────
await fastify.register(rateLimit, {
    global: false,
});

// ── Routes — all under /api prefix ──────────────────────────────
await fastify.register(healthRoutes, { prefix: '/api' });
await fastify.register(authRoutes, { prefix: '/api' });
await fastify.register(homesRoutes, { prefix: '/api' });
await fastify.register(devicesRoutes, { prefix: '/api' });
await fastify.register(shadowRoutes, { prefix: '/api' });
await fastify.register(commandsRoutes, { prefix: '/api' });
await fastify.register(telemetryRoutes, { prefix: '/api' });

// ── Start ────────────────────────────────────────────────────────
const port = parseInt(process.env.PORT || '3000');
try {
    await fastify.listen({ port, host: '0.0.0.0' });
} catch (err) {
    fastify.log.error(err);
    process.exit(1);
}
