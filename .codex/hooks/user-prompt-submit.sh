#!/bin/sh

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python)}"

[ -n "$PYTHON_BIN" ] || exit 0

"$PYTHON_BIN" "$SCRIPT_DIR/render-planning-context.py" --mode user-prompt "$(pwd)"
exit 0
