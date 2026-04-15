#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

psql_query "
SELECT id, name, home_id, room_id, online, last_seen, firmware_ver, created_at
FROM devices
WHERE id = '$DEVICE_ID';
"
