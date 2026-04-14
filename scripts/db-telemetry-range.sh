#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

FROM_TS="${1:-1999-12-31T00:00:00Z}"
TO_TS="${2:-2000-01-02T00:00:00Z}"
LIMIT="${3:-20}"

psql_query "
SELECT device_id, ts, payload
FROM telemetry
WHERE device_id = '$DEVICE_ID'
  AND ts BETWEEN '$FROM_TS' AND '$TO_TS'
ORDER BY ts DESC
LIMIT $LIMIT;
"
