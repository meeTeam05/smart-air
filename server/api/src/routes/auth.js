import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';

const REFRESH_EXPIRES_DAYS = parseInt(process.env.REFRESH_TOKEN_EXPIRES_DAYS || '30');

export default async function authRoutes(fastify) {
    const rl = { config: { rateLimit: { max: 10, timeWindow: '1 minute' } } };

    // POST /api/auth/register
    fastify.post('/auth/register', rl, async (request, reply) => {
        const { email, password, full_name } = request.body || {};
        if (!email || !password) return reply.code(400).send({ error: 'email and password required' });

        const hash = await bcrypt.hash(password, 12);
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
        const refreshToken = uuidv4();
        const expiresAt = new Date(Date.now() + REFRESH_EXPIRES_DAYS * 86400 * 1000);

        await fastify.db.query(
            'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
            [user.id, refreshToken, expiresAt]
        );
        await fastify.redis.set(`session:${user.id}`, refreshToken, 'EX', REFRESH_EXPIRES_DAYS * 86400);

        reply.setCookie('refreshToken', refreshToken, {
            httpOnly: true, sameSite: 'Strict', path: '/api/auth/refresh', maxAge: REFRESH_EXPIRES_DAYS * 86400
        });
        return { accessToken, user: { id: user.id, email: user.email, full_name: user.full_name } };
    });

    // POST /api/auth/refresh
    fastify.post('/auth/refresh', rl, async (request, reply) => {
        const token = request.cookies?.refreshToken;
        if (!token) return reply.code(401).send({ error: 'No refresh token' });

        const { rows } = await fastify.db.query(
            `SELECT rt.id, rt.user_id, u.email FROM refresh_tokens rt
             JOIN users u ON u.id = rt.user_id
             WHERE rt.token = $1 AND rt.expires_at > NOW()`,
            [token]
        );
        if (rows.length === 0) return reply.code(401).send({ error: 'Invalid or expired refresh token' });

        const { id: rtId, user_id, email } = rows[0];
        const newRefreshToken = uuidv4();
        const expiresAt = new Date(Date.now() + REFRESH_EXPIRES_DAYS * 86400 * 1000);

        await fastify.db.query('DELETE FROM refresh_tokens WHERE id = $1', [rtId]);
        await fastify.db.query(
            'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
            [user_id, newRefreshToken, expiresAt]
        );
        await fastify.redis.set(`session:${user_id}`, newRefreshToken, 'EX', REFRESH_EXPIRES_DAYS * 86400);

        const accessToken = fastify.jwt.sign({ sub: user_id, email });
        reply.setCookie('refreshToken', newRefreshToken, {
            httpOnly: true, sameSite: 'Strict', path: '/api/auth/refresh', maxAge: REFRESH_EXPIRES_DAYS * 86400
        });
        return { accessToken };
    });

    // POST /api/auth/logout
    fastify.post('/auth/logout', { preHandler: fastify.authenticate }, async (request, reply) => {
        const userId = request.user.sub;
        await fastify.db.query('DELETE FROM refresh_tokens WHERE user_id = $1', [userId]);
        await fastify.redis.del(`session:${userId}`);
        reply.clearCookie('refreshToken', { path: '/api/auth/refresh' });
        return { success: true };
    });
}
