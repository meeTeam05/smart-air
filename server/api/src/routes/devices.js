import { v4 as uuidv4 } from 'uuid';
import { createDeviceUser, deleteDeviceUser } from '../services/emqx.js';
import { normalizeDeviceId } from '../utils/device-id.js';

export default async function devicesRoutes(fastify) {
    const auth = { preHandler: fastify.authenticate };

    // POST /api/devices — called after BLE provisioning
    fastify.post('/devices', auth, async (request, reply) => {
        const userId = request.user.sub;
        const { device_id, name, home_id, room_id } = request.body || {};
        const normalizedDeviceId = normalizeDeviceId(device_id);
        const uuidRe = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (!normalizedDeviceId || !name || !home_id) {
            return reply.code(400).send({ error: 'device_id, name, home_id required' });
        }
        if (!uuidRe.test(home_id)) {
            return reply.code(400).send({ error: 'home_id must be a valid UUID' });
        }

        // Verify caller is a member of the home
        const { rows: memberRows } = await fastify.db.query(
            'SELECT 1 FROM home_members WHERE home_id = $1 AND user_id = $2',
            [home_id, userId]
        );
        if (memberRows.length === 0) return reply.code(403).send({ error: 'Forbidden' });

        // Get default device type
        const { rows: typeRows } = await fastify.db.query(
            "SELECT id FROM device_types WHERE name = 'smart_air_v1' LIMIT 1"
        );
        const typeId = typeRows[0]?.id || null;

        const secretKey = uuidv4();
        let device;
        try {
            const { rows } = await fastify.db.query(
                `INSERT INTO devices (id, home_id, room_id, type_id, owner_id, name, secret_key)
                 VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
                [normalizedDeviceId, home_id, room_id || null, typeId, userId, name, secretKey]
            );
            device = rows[0];
        } catch (err) {
            if (err.code === '23505') return reply.code(409).send({ error: 'Device already registered' });
            throw err;
        }

        // Create EMQX user + ACL
        try {
            await createDeviceUser(normalizedDeviceId, secretKey);
        } catch (err) {
            fastify.log.warn({ err }, 'EMQX user creation failed — device still saved');
        }

        return reply.code(201).send({ ...device, secret_key: secretKey });
    });

    // GET /api/devices/announce/:mac — provisioning poll: has device announced itself online?
    // Returns {announced: true} when MQTT bridge saw the device come online.
    // The record disappears after 5 minutes so stale announcements don't linger.
    fastify.get('/devices/announce/:mac', auth, async (request, reply) => {
        const deviceId = normalizeDeviceId(request.params.mac);
        if (!deviceId) return reply.code(400).send({ error: 'Invalid mac' });
        const announced = await fastify.redis.get(`announce:${deviceId}`);
        return { announced: !!announced };
    });

    // GET /api/devices
    fastify.get('/devices', auth, async (request) => {
        const userId = request.user.sub;
        const { rows } = await fastify.db.query(
            `SELECT d.id, d.name, d.home_id, d.room_id, d.online, d.last_seen, d.firmware_ver, d.created_at
             FROM devices d
             JOIN home_members hm ON hm.home_id = d.home_id
             WHERE hm.user_id = $1
             ORDER BY d.created_at`,
            [userId]
        );
        return rows;
    });

    // PUT /api/devices/:id
    fastify.put('/devices/:id', auth, async (request, reply) => {
        const userId = request.user.sub;
        const deviceId = normalizeDeviceId(request.params.id);
        const { rows: devRows } = await fastify.db.query(
            'SELECT home_id FROM devices WHERE id = $1',
            [deviceId]
        );
        if (devRows.length === 0) return reply.code(404).send({ error: 'Not found' });
        const { rows: m } = await fastify.db.query(
            'SELECT 1 FROM home_members WHERE home_id = $1 AND user_id = $2',
            [devRows[0].home_id, userId]
        );
        if (m.length === 0) return reply.code(403).send({ error: 'Forbidden' });

        const { name, room_id } = request.body || {};
        const { rows } = await fastify.db.query(
            `UPDATE devices SET
               name = COALESCE($1, name),
               room_id = COALESCE($2, room_id)
             WHERE id = $3 RETURNING id, name, home_id, room_id, online, last_seen, firmware_ver`,
            [name || null, room_id || null, deviceId]
        );
        return rows[0];
    });

    // DELETE /api/devices/:id
    fastify.delete('/devices/:id', auth, async (request, reply) => {
        const userId = request.user.sub;
        const deviceId = normalizeDeviceId(request.params.id);
        const { rows: devRows } = await fastify.db.query(
            'SELECT home_id, owner_id FROM devices WHERE id = $1',
            [deviceId]
        );
        if (devRows.length === 0) return reply.code(404).send({ error: 'Not found' });

        const { rows: m } = await fastify.db.query(
            "SELECT role FROM home_members WHERE home_id = $1 AND user_id = $2",
            [devRows[0].home_id, userId]
        );
        if (m.length === 0 || !['owner', 'admin'].includes(m[0].role)) {
            return reply.code(403).send({ error: 'Forbidden' });
        }

        await fastify.db.query('DELETE FROM devices WHERE id = $1', [deviceId]);
        await fastify.redis.del(`shadow:${deviceId}`);
        await fastify.redis.del(`pending_cmds:${deviceId}`);

        try {
            await deleteDeviceUser(deviceId);
        } catch (err) {
            fastify.log.warn({ err }, 'EMQX user deletion failed');
        }

        return reply.code(204).send();
    });
}
