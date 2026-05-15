#!/bin/sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOLVER="${SCRIPT_DIR}/resolve-plan-dir.sh"

resolve_plan_file() {
    plan_dir=""
    if [ -f "${RESOLVER}" ]; then
        plan_dir="$(sh "${RESOLVER}" 2>/dev/null)"
    fi
    if [ -n "${plan_dir}" ] && [ -f "${plan_dir}/task_plan.md" ]; then
        printf "%s\n" "${plan_dir}/task_plan.md"
        return 0
    fi
    return 1
}

attestation_path_for() {
    plan_file="$1"
    plan_dir="$(dirname "${plan_file}")"
    printf "%s\n" "${plan_dir}/.attestation"
}

compute_hash() {
    target="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "${target}" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "${target}" | awk '{print $1}'
    else
        printf "ERROR: no sha256 utility available\n" >&2
        return 1
    fi
}

mode="attest"
case "${1:-}" in
    --show) mode="show" ;;
    --clear) mode="clear" ;;
    "") mode="attest" ;;
    *)
        printf "Usage: %s [--show|--clear]\n" "$0" >&2
        exit 2
        ;;
esac

plan_file="$(resolve_plan_file)" || {
    printf "[plan-attest] No task_plan.md found. Create a plan first.\n" >&2
    exit 1
}

attestation_file="$(attestation_path_for "${plan_file}")"

case "${mode}" in
    show)
        if [ -f "${attestation_file}" ]; then
            printf "Plan: %s\n" "${plan_file}"
            printf "Attestation: %s\n" "${attestation_file}"
            printf "SHA-256: %s\n" "$(cat "${attestation_file}")"
        else
            printf "[plan-attest] No attestation set for %s.\n" "${plan_file}"
            exit 1
        fi
        ;;
    clear)
        if [ -f "${attestation_file}" ]; then
            rm -f "${attestation_file}"
            printf "[plan-attest] Cleared attestation for %s.\n" "${plan_file}"
        else
            printf "[plan-attest] No attestation to clear.\n"
        fi
        ;;
    attest)
        hash_val="$(compute_hash "${plan_file}")" || exit 1
        printf "%s\n" "${hash_val}" > "${attestation_file}"
        short_hash="$(printf "%s" "${hash_val}" | cut -c1-12)"
        printf "[plan-attest] Locked %s\n" "${plan_file}"
        printf "[plan-attest] SHA-256: %s... (stored in %s)\n" "${short_hash}" "${attestation_file}"
        ;;
esac

exit 0
