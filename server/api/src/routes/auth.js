import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import { BCRYPT_ROUNDS, REFRESH_COOKIE_PATH, SECONDS_PER_DAY } from '../constants.js';

const REFRESH_EXPIRES_DAYS = parseInt(process.env.REFRESH_TOKEN_EXPIRES_DAYS || '30');

async function issueRefreshToken(fastify, reply, userId) {
    const token = uuidv4();
    const expiresAt = new Date(Date.now() + REFRESH_EXPIRES_DAYS * SECONDS_PER_DAY * 1000);
    await fastify.db.query(
        'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
        [userId, token, expiresAt]
    );
    await fastify.redis.set(`session:${userId}`, token, 'EX', REFRESH_EXPIRES_DAYS * SECONDS_PER_DAY);
    reply.setCookie('refreshToken', token, {
        httpOnly: true, sameSite: 'Strict', path: REFRESH_COOKIE_PATH, maxAge: REFRESH_EXPIRES_DAYS * SECONDS_PER_DAY
    });
    return token;
}

export default async function authRoutes(fastify) {
    const rl = { config: { rateLimit: { max: 10, timeWindow: '1 minute' } } };

    // POST /api/auth/register
    fastify.post('/auth/register', rl, async (request, reply) => {
        const { email, password, full_name } = request.body || {};
        if (!email || !password) return reply.code(400).send({ error: 'email and password required' });

        const hash = await bcrypt.hash(password, BCRYPT_ROUNDS);
        try {
            const { rows } = await fastify.db.query(
                `INSERT INTO users (email, password_hash, full_name)
                 VALUES ($1, $2, $3) RETURNING id, email, full_name, created_at`,
                [email.toLowerCase(), hash, full_name || null]
            );
            return reply.code(201).send(rows[0]);
        } catch (err) {
            if (err.code === '23505') return reply.code(409).send({ error: 'Email already registered' });
            throw err;
        }
    });

    // POST /api/auth/login
    fastify.post('/auth/login', rl, async (request, reply) => {
        const { email, password } = request.body || {};
        if (!email || !password) return reply.code(400).send({ error: 'email and password required' });

        const { rows } = await fastify.db.query(
            'SELECT id, email, password_hash, full_name, is_active FROM users WHERE email = $1',
            [email.toLowerCase()]
        );
        const user = rows[0];
        if (!user || !user.is_active) return reply.code(401).send({ error: 'Invalid credentials' });

        const valid = await bcrypt.compare(password, user.password_hash);
        if (!valid) return reply.code(401).send({ error: 'Invalid credentials' });

        const accessToken = fastify.jwt.sign({ sub: user.id, email: user.email });
        const refreshToken = await issueRefreshToken(fastify, reply, user.id);
        // refreshToken also in body for mobile clients (no cookie jar)
        return { accessToken, refreshToken, user: { id: user.id, email: user.email, full_name: user.full_name } };
    });

    // POST /api/auth/refresh
    fastify.post('/auth/refresh', rl, async (request, reply) => {
        // body.refreshToken takes priority (mobile); fallback to HttpOnly cookie (browser)
        const token = request.body?.refreshToken ?? request.cookies?.refreshToken;
        if (!token) return reply.code(401).send({ error: 'No refresh token' });

        const { rows } = await fastify.db.query(
            `SELECT rt.id, rt.user_id, u.email FROM refresh_tokens rt
             JOIN users u ON u.id = rt.user_id
             WHERE rt.token = $1 AND rt.expires_at > NOW()`,
            [token]
        );
        if (rows.length === 0) return reply.code(401).send({ error: 'Invalid or expired refresh token' });

        const { id: rtId, user_id, email } = rows[0];
        // Revoke old token before issuing new one (token rotation)
        await fastify.db.query('DELETE FROM refresh_tokens WHERE id = $1', [rtId]);

        const accessToken = fastify.jwt.sign({ sub: user_id, email });
        const newRefreshToken = await issueRefreshToken(fastify, reply, user_id);
        return { accessToken, refreshToken: newRefreshToken };
    });

    // POST /api/auth/logout
    fastify.post('/auth/logout', { preHandler: fastify.authenticate }, async (request, reply) => {
        const userId = request.user.sub;
        await fastify.db.query('DELETE FROM refresh_tokens WHERE user_id = $1', [userId]);
        await fastify.redis.del(`session:${userId}`);
        reply.clearCookie('refreshToken', { path: REFRESH_COOKIE_PATH });
        return { success: true };
    });
}
