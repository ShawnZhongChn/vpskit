#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
    echo "[FAIL] $1" >&2
    exit 1
}

count_lang_vars() {
    grep -E '^(MSG_|RMSG_|LANG_)' "$1" | cut -d= -f1 | sort -u
}

test_zh_syntax() {
    bash -n "$ROOT_DIR/lang/zh.sh"
}

test_zh_covers_en_vars() {
    local missing
    missing="$(comm -23 <(count_lang_vars "$ROOT_DIR/lang/en.sh") <(bash -c ". '$ROOT_DIR/lang/zh.sh'; compgen -v | grep -E '^(MSG_|RMSG_|LANG_)' | sort -u"))"
    if [ -n "$missing" ]; then
        echo "$missing" >&2
        fail "zh language file is missing variables from en"
    fi
}

test_default_lang_is_zh() {
    local output home_dir
    home_dir="$(mktemp -d)"
    trap 'rm -rf "$home_dir"' RETURN
    output="$(HOME="$home_dir" bash -c ". '$ROOT_DIR/lang.sh'; printf '%s' \"\$VPSKIT_LANG_CODE\"")"
    [ "$output" = "zh" ] || fail "default language should be zh, got $output"
}

test_vpskit_menu_is_zh() {
    local output home_dir
    home_dir="$(mktemp -d)"
    trap 'rm -rf "$home_dir"' RETURN
    output="$(HOME="$home_dir" VPSKIT_LANG=zh python3 - "$ROOT_DIR" <<'PY'
import os
import pty
import subprocess
import sys
import time

root = sys.argv[1]
master, slave = pty.openpty()
proc = subprocess.Popen(
    ["bash", "vpskit.sh"],
    cwd=root,
    stdin=slave,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=os.environ.copy(),
)
os.close(slave)
time.sleep(0.2)
os.write(master, b"q\n")
stdout, stderr = proc.communicate(timeout=5)
os.close(master)
if proc.returncode != 0:
    raise SystemExit(stderr)
print(stdout)
PY
)"
    printf '%s' "$output" | grep -q "请选择要执行的操作" || fail "vpskit menu should be Chinese"
    printf '%s' "$output" | grep -q "初始化或更新 VPS" || fail "vpskit option should be Chinese"
}

test_zh_syntax
test_zh_covers_en_vars
test_default_lang_is_zh
test_vpskit_menu_is_zh

echo "[OK] zh i18n tests passed"
