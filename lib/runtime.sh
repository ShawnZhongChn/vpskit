#!/bin/bash

# Shared runtime helpers for vpskit scripts.
# This file is meant to be sourced, not executed directly.

VK_SUCCESS=0
VK_GENERAL_FAILURE=1
VK_INVALID_ARGUMENT=2
VK_MISSING_DEPENDENCY=3
VK_INVALID_INPUT=4
VK_USER_CANCELLED=5
VK_NON_INTERACTIVE_MISSING_INPUT=6
VK_PROMPT_QUIT=10
VK_PROMPT_NON_INTERACTIVE_NO_DEFAULT=11
VK_PROMPT_MAX_ATTEMPTS=12
VK_REMOTE_GENERATE_FAILED=20
VK_REMOTE_PLACEHOLDER_FAILED=21
VK_REMOTE_MKTEMP_FAILED=22
VK_REMOTE_UPLOAD_FAILED=23
VK_REMOTE_EXECUTE_FAILED=24
VK_REMOTE_CLEANUP_FAILED=25
VK_NETWORK_TIMEOUT=30

vk_is_interactive() {
    [ -t 0 ]
}

vk_code_name() {
    case "$1" in
        0) echo "success" ;;
        1) echo "general_failure" ;;
        2) echo "invalid_argument" ;;
        3) echo "missing_dependency" ;;
        4) echo "invalid_input" ;;
        5) echo "user_cancelled" ;;
        6) echo "non_interactive_missing_input" ;;
        10) echo "prompt_quit" ;;
        11) echo "prompt_non_interactive_no_default" ;;
        12) echo "prompt_max_attempts" ;;
        20) echo "remote_generate_failed" ;;
        21) echo "remote_placeholder_failed" ;;
        22) echo "remote_mktemp_failed" ;;
        23) echo "remote_upload_failed" ;;
        24) echo "remote_execute_failed" ;;
        25) echo "remote_cleanup_failed" ;;
        30) echo "network_timeout" ;;
        *) echo "unknown" ;;
    esac
}

vk_log_err() {
    printf '[ERR] code=%s name=%s step=%s message=%s\n' \
        "$1" "$(vk_code_name "$1")" "$2" "$3" >&2
}

vk_log_warn() {
    printf '[WARN] step=%s message=%s\n' "$1" "$2" >&2
}

vk_fail() {
    local code="${1:-$VK_GENERAL_FAILURE}"
    local step_id="${2:-runtime}"
    local message="${3:-failed}"

    vk_log_err "$code" "$step_id" "$message"
    return "$code"
}

vk_trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

vk_is_quit_input() {
    case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
        q|quit|exit) return 0 ;;
        *) return 1 ;;
    esac
}

vk_validator_choice_contains() {
    local value="$1"
    local choices="$2"
    local choice

    IFS=',' read -r -a _vk_choices <<< "$choices"
    for choice in "${_vk_choices[@]}"; do
        if [ "$value" = "$(vk_trim "$choice")" ]; then
            return 0
        fi
    done
    return 1
}

vk_validate() {
    local value="$1"
    local validator="${2:-none}"
    local choices

    case "$validator" in
        ""|none) return 0 ;;
        non_empty)
            [ -n "$value" ]
            ;;
        number)
            [[ "$value" =~ ^[0-9]+$ ]]
            ;;
        ip4)
            [[ "$value" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
            ;;
        choice:*)
            choices="${validator#choice:}"
            vk_validator_choice_contains "$value" "$choices"
            ;;
        *)
            return 0
            ;;
    esac
}

vk_assign_result() {
    local result_var="$1"
    local value="$2"

    if [ -z "$result_var" ]; then
        return "$VK_INVALID_ARGUMENT"
    fi

    printf -v "$result_var" '%s' "$value"
}

vk_prompt() {
    local result_var="$1"
    local prompt="$2"
    local default="${3:-}"
    local validator="${4:-none}"
    local max_attempts="${5:-3}"
    local attempts=0
    local value

    if [ -z "$result_var" ]; then
        return "$VK_INVALID_ARGUMENT"
    fi

    if ! vk_is_interactive; then
        if [ -n "$default" ]; then
            if vk_validate "$default" "$validator"; then
                vk_assign_result "$result_var" "$default"
                return "$VK_SUCCESS"
            fi
            return "$VK_INVALID_INPUT"
        fi
        return "$VK_PROMPT_NON_INTERACTIVE_NO_DEFAULT"
    fi

    while [ "$attempts" -lt "$max_attempts" ]; do
        if [ -n "$default" ]; then
            read -r -p "$prompt" value || return "$VK_PROMPT_QUIT"
            value="${value:-$default}"
        else
            read -r -p "$prompt" value || return "$VK_PROMPT_QUIT"
        fi

        value="$(vk_trim "$value")"
        if vk_is_quit_input "$value"; then
            return "$VK_PROMPT_QUIT"
        fi

        if vk_validate "$value" "$validator"; then
            vk_assign_result "$result_var" "$value"
            return "$VK_SUCCESS"
        fi

        attempts=$((attempts + 1))
    done

    return "$VK_PROMPT_MAX_ATTEMPTS"
}

vk_confirm() {
    local prompt="$1"
    local default="${2:-}"
    local max_attempts="${3:-3}"
    local choice
    local default_normalized

    default_normalized="$(printf '%s' "$default" | tr '[:upper:]' '[:lower:]')"

    if ! vk_is_interactive; then
        case "$default_normalized" in
            y|yes|o|oui|true|1) return "$VK_SUCCESS" ;;
            n|no|non|false|0) return 1 ;;
            *) return "$VK_PROMPT_NON_INTERACTIVE_NO_DEFAULT" ;;
        esac
    fi

    if vk_prompt choice "$prompt" "$default" "choice:y,Y,yes,YES,o,O,oui,OUI,n,N,no,NO,non,NON" "$max_attempts"; then
        case "$(printf '%s' "$choice" | tr '[:upper:]' '[:lower:]')" in
            y|yes|o|oui) return "$VK_SUCCESS" ;;
            n|no|non) return 1 ;;
        esac
    else
        return "$?"
    fi
}

vk_menu() {
    local result_var="$1"
    local prompt="$2"
    local options="$3"
    local default="${4:-}"
    local max_attempts="${5:-3}"

    vk_prompt "$result_var" "$prompt" "$default" "choice:${options}" "$max_attempts"
}

vk_run() {
    local step_id="$1"
    local severity="$2"
    local timeout_seconds="$3"
    shift 3
    local status
    local had_errexit=0

    if [ "$#" -eq 0 ]; then
        return "$VK_INVALID_ARGUMENT"
    fi

    case "$-" in
        *e*) had_errexit=1 ;;
    esac

    set +e
    if [ "$timeout_seconds" -gt 0 ] 2>/dev/null && command -v timeout >/dev/null 2>&1; then
        timeout "$timeout_seconds" "$@"
    else
        "$@"
    fi
    status=$?
    if [ "$had_errexit" -eq 1 ]; then
        set -e
    else
        set +e
    fi

    if [ "$status" -ne 0 ] && [ "$severity" = "optional" ]; then
        vk_degrade "$step_id" warn "optional command failed: $*"
    fi

    return "$status"
}

vk_degrade() {
    local step_id="$1"
    local severity="${2:-warn}"
    local message="${3:-degraded}"

    case "$severity" in
        warn|warning) vk_log_warn "$step_id" "$message" ;;
        info) printf '[INFO] step=%s message=%s\n' "$step_id" "$message" >&2 ;;
        *) vk_log_warn "$step_id" "$message" ;;
    esac
}

vk_timestamp() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

vk_step_write() {
    local progress_file="$1"
    local step_id="$2"
    local status="$3"
    local code="${4:-}"
    local message="${5:-}"
    local progress_dir

    if [ -z "$progress_file" ] || [ -z "$step_id" ]; then
        return "$VK_INVALID_INPUT"
    fi

    progress_dir="$(dirname "$progress_file")"
    mkdir -p "$progress_dir"
    printf '%s|%s|%s|%s|%s\n' "$(vk_timestamp)" "$step_id" "$status" "$code" "$message" >> "$progress_file"
}

vk_step_start() {
    vk_step_write "$1" "$2" started "" "${3:-}"
}

vk_step_done() {
    vk_step_write "$1" "$2" done "" "${3:-}"
}

vk_step_skip() {
    vk_step_write "$1" "$2" skipped "" "${3:-}"
}

vk_step_fail() {
    vk_step_write "$1" "$2" failed "${3:-$VK_GENERAL_FAILURE}" "${4:-}"
}

vk_step_degrade() {
    vk_step_write "$1" "$2" degraded "${3:-$VK_GENERAL_FAILURE}" "${4:-}"
}

vk_step_is_done() {
    local progress_file="$1"
    local step_id="$2"

    [ -f "$progress_file" ] || return 1

    if grep -q "^${step_id}$" "$progress_file" 2>/dev/null; then
        return "$VK_SUCCESS"
    fi

    awk -F'|' -v step="$step_id" '$2 == step && $3 == "done" { found=1 } END { exit found ? 0 : 1 }' "$progress_file"
}
