import fp from 'fastify-plugin';
import pg from 'pg';

const { Pool } = pg;

async function dbPlugin(fastify) {
    const pool = new Pool({
        host: process.env.POSTGRES_HOST || 'postgres',
        port: parseInt(process.env.POSTGRES_PORT || '5432'),
        database: process.env.POSTGRES_DB || 'smartair',
        user: process.env.POSTGRES_USER || 'smartair',
        password: process.env.POSTGRES_PASSWORD,
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
