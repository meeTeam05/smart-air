#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

psql_query "
SELECT
  u.email,
  h.id AS home_id,
  h.name AS home_name,
  hm.role
FROM home_members hm
JOIN users u ON u.id = hm.user_id
JOIN homes h ON h.id = hm.home_id
ORDER BY h.created_at, u.email;
"
