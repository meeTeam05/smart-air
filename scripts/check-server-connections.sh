#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_lib.sh
source "$SCRIPT_DIR/_lib.sh"

usage() {
    cat <<'EOF'
Usage: check-server-connections.sh

Read-only runtime connectivity checks for the services defined in
server/docker-compose.yml and server/.env.
EOF
}

if (($# == 1)) && [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

if (($# != 0)); then
    usage
    exit 2
fi

check_common_prerequisites
check_curl_prerequisite

POSTGRES_DB="$(env_require "POSTGRES_DB")"
POSTGRES_USER="$(env_require "POSTGRES_USER")"
POSTGRES_PASSWORD="$(env_get "POSTGRES_PASSWORD")"
REDIS_PASSWORD="$(env_require "REDIS_PASSWORD")"
EMQX_API_KEY="$(env_require "EMQX_API_KEY")"
EMQX_API_SECRET="$(env_require "EMQX_API_SECRET")"

pg_query_raw() {
    local sql="$1"
    compose exec -T postgres env PGPASSWORD="${POSTGRES_PASSWORD:-}" \
        psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
        -At -F $'\t' -c "$sql"
}

optional_service() {
    case "$1" in
        pgadmin|portainer) return 0 ;;
        *) return 1 ;;
    esac
}

service_available_for_probe() {
    local service="$1"
    if ! compose_has_service "$service"; then
        skip "$service is not declared in $(basename "$COMPOSE_FILE")"
        return 1
    fi

    local state
    state="$(service_state "$service")"
    if [[ "$state" == "running" ]]; then
        return 0
    fi

    if optional_service "$service"; then
        skip "$service is optional and not running"
    else
        fail "$service is not running"
    fi
    return 1
}

service_status_matrix() {
    local service="$1"
    if ! compose_has_service "$service"; then
        skip "$service is not declared"
        return
    fi

    local state
    local health
    state="$(service_state "$service")"
    health="$(service_health "$service")"

    if [[ "$state" == "missing" ]]; then
        if optional_service "$service"; then
            skip "$service declared but not running"
        else
            fail "$service declared but not running"
        fi
        return
    fi

    if [[ "$state" != "running" ]]; then
        if optional_service "$service"; then
            skip "$service state is $state"
        else
            fail "$service state is $state"
        fi
        return
    fi

    if [[ "$health" == "healthy" || "$health" == "none" ]]; then
        pass "$service is $(service_runtime_label "$service")"
        return
    fi

    fail "$service is $(service_runtime_label "$service")"
}

print_section "Compose Status"
for service in postgres redis api nginx cloudflared emqx grafana pgadmin portainer; do
    service_status_matrix "$service"
done

print_section "Deep Probes"
if service_available_for_probe "postgres"; then
    if output="$(pg_query_raw "SELECT 1;" 2>&1)"; then
        pass "postgres accepts SELECT 1"
        printf '%s\n' "$output"
    else
        fail "postgres SELECT 1 probe failed"
        printf '%s\n' "$output"
    fi
fi

if service_available_for_probe "redis"; then
    if output="$(compose exec -T redis env REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping 2>&1)"; then
        if [[ "$output" == *"PONG"* ]]; then
            pass "redis responds to ping"
            printf '%s\n' "$output"
        else
            fail "redis ping returned unexpected output"
            printf '%s\n' "$output"
        fi
    else
        fail "redis ping probe failed"
        printf '%s\n' "$output"
    fi
fi

if service_available_for_probe "api"; then
    if live_json="$(compose exec -T api wget -qO- http://127.0.0.1:3000/api/health/live 2>&1)"; then
        compact_live="$(printf '%s' "$live_json" | strip_json_whitespace)"
        if [[ "$compact_live" == *'"status":"ok"'* ]]; then
            pass "api live health endpoint is ok"
            printf '%s\n' "$live_json"
        else
            fail "api live health endpoint returned unexpected JSON"
            printf '%s\n' "$live_json"
        fi
    else
        fail "api live health endpoint probe failed"
        printf '%s\n' "$live_json"
    fi

    if ready_json="$(compose exec -T api wget -qO- http://127.0.0.1:3000/api/health/ready 2>&1)"; then
        compact_ready="$(printf '%s' "$ready_json" | strip_json_whitespace)"
        if [[ "$compact_ready" == *'"status":"ok"'* && \
              "$compact_ready" == *'"postgres":"ok"'* && \
              "$compact_ready" == *'"redis":"ok"'* && \
              "$compact_ready" == *'"mqtt":"ok"'* ]]; then
            pass "api ready health endpoint reports postgres, redis, and mqtt ok"
            printf '%s\n' "$ready_json"
        else
            fail "api ready health endpoint returned degraded or unexpected JSON"
            printf '%s\n' "$ready_json"
        fi
    else
        fail "api ready health endpoint probe failed"
        printf '%s\n' "$ready_json"
    fi
fi

if service_available_for_probe "nginx"; then
    if nginx_json="$(compose exec -T nginx wget -qO- http://127.0.0.1/nginx/health 2>&1)"; then
        compact_nginx="$(printf '%s' "$nginx_json" | strip_json_whitespace)"
        if [[ "$compact_nginx" == *'"status":"ok"'* ]]; then
            pass "nginx health endpoint is ok"
            printf '%s\n' "$nginx_json"
        else
            fail "nginx health endpoint returned unexpected JSON"
            printf '%s\n' "$nginx_json"
        fi
    else
        fail "nginx health endpoint probe failed"
        printf '%s\n' "$nginx_json"
    fi
fi

if service_available_for_probe "emqx"; then
    if emqx_status="$(compose exec -T emqx emqx ctl status 2>&1)"; then
        if printf '%s' "$emqx_status" | grep -qi 'started'; then
            pass "emqx broker reports started"
            printf '%s\n' "$emqx_status"
        else
            fail "emqx broker status did not include started"
            printf '%s\n' "$emqx_status"
        fi
    else
        fail "emqx broker status probe failed"
        printf '%s\n' "$emqx_status"
    fi

    if emqx_api_body="$(curl -fsS -u "$EMQX_API_KEY:$EMQX_API_SECRET" http://127.0.0.1:18083/api/v5/status 2>&1)"; then
        pass "emqx admin API responded on localhost:18083"
        printf '%s\n' "$emqx_api_body"
    else
        fail "emqx admin API probe failed"
        printf '%s\n' "$emqx_api_body"
    fi
fi

if compose_has_service "grafana"; then
    grafana_state="$(service_state "grafana")"
    grafana_health="$(service_health "grafana")"
    if [[ "$grafana_state" == "running" && "$grafana_health" == "healthy" ]]; then
        pass "grafana is running and healthy"
    elif [[ "$grafana_state" == "running" && "$grafana_health" == "none" ]]; then
        pass "grafana is running"
    else
        fail "grafana runtime is $(service_runtime_label "grafana")"
    fi
else
    skip "grafana is not declared"
fi

if service_available_for_probe "pgadmin"; then
    if pgadmin_code="$(curl -sS -o /dev/null -I -w '%{http_code}' http://127.0.0.1:5050 2>&1)"; then
        if [[ "$pgadmin_code" == "200" || "$pgadmin_code" == "302" ]]; then
            pass "pgadmin responds on localhost:5050 with HTTP $pgadmin_code"
        else
            fail "pgadmin returned HTTP $pgadmin_code on localhost:5050"
        fi
    else
        fail "pgadmin localhost probe failed"
        printf '%s\n' "$pgadmin_code"
    fi
fi

if service_available_for_probe "portainer"; then
    if portainer_code="$(curl -sS -o /dev/null -I -w '%{http_code}' http://127.0.0.1:9000 2>&1)"; then
        if [[ "$portainer_code" == "200" ]]; then
            pass "portainer responds on localhost:9000 with HTTP 200"
        else
            fail "portainer returned HTTP $portainer_code on localhost:9000"
        fi
    else
        fail "portainer localhost probe failed"
        printf '%s\n' "$portainer_code"
    fi
fi

if service_available_for_probe "cloudflared"; then
    if cloudflared_logs="$(compose logs --no-color --tail=120 cloudflared 2>&1)"; then
        if printf '%s' "$cloudflared_logs" | grep -Eqi 'Registered tunnel connection|Connection .* registered'; then
            pass "cloudflared logs show an active tunnel connection"
            printf '%s\n' "$cloudflared_logs"
        elif printf '%s' "$cloudflared_logs" | grep -Eqi 'retry|timeout|terminated|unable to reach|failed'; then
            fail "cloudflared logs show retry or failure patterns without a confirmed connection"
            printf '%s\n' "$cloudflared_logs"
        else
            warn "cloudflared logs are inconclusive"
            printf '%s\n' "$cloudflared_logs"
        fi
    else
        fail "cloudflared log probe failed"
        printf '%s\n' "$cloudflared_logs"
    fi
fi

finalize_checks
