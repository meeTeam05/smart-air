import { requireRole, checkMembership } from '../utils/check-access.js';

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
        if (!name) return reply.code(400).send({ error: 'name required' });

        const home = await fastify.withTransaction(async (client) => {
            const { rows } = await client.query(
                `INSERT INTO homes (owner_id, name, address, timezone)
                 VALUES ($1, $2, $3, $4) RETURNING *`,
                [userId, name, address || null, timezone || 'Asia/Ho_Chi_Minh']
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
        const userId = request.user.sub;
        await requireRole(fastify, request.params.id, userId, 'owner', 'admin');
        const { name, address, timezone } = request.body || {};
        const { rows } = await fastify.db.query(
            `UPDATE homes SET
               name = COALESCE($1, name),
               address = COALESCE($2, address),
               timezone = COALESCE($3, timezone)
             WHERE id = $4 RETURNING *`,
            [name || null, address || null, timezone || null, request.params.id]
        );
        if (rows.length === 0) return reply.code(404).send({ error: 'Not found' });
        return rows[0];
    });

    fastify.delete('/homes/:id', auth, async (request, reply) => {
        const userId = request.user.sub;
        await requireRole(fastify, request.params.id, userId, 'owner');
        await fastify.db.query('DELETE FROM homes WHERE id = $1', [request.params.id]);
        return reply.code(204).send();
    });

    fastify.post('/homes/:id/invite', auth, async (request, reply) => {
        const userId = request.user.sub;
        await requireRole(fastify, request.params.id, userId, 'owner', 'admin');
        const { email, role } = request.body || {};
        if (!email) return reply.code(400).send({ error: 'email required' });

        const { rows: userRows } = await fastify.db.query(
            'SELECT id FROM users WHERE email = $1',
            [email.toLowerCase()]
        );
        if (userRows.length === 0) return reply.code(404).send({ error: 'User not found' });

        try {
            await fastify.db.query(
                'INSERT INTO home_members (home_id, user_id, role) VALUES ($1, $2, $3)',
                [request.params.id, userRows[0].id, role || 'member']
            );
        } catch (err) {
            if (err.code === '23505') return reply.code(409).send({ error: 'Already a member' });
            throw err;
        }
        return { success: true };
    });

    // ── Rooms ────────────────────────────────────────────────────
    fastify.get('/homes/:homeId/rooms', auth, async (request, reply) => {
        const userId = request.user.sub;
        const allowed = await checkMembership(fastify, request.params.homeId, userId);
        if (!allowed) return reply.code(403).send({ error: 'Forbidden' });
        const { rows } = await fastify.db.query(
            'SELECT * FROM rooms WHERE home_id = $1 ORDER BY name',
            [request.params.homeId]
        );
        return rows;
    });

    fastify.post('/homes/:homeId/rooms', auth, async (request, reply) => {
        const userId = request.user.sub;
        await requireRole(fastify, request.params.homeId, userId, 'owner', 'admin');
        const { name, icon } = request.body || {};
        if (!name) return reply.code(400).send({ error: 'name required' });
        const { rows } = await fastify.db.query(
            'INSERT INTO rooms (home_id, name, icon) VALUES ($1, $2, $3) RETURNING *',
            [request.params.homeId, name, icon || null]
        );
        return reply.code(201).send(rows[0]);
    });

    fastify.put('/rooms/:id', auth, async (request, reply) => {
        const { rows: roomRows } = await fastify.db.query('SELECT home_id FROM rooms WHERE id = $1', [request.params.id]);
        if (roomRows.length === 0) return reply.code(404).send({ error: 'Not found' });
        await requireRole(fastify, roomRows[0].home_id, request.user.sub, 'owner', 'admin');
        const { name, icon } = request.body || {};
        const { rows } = await fastify.db.query(
            `UPDATE rooms SET name = COALESCE($1, name), icon = COALESCE($2, icon) WHERE id = $3 RETURNING *`,
            [name || null, icon || null, request.params.id]
        );
        return rows[0];
    });

    fastify.delete('/rooms/:id', auth, async (request, reply) => {
        const { rows: roomRows } = await fastify.db.query('SELECT home_id FROM rooms WHERE id = $1', [request.params.id]);
        if (roomRows.length === 0) return reply.code(404).send({ error: 'Not found' });
        await requireRole(fastify, roomRows[0].home_id, request.user.sub, 'owner', 'admin');
        await fastify.db.query('DELETE FROM rooms WHERE id = $1', [request.params.id]);
        return reply.code(204).send();
    });
}
