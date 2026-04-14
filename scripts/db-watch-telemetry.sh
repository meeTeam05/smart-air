#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

INTERVAL="${INTERVAL:-2}"

while true; do
  clear
  date
  echo
  psql_query "
  SELECT device_id, ts, payload
  FROM telemetry
  WHERE device_id = '$DEVICE_ID'
  ORDER BY ts DESC
  LIMIT 5;
  "
  sleep "$INTERVAL"
done
