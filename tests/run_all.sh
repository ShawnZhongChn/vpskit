#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run() {
    echo "[RUN] $*"
    "$@"
}

run_bash_n() {
    echo "[RUN] bash syntax matrix"
    bash -n \
        "$ROOT_DIR/vpskit.sh" \
        "$ROOT_DIR/setup.sh" \
        "$ROOT_DIR/deploy.sh" \
        "$ROOT_DIR/backup.sh" \
        "$ROOT_DIR/status.sh" \
        "$ROOT_DIR/security.sh" \
        "$ROOT_DIR/settings.sh" \
        "$ROOT_DIR/lang.sh" \
        "$ROOT_DIR/lang/en.sh" \
        "$ROOT_DIR/lang/fr.sh" \
        "$ROOT_DIR/lang/zh.sh" \
        "$ROOT_DIR/lib/runtime.sh" \
        "$ROOT_DIR/lib/remote_exec.sh" \
        "$ROOT_DIR/tests/test_runtime.sh" \
        "$ROOT_DIR/tests/test_i18n_zh.sh" \
        "$ROOT_DIR/tests/test_remote_exec.sh" \
        "$ROOT_DIR/tests/test_setup_hardening.sh" \
        "$ROOT_DIR/tests/test_deploy_reliability.sh" \
        "$ROOT_DIR/tests/test_ops_flow_reliability.sh" \
        "$ROOT_DIR/tests/run_all.sh"
    echo "[OK] bash syntax matrix"
}

run_feature_tests() {
    run bash "$ROOT_DIR/tests/test_runtime.sh"
    run bash "$ROOT_DIR/tests/test_i18n_zh.sh"
    run bash "$ROOT_DIR/tests/test_remote_exec.sh"
    run bash "$ROOT_DIR/tests/test_setup_hardening.sh"
    run bash "$ROOT_DIR/tests/test_deploy_reliability.sh"
    run bash "$ROOT_DIR/tests/test_ops_flow_reliability.sh"
}

run_yaml_validation() {
    local validator="$ROOT_DIR/.codestable/tools/validate-yaml.py"

    echo "[RUN] CodeStable YAML validation"
    run python3 "$validator" --file "$ROOT_DIR/.codestable/roadmap/vpskit-stability-zh-hardening/vpskit-stability-zh-hardening-items.yaml"
    run python3 "$validator" --dir "$ROOT_DIR/.codestable/features" --yaml-only
    echo "[OK] CodeStable YAML validation"
}

run_bash_n
run_feature_tests
run_yaml_validation

echo "[OK] all tests passed"
