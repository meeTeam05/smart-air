#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

echo "== tables =="
psql_exec -c "\dt"

echo
echo "== device state =="
psql_query "
SELECT id, name, online, last_seen, firmware_ver
FROM devices
WHERE id = '$DEVICE_ID';
"

echo
echo "== latest telemetry =="
psql_query "
SELECT device_id, ts, payload
FROM telemetry
WHERE device_id = '$DEVICE_ID'
ORDER BY ts DESC
LIMIT 5;
"

echo
echo "== shadow =="
psql_query "
SELECT device_id, reported, desired, updated_at
FROM device_shadows
WHERE device_id = '$DEVICE_ID';
"

echo
echo "== commands =="
psql_query "
SELECT id, status, created_at, executed_at, payload
FROM commands
WHERE device_id = '$DEVICE_ID'
ORDER BY created_at DESC
LIMIT 5;
"
