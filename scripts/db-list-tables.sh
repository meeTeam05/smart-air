#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

psql_exec -c "\dt"
