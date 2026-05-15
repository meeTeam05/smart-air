#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATE_DIR="$SKILL_ROOT/templates"

USE_PLAN_DIR=1
PLAN_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plan-dir)
            USE_PLAN_DIR=1
            shift
            ;;
        --root)
            USE_PLAN_DIR=0
            shift
            ;;
        *)
            if [ -z "$PLAN_NAME" ]; then
                PLAN_NAME="$1"
            else
                PLAN_NAME="$PLAN_NAME $1"
            fi
            shift
            ;;
    esac
done

slugify() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -e 's/[^a-z0-9]/-/g' -e 's/-\{2,\}/-/g' -e 's/^-//' -e 's/-$//' \
        | cut -c1-40
}

PLAN_DIR="."
if [ "$USE_PLAN_DIR" -eq 1 ]; then
    slug="$(slugify "${PLAN_NAME:-untitled}")"
    plan_id="$(date +%Y-%m-%d)-${slug:-untitled}"
    PLAN_DIR=".planning/$plan_id"
    mkdir -p "$PLAN_DIR"
    mkdir -p .planning/sessions
    printf '%s\n' "$plan_id" > .planning/.active_plan
fi

for file in task_plan.md findings.md progress.md; do
    target="$PLAN_DIR/$file"
    if [ ! -f "$target" ]; then
        cp "$TEMPLATE_DIR/$file" "$target"
        echo "Created $target"
    else
        echo "$target already exists, skipping"
    fi
done
