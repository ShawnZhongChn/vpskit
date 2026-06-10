#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY_SH="$ROOT_DIR/deploy.sh"

fail() {
    echo "[FAIL] $1" >&2
    exit 1
}

assert_contains() {
    local needle="$1"
    local haystack="$2"
    local message="$3"

    if ! grep -Fq -- "$needle" "$haystack"; then
        echo "---- $haystack ----" >&2
        cat "$haystack" >&2
        echo "-------------------" >&2
        fail "$message"
    fi
}

assert_not_contains() {
    local needle="$1"
    local haystack="$2"
    local message="$3"

    if grep -Fq -- "$needle" "$haystack"; then
        echo "---- $haystack ----" >&2
        cat "$haystack" >&2
        echo "-------------------" >&2
        fail "$message"
    fi
}

assert_count() {
    local expected="$1"
    local needle="$2"
    local haystack="$3"
    local message="$4"
    local actual

    actual=$(grep -Fc -- "$needle" "$haystack" || true)
    if [ "$expected" != "$actual" ]; then
        fail "$message: expected $expected, got $actual"
    fi
}

assert_order() {
    local first="$1"
    local second="$2"
    local haystack="$3"
    local message="$4"
    local first_line second_line

    first_line=$(grep -Fn -- "$first" "$haystack" | head -1 | cut -d: -f1 || true)
    second_line=$(grep -Fn -- "$second" "$haystack" | head -1 | cut -d: -f1 || true)

    if [ -z "$first_line" ] || [ -z "$second_line" ] || [ "$first_line" -ge "$second_line" ]; then
        fail "$message"
    fi
}

extract_main_deploy_heredoc() {
    local output="$1"

    awk '
        /^cat > "\$TMPSCRIPT" << '\''DEPLOY_EOF'\''$/ { in_deploy=1; next }
        in_deploy && /^DEPLOY_EOF$/ { exit }
        in_deploy { print }
    ' "$DEPLOY_SH" > "$output"
}

test_deploy_uses_remote_exec_wrapper() {
    assert_contains 'vk_remote_prepare_script "$script_path"' "$DEPLOY_SH" "deploy helper should prepare scripts through wrapper"
    assert_contains 'vk_remote_exec "$script_path"' "$DEPLOY_SH" "deploy helper should execute scripts through wrapper"
    assert_count "3" 'run_prepared_remote_script "$TMPSCRIPT" "$MSG_DEPLOY_SCRIPT_SEND_FAILED"' "$DEPLOY_SH" "rollback, update and main deploy should all use the prepared remote helper"
    assert_not_contains 'REMOTE_TMP=$(ssh' "$DEPLOY_SH" "deploy.sh should not inline remote mktemp"
    assert_not_contains "chmod 700 '" "$DEPLOY_SH" "deploy.sh should not inline remote chmod execution"
    assert_not_contains "sudo bash '" "$DEPLOY_SH" "deploy.sh should not inline sudo bash execution"
    assert_not_contains "rm -f '\${REMOTE_TMP}'" "$DEPLOY_SH" "deploy.sh should not inline remote cleanup"
    assert_contains '-o BatchMode=yes -o ConnectTimeout=10 "$ENV_FILE"' "$DEPLOY_SH" ".env upload should use non-interactive SSH options"
}

test_main_deploy_contracts() {
    local tmp_dir remote_script
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    remote_script="$tmp_dir/main-deploy.sh"
    extract_main_deploy_heredoc "$remote_script"

    [ -s "$remote_script" ] || fail "main deploy heredoc should be extractable"
    bash -n "$remote_script"

    assert_contains 'DEPLOY_TYPE=""' "$remote_script" "deploy type should have a safe default"
    assert_contains 'HEALTH_URL="http://localhost:${APP_PORT}"' "$remote_script" "health URL should default to localhost app port"
    assert_contains 'HEALTH_STATUS="warn"' "$remote_script" "health status should default to warn"
    assert_contains 'HEALTH_CODE="000"' "$remote_script" "health code should default to 000"
    assert_contains 'HEALTH_MESSAGE="not_checked"' "$remote_script" "health message should default before curl"
    assert_contains 'DEPLOY_TYPE="compose"' "$remote_script" "compose deployments should persist deploy type"
    assert_contains 'DEPLOY_TYPE="dockerfile"' "$remote_script" "Dockerfile deployments should persist deploy type"
    assert_contains 'echo "$DEPLOY_TYPE" > "$APP_DIR/.deploy-type"' "$remote_script" "deploy type metadata should be written"
    assert_contains 'echo "$HEALTH_URL" > "$APP_DIR/.deploy-health-url"' "$remote_script" "health URL metadata should be written"
    assert_contains 'echo "$HEALTH_STATUS" > "$APP_DIR/.deploy-health-status"' "$remote_script" "health status metadata should be written"
    assert_contains 'echo "$HEALTH_CODE" > "$APP_DIR/.deploy-health-code"' "$remote_script" "health code metadata should be written"
    assert_contains 'echo "$HEALTH_MESSAGE" > "$APP_DIR/.deploy-health-message"' "$remote_script" "health message metadata should be written"
}

test_health_mapping_and_rollback_hint() {
    local tmp_dir remote_script
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    remote_script="$tmp_dir/main-deploy.sh"
    extract_main_deploy_heredoc "$remote_script"

    assert_contains 'echo "$RMSG_DEPLOY_ERR_ROLLBACK_HINT"' "$remote_script" "failure trap should print rollback hint"
    assert_contains 'bash deploy.sh  # choose rollback for $APP_NAME' "$remote_script" "failure trap should show rollback entry point"
    assert_contains 'echo "$CURRENT_COMMIT" > "$APP_DIR/.last-working-commit"' "$remote_script" "redeploy should save last working commit before update"
    assert_contains 'if [ "$HTTP_CODE" = "000" ]; then' "$remote_script" "health check should handle curl 000"
    assert_contains 'elif [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then' "$remote_script" "health check should treat 2xx/3xx as ok"
    assert_contains 'HEALTH_STATUS="ok"' "$remote_script" "successful health checks should persist ok"
    assert_contains 'HEALTH_STATUS="warn"' "$remote_script" "failed or warning health checks should persist warn"
    assert_contains 'RMSG_DEPLOY_HEALTH_WARN' "$remote_script" "4xx/5xx health checks should remain warnings"
}

test_caddy_failure_is_terminal() {
    local tmp_dir remote_script
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    remote_script="$tmp_dir/main-deploy.sh"
    extract_main_deploy_heredoc "$remote_script"

    assert_count "2" 'exit 34' "$remote_script" "Caddy validate and reload failures should both exit 34"
    assert_count "2" 'cp "${CADDYFILE}.bak" "$CADDYFILE"' "$remote_script" "Caddy failure paths should restore the backup"
    assert_contains 'warn "$RMSG_DEPLOY_CADDY_CONFIG_RESTORED"' "$remote_script" "Caddy failure paths should report restoration"
    assert_order 'if ! caddy validate --config "$CADDYFILE" --adapter caddyfile' 'mark_done "step_caddy"' "$remote_script" "Caddy step should only be marked done after validation and reload block"
    assert_order 'if ! systemctl reload caddy' 'mark_done "step_caddy"' "$remote_script" "Caddy step should only be marked done after reload succeeds"
}

test_deploy_uses_remote_exec_wrapper
test_main_deploy_contracts
test_health_mapping_and_rollback_hint
test_caddy_failure_is_terminal

echo "[OK] deploy reliability tests passed"
