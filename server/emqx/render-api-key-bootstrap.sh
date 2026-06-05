#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ENV_FILE="${1:-$SCRIPT_DIR/../.env}"
OUT_FILE="${2:-$SCRIPT_DIR/api-key.bootstrap}"

if [ ! -f "$ENV_FILE" ]; then
    echo "Missing env file: $ENV_FILE" >&2
    exit 1
fi

get_env() {
    awk -F= -v key="$1" '
        $1 == key {
            sub(/^[^=]*=/, "")
            print
            exit
        }
    ' "$ENV_FILE"
}

EMQX_API_KEY="${EMQX_API_KEY:-$(get_env EMQX_API_KEY)}"
EMQX_API_SECRET="${EMQX_API_SECRET:-$(get_env EMQX_API_SECRET)}"

if [ -z "$EMQX_API_KEY" ] || [ -z "$EMQX_API_SECRET" ]; then
    echo "EMQX_API_KEY and EMQX_API_SECRET are required" >&2
    exit 1
fi

umask 077
printf '%s:%s:administrator\n' "$EMQX_API_KEY" "$EMQX_API_SECRET" > "$OUT_FILE"
echo "Wrote $OUT_FILE"
