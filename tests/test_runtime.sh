#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/runtime.sh
. "$ROOT_DIR/lib/runtime.sh"

fail() {
    echo "[FAIL] $1" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [ "$expected" != "$actual" ]; then
        fail "$message: expected '$expected', got '$actual'"
    fi
}

test_non_interactive_prompt_no_default() {
    local result="" status
    set +e
    vk_prompt result "value: " "" non_empty 3
    status=$?
    set -e
    assert_eq "11" "$status" "vk_prompt without default should not block in non-interactive mode"
}

test_non_interactive_prompt_default() {
    local result="" status
    set +e
    vk_prompt result "value: " "abc" non_empty 3
    status=$?
    set -e
    assert_eq "0" "$status" "vk_prompt with valid default should succeed"
    assert_eq "abc" "$result" "vk_prompt should assign default"
}

test_non_interactive_confirm_default_yes() {
    local status
    set +e
    vk_confirm "continue? " "yes" 3
    status=$?
    set -e
    assert_eq "0" "$status" "vk_confirm yes default should succeed"
}

test_run_failure_status() {
    local status
    set +e
    vk_run test_step required 0 false
    status=$?
    set -e
    assert_eq "1" "$status" "vk_run should return command failure status"
}

test_step_events_and_legacy_done() {
    local progress
    progress="$(mktemp)"
    trap 'rm -f "$progress"' RETURN

    vk_step_start "$progress" step1 "start"
    vk_step_done "$progress" step1 "done"
    vk_step_is_done "$progress" step1 || fail "vk_step_is_done should read event format"

    printf 'legacy_step\n' > "$progress"
    vk_step_is_done "$progress" legacy_step || fail "vk_step_is_done should read legacy format"
}

test_vpskit_menu_q() {
    VPSKIT_LANG=en python3 - "$ROOT_DIR" <<'PY'
import os
import pty
import subprocess
import sys
import time

root = sys.argv[1]
master, slave = pty.openpty()
env = os.environ.copy()
env["VPSKIT_LANG"] = "en"
proc = subprocess.Popen(
    ["bash", "vpskit.sh"],
    cwd=root,
    stdin=slave,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=env,
)
os.close(slave)
time.sleep(0.2)
os.write(master, b"q\n")
stdout, stderr = proc.communicate(timeout=5)
os.close(master)
if proc.returncode != 0:
    raise SystemExit(f"expected q to exit 0, got {proc.returncode}\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}")
if "Bye" not in stdout and "Au revoir" not in stdout and "See you soon" not in stdout:
    raise SystemExit(f"expected bye output\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}")
PY
}

test_vpskit_menu_invalid_attempts() {
    VPSKIT_LANG=en python3 - "$ROOT_DIR" <<'PY'
import os
import pty
import subprocess
import sys
import time

root = sys.argv[1]
master, slave = pty.openpty()
env = os.environ.copy()
env["VPSKIT_LANG"] = "en"
proc = subprocess.Popen(
    ["bash", "vpskit.sh"],
    cwd=root,
    stdin=slave,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=env,
)
os.close(slave)
time.sleep(0.2)
os.write(master, b"x\ny\nz\n")
stdout, stderr = proc.communicate(timeout=5)
os.close(master)
if proc.returncode != 12:
    raise SystemExit(f"expected invalid attempts to exit 12, got {proc.returncode}\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}")
if "code=12" not in stderr:
    raise SystemExit(f"expected code=12 in stderr\nSTDOUT:\n{stdout}\nSTDERR:\n{stderr}")
PY
}

test_non_interactive_prompt_no_default
test_non_interactive_prompt_default
test_non_interactive_confirm_default_yes
test_run_failure_status
test_step_events_and_legacy_done
test_vpskit_menu_q
test_vpskit_menu_invalid_attempts

echo "[OK] runtime tests passed"
