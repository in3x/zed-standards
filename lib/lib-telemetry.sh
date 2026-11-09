#!/usr/bin/env bash
# ==============================================================================
# Healthchecks & NTFY Telemetry Notification Library
# ==============================================================================

# Pings a Healthchecks.io (or compatible) monitoring URL
ping_hc() {
    local hc_url="${1:-${HC_PING_URL:-}}"
    local status="${2:-}"

    if [[ -n "$hc_url" ]]; then
        local target_url="$hc_url"
        [[ -n "$status" ]] && target_url="${target_url}/${status}"
        curl -fsS -m 10 "$target_url" >/dev/null 2>&1 || true
    fi
}

# Sends push notifications via ntfy.sh (or self-hosted ntfy instance)
send_ntfy() {
    local topic="${1:-${NTFY_TOPIC:-}}"
    local title="${2:-System Alert}"
    local message="${3:-No message body provided.}"
    local priority="${4:-default}"
    local token="${5:-${NTFY_AUTH_TOKEN:-${NTFY_TOKEN:-}}}"
    local server="${6:-${NTFY_URL:-https://ntfy.sh}}"

    if [[ -n "$topic" ]]; then
        local auth_header=()
        [[ -n "$token" ]] && auth_header=(-H "Authorization: Bearer ${token}")

        curl -s \
             "${auth_header[@]}" \
             -H "Title: ${title}" \
             -H "Priority: ${priority}" \
             -d "${message}" \
             "${server%/}/${topic}" >/dev/null 2>&1 || true
    fi
}

# Standard error trap handler for unattended scripts
failure_handler() {
    local line_no="${1:-unknown}"
    local script_name="${2:-$(basename "$0")}"
    local host_name
    host_name="$(hostname 2>/dev/null || echo "host")"

    logger -t "${script_name}" "Script error occurred on line ${line_no}." 2>/dev/null || true
    send_ntfy "${NTFY_TOPIC:-}" "🚨 Pipeline Failure: ${script_name}" "${script_name} crashed on ${host_name} at line ${line_no}." "urgent"
    ping_hc "${HC_PING_URL:-}" "fail"
    exit 1
}
