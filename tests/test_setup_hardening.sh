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

    if ! grep -Fq "$needle" "$haystack"; then
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

    if grep -Fq "$needle" "$haystack"; then
        echo "---- $haystack ----" >&2
        cat "$haystack" >&2
        echo "-------------------" >&2
        fail "$message"
    fi
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [ "$expected" != "$actual" ]; then
        fail "$message: expected '$expected', got '$actual'"
    fi
}

extract_remote_setup_helpers() {
    local output="$1"

    awk '
        /^# PROGRESSION ET INTERACTION$/ { in_helpers=1; print; next }
        in_helpers && /^# ÉTAPES DE SÉCURISATION$/ { exit }
        in_helpers { print }
    ' "$ROOT_DIR/setup.sh" > "$output"
}

test_setup_uses_remote_exec_wrapper() {
    grep -q 'vk_remote_prepare_script "$TMPSCRIPT"' "$ROOT_DIR/setup.sh" || fail "setup.sh should prepare remote script through wrapper"
    grep -q 'vk_remote_exec "$TMPSCRIPT"' "$ROOT_DIR/setup.sh" || fail "setup.sh should execute remote script through wrapper"
    ! grep -q "chmod 700.*sudo bash.*rm -f" "$ROOT_DIR/setup.sh" || fail "setup.sh should not keep old combined sudo execution"
    ! grep -q "REMOTE_TMP=.*mktemp /tmp/vps-" "$ROOT_DIR/setup.sh" || fail "setup.sh should not inline remote mktemp"
}

test_progress_events_and_summary() {
    local tmp_dir helper_script output status
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    helper_script="$tmp_dir/setup_helpers.sh"
    output="$tmp_dir/summary.txt"
    extract_remote_setup_helpers "$helper_script"
    bash -n "$helper_script"

    cat > "$tmp_dir/run.sh" <<RUN_EOF
#!/bin/bash
set -euo pipefail
GREEN=''
YELLOW=''
RED=''
BOLD=''
NC=''
USERNAME='deploy'
DISTRO_NAME='Fixture Linux'
PROGRESS_FILE='$tmp_dir/progress'
PROGRESS_FILE_LEGACY='$tmp_dir/legacy-progress'
RMSG_SETUP_STEP_ALREADY_DONE='(already done)'
RMSG_SETUP_FINAL_TITLE='Server ready'
RMSG_SETUP_FINAL_DISTRO='Distribution: %s'
RMSG_SETUP_FINAL_INSTALLED='Installed:'
RMSG_SETUP_STEP_EXECUTE_PROMPT='Execute? '
. '$helper_script'
printf 'step1\n' > "\$PROGRESS_FILE"
step_is_done step1 || exit 10
progress_write step2 started '' 'user'
step_done step2 'user done'
step_skip_event step3 'ssh skipped'
step_degrade step6 docker_restart 'docker warning'
step_fail step4 40 'ssh failed'
print_final_summary > '$output'
RUN_EOF
    chmod +x "$tmp_dir/run.sh"
    "$tmp_dir/run.sh"

    assert_contains "|step2|done||user done" "$tmp_dir/progress" "done event should be event formatted"
    assert_contains "|step3|skipped||ssh skipped" "$tmp_dir/progress" "skipped event should be event formatted"
    assert_contains "|step6|degraded|docker_restart|docker warning" "$tmp_dir/progress" "degraded event should include code"
    assert_contains "|step4|failed|40|ssh failed" "$tmp_dir/progress" "failed event should include code"
    assert_contains "[OK] Git" "$output" "legacy step1 should render as OK"
    assert_contains "[OK] deploy (sudo)" "$output" "done step should render as OK"
    assert_contains "[SKIP] SSH key only" "$output" "skipped step should render as SKIP"
    assert_contains "[WARN] Docker + log rotation" "$output" "degraded step should render as WARN"
    assert_contains "[ERR] Root disabled" "$output" "failed step should render as ERR"
    assert_not_contains "[OK] SSH key only" "$output" "skipped step must not render as OK"
    assert_not_contains "[OK] Docker + log rotation" "$output" "degraded step must not render as OK"
}

test_run_setup_step_failed_returns_event() {
    local tmp_dir helper_script status
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    helper_script="$tmp_dir/setup_helpers.sh"
    extract_remote_setup_helpers "$helper_script"

    cat > "$tmp_dir/run_fail.sh" <<RUN_EOF
#!/bin/bash
set -euo pipefail
GREEN=''
YELLOW=''
RED=''
BOLD=''
NC=''
PROGRESS_FILE='$tmp_dir/progress'
RMSG_SETUP_STEP_ALREADY_DONE='(already done)'
RMSG_SETUP_STEP_EXECUTE_PROMPT='Execute? '
. '$helper_script'
confirm_step() { return 0; }
failed_command() { return 42; }
run_setup_step step_failure 'Failure step' 'desc' 'done' failed_command
RUN_EOF
    chmod +x "$tmp_dir/run_fail.sh"
    set +e
    "$tmp_dir/run_fail.sh" >/dev/null 2>&1
    status=$?
    set -e
    assert_eq "42" "$status" "failed setup step should return command status"
    assert_contains "|step_failure|failed|42|Failure step" "$tmp_dir/progress" "failed setup step should record failed event"
}

test_zh_remote_injection_exports_inherited_setup_vars() {
    local tmp_dir script
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    script="$tmp_dir/remote.sh"
    printf '#!/bin/bash\necho "$RMSG_SETUP_STEP1_TITLE"\n' > "$script"
    HOME="$tmp_dir/home" VPSKIT_LANG=zh bash -c ". '$ROOT_DIR/lang.sh' >/dev/null 2>&1; inject_lang_into_remote '$script'"
    assert_contains "RMSG_SETUP_STEP1_TITLE=" "$script" "zh remote injection should include inherited setup RMSG variables"
}

test_setup_uses_remote_exec_wrapper
test_progress_events_and_summary
test_run_setup_step_failed_returns_event
test_zh_remote_injection_exports_inherited_setup_vars

echo "[OK] setup hardening tests passed"
