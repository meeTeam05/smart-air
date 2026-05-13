import fp from 'fastify-plugin';
import pg from 'pg';

const { Pool } = pg;

function parseEnvInt(name, fallback) {
    const value = Number.parseInt(process.env[name] || '', 10);
    return Number.isInteger(value) && value > 0 ? value : fallback;
}

async function dbPlugin(fastify) {
    const pool = new Pool({
        host: process.env.POSTGRES_HOST || 'postgres',
        port: parseEnvInt('POSTGRES_PORT', 5432),
        database: process.env.POSTGRES_DB || 'smartair',
        user: process.env.POSTGRES_USER || 'smartair',
        password: process.env.POSTGRES_PASSWORD,
        max: parseEnvInt('PG_POOL_MAX', 20),
        idleTimeoutMillis: parseEnvInt('PG_IDLE_TIMEOUT_MS', 30_000),
        connectionTimeoutMillis: parseEnvInt('PG_CONNECTION_TIMEOUT_MS', 5_000),
        statement_timeout: parseEnvInt('PG_STATEMENT_TIMEOUT_MS', 10_000),
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
