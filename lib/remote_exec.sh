#!/bin/bash

# Shared remote execution helpers for vpskit scripts.
# This file is meant to be sourced, not executed directly.

if [ -z "${VK_SUCCESS+x}" ]; then
    VK_SUCCESS=0
    VK_INVALID_ARGUMENT=2
    VK_REMOTE_GENERATE_FAILED=20
    VK_REMOTE_PLACEHOLDER_FAILED=21
    VK_REMOTE_MKTEMP_FAILED=22
    VK_REMOTE_UPLOAD_FAILED=23
    VK_REMOTE_EXECUTE_FAILED=24
    VK_REMOTE_CLEANUP_FAILED=25
fi

vk_remote_log_err() {
    local code="$1"
    local step="${2:-remote_exec}"
    local message="${3:-failed}"

    if command -v vk_log_err >/dev/null 2>&1; then
        vk_log_err "$code" "$step" "$message"
    else
        printf '[ERR] code=%s step=%s message=%s\n' "$code" "$step" "$message" >&2
    fi
}

vk_remote_sed_escape() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/&/\\&/g' -e 's/|/\\|/g'
}

vk_remote_sed_inplace() {
    local expression="$1"
    local file="$2"

    if [ "$(uname -s)" = "Darwin" ]; then
        sed -i '' "$expression" "$file"
    else
        sed -i "$expression" "$file"
    fi
}

vk_remote_timeout_bin() {
    if command -v timeout >/dev/null 2>&1; then
        printf '%s' timeout
    elif command -v gtimeout >/dev/null 2>&1; then
        printf '%s' gtimeout
    fi
    return 0
}

vk_remote_replace_placeholder() {
    local script_path="${1:-}"
    local placeholder="${2:-}"
    local value="${3:-}"
    local safe_value

    if [ -z "$script_path" ] || [ -z "$placeholder" ] || [ ! -f "$script_path" ]; then
        vk_remote_log_err "$VK_REMOTE_PLACEHOLDER_FAILED" remote_prepare "placeholder replacement received invalid arguments"
        return "$VK_REMOTE_PLACEHOLDER_FAILED"
    fi

    safe_value="$(vk_remote_sed_escape "$value")"
    if ! vk_remote_sed_inplace "s|${placeholder}|${safe_value}|g" "$script_path"; then
        vk_remote_log_err "$VK_REMOTE_PLACEHOLDER_FAILED" remote_prepare "placeholder replacement failed: ${placeholder}"
        return "$VK_REMOTE_PLACEHOLDER_FAILED"
    fi

    return "$VK_SUCCESS"
}

vk_remote_prepare_script() {
    local script_path="${1:-}"
    [ "$#" -gt 0 ] && shift
    local placeholder
    local value

    if [ -z "$script_path" ] || [ ! -s "$script_path" ]; then
        vk_remote_log_err "$VK_REMOTE_GENERATE_FAILED" remote_prepare "remote script is missing or empty"
        return "$VK_REMOTE_GENERATE_FAILED"
    fi

    if command -v inject_lang_into_remote >/dev/null 2>&1; then
        if ! inject_lang_into_remote "$script_path"; then
            vk_remote_log_err "$VK_REMOTE_GENERATE_FAILED" remote_prepare "language injection failed"
            return "$VK_REMOTE_GENERATE_FAILED"
        fi
    fi

    if [ $(( $# % 2 )) -ne 0 ]; then
        vk_remote_log_err "$VK_REMOTE_PLACEHOLDER_FAILED" remote_prepare "placeholder arguments must be pairs"
        return "$VK_REMOTE_PLACEHOLDER_FAILED"
    fi

    while [ "$#" -gt 0 ]; do
        placeholder="$1"
        value="$2"
        shift 2
        if ! vk_remote_replace_placeholder "$script_path" "$placeholder" "$value"; then
            return "$VK_REMOTE_PLACEHOLDER_FAILED"
        fi
    done

    if ! bash -n "$script_path" 2>/dev/null; then
        vk_remote_log_err "$VK_REMOTE_GENERATE_FAILED" remote_prepare "remote script syntax check failed"
        return "$VK_REMOTE_GENERATE_FAILED"
    fi

    return "$VK_SUCCESS"
}

vk_remote_exec() {
    local script_path="${1:-}"
    local ssh_user="${2:-}"
    local host="${3:-}"
    local ssh_key="${4:-}"
    local sudo_mode="${5:-}"
    local timeout_seconds="${6:-900}"
    local tty_mode="${7:-auto}"
    local remote_target
    local remote_tmp
    local ssh_tty_flag=()
    local ssh_args=()
    local exec_prefix
    local execute_status
    local cleanup_status
    local timeout_bin
    local had_errexit=0

    if [ -z "$script_path" ] || [ ! -s "$script_path" ]; then
        vk_remote_log_err "$VK_REMOTE_GENERATE_FAILED" remote_exec "remote script is missing or empty"
        return "$VK_REMOTE_GENERATE_FAILED"
    fi
    if ! bash -n "$script_path" 2>/dev/null; then
        vk_remote_log_err "$VK_REMOTE_GENERATE_FAILED" remote_exec "remote script syntax check failed"
        return "$VK_REMOTE_GENERATE_FAILED"
    fi
    if [ -z "$ssh_user" ] || [ -z "$host" ] || [ -z "$ssh_key" ]; then
        vk_remote_log_err "$VK_INVALID_ARGUMENT" remote_exec "ssh_user, host and ssh_key are required"
        return "$VK_INVALID_ARGUMENT"
    fi

    remote_target="${ssh_user}@${host}"
    ssh_args=(-i "$ssh_key" -o BatchMode=yes -o ConnectTimeout=10)
    timeout_bin="$(vk_remote_timeout_bin)"

    case "$tty_mode" in
        always) ssh_tty_flag=(-t) ;;
        never) ssh_tty_flag=() ;;
        auto|*)
            if [ -t 0 ]; then
                ssh_tty_flag=(-t)
            fi
            ;;
    esac

    case "$-" in
        *e*) had_errexit=1 ;;
    esac

    set +e
    if [ -n "$timeout_bin" ] && [ "$timeout_seconds" -gt 0 ] 2>/dev/null; then
        remote_tmp="$("$timeout_bin" "$timeout_seconds" ssh "${ssh_args[@]}" "$remote_target" "mktemp /tmp/vps-XXXXXXXXXX.sh")"
    else
        remote_tmp="$(ssh "${ssh_args[@]}" "$remote_target" "mktemp /tmp/vps-XXXXXXXXXX.sh")"
    fi
    execute_status=$?
    if [ "$had_errexit" -eq 1 ]; then
        set -e
    else
        set +e
    fi
    if [ "$execute_status" -ne 0 ] || [ -z "$remote_tmp" ]; then
        vk_remote_log_err "$VK_REMOTE_MKTEMP_FAILED" remote_exec "remote mktemp failed"
        return "$VK_REMOTE_MKTEMP_FAILED"
    fi

    set +e
    if [ -n "$timeout_bin" ] && [ "$timeout_seconds" -gt 0 ] 2>/dev/null; then
        "$timeout_bin" "$timeout_seconds" scp "${ssh_args[@]}" "$script_path" "${remote_target}:${remote_tmp}"
    else
        scp "${ssh_args[@]}" "$script_path" "${remote_target}:${remote_tmp}"
    fi
    execute_status=$?
    if [ "$execute_status" -ne 0 ]; then
        if [ -n "$timeout_bin" ] && [ "$timeout_seconds" -gt 0 ] 2>/dev/null; then
            "$timeout_bin" "$timeout_seconds" ssh "${ssh_args[@]}" "$remote_target" "rm -f '${remote_tmp}'" >/dev/null 2>&1
        else
            ssh "${ssh_args[@]}" "$remote_target" "rm -f '${remote_tmp}'" >/dev/null 2>&1
        fi
        if [ "$had_errexit" -eq 1 ]; then
            set -e
        else
            set +e
        fi
        vk_remote_log_err "$VK_REMOTE_UPLOAD_FAILED" remote_exec "remote upload failed"
        return "$VK_REMOTE_UPLOAD_FAILED"
    fi
    if [ "$had_errexit" -eq 1 ]; then
        set -e
    else
        set +e
    fi

    if [ "$sudo_mode" = "true" ] || [ "$sudo_mode" = "1" ] || [ "$sudo_mode" = "yes" ]; then
        exec_prefix="sudo bash"
    else
        exec_prefix="bash"
    fi

    set +e
    if [ -n "$timeout_bin" ] && [ "$timeout_seconds" -gt 0 ] 2>/dev/null; then
        "$timeout_bin" "$timeout_seconds" ssh "${ssh_tty_flag[@]}" "${ssh_args[@]}" "$remote_target" "chmod 700 '${remote_tmp}' && ${exec_prefix} '${remote_tmp}'"
    else
        ssh "${ssh_tty_flag[@]}" "${ssh_args[@]}" "$remote_target" "chmod 700 '${remote_tmp}' && ${exec_prefix} '${remote_tmp}'"
    fi
    execute_status=$?
    if [ -n "$timeout_bin" ] && [ "$timeout_seconds" -gt 0 ] 2>/dev/null; then
        "$timeout_bin" "$timeout_seconds" ssh "${ssh_args[@]}" "$remote_target" "rm -f '${remote_tmp}'"
    else
        ssh "${ssh_args[@]}" "$remote_target" "rm -f '${remote_tmp}'"
    fi
    cleanup_status=$?
    if [ "$had_errexit" -eq 1 ]; then
        set -e
    else
        set +e
    fi

    if [ "$execute_status" -ne 0 ]; then
        vk_remote_log_err "$VK_REMOTE_EXECUTE_FAILED" remote_exec "remote chmod or execution failed"
        return "$VK_REMOTE_EXECUTE_FAILED"
    fi

    if [ "$cleanup_status" -ne 0 ]; then
        vk_remote_log_err "$VK_REMOTE_CLEANUP_FAILED" remote_exec "remote cleanup failed: ${remote_tmp}"
        return "$VK_REMOTE_CLEANUP_FAILED"
    fi

    return "$VK_SUCCESS"
}
