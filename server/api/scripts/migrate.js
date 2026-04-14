import fs from 'fs/promises';
import path from 'path';
import pg from 'pg';
import { fileURLToPath } from 'url';

const { Pool } = pg;

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const migrationsDir = path.resolve(__dirname, '../../db/migrations');

async function ensureMigrationsTable(pool) {
    await pool.query(`
        CREATE TABLE IF NOT EXISTS schema_migrations (
            version     VARCHAR PRIMARY KEY,
            applied_at  TIMESTAMPTZ DEFAULT NOW()
        )
    `);
}

async function seedLegacyInitialMigration(pool) {
    const { rows } = await pool.query(
        "SELECT to_regclass('public.users') AS users_table"
    );
    const hasInitialSchema = rows[0]?.users_table !== null;
    if (!hasInitialSchema) return;

    await pool.query(
        `INSERT INTO schema_migrations (version)
         VALUES ('001_initial_schema.sql')
         ON CONFLICT (version) DO NOTHING`
    );
}

async function run() {
    const pool = new Pool({
        host: process.env.POSTGRES_HOST || 'postgres',
        port: parseInt(process.env.POSTGRES_PORT || '5432', 10),
        database: process.env.POSTGRES_DB || 'smartair',
        user: process.env.POSTGRES_USER || 'smartair',
        password: process.env.POSTGRES_PASSWORD,
    });

    try {
        await ensureMigrationsTable(pool);
        await seedLegacyInitialMigration(pool);

        const applied = await pool.query('SELECT version FROM schema_migrations');
        const appliedSet = new Set(applied.rows.map((row) => row.version));

        const files = (await fs.readdir(migrationsDir))
            .filter((file) => file.endsWith('.sql'))
            .sort();

        for (const file of files) {
            if (appliedSet.has(file)) continue;

            const sql = await fs.readFile(path.join(migrationsDir, file), 'utf8');
            console.log(`Applying migration ${file}`);
            await pool.query(sql);
            await pool.query(
                'INSERT INTO schema_migrations (version) VALUES ($1)',
                [file]
            );
        }

        console.log('Migrations complete');
    } finally {
        await pool.end();
    }
}

run().catch((err) => {
    console.error('Migration failed');
    console.error(err);
    process.exit(1);
});
