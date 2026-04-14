#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

TABLE="${1:-}"

if [ -z "$TABLE" ]; then
  echo "Usage: $0 <table_name>"
  exit 1
fi

psql_exec -c "\d $TABLE"
