#!/usr/bin/env bash

PLAN_FILE="${1:-}"

if [ -z "$PLAN_FILE" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    RESOLVER="${SCRIPT_DIR}/resolve-plan-dir.sh"
    if [ -f "$RESOLVER" ]; then
        PLAN_DIR="$(sh "$RESOLVER" 2>/dev/null || true)"
        if [ -n "$PLAN_DIR" ] && [ -f "${PLAN_DIR}/task_plan.md" ]; then
            PLAN_FILE="${PLAN_DIR}/task_plan.md"
        fi
    fi
fi

[ -n "$PLAN_FILE" ] || PLAN_FILE="task_plan.md"

if [ ! -f "$PLAN_FILE" ]; then
    echo "[planning-with-files] No task_plan.md found - no active planning session."
    exit 0
fi

TOTAL=$(grep -c "### Phase" "$PLAN_FILE" || true)
COMPLETE=$(grep -cF "**Status:** complete" "$PLAN_FILE" || true)
IN_PROGRESS=$(grep -cF "**Status:** in_progress" "$PLAN_FILE" || true)
PENDING=$(grep -cF "**Status:** pending" "$PLAN_FILE" || true)

if [ "$COMPLETE" -eq 0 ] && [ "$IN_PROGRESS" -eq 0 ] && [ "$PENDING" -eq 0 ]; then
    COMPLETE=$(grep -c "\[complete\]" "$PLAN_FILE" || true)
    IN_PROGRESS=$(grep -c "\[in_progress\]" "$PLAN_FILE" || true)
    PENDING=$(grep -c "\[pending\]" "$PLAN_FILE" || true)
fi

: "${TOTAL:=0}"
: "${COMPLETE:=0}"
: "${IN_PROGRESS:=0}"
: "${PENDING:=0}"

if [ "$COMPLETE" -eq "$TOTAL" ] && [ "$TOTAL" -gt 0 ]; then
    echo "[planning-with-files] ALL PHASES COMPLETE ($COMPLETE/$TOTAL). If the user has additional work, add new phases to task_plan.md before starting."
else
    echo "[planning-with-files] Task in progress ($COMPLETE/$TOTAL phases complete). Update progress.md before stopping."
    if [ "$IN_PROGRESS" -gt 0 ]; then
        echo "[planning-with-files] $IN_PROGRESS phase(s) still in progress."
    fi
    if [ "$PENDING" -gt 0 ]; then
        echo "[planning-with-files] $PENDING phase(s) pending."
    fi
fi
exit 0
