#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_lib.sh
source "$SCRIPT_DIR/_lib.sh"

usage() {
    cat <<'EOF'
Usage: check-db.sh <device_id>

Read-only runtime and schema checks against the postgres service defined in
server/docker-compose.yml and server/.env.
EOF
}

if (($# == 1)) && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

if (($# != 1)); then
    usage
    exit 2
fi

DEVICE_ID="$1"
DEVICE_ID_SQL="$(sql_quote_literal "$DEVICE_ID")"
POSTGRES_DB="$(env_require "POSTGRES_DB")"
POSTGRES_USER="$(env_require "POSTGRES_USER")"
POSTGRES_PASSWORD="$(env_get "POSTGRES_PASSWORD")"

pg_query_raw() {
    local sql="$1"
    shift
    compose exec -T postgres env PGPASSWORD="${POSTGRES_PASSWORD:-}" \
        psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -At -F $'\t' "$@" -c "$sql"
}

pg_query_report() {
    local sql="$1"
    shift
    compose exec -T postgres env PGPASSWORD="${POSTGRES_PASSWORD:-}" \
        psql -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -P pager=off "$@" -c "$sql"
}

run_pg_probe() {
    local label="$1"
    local sql="$2"
    shift 2
    local output
    if output="$(pg_query_raw "$sql" "$@" 2>&1)"; then
        pass "$label"
        if [[ -n "$output" ]]; then
            printf '%s\n' "$output"
        fi
        return 0
    fi

    fail "$label"
    printf '%s\n' "$output"
    return 1
}

check_common_prerequisites

print_section "Database Runtime"
if ! compose_has_service "postgres"; then
    fail "postgres service is not declared in $(basename "$COMPOSE_FILE")"
    finalize_checks
fi

postgres_state="$(service_state "postgres")"
postgres_health="$(service_health "postgres")"
if [[ "$postgres_state" != "running" ]]; then
    fail "postgres container state is $postgres_state"
elif [[ "$postgres_health" != "healthy" && "$postgres_health" != "none" ]]; then
    fail "postgres container health is $postgres_health"
else
    pass "postgres runtime is $(service_runtime_label "postgres")"
fi

if ! run_pg_probe "SELECT 1 canary query" "SELECT 1;"; then
    finalize_checks
fi

print_section "Schema"
schema_table_exists="$(
    pg_query_raw "SELECT EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = 'schema_migrations'
    );"
)"
if [[ "$schema_table_exists" == "t" ]]; then
    pass "schema_migrations table exists"
else
    fail "schema_migrations table is missing"
fi

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
expected_versions_file="$temp_dir/expected.txt"
applied_versions_file="$temp_dir/applied.txt"

if [[ "$schema_table_exists" == "t" ]]; then
    find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name '*.sql' -printf '%f\n' | sort >"$expected_versions_file"
    pg_query_raw "SELECT version FROM schema_migrations ORDER BY version;" >"$applied_versions_file"

    missing_versions="$(comm -23 "$expected_versions_file" "$applied_versions_file" || true)"
    extra_versions="$(comm -13 "$expected_versions_file" "$applied_versions_file" || true)"

    if [[ -z "$missing_versions" && -z "$extra_versions" ]]; then
        pass "schema_migrations matches files in server/db/migrations"
    else
        [[ -n "$missing_versions" ]] && fail "missing applied migrations: $(printf '%s\n' "$missing_versions" | join_lines)"
        [[ -n "$extra_versions" ]] && fail "unexpected applied migrations: $(printf '%s\n' "$extra_versions" | join_lines)"
    fi
else
    skip "schema_migrations diff skipped because the table is missing"
fi

installed_extensions="$temp_dir/extensions.txt"
expected_extensions="$temp_dir/expected-extensions.txt"
printf '%s\n' citext pgcrypto timescaledb | sort >"$expected_extensions"
pg_query_raw "SELECT extname FROM pg_extension WHERE extname IN ('citext', 'pgcrypto', 'timescaledb') ORDER BY extname;" >"$installed_extensions"
missing_extensions="$(comm -23 "$expected_extensions" "$installed_extensions" || true)"
if [[ -z "$missing_extensions" ]]; then
    pass "required extensions are installed"
else
    fail "missing extensions: $(printf '%s\n' "$missing_extensions" | join_lines)"
fi

missing_tables="$(
    pg_query_raw "
        WITH required(name) AS (
            VALUES
                ('users'),
                ('homes'),
                ('home_members'),
                ('rooms'),
                ('devices'),
                ('device_shadows'),
                ('commands'),
                ('telemetry'),
                ('schema_migrations')
        )
        SELECT name
        FROM required
        WHERE to_regclass('public.' || name) IS NULL
        ORDER BY name;
    "
)"
if [[ -z "$missing_tables" ]]; then
    pass "core tables exist"
else
    fail "missing tables: $(printf '%s\n' "$missing_tables" | join_lines)"
fi

telemetry_hypertable="$(
    pg_query_raw "
        SELECT EXISTS (
            SELECT 1
            FROM timescaledb_information.hypertables
            WHERE hypertable_schema = 'public'
              AND hypertable_name = 'telemetry'
        );
    "
)"
if [[ "$telemetry_hypertable" == "t" ]]; then
    pass "telemetry is a TimescaleDB hypertable"
else
    fail "telemetry is not registered as a TimescaleDB hypertable"
fi

print_section "Device"
device_exists="$(pg_query_raw "SELECT EXISTS (SELECT 1 FROM devices WHERE id = $DEVICE_ID_SQL);")"
if [[ "$device_exists" != "t" ]]; then
    fail "device '$DEVICE_ID' does not exist"
    skip "device-dependent sections skipped"
    finalize_checks
fi

pass "device '$DEVICE_ID' exists"
pg_query_report "
    SELECT
        d.id AS device_id,
        d.name AS device_name,
        h.name AS home_name,
        r.name AS room_name,
        COALESCE(u.full_name, u.email, h.owner_id::text, d.owner_id::text) AS owner,
        d.online,
        d.last_seen,
        d.firmware_ver,
        d.created_at
    FROM devices d
    LEFT JOIN homes h ON h.id = d.home_id
    LEFT JOIN rooms r ON r.id = d.room_id
    LEFT JOIN users u ON u.id = COALESCE(d.owner_id, h.owner_id)
    WHERE d.id = $DEVICE_ID_SQL;
"

shadow_exists="$(pg_query_raw "SELECT EXISTS (SELECT 1 FROM device_shadows WHERE device_id = $DEVICE_ID_SQL);")"
print_section "Shadow"
if [[ "$shadow_exists" == "t" ]]; then
    pass "shadow row exists"
    pg_query_report "
        SELECT
            device_id,
            jsonb_pretty(reported) AS reported,
            jsonb_pretty(desired) AS desired,
            updated_at
        FROM device_shadows
        WHERE device_id = $DEVICE_ID_SQL;
    "
else
    warn "shadow row is missing for '$DEVICE_ID'"
fi

telemetry_count="$(pg_query_raw "SELECT COUNT(*) FROM telemetry WHERE device_id = $DEVICE_ID_SQL;")"
print_section "Telemetry"
if [[ "$telemetry_count" == "0" ]]; then
    warn "no telemetry rows found for '$DEVICE_ID'"
else
    pass "telemetry rows found for '$DEVICE_ID'"
    pg_query_report "
        WITH latest AS (
            SELECT device_id, ts, jsonb_pretty(payload) AS payload
            FROM telemetry
            WHERE device_id = $DEVICE_ID_SQL
            ORDER BY ts DESC
            LIMIT 1
        )
        SELECT
            latest.device_id,
            latest.ts AS latest_ts,
            latest.payload AS latest_payload,
            (SELECT COUNT(*) FROM telemetry WHERE device_id = $DEVICE_ID_SQL AND ts >= NOW() - INTERVAL '24 hours') AS count_24h,
            (SELECT COUNT(*) FROM telemetry WHERE device_id = $DEVICE_ID_SQL) AS count_all
        FROM latest;
    "
fi

command_count="$(pg_query_raw "SELECT COUNT(*) FROM commands WHERE device_id = $DEVICE_ID_SQL;")"
print_section "Commands"
if [[ "$command_count" == "0" ]]; then
    warn "no commands found for '$DEVICE_ID'"
else
    pass "commands found for '$DEVICE_ID'"
    printf 'Recent commands:\n'
    pg_query_report "
        SELECT
            id,
            status,
            created_at,
            executed_at,
            payload
        FROM commands
        WHERE device_id = $DEVICE_ID_SQL
        ORDER BY created_at DESC
        LIMIT 10;
    "

    printf '\nStatus histogram:\n'
    pg_query_report "
        SELECT
            status,
            COUNT(*) AS total
        FROM commands
        WHERE device_id = $DEVICE_ID_SQL
        GROUP BY status
        ORDER BY status;
    "
fi

finalize_checks
