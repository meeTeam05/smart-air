#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

psql_query "
SELECT device_id, reported, desired, updated_at
FROM device_shadows
WHERE device_id = '$DEVICE_ID';
"
