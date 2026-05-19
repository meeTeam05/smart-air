import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { v4 as uuidv4 } from 'uuid';
import { BCRYPT_ROUNDS, REFRESH_COOKIE_PATH, SECONDS_PER_DAY } from '../constants.js';
import { isValidEmail, normalizeEmail } from '../utils/parse.js';

const REFRESH_EXPIRES_DAYS = parseInt(process.env.REFRESH_TOKEN_EXPIRES_DAYS || '30');
const REFRESH_RACE_GRACE_MS = 5_000;

function hashRefreshToken(token) {
    return crypto.createHash('sha256').update(token).digest('hex');
}

async function revokeUserRefreshSessions(fastify, userId) {
    await fastify.db.query('DELETE FROM refresh_tokens WHERE user_id = $1', [userId]);
}

async function markRefreshTokenConsumed(client, tokenHash, userId, expiresAt) {
    await client.query(
        `INSERT INTO refresh_token_reuse_markers (token_hash, user_id, expires_at, consumed_at)
         VALUES ($1, $2, $3, NOW())
         ON CONFLICT (token_hash) DO UPDATE
            SET user_id = EXCLUDED.user_id,
                expires_at = GREATEST(refresh_token_reuse_markers.expires_at, EXCLUDED.expires_at),
                consumed_at = NOW()`,
        [tokenHash, userId, expiresAt]
    );
}

async function findConsumedRefreshToken(client, tokenHash) {
    const { rows } = await client.query(
        `SELECT user_id, consumed_at
         FROM refresh_token_reuse_markers
         WHERE token_hash = $1 AND expires_at > NOW()`,
        [tokenHash]
    );
    return rows[0]
        ? { userId: rows[0].user_id, consumedAt: rows[0].consumed_at }
        : null;
}

function isRecentRefreshRace(consumedAt) {
    const consumedMs = consumedAt instanceof Date ? consumedAt.getTime() : Date.parse(consumedAt);
    return Number.isFinite(consumedMs) && (Date.now() - consumedMs) <= REFRESH_RACE_GRACE_MS;
}

function isValidPassword(password) {
    if (typeof password !== 'string') return false;
    const bytes = Buffer.byteLength(password, 'utf8');
    return bytes >= 8 && bytes <= 72;
}

async function createRefreshToken(client, userId) {
    const token = uuidv4();
    const tokenHash = hashRefreshToken(token);
    const expiresAt = new Date(Date.now() + REFRESH_EXPIRES_DAYS * SECONDS_PER_DAY * 1000);
    await client.query(
        'INSERT INTO refresh_tokens (user_id, token, expires_at) VALUES ($1, $2, $3)',
        [userId, tokenHash, expiresAt]
    );
    return { token, tokenHash, expiresAt };
}

function setRefreshCookie(reply, token) {
    reply.setCookie('refreshToken', token, {
        httpOnly: true,
        sameSite: 'Strict',
        path: REFRESH_COOKIE_PATH,
        maxAge: REFRESH_EXPIRES_DAYS * SECONDS_PER_DAY,
        secure: process.env.NODE_ENV === 'production',
    });
}

async function issueRefreshToken(fastify, reply, userId) {
    const { token } = await createRefreshToken(fastify.db, userId);
    setRefreshCookie(reply, token);
    return token;
}

export default async function authRoutes(fastify) {
    const authRateLimitConfig = { config: { rateLimit: { max: 10, timeWindow: '1 minute' } } };

    // POST /api/auth/register
    fastify.post('/auth/register', authRateLimitConfig, async (request, reply) => {
        const { email, password, full_name } = request.body || {};
        const normalizedEmail = normalizeEmail(email);
        if (!isValidEmail(normalizedEmail)) return reply.code(400).send({ error: 'valid email required' });
        if (!isValidPassword(password)) {
            return reply.code(400).send({ error: 'password must be 8-72 bytes' });
        }

        const hash = await bcrypt.hash(password, BCRYPT_ROUNDS);
        try {
            const { rows } = await fastify.db.query(
                `INSERT INTO users (email, password_hash, full_name)
                 VALUES ($1, $2, $3) RETURNING id, email, full_name, created_at`,
                [normalizedEmail, hash, typeof full_name === 'string' && full_name.trim() ? full_name.trim() : null]
            );
            return reply.code(201).send(rows[0]);
        } catch (err) {
            if (err.code === '23505') return reply.code(409).send({ error: 'Email already registered' });
            throw err;
        }
    });

    // POST /api/auth/login
    fastify.post('/auth/login', authRateLimitConfig, async (request, reply) => {
        const { email, password } = request.body || {};
        const normalizedEmail = normalizeEmail(email);
        if (!isValidEmail(normalizedEmail) || typeof password !== 'string') {
            return reply.code(400).send({ error: 'email and password required' });
        }

        const { rows } = await fastify.db.query(
            'SELECT id, email, password_hash, full_name, is_active FROM users WHERE email = $1',
            [normalizedEmail]
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
    fastify.post('/auth/refresh', authRateLimitConfig, async (request, reply) => {
        // body.refreshToken takes priority (mobile); fallback to HttpOnly cookie (browser)
        const token = request.body?.refreshToken !== undefined
            ? request.body.refreshToken
            : request.cookies?.refreshToken;
        if (token === undefined || token === null) return reply.code(401).send({ error: 'No refresh token' });
        if (typeof token !== 'string' || token.trim() === '') {
            return reply.code(401).send({ error: 'Invalid or expired refresh token' });
        }
        const tokenHash = hashRefreshToken(token);

        const refreshResult = await fastify.withTransaction(async (client) => {
            const { rows } = await client.query(
                `SELECT rt.id, rt.user_id, rt.expires_at, u.email FROM refresh_tokens rt
                 JOIN users u ON u.id = rt.user_id
                 WHERE rt.token = $1 AND rt.expires_at > NOW() AND u.is_active = TRUE
                 FOR UPDATE OF rt`,
                [tokenHash]
            );

            if (rows.length === 0) {
                const consumedToken = await findConsumedRefreshToken(client, tokenHash);
                if (consumedToken) {
                    if (isRecentRefreshRace(consumedToken.consumedAt)) {
                        return { invalid: true, reuseUserId: consumedToken.userId, race: true };
                    }
                    await client.query('DELETE FROM refresh_tokens WHERE user_id = $1', [consumedToken.userId]);
                    return { invalid: true, reuseUserId: consumedToken.userId, replay: true };
                }
                return { invalid: true };
            }

            const { id: rtId, user_id, email, expires_at: expiresAt } = rows[0];
            await markRefreshTokenConsumed(client, tokenHash, user_id, expiresAt);

            const { rowCount } = await client.query(
                'DELETE FROM refresh_tokens WHERE id = $1 RETURNING id',
                [rtId]
            );

            if (rowCount === 0) {
                await client.query('DELETE FROM refresh_tokens WHERE user_id = $1', [user_id]);
                return { invalid: true, reuseUserId: user_id, rtId, replay: true };
            }

            const accessToken = fastify.jwt.sign({ sub: user_id, email });
            const newRefreshToken = await createRefreshToken(client, user_id);
            return { accessToken, refreshToken: newRefreshToken.token, userId: user_id };
        });

        if (refreshResult.invalid) {
            if (refreshResult.reuseUserId) {
                if (refreshResult.race) {
                    fastify.log.info(
                        {
                            event: 'refresh_race_retry_ignored',
                            userId: refreshResult.reuseUserId,
                            tokenHashPrefix: tokenHash.slice(0, 12),
                        },
                        'Concurrent refresh retry rejected without revoking active sessions'
                    );
                } else {
                fastify.log.warn(
                    {
                        event: refreshResult.replay ? 'refresh_reuse_detected' : 'refresh_race_or_reuse',
                        userId: refreshResult.reuseUserId,
                        rtId: refreshResult.rtId,
                        tokenHashPrefix: tokenHash.slice(0, 12),
                    },
                    'Refresh token replay detected; revoked active refresh sessions'
                );
                }
            } else {
                fastify.log.info(
                    {
                        event: 'refresh_invalid_or_expired',
                        tokenHashPrefix: tokenHash.slice(0, 12),
                    },
                    'Invalid or expired refresh token rejected'
                );
            }

            reply.clearCookie('refreshToken', {
                path: REFRESH_COOKIE_PATH,
                secure: process.env.NODE_ENV === 'production',
            });
            return reply.code(401).send({ error: 'Invalid or expired refresh token' });
        }

        setRefreshCookie(reply, refreshResult.refreshToken);
        return { accessToken: refreshResult.accessToken, refreshToken: refreshResult.refreshToken };
    });

    // POST /api/auth/logout
    fastify.post('/auth/logout', { preHandler: fastify.authenticate }, async (request, reply) => {
        const userId = request.user.sub;
        await revokeUserRefreshSessions(fastify, userId);
        reply.clearCookie('refreshToken', {
            path: REFRESH_COOKIE_PATH,
            secure: process.env.NODE_ENV === 'production',
        });
        return { success: true };
    });
}
