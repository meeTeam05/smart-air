#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

LIMIT="${1:-10}"

psql_query "
SELECT device_id, ts, payload
FROM telemetry
WHERE device_id = '$DEVICE_ID'
ORDER BY ts DESC
LIMIT $LIMIT;
"
