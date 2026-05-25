#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_lib.sh
source "$SCRIPT_DIR/_lib.sh"

OUTPUT_DIR="$ROOT_DIR/data/csv_analytics"
OUTPUT_FILE="$OUTPUT_DIR/telemetry_flat.csv"

usage() {
    cat <<'EOF'
Usage: export-telemetry-csv.sh

Export public-friendly telemetry rows from PostgreSQL/TimescaleDB to:
  data/csv_analytics/telemetry_flat.csv

Output columns:
  device_id, ts, mode, temperature, humidity, co_ppm, no2_ppm

Notes:
  - device_id is exported as stored in the database.
  - The script overwrites the output file on each run.
EOF
}

if (($# == 1)) && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

if (($# != 0)); then
    usage
    exit 2
fi

check_common_prerequisites

POSTGRES_DB="$(env_require "POSTGRES_DB")"
POSTGRES_USER="$(env_require "POSTGRES_USER")"
POSTGRES_PASSWORD="$(env_get "POSTGRES_PASSWORD")"

if ! compose_has_service "postgres"; then
    usage_error "postgres service is not declared in $(basename "$COMPOSE_FILE")"
fi

postgres_state="$(service_state "postgres")"
if [[ "$postgres_state" != "running" ]]; then
    usage_error "postgres container state is $postgres_state"
fi

mkdir -p "$OUTPUT_DIR"

tmp_file="$(mktemp "$OUTPUT_DIR/telemetry_flat.XXXXXX.csv")"
trap 'rm -f "$tmp_file"' EXIT

read -r -d '' export_sql <<'SQL' || true
COPY (
    SELECT
        device_id,
        ts,
        payload->>'mode' AS mode,
        CASE
            WHEN jsonb_typeof(payload->'temperature') = 'number'
                THEN (payload->>'temperature')::double precision
            ELSE NULL
        END AS temperature,
        CASE
            WHEN jsonb_typeof(payload->'humidity') = 'number'
                THEN (payload->>'humidity')::double precision
            ELSE NULL
        END AS humidity,
        CASE
            WHEN jsonb_typeof(payload->'co_ppm') = 'number'
                THEN (payload->>'co_ppm')::double precision
            ELSE NULL
        END AS co_ppm,
        CASE
            WHEN jsonb_typeof(payload->'no2_ppm') = 'number'
                THEN (payload->>'no2_ppm')::double precision
            ELSE NULL
        END AS no2_ppm
    FROM telemetry
    ORDER BY ts ASC, device_id ASC
) TO STDOUT WITH (FORMAT csv, HEADER true)
SQL

compose exec -T postgres env PGPASSWORD="${POSTGRES_PASSWORD:-}" \
    psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    -c "$export_sql" >"$tmp_file"

mv "$tmp_file" "$OUTPUT_FILE"
trap - EXIT

pass "exported telemetry CSV to $OUTPUT_FILE"
