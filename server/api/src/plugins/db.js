import fp from 'fastify-plugin';
import pg from 'pg';
import { config } from '../config.js';

const { Pool } = pg;

async function dbPlugin(fastify) {
    const pool = new Pool({
        host: config.db.host,
        port: config.db.port,
        database: config.db.database,
        user: config.db.user,
        password: config.db.password,
        max: config.db.poolMax,
        idleTimeoutMillis: config.db.idleTimeoutMs,
        connectionTimeoutMillis: config.db.connectionTimeoutMs,
        statement_timeout: config.db.statementTimeoutMs,
    });

    await pool.query('SELECT 1'); // verify connection on startup
    fastify.decorate('db', pool);

    fastify.decorate('withTransaction', async (fn) => {
        const client = await pool.connect();
        try {
            await client.query('BEGIN');
            const result = await fn(client);
            await client.query('COMMIT');
            return result;
        } catch (err) {
            await client.query('ROLLBACK');
            throw err;
        } finally {
            client.release();
        }
    });

    fastify.addHook('onClose', async () => pool.end());
}

export default fp(dbPlugin);
