#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

LIMIT="${1:-20}"

psql_query "
SELECT id, device_id, payload, status, created_at, executed_at
FROM commands
WHERE device_id = '$DEVICE_ID'
ORDER BY created_at DESC
LIMIT $LIMIT;
"
