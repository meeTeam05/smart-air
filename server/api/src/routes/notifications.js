import { listNotificationEventsForUser } from '../services/notification-events.js';
import { parsePositiveInt } from '../utils/parse.js';

const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 100;

export default async function notificationsRoutes(fastify) {
    const auth = { preHandler: fastify.authenticate };

    fastify.get('/notifications', auth, async (request, reply) => {
        const userId = request.user.sub;
        const limit = parsePositiveInt(request.query.limit, DEFAULT_LIMIT, MAX_LIMIT);
        if (limit === null || limit <= 0) {
            return reply.code(400).send({ error: 'limit must be a positive integer' });
        }

        const beforeIdRaw = request.query.before_id;
        const beforeId = beforeIdRaw == null ? null : String(beforeIdRaw).trim();
        if (beforeId != null && !/^[0-9]+$/.test(beforeId)) {
            return reply.code(400).send({ error: 'before_id must be a numeric event id' });
        }

        return listNotificationEventsForUser(fastify, userId, {
            beforeId,
            limit,
        });
    });
}
