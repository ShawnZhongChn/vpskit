#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

extract_heredoc() {
    local script="$1"
    local marker="$2"
    local output="$3"

    awk -v marker="$marker" '
        $0 ~ "<< \047" marker "\047" { in_doc=1; next }
        in_doc && $0 == marker { exit }
        in_doc { print }
    ' "$script" > "$output"
}

test_ops_uses_remote_exec_wrapper() {
    assert_contains 'load_shared_lib "lib/remote_exec.sh"' "$ROOT_DIR/backup.sh" "backup.sh should load remote exec"
    assert_contains 'load_shared_lib "lib/remote_exec.sh"' "$ROOT_DIR/security.sh" "security.sh should load remote exec"
    assert_contains 'load_shared_lib "lib/remote_exec.sh"' "$ROOT_DIR/settings.sh" "settings.sh should load remote exec"
    assert_count "2" 'run_prepared_remote_script "$TMPSCRIPT"' "$ROOT_DIR/backup.sh" "backup restore and save should use wrapper helper"
    assert_contains 'vk_remote_exec "$TMPSCRIPT" "$SSH_USER" "$VPS_IP" "$SSH_KEY" true 900 auto' "$ROOT_DIR/security.sh" "security audit should use wrapper"
    assert_count "2" 'run_prepared_remote_script "$TMPSCRIPT"' "$ROOT_DIR/settings.sh" "settings remote backup scripts should use wrapper helper"

    for script in backup.sh security.sh settings.sh; do
        assert_not_contains 'REMOTE_TMP=$(ssh' "$ROOT_DIR/$script" "$script should not inline remote mktemp"
        assert_not_contains "chmod 700 '\${REMOTE_TMP}'; sudo bash" "$ROOT_DIR/$script" "$script should not inline old combined remote execution"
    done
}

test_backup_metadata_bundle() {
    local tmp_dir restore_script backup_script rclone_script
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    restore_script="$tmp_dir/restore.sh"
    backup_script="$tmp_dir/backup.sh"
    rclone_script="$tmp_dir/rclone.sh"

    extract_heredoc "$ROOT_DIR/backup.sh" RESTORE_EOF "$restore_script"
    extract_heredoc "$ROOT_DIR/backup.sh" BACKUP_EOF "$backup_script"
    extract_heredoc "$ROOT_DIR/settings.sh" RCLONE_EOF "$rclone_script"

    bash -n "$restore_script"
    bash -n "$backup_script"
    bash -n "$rclone_script"

    for metadata in deploy-branch deploy-type deploy-health-url deploy-health-status deploy-health-code deploy-health-message; do
        assert_contains "$metadata" "$restore_script" "restore should restore $metadata"
        assert_contains "$metadata" "$backup_script" "backup should save $metadata"
        assert_contains "$metadata" "$rclone_script" "cron backup should save $metadata"
    done

    assert_contains '"health_status": "%s"' "$backup_script" "backup metadata.json should include health status"
    assert_contains '"deploy_type": "%s"' "$backup_script" "backup metadata.json should include deploy type"
}

test_status_and_security_consume_deploy_health() {
    local tmp_dir status_script security_script
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    status_script="$tmp_dir/status.sh"
    security_script="$tmp_dir/security.sh"

    extract_heredoc "$ROOT_DIR/status.sh" STATUS_EOF "$status_script"
    extract_heredoc "$ROOT_DIR/security.sh" SECURITY_EOF "$security_script"

    bash -n "$status_script"
    bash -n "$security_script"

    assert_contains '.deploy-type' "$status_script" "status should read deploy type"
    assert_contains '.deploy-health-status' "$status_script" "status should read deploy health status"
    assert_contains 'RMSG_STATUS_HEALTH_OK' "$status_script" "status should render ok health"
    assert_contains 'RMSG_STATUS_HEALTH_WARN' "$status_script" "status should render warning health"
    assert_contains 'RMSG_STATUS_HEALTH_ERR' "$status_script" "status should render failed health"

    assert_contains '.deploy-health-status' "$security_script" "security should read deploy health status"
    assert_contains 'RMSG_SECURITY_DEPLOY_HEALTH_OK' "$security_script" "security should audit ok health"
    assert_contains 'RMSG_SECURITY_DEPLOY_HEALTH_WARN' "$security_script" "security should audit warning health"
    assert_contains 'RMSG_SECURITY_DEPLOY_HEALTH_ERR' "$security_script" "security should audit failed health"
}

test_extra_file_transfer_and_settings_failure_paths() {
    assert_contains 'scp -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 "$RESTORE_FILE"' "$ROOT_DIR/backup.sh" "restore tarball upload should use SSH safety options"
    assert_contains 'scp -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 "${USERNAME}@${VPS_IP}:/tmp/${BACKUP_FILE}"' "$ROOT_DIR/backup.sh" "backup retrieval should use SSH safety options"
    assert_contains 'MSG_BACKUP_ERR_RETRIEVE' "$ROOT_DIR/backup.sh" "backup retrieval failure should be explicit"
    assert_order 'run_prepared_remote_script "$TMPSCRIPT" "$username" "$vps_ip" "$ssh_key" true 900 auto "$MSG_SETTINGS_RBACKUP_REMOTE_FAILED"' 'success "$MSG_SETTINGS_RBACKUP_CRON_UPDATED"' "$ROOT_DIR/settings.sh" "cron update should run wrapper before success"
    assert_order 'run_prepared_remote_script "$TMPSCRIPT" "$username" "$vps_ip" "$ssh_key" true 1800 auto "$MSG_SETTINGS_RBACKUP_REMOTE_FAILED"' 'success "$MSG_SETTINGS_RBACKUP_RCLONE_OK"' "$ROOT_DIR/settings.sh" "rclone setup should run wrapper before success"
    assert_contains 'return $?' "$ROOT_DIR/settings.sh" "settings remote backup failure should return non-zero"
}

test_ops_uses_remote_exec_wrapper
test_backup_metadata_bundle
test_status_and_security_consume_deploy_health
test_extra_file_transfer_and_settings_failure_paths

echo "[OK] ops flow reliability tests passed"
