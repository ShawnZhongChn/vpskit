#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/runtime.sh
. "$ROOT_DIR/lib/runtime.sh"
# shellcheck source=../lib/remote_exec.sh
. "$ROOT_DIR/lib/remote_exec.sh"

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

assert_log_contains() {
    local pattern="$1"
    local file="$2"
    local message="$3"

    if ! grep -q "$pattern" "$file"; then
        echo "---- fake command log ----" >&2
        cat "$file" >&2
        echo "--------------------------" >&2
        fail "$message"
    fi
}

make_remote_script() {
    local script_path="$1"
    printf '#!/bin/bash\nset -euo pipefail\necho "__VALUE__"\n' > "$script_path"
}

make_fake_bin() {
    local fake_dir="$1"

    cat > "$fake_dir/ssh" <<'FAKE_SSH'
#!/bin/bash
{
    printf 'SSH'
    for arg in "$@"; do
        printf ' <%s>' "$arg"
    done
    printf '\n'
} >> "$VK_FAKE_LOG"

cmd="${!#}"
case "$cmd" in
    *"mktemp /tmp/vps-"*)
        if [ "${VK_FAKE_FAIL:-}" = "mktemp" ]; then
            exit 42
        fi
        printf '/tmp/vps-fake.sh\n'
        ;;
    *"chmod 700"*)
        if [ "${VK_FAKE_FAIL:-}" = "execute" ]; then
            exit 43
        fi
        ;;
    *"rm -f"*)
        if [ "${VK_FAKE_FAIL:-}" = "cleanup" ]; then
            exit 44
        fi
        ;;
esac
FAKE_SSH

    cat > "$fake_dir/scp" <<'FAKE_SCP'
#!/bin/bash
{
    printf 'SCP'
    for arg in "$@"; do
        printf ' <%s>' "$arg"
    done
    printf '\n'
} >> "$VK_FAKE_LOG"

if [ "${VK_FAKE_FAIL:-}" = "upload" ]; then
    exit 45
fi
FAKE_SCP

    chmod +x "$fake_dir/ssh" "$fake_dir/scp"
}

with_fake_remote() {
    local fail_phase="$1"
    local expected_status="$2"
    local extra_check="${3:-}"
    local tmp_dir fake_dir script key log status

    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    fake_dir="$tmp_dir/bin"
    mkdir -p "$fake_dir"
    make_fake_bin "$fake_dir"

    script="$tmp_dir/remote.sh"
    key="$tmp_dir/id_ed25519"
    log="$tmp_dir/fake.log"
    make_remote_script "$script"
    printf 'fake-key\n' > "$key"
    : > "$log"

    set +e
    PATH="$fake_dir:$PATH" VK_FAKE_LOG="$log" VK_FAKE_FAIL="$fail_phase" \
        vk_remote_exec "$script" deploy 203.0.113.10 "$key" true 0 never
    status=$?
    set -e

    assert_eq "$expected_status" "$status" "vk_remote_exec status for fail phase '$fail_phase'"

    case "$extra_check" in
        success)
            assert_log_contains "BatchMode=yes" "$log" "ssh/scp should use BatchMode=yes"
            assert_log_contains "ConnectTimeout=10" "$log" "ssh/scp should use ConnectTimeout"
            assert_log_contains "mktemp /tmp/vps-" "$log" "should create remote temp script"
            assert_log_contains "chmod 700" "$log" "should chmod remote temp script"
            assert_log_contains "sudo bash" "$log" "should execute with sudo bash"
            assert_log_contains "rm -f" "$log" "should clean remote temp script"
            assert_log_contains "^SCP" "$log" "should upload script with scp"
            ;;
        cleanup)
            assert_log_contains "rm -f" "$log" "should attempt cleanup after failure"
            ;;
    esac
}

test_prepare_replaces_special_chars() {
    local tmp_dir script
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    script="$tmp_dir/remote.sh"
    make_remote_script "$script"

    vk_remote_prepare_script "$script" "__VALUE__" 'a\&b|c'
    bash -n "$script"
    grep -q 'a\\&b|c' "$script" || fail "placeholder should preserve sed-special characters"
}

test_prepare_rejects_odd_placeholder_args() {
    local tmp_dir script status
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "$tmp_dir"' RETURN
    script="$tmp_dir/remote.sh"
    make_remote_script "$script"

    set +e
    vk_remote_prepare_script "$script" "__VALUE__"
    status=$?
    set -e
    assert_eq "21" "$status" "odd placeholder arguments should return 21"
}

test_exec_rejects_missing_script() {
    local status
    set +e
    vk_remote_exec "/no/such/script.sh" deploy 203.0.113.10 /tmp/key true 0 never
    status=$?
    set -e
    assert_eq "20" "$status" "missing script should return 20"
}

test_prepare_replaces_special_chars
test_prepare_rejects_odd_placeholder_args
test_exec_rejects_missing_script
with_fake_remote none 0 success
with_fake_remote mktemp 22
with_fake_remote upload 23 cleanup
with_fake_remote execute 24 cleanup
with_fake_remote cleanup 25

echo "[OK] remote exec tests passed"
