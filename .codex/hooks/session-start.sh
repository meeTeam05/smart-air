#!/bin/sh

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CODEX_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(CDPATH= cd -- "$CODEX_DIR/.." && pwd)"
SKILL_DIR="$REPO_ROOT/.agents/skills/planning-with-files"
PYTHON_BIN="${PYTHON_BIN:-$(command -v python3 || command -v python)}"
TMP_OUTPUT="$(mktemp)"

cleanup() {
    rm -f "$TMP_OUTPUT"
}

trap cleanup EXIT

if [ -n "$PYTHON_BIN" ] && [ -f "$SKILL_DIR/scripts/session-catchup.py" ]; then
    "$PYTHON_BIN" "$SKILL_DIR/scripts/session-catchup.py" "$(pwd)" >>"$TMP_OUTPUT" 2>/dev/null || true
fi

sh "$SCRIPT_DIR/user-prompt-submit.sh" >>"$TMP_OUTPUT" 2>/dev/null || true

if [ -s "$TMP_OUTPUT" ] && [ -n "$PYTHON_BIN" ]; then
    "$PYTHON_BIN" - "$TMP_OUTPUT" <<'PY'
import json
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8").strip()
if text:
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": text,
            }
        },
        sys.stdout,
        ensure_ascii=False,
    )
    sys.stdout.write("\n")
PY
fi

exit 0
