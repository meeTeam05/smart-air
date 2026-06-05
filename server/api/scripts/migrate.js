import fs from 'fs/promises';
import path from 'path';
import pg from 'pg';
import { fileURLToPath } from 'url';
import { config } from '../src/config.js';

const { Pool } = pg;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const migrationsDir = path.resolve(__dirname, '../../db/migrations');

const MIGRATION_LOCK_ID = 54321;
const LOCK_TIMEOUT_MS = 60000;
const LOCK_RETRY_INTERVAL_MS = 1000;

async function acquireLock(client) {
    const startTime = Date.now();
    while (Date.now() - startTime < LOCK_TIMEOUT_MS) {
        const { rows } = await client.query('SELECT pg_try_advisory_lock($1) as locked', [MIGRATION_LOCK_ID]);
        if (rows[0].locked) {
            return true;
        }
        console.log('Migration lock busy, waiting...');
        await new Promise(resolve => setTimeout(resolve, LOCK_RETRY_INTERVAL_MS));
    }
    return false;
}

async function ensureMigrationsTable(db) {
    await db.query(`
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version     VARCHAR PRIMARY KEY,
            applied_at  TIMESTAMPTZ DEFAULT NOW()
        )
    `);
}

async function seedLegacyInitialMigration(db) {
    const { rows } = await db.query(
        "SELECT to_regclass('public.users') AS users_table"
    );
    const hasInitialSchema = rows[0]?.users_table !== null;
    if (!hasInitialSchema) return;

    await db.query(
        `INSERT INTO schema_migrations (version)
         VALUES ('001_initial_schema.sql')
         ON CONFLICT (version) DO NOTHING`
    );
}

async function run() {
    const pool = new Pool({
        host: config.db.host,
        port: config.db.port,
        database: config.db.database,
        user: config.db.user,
        password: config.db.password,
    });

    const client = await pool.connect();
    let lockAcquired = false;

    try {
        lockAcquired = await acquireLock(client);
        if (!lockAcquired) {
            throw new Error(`Failed to acquire migration lock (${MIGRATION_LOCK_ID}) after ${LOCK_TIMEOUT_MS / 1000}s`);
        }
        console.log('Migration advisory lock acquired');

        await ensureMigrationsTable(client);
        await seedLegacyInitialMigration(client);

        const applied = await client.query('SELECT version FROM schema_migrations');
        const appliedSet = new Set(applied.rows.map((row) => row.version));

        const files = (await fs.readdir(migrationsDir))
            .filter((file) => file.endsWith('.sql'))
            .sort();

        for (const file of files) {
            if (appliedSet.has(file)) continue;

            const sql = await fs.readFile(path.join(migrationsDir, file), 'utf8');
            console.log(`Applying migration ${file}`);
            await client.query(sql);
            await client.query(
                'INSERT INTO schema_migrations (version) VALUES ($1)',
                [file]
            );
        }

        console.log('Migrations complete');
    } finally {
        if (lockAcquired) {
            await client.query('SELECT pg_advisory_unlock($1)', [MIGRATION_LOCK_ID]);
            console.log('Migration advisory lock released');
        }
        client.release();
        await pool.end();
    }
}

run().catch((err) => {
    console.error('Migration failed');
    console.error(err);
    process.exit(1);
});
