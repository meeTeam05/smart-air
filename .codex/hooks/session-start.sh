#!/bin/sh

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python)}"
TMP_OUTPUT="$(mktemp)"

cleanup() {
    rm -f "$TMP_OUTPUT"
}

trap cleanup EXIT

[ -n "$PYTHON_BIN" ] || exit 0

"$PYTHON_BIN" "$SCRIPT_DIR/render-planning-context.py" --mode session-start "$(pwd)" >"$TMP_OUTPUT"

if [ -s "$TMP_OUTPUT" ]; then
    "$PYTHON_BIN" "$SCRIPT_DIR/emit-session-start-json.py" <"$TMP_OUTPUT"
fi

exit 0
