import { requireRole, checkMembership } from '../utils/check-access.js';
import { cleanupDeletedDevice } from '../services/device-cleanup.js';
import { MAX_HOMES_PER_USER, MAX_ROOMS_PER_HOME } from '../constants.js';
import { cleanOptionalString, cleanRequiredString, isValidEmail, normalizeEmail, parseUuid } from '../utils/parse.js';

const VALID_INVITE_ROLES = new Set(['admin', 'member']);

async function lockQuota(client, key) {
    await client.query('SELECT pg_advisory_xact_lock(hashtext($1))', [key]);
}

function cleanNullableString(value) {
    if (value === undefined) return undefined;
    if (value === null) return null;
    return cleanOptionalString(value);
}

export default async function homesRoutes(fastify) {
    const auth = { preHandler: fastify.authenticate };

    // ── Homes ────────────────────────────────────────────────────
    fastify.get('/homes', auth, async (request) => {
        const userId = request.user.sub;
        const { rows } = await fastify.db.query(
            `SELECT h.* FROM homes h
             JOIN home_members hm ON hm.home_id = h.id
             WHERE hm.user_id = $1
             ORDER BY h.created_at`,
            [userId]
        );
        return rows;
    });

    fastify.post('/homes', auth, async (request, reply) => {
        const userId = request.user.sub;
        const { name, address, timezone } = request.body || {};
        const cleanName = cleanRequiredString(name);
        if (!cleanName) return reply.code(400).send({ error: 'name required' });
        const cleanAddress = cleanNullableString(address);
        const cleanTimezone = cleanOptionalString(timezone) || 'Asia/Ho_Chi_Minh';
        if (address !== undefined && cleanAddress === null && address !== null) return reply.code(400).send({ error: 'address must be non-empty' });
        if (timezone !== undefined && !cleanOptionalString(timezone)) return reply.code(400).send({ error: 'timezone must be non-empty' });

        const home = await fastify.withTransaction(async (client) => {
            await lockQuota(client, `quota:homes:${userId}`);
            const { rows: countRows } = await client.query(
                'SELECT COUNT(*)::int AS n FROM home_members WHERE user_id = $1 AND role = $2',
                [userId, 'owner']
            );
            if (countRows[0].n >= MAX_HOMES_PER_USER) {
                const err = new Error('home limit reached');
                err.statusCode = 429;
                throw err;
            }
            const { rows } = await client.query(
                `INSERT INTO homes (owner_id, name, address, timezone)
                 VALUES ($1, $2, $3, $4) RETURNING *`,
                [userId, cleanName, cleanAddress ?? null, cleanTimezone]
            );
            const home = rows[0];
            await client.query(
                'INSERT INTO home_members (home_id, user_id, role) VALUES ($1, $2, $3)',
                [home.id, userId, 'owner']
            );
            return home;
        });
        return reply.code(201).send(home);
    });

    fastify.put('/homes/:id', auth, async (request, reply) => {
        const homeId = parseUuid(request.params.id);
        if (!homeId) return reply.code(400).send({ error: 'home id must be UUID' });
        const userId = request.user.sub;
        await requireRole(fastify, homeId, userId, 'owner', 'admin');
        const { name, address, timezone } = request.body || {};
        const cleanName = name === undefined ? undefined : cleanRequiredString(name);
        const cleanAddress = cleanNullableString(address);
        const cleanTimezone = timezone === undefined ? undefined : cleanOptionalString(timezone);
        if (name !== undefined && !cleanName) return reply.code(400).send({ error: 'name must be non-empty' });
        if (address !== undefined && cleanAddress === null && address !== null) return reply.code(400).send({ error: 'address must be non-empty' });
        if (timezone !== undefined && !cleanTimezone) return reply.code(400).send({ error: 'timezone must be non-empty' });
        const { rows } = await fastify.db.query(
            `UPDATE homes SET
               name = CASE WHEN $1 THEN $2 ELSE name END,
               address = CASE WHEN $3 THEN $4 ELSE address END,
               timezone = CASE WHEN $5 THEN $6 ELSE timezone END
             WHERE id = $7 RETURNING *`,
            [
                name !== undefined, cleanName ?? null,
                address !== undefined, cleanAddress ?? null,
                timezone !== undefined, cleanTimezone ?? null,
                homeId,
            ]
        );
        if (rows.length === 0) return reply.code(404).send({ error: 'Not found' });
        return rows[0];
    });

    fastify.delete('/homes/:id', auth, async (request, reply) => {
        const homeId = parseUuid(request.params.id);
        if (!homeId) return reply.code(400).send({ error: 'home id must be UUID' });
        const userId = request.user.sub;

        const deviceIds = await fastify.withTransaction(async (client) => {
            const { rows: homeRows } = await client.query(
                `SELECT h.id
                 FROM homes h
                 JOIN home_members hm ON hm.home_id = h.id
                 JOIN users u ON u.id = hm.user_id
                 WHERE h.id = $1 AND hm.user_id = $2 AND hm.role = $3 AND u.is_active = TRUE
                 FOR UPDATE OF h`,
                [homeId, userId, 'owner']
            );
            if (homeRows.length === 0) {
                const err = new Error('Forbidden');
                err.statusCode = 403;
                throw err;
            }

            const { rows: deviceRows } = await client.query(
                'SELECT id FROM devices WHERE home_id = $1',
                [homeId]
            );
            await client.query('DELETE FROM homes WHERE id = $1', [homeId]);
            return deviceRows.map((row) => row.id);
        });
        for (const deviceId of deviceIds) {
            await cleanupDeletedDevice(fastify, deviceId);
        }
        return reply.code(204).send();
    });

    fastify.post('/homes/:id/invite', auth, async (request, reply) => {
        const homeId = parseUuid(request.params.id);
        if (!homeId) return reply.code(400).send({ error: 'home id must be UUID' });
        const userId = request.user.sub;
        await requireRole(fastify, homeId, userId, 'owner', 'admin');
        const { email, role } = request.body || {};
        const normalizedEmail = normalizeEmail(email);
        if (!isValidEmail(normalizedEmail)) {
            return reply.code(400).send({ error: 'valid email required' });
        }

        if (role && !VALID_INVITE_ROLES.has(role)) {
            return reply.code(400).send({ error: 'role must be admin or member' });
        }

        const { rows: userRows } = await fastify.db.query(
            'SELECT id FROM users WHERE email = $1',
            [normalizedEmail]
        );
        if (userRows.length === 0) {
            // Return success without revealing whether email is registered (S9)
            return { success: true };
        }

        try {
            await fastify.db.query(
                'INSERT INTO home_members (home_id, user_id, role) VALUES ($1, $2, $3)',
                [homeId, userRows[0].id, role || 'member']
            );
        } catch (err) {
            if (err.code === '23505') return reply.code(409).send({ error: 'Already a member' });
            throw err;
        }
        return { success: true };
    });

    // ── Rooms ────────────────────────────────────────────────────
    fastify.get('/homes/:homeId/rooms', auth, async (request, reply) => {
        const homeId = parseUuid(request.params.homeId);
        if (!homeId) return reply.code(400).send({ error: 'home id must be UUID' });
        const userId = request.user.sub;
        const allowed = await checkMembership(fastify, homeId, userId);
        if (!allowed) return reply.code(403).send({ error: 'Forbidden' });
        const { rows } = await fastify.db.query(
            'SELECT * FROM rooms WHERE home_id = $1 ORDER BY name',
            [homeId]
        );
        return rows;
    });

    fastify.post('/homes/:homeId/rooms', auth, async (request, reply) => {
        const homeId = parseUuid(request.params.homeId);
        if (!homeId) return reply.code(400).send({ error: 'home id must be UUID' });
        const userId = request.user.sub;
        await requireRole(fastify, homeId, userId, 'owner', 'admin');
        const { name, icon } = request.body || {};
        const cleanName = cleanRequiredString(name);
        const cleanIcon = cleanNullableString(icon);
        if (!cleanName) return reply.code(400).send({ error: 'name required' });
        if (icon !== undefined && cleanIcon === null && icon !== null) return reply.code(400).send({ error: 'icon must be non-empty' });
        const room = await fastify.withTransaction(async (client) => {
            await lockQuota(client, `quota:rooms:${homeId}`);
            const { rows: countRows } = await client.query(
                'SELECT COUNT(*)::int AS n FROM rooms WHERE home_id = $1',
                [homeId]
            );
            if (countRows[0].n >= MAX_ROOMS_PER_HOME) {
                const err = new Error('room limit reached');
                err.statusCode = 429;
                throw err;
            }
            const { rows } = await client.query(
                'INSERT INTO rooms (home_id, name, icon) VALUES ($1, $2, $3) RETURNING *',
                [homeId, cleanName, cleanIcon ?? null]
            );
            return rows[0];
        });
        return reply.code(201).send(room);
    });

    fastify.put('/rooms/:id', auth, async (request, reply) => {
        const roomId = parseUuid(request.params.id);
        if (!roomId) return reply.code(400).send({ error: 'room id must be UUID' });
        const { rows: roomRows } = await fastify.db.query('SELECT home_id FROM rooms WHERE id = $1', [roomId]);
        if (roomRows.length === 0) return reply.code(404).send({ error: 'Not found' });
        await requireRole(fastify, roomRows[0].home_id, request.user.sub, 'owner', 'admin');
        const { name, icon } = request.body || {};
        const cleanName = name === undefined ? undefined : cleanRequiredString(name);
        const cleanIcon = cleanNullableString(icon);
        if (name !== undefined && !cleanName) return reply.code(400).send({ error: 'name must be non-empty' });
        if (icon !== undefined && cleanIcon === null && icon !== null) return reply.code(400).send({ error: 'icon must be non-empty' });
        const { rows } = await fastify.db.query(
            `UPDATE rooms SET
               name = CASE WHEN $1 THEN $2 ELSE name END,
               icon = CASE WHEN $3 THEN $4 ELSE icon END
             WHERE id = $5 RETURNING *`,
            [name !== undefined, cleanName ?? null, icon !== undefined, cleanIcon ?? null, roomId]
        );
        if (rows.length === 0) return reply.code(404).send({ error: 'Not found' });
        return rows[0];
    });

    fastify.delete('/rooms/:id', auth, async (request, reply) => {
        const roomId = parseUuid(request.params.id);
        if (!roomId) return reply.code(400).send({ error: 'room id must be UUID' });
        const { rows: roomRows } = await fastify.db.query('SELECT home_id FROM rooms WHERE id = $1', [roomId]);
        if (roomRows.length === 0) return reply.code(404).send({ error: 'Not found' });
        await requireRole(fastify, roomRows[0].home_id, request.user.sub, 'owner', 'admin');
        await fastify.db.query('DELETE FROM rooms WHERE id = $1', [roomId]);
        return reply.code(204).send();
    });
}
