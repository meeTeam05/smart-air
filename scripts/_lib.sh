#!/usr/bin/env bash
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$LIB_DIR/.." && pwd)"
SERVER_DIR="$ROOT_DIR/server"
COMPOSE_FILE="$SERVER_DIR/docker-compose.yml"
ENV_FILE="$SERVER_DIR/.env"
MIGRATIONS_DIR="$SERVER_DIR/db/migrations"

declare -ag FAILURES=()
declare -ag WARNINGS=()
declare -ag DECLARED_SERVICES=()

print_section() {
    printf '\n== %s ==\n' "$1"
}

print_status() {
    local level="$1"
    shift
    printf '%-4s %s\n' "$level" "$*"
}

pass() {
    print_status "PASS" "$@"
}

warn() {
    WARNINGS+=("$*")
    print_status "WARN" "$@"
}

fail() {
    FAILURES+=("$*")
    print_status "FAIL" "$@"
}

skip() {
    print_status "SKIP" "$@"
}

info() {
    print_status "INFO" "$@"
}

usage_error() {
    print_status "FAIL" "$1"
    exit 2
}

finalize_checks() {
    print_section "Summary"
    info "warnings: ${#WARNINGS[@]}"
    info "failures: ${#FAILURES[@]}"

    if ((${#WARNINGS[@]} > 0)); then
        local item
        for item in "${WARNINGS[@]}"; do
            print_status "WARN" "$item"
        done
    fi

    if ((${#FAILURES[@]} > 0)); then
        local item
        for item in "${FAILURES[@]}"; do
            print_status "FAIL" "$item"
        done
        exit 1
    fi

    exit 0
}

ensure_file() {
    local path="$1"
    [[ -f "$path" ]] || usage_error "required file not found: $path"
}

require_command() {
    local name="$1"
    command -v "$name" >/dev/null 2>&1 || usage_error "required command not found: $name"
}

check_common_prerequisites() {
    require_command docker
    require_command awk
    require_command comm
    require_command find
    require_command mktemp
    require_command sort

    if ! docker compose version >/dev/null 2>&1; then
        usage_error "docker compose is required"
    fi

    ensure_file "$COMPOSE_FILE"
    ensure_file "$ENV_FILE"
    [[ -d "$MIGRATIONS_DIR" ]] || usage_error "migrations directory not found: $MIGRATIONS_DIR"
}

check_curl_prerequisite() {
    require_command curl
}

compose() {
    docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" "$@"
}

env_get() {
    local key="$1"
    awk -v key="$key" '
        /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
        {
            line = $0
            sub(/^[[:space:]]*export[[:space:]]+/, "", line)
            pos = index(line, "=")
            if (pos == 0) next

            name = substr(line, 1, pos - 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
            if (name != key) next

            value = substr(line, pos + 1)
            sub(/\r$/, "", value)
            if (value ~ /^".*"$/ || value ~ /^'\''.*'\''$/) {
                value = substr(value, 2, length(value) - 2)
            }
            print value
            exit
        }
    ' "$ENV_FILE"
}

env_require() {
    local key="$1"
    local value
    value="$(env_get "$key")"
    [[ -n "$value" ]] || usage_error "required key missing in $(basename "$ENV_FILE"): $key"
    printf '%s' "$value"
}

load_declared_services() {
    if ((${#DECLARED_SERVICES[@]} > 0)); then
        return
    fi

    mapfile -t DECLARED_SERVICES < <(
        awk '
            /^services:[[:space:]]*$/ {
                in_services = 1
                next
            }

            in_services && /^[^[:space:]]/ {
                exit
            }

            in_services && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
                name = $1
                sub(/:$/, "", name)
                print name
            }
        ' "$COMPOSE_FILE"
    )
    ((${#DECLARED_SERVICES[@]} > 0)) || usage_error "failed to resolve compose services from $COMPOSE_FILE"
}

compose_has_service() {
    local service="$1"
    load_declared_services
    local declared
    for declared in "${DECLARED_SERVICES[@]}"; do
        [[ "$declared" == "$service" ]] && return 0
    done
    return 1
}

service_container_id() {
    local service="$1"
    compose ps -q "$service" 2>/dev/null | head -n 1
}

service_state() {
    local service="$1"
    local container_id
    container_id="$(service_container_id "$service")"
    if [[ -z "$container_id" ]]; then
        printf 'missing'
        return 0
    fi
    docker inspect -f '{{.State.Status}}' "$container_id"
}

service_health() {
    local service="$1"
    local container_id
    container_id="$(service_container_id "$service")"
    if [[ -z "$container_id" ]]; then
        printf 'missing'
        return 0
    fi
    docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container_id"
}

service_runtime_label() {
    local service="$1"
    local state
    local health
    state="$(service_state "$service")"
    health="$(service_health "$service")"

    if [[ "$state" == "missing" ]]; then
        printf 'not running'
        return 0
    fi

    if [[ "$health" == "none" ]]; then
        printf '%s' "$state"
        return 0
    fi

    printf '%s (%s)' "$state" "$health"
}

strip_json_whitespace() {
    tr -d '[:space:]'
}

join_lines() {
    awk '
        NF {
            if (count > 0) {
                printf ", "
            }
            printf "%s", $0
            count++
        }
    '
}

sql_quote_literal() {
    local value="$1"
    value=${value//\'/\'\'}
    printf "'%s'" "$value"
}
