---
doc_type: feature-acceptance
feature: 2026-06-08-setup-hardening-pass
status: accepted
summary: setup 服务器加固流程已接入统一远端执行、事件进度和真实结果摘要
tags: [setup, hardening, reliability, bash]
---

# setup-hardening-pass 验收报告

> 阶段：阶段 3（验收闭环）
> 验收日期：2026-06-08
> 关联方案 doc：.codestable/features/2026-06-08-setup-hardening-pass/setup-hardening-pass-design.md

## 1. 接口契约核对

**接口示例逐项核对**：
- [x] `setup.sh` 已通过 `vk_remote_prepare_script "$TMPSCRIPT" "__USERNAME__" "$USERNAME" "__SSH_USER__" "$SSH_USER"` 准备远端脚本。
- [x] `setup.sh` 已通过 `vk_remote_exec "$TMPSCRIPT" "$SSH_USER" "$VPS_IP" "$SSH_KEY" "$USE_SUDO" 1800 always` 执行远端 setup。
- [x] 远端 heredoc 内已实现 `progress_write`、`step_is_done`、`step_done`、`step_skip_event`、`step_fail`、`step_degrade`、`print_final_summary`。
- [x] `lang.sh` 的 `inject_lang_into_remote` 改为 source 语言文件后导出完整 `RMSG_` / `LANG_` 当前值。

**名词层"现状 → 变化"逐项核对**：
- [x] 旧 setup inline `REMOTE_TMP=$(ssh ... mktemp)` 和组合式 `chmod; sudo/bash; rm` 已移除。
- [x] 新进度写入事件格式，同时 `step_is_done` 兼容旧单行 `step1`。
- [x] final summary 从 progress 最后状态渲染 `[OK]/[WARN]/[SKIP]/[ERR]`。

**流程图核对**：
- [x] 本地 prepare/exec → 远端 detect/step events → summary 的节点均有代码落点。

## 2. 行为与决策核对

**需求摘要逐项验证**：
- [x] setup 远端执行消费 `lib/remote_exec.sh`，获得 wrapper 的 `20-25` 分阶段错误码。
- [x] setup step 写 started/done/skipped/failed/degraded 事件。
- [x] 关键 step 失败由 `run_setup_step` 记录 `failed` 并退出。
- [x] 用户跳过 step 会写 `skipped`，summary 显示 `[SKIP]`。
- [x] Docker log rotation restart 失败写 `degraded`，summary 显示 `[WARN]`。
- [x] 中文远端注入包含继承的 setup `RMSG_*` 变量。

**明确不做逐项核对**：
- [x] 未新增或删除 setup 加固步骤。
- [x] 未替换 Docker 安装策略。
- [x] 未改 `security.sh` 或 `status.sh` 审计规则。
- [x] 未引入真实 VPS 集成测试硬依赖。

**关键决策落地**：
- [x] setup 远端执行切到共享 wrapper。
- [x] 进度从单行 done 升级为事件格式。
- [x] 失败不再只依赖 `set -e` 自然中断，先写 failed event。
- [x] summary 不再硬编码全 `[OK]`。

**挂载点反向核对**：
- [x] `setup.sh` shared lib 加载点存在。
- [x] `setup.sh` wrapper 调用存在。
- [x] 远端 progress helpers 和 final summary 存在。
- [x] `lang.sh` 远端注入导出逻辑存在。
- [x] `tests/test_setup_hardening.sh` 覆盖本 feature 关键行为。

## 3. 验收场景核对

- [x] S1：`setup.sh` 使用 wrapper，旧组合式远端执行行不存在。
- [x] S2：新事件格式写入，旧单行 `step1` 仍被视为 done。
- [x] S3：跳过 step 写 `skipped`，summary 显示 `[SKIP]`。
- [x] S4：关键 step 失败写 `failed`，返回非零。
- [x] S5：Docker log rotation restart 失败写 `degraded`，summary 显示 `[WARN]`。
- [x] S6：SSH hardening 失败路径恢复备份、返回 40，由 `run_setup_step` 写 failed，不写 done。
- [x] S7：summary 从最后事件渲染，skipped/degraded/failed 不显示为全成功。
- [x] S8：`VPSKIT_LANG=zh` 注入包含继承的 `RMSG_SETUP_STEP1_TITLE`。

证据：`bash tests/test_setup_hardening.sh`、`rg` 静态检查、`bash -n` 语法检查。

## 4. 术语一致性

- setup-hardening：集中指 `setup.sh` 的远端初始化/加固步骤。
- setup step event：代码中为 `progress_write` 事件格式，和 runtime step 契约一致。
- degraded setup step：代码中为 `step_degrade` 和 summary `[WARN]`。
- hardening summary：代码中为 `print_final_summary`。

## 5. 架构归并

- [x] `.codestable/architecture/ARCHITECTURE.md` 已补充 setup 消费 `lib/remote_exec.sh`。
- [x] 架构已补充 setup progress event 兼容 legacy 单行 marker。
- [x] 架构已补充 setup summary 必须从最后事件状态渲染，不能硬编码全 `[OK]`。

## 6. requirement 回写

- [x] `requirement` 为空；本 feature 是 roadmap 内 setup-hardening 技术能力，不新增独立用户愿景文档。本次跳过 requirement 回写。

## 7. roadmap 回写

- [x] items.yaml 中 `setup-hardening-pass` 已改为 `done`，feature 指向 `2026-06-08-setup-hardening-pass`。
- [x] roadmap 主文档第 5 节对应条目已同步为 `done`。
- [x] YAML 校验通过。

## 8. attention.md 候选盘点

- [x] 候选：`setup.sh` 远端脚本现在写事件进度，fixture 测试通过抽取 heredoc helper 验证，不需要真实 VPS。该信息适合后续 roadmap acceptance 时决定是否加入 attention。

## 9. 遗留

- 后续优化点：`setup.sh` 本地交互仍有多个 `read -p`，可后续迁移到 runtime input helper。
- 已知限制：Docker 安装方式仍保留 `curl -fsSL https://get.docker.com | sh`，是否替换需要单独安全决策。
- 顺手发现：修复 `zh.sh` 继承变量未注入远端脚本的问题，已纳入本 feature 合同。

## 验证命令

```bash
bash tests/test_setup_hardening.sh
bash tests/test_remote_exec.sh
bash tests/test_runtime.sh
bash tests/test_i18n_zh.sh
bash -n vpskit.sh lib/runtime.sh lib/remote_exec.sh lang.sh lang/zh.sh settings.sh tests/test_runtime.sh tests/test_i18n_zh.sh tests/test_remote_exec.sh tests/test_setup_hardening.sh setup.sh deploy.sh backup.sh status.sh security.sh
python .codestable/tools/validate-yaml.py --file .codestable/features/2026-06-08-setup-hardening-pass/setup-hardening-pass-checklist.yaml --yaml-only
python .codestable/tools/validate-yaml.py --file .codestable/features/2026-06-08-setup-hardening-pass/setup-hardening-pass-contracts.yaml --yaml-only
python .codestable/tools/validate-yaml.py --file .codestable/roadmap/vpskit-stability-zh-hardening/vpskit-stability-zh-hardening-items.yaml --yaml-only
```
