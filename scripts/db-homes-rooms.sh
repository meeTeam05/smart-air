#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

psql_query "
SELECT h.id AS home_id, h.name AS home_name, r.id AS room_id, r.name AS room_name
FROM homes h
LEFT JOIN rooms r ON r.home_id = h.id
ORDER BY h.created_at, r.name;
"
