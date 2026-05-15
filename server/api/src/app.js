import Fastify from 'fastify';
import cors from '@fastify/cors';
import rateLimit from '@fastify/rate-limit';
import cookie from '@fastify/cookie';

import { ALLOWED_ORIGINS } from './constants.js';
import dbPlugin from './plugins/db.js';
import redisPlugin from './plugins/redis.js';
import authPlugin from './plugins/auth.js';
import mqttPlugin from './plugins/mqtt.js';
import realtimePlugin from './plugins/realtime.js';

import healthRoutes from './routes/health.js';
import authRoutes from './routes/auth.js';
import homesRoutes from './routes/homes.js';
import devicesRoutes from './routes/devices.js';
import shadowRoutes from './routes/shadow.js';
import commandsRoutes from './routes/commands.js';
import telemetryRoutes from './routes/telemetry.js';
import realtimeRoutes from './routes/realtime.js';
import { registerCommandTimeoutJob } from './jobs/command-timeout.js';
import { registerEmqxCleanupRetryJob } from './jobs/emqx-cleanup-retry.js';
import { registerRefreshTokenMarkerCleanupJob } from './jobs/refresh-token-marker-cleanup.js';
import { registerRealtimeEventRetentionJob } from './jobs/realtime-event-retention.js';

// ── Startup guards ──────────────────────────────────────────────
const REQUIRED_RUNTIME_ENV_VARS = [
    'JWT_SECRET',
    'POSTGRES_PASSWORD',
    'REDIS_PASSWORD',
    'EMQX_API_KEY',
    'EMQX_API_SECRET',
    'EMQX_MQTT_PASSWORD',
];

const DEFAULT_BODY_LIMIT_BYTES = 65_536;

function parsePositiveIntEnv(name, fallback) {
    const value = Number.parseInt(process.env[name] || '', 10);
    return Number.isInteger(value) && value > 0 ? value : fallback;
}

function getMissingRequiredEnvVars(requiredVars) {
    return requiredVars.filter((name) => {
        const value = process.env[name];
        return typeof value !== 'string' || value.trim() === '';
    });
}

function getSafeClientErrorMessage(error, statusCode) {
    if (error.validation) return 'Invalid request payload';
    if (statusCode === 400) return 'Bad request';
    if (statusCode === 401) return 'Unauthorized';
    if (statusCode === 403) return 'Forbidden';
    if (statusCode === 404) return 'Not found';
    if (statusCode === 405) return 'Method not allowed';
    if (statusCode === 409) return 'Conflict';
    if (statusCode === 429) return 'Too many requests';
    return 'Internal server error';
}

const missingRequiredEnvVars = getMissingRequiredEnvVars(REQUIRED_RUNTIME_ENV_VARS);
if (missingRequiredEnvVars.length > 0) {
    console.error('FATAL: Missing required environment variables for server/api startup:');
    for (const name of missingRequiredEnvVars) {
        console.error(`- ${name}`);
    }
    process.exit(1);
}

const fastify = Fastify({
    bodyLimit: parsePositiveIntEnv('BODY_LIMIT_BYTES', DEFAULT_BODY_LIMIT_BYTES),
    logger: {
        level: process.env.LOG_LEVEL || 'info',
        redact: [
            'req.headers.authorization',
            'req.body.password',
            'req.body.refreshToken',
            'req.body.secret_key',
            'res.body.refreshToken',
        ],
    },
});

// ── Core plugins ────────────────────────────────────────────────
await fastify.register(cors, { origin: ALLOWED_ORIGINS, credentials: true });
await fastify.register(cookie);
await fastify.register(dbPlugin);
await fastify.register(redisPlugin);
await fastify.register(authPlugin);
await fastify.register(mqttPlugin);
await fastify.register(realtimePlugin);

registerCommandTimeoutJob(fastify);
registerEmqxCleanupRetryJob(fastify);
registerRefreshTokenMarkerCleanupJob(fastify);
registerRealtimeEventRetentionJob(fastify);

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
await fastify.register(realtimeRoutes, { prefix: '/api' });

// ── Global Error Handler ─────────────────────────────────────────
fastify.setErrorHandler((error, request, reply) => {
    const rawStatusCode = Number(error?.statusCode);
    const statusCode = Number.isInteger(rawStatusCode) && rawStatusCode >= 400 && rawStatusCode < 600
        ? rawStatusCode
        : 500;

    // Server-side: structured log with request context
    fastify.log.error(
        {
            err: error,
            requestId: request.id,
            method: request.method,
            url: request.url,
            ip: request.ip,
            userAgent: request.headers['user-agent'],
            statusCode,
        },
        'Request failed'
    );

    if (reply.sent) return;

    // Client-side: sanitized payload
    if (statusCode >= 500) {
        return reply.code(500).send({ error: 'Internal server error' });
    }

    // Respect explicit statusCode for known operational errors (4xx)
    const safeMessage = getSafeClientErrorMessage(error, statusCode);
    reply.code(statusCode).send({
        error: safeMessage,
        ...(process.env.NODE_ENV === 'development' ? { originalError: error.message } : {})
    });
});

// ── Start ────────────────────────────────────────────────────────
const port = parseInt(process.env.PORT || '3000');
try {
    await fastify.listen({ port, host: '0.0.0.0' });
} catch (err) {
    fastify.log.error(err);
    process.exit(1);
}

// ── Graceful shutdown ────────────────────────────────────────────
for (const signal of ['SIGTERM', 'SIGINT']) {
    process.on(signal, async () => {
        fastify.log.info({ signal }, 'Shutting down gracefully');
        await fastify.close();
        process.exit(0);
    });
}
