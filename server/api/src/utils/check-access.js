/**
 * Shared authorization helpers.
 *
 * Three levels of access check:
 *   checkDeviceAccess — user is a member of the home that owns this device
 *   checkMembership   — user is a member of a specific home (any role)
 *   requireRole       — user has a specific role in a home (throws 403)
 */

export async function checkDeviceAccess(fastify, deviceId, userId) {
    const { rows } = await fastify.db.query(
        `SELECT 1 FROM devices d
         JOIN home_members hm ON hm.home_id = d.home_id
         WHERE d.id = $1 AND hm.user_id = $2`,
        [deviceId, userId]
    );
    return rows.length > 0;
}

export async function checkMembership(fastify, homeId, userId) {
    const { rows } = await fastify.db.query(
        'SELECT 1 FROM home_members WHERE home_id = $1 AND user_id = $2',
        [homeId, userId]
    );
    return rows.length > 0;
}

export async function requireRole(fastify, homeId, userId, ...roles) {
    const { rows } = await fastify.db.query(
        'SELECT role FROM home_members WHERE home_id = $1 AND user_id = $2',
        [homeId, userId]
    );
    if (rows.length === 0 || !roles.includes(rows[0].role)) {
        const err = new Error('Forbidden');
        err.statusCode = 403;
        throw err;
    }
}
