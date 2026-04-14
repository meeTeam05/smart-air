#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DB_CONTAINER="${DB_CONTAINER:-sa-postgres}"
DB_NAME="${DB_NAME:-smartair}"
DB_USER="${DB_USER:-smartair}"

DEVICE_ID="${DEVICE_ID:-dc:b4:d9:13:ed:8c}"
HOME_ID="${HOME_ID:-}"
ROOM_ID="${ROOM_ID:-}"

psql_exec() {
  docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" "$@"
}

psql_query() {
  local sql="$1"
  psql_exec -c "$sql"
}

need_jq() {
  command -v jq >/dev/null 2>&1 || {
    echo "jq is required"
    exit 1
  }
}
