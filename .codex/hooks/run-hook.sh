#!/bin/sh

set -u

EVENT_NAME="${1:-unknown}"
if [ "$#" -gt 0 ]; then
    shift
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CODEX_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$CODEX_DIR/log"
LOG_FILE="$LOG_DIR/local-hooks.log"
TMP_ERR="$(mktemp)"

cleanup() {
    rm -f "$TMP_ERR"
}

trap cleanup EXIT

mkdir -p "$LOG_DIR"

if [ "$#" -eq 0 ]; then
    {
        printf '[%s] event=%s rc=127 cwd=%s\n' "$(date -Iseconds 2>/dev/null || date)" "$EVENT_NAME" "$PWD"
        printf 'wrapper invoked without command\n\n'
    } >>"$LOG_FILE"
    exit 0
fi

"$@" 2>"$TMP_ERR"
RC=$?

if [ -s "$TMP_ERR" ] || [ "$RC" -ne 0 ]; then
    {
        printf '[%s] event=%s rc=%s cwd=%s\n' "$(date -Iseconds 2>/dev/null || date)" "$EVENT_NAME" "$RC" "$PWD"
        printf 'argv:\n'
        for arg in "$@"; do
            printf '  - %s\n' "$arg"
        done
        if [ -s "$TMP_ERR" ]; then
            cat "$TMP_ERR"
        else
            printf 'command exited non-zero without stderr\n'
        fi
        printf '\n'
    } >>"$LOG_FILE"
fi

exit 0
