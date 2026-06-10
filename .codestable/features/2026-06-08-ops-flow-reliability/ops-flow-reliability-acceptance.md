---
doc_type: feature-acceptance
feature: 2026-06-08-ops-flow-reliability
status: accepted
summary: ops 备份、恢复、状态、安全审计和远程备份设置已接入统一远端执行并消费 deploy health metadata
tags: [ops, backup, status, security, remote-backup, reliability]
---

# ops-flow-reliability 验收报告

> 阶段：阶段 3（验收闭环）
> 验收日期：2026-06-08
> 关联方案 doc：.codestable/features/2026-06-08-ops-flow-reliability/ops-flow-reliability-design.md

## 1. 接口契约核对

**接口示例逐项核对**：
- [x] `backup.sh` 已加载 `lib/remote_exec.sh`，restore/save 远端脚本通过 `run_prepared_remote_script` 执行。
- [x] `security.sh` 已通过 `vk_remote_prepare_script` / `vk_remote_exec` 执行远端审计脚本。
- [x] `settings.sh` 已加载 `lib/remote_exec.sh`，rclone 配置和 cron 更新远端脚本通过 wrapper 执行。
- [x] `status.sh` 读取 `.deploy-type` 和 `.deploy-health-url/status/code/message`。
- [x] `security.sh` 读取 `.deploy-health-status/code/message` 和 `.deploy-type` 并输出审计项。

**名词层"现状 → 变化"逐项核对**：
- [x] `backup.sh`、`security.sh`、`settings.sh` 目标远端执行块不再保留 inline `REMOTE_TMP=$(ssh ... mktemp)` 和组合式 `chmod 700; sudo bash; rm -f`。
- [x] backup save/restore 保留旧 `deploy-domain`、`deploy-port`，并新增 deploy branch/type/health metadata。
- [x] settings cron backup 复制 deploy branch/type/health metadata。
- [x] restore tarball upload 和 backup archive download 使用 `BatchMode=yes`、`ConnectTimeout=10` 并检查失败。

## 2. 行为与决策核对

**需求摘要逐项验证**：
- [x] backup restore/save 远端执行接入 wrapper。
- [x] security audit 远端执行接入 wrapper。
- [x] settings rclone/cron 远端配置接入 wrapper，失败 return 非零。
- [x] status/security 消费 deploy health metadata。
- [x] backup 和 remote-backup cron 携带 deploy health/type/branch metadata。
- [x] 可降级数据库 dump 策略保持 warning + volume fallback。

**明确不做逐项核对**：
- [x] 未重写所有 `read -p` 为 runtime prompt。
- [x] 未把数据库 dump 失败升级成整次 backup 失败。
- [x] 未改变备份主命令或归档入口。
- [x] 未引入真实 S3/VPS 集成测试硬依赖。
- [x] 未重写 `settings.sh` 的远程备份 wizard 结构。

## 3. 验收场景核对

- [x] S1：`backup.sh` restore/save 远端脚本执行都使用 `vk_remote_prepare_script` / `vk_remote_exec`。
- [x] S2：`security.sh` 远端审计执行使用 wrapper，旧组合式执行行不存在。
- [x] S3：`settings.sh` rclone 配置和 cron 更新远端执行使用 wrapper，失败不打印成功完成。
- [x] S4：`backup.sh` save、restore 和 settings cron backup 携带或恢复 `.deploy-type`、`.deploy-branch`、`.deploy-health-*`。
- [x] S5：`status.sh` 展示 deploy type 和 health status/code/message。
- [x] S6：`security.sh` 把 deploy health warn/failed 纳入审计输出。
- [x] S7：restore tarball 上传和本地 backup 下载使用 `BatchMode=yes`、`ConnectTimeout=10` 并检查失败。
- [x] S8：本 feature 未改变数据库 dump warning + volume fallback 策略，未引入真实 S3/VPS 测试硬依赖。

证据：`bash tests/test_ops_flow_reliability.sh`、`rg` 静态检查、`bash -n` 语法检查。

## 4. 术语一致性

- ops-flow：集中指 backup/status/security/settings 的运维流程。
- backup metadata bundle：代码中为归档内 `deploy-domain/port/branch/type/health-*` 文件集合。
- deploy health consumer：代码中为 status/security heredoc 读取 `.deploy-health-*` 的节点。
- degraded ops result：保留在 dump/S3 等 warning 语义中，不升级为必然失败。

## 5. 架构归并

- [x] `.codestable/architecture/ARCHITECTURE.md` 已补充 backup/security/settings 消费 `lib/remote_exec.sh`。
- [x] 架构已补充 backup metadata bundle 包含 deploy health/type。
- [x] 架构已补充 status/security 消费 deploy health metadata 但不把 warn 作为阻断。

## 6. requirement 回写

- [x] `requirement` 为空；本 feature 是 roadmap 内 ops-flows 技术能力，不新增独立用户愿景文档。本次跳过 requirement 回写。

## 7. roadmap 回写

- [x] items.yaml 中 `ops-flow-reliability` 已改为 `done`，feature 指向 `2026-06-08-ops-flow-reliability`。
- [x] roadmap 主文档第 5 节对应条目已同步为 `done`。
- [x] YAML 校验通过。

## 8. attention.md 候选盘点

- [x] 候选：ops-flow 的测试通过抽取 heredoc 和静态 grep 验证 wrapper 与 metadata，不需要真实 VPS/S3。后续 verification-harness 可统一沉淀。

## 9. 遗留

- 交互循环仍有大量 `read -p`，后续可按 runtime input contract 单独推进。
- 真实 VPS/S3 端到端验证仍是人工验收项，不在本 feature 强制。
- `settings.sh` 和 `backup.sh` 仍偏胖，后续适合独立 refactor。

## 验证命令

```bash
bash tests/test_ops_flow_reliability.sh
bash tests/test_deploy_reliability.sh
bash tests/test_setup_hardening.sh
bash tests/test_remote_exec.sh
bash tests/test_runtime.sh
bash tests/test_i18n_zh.sh
bash -n vpskit.sh lib/runtime.sh lib/remote_exec.sh lang.sh lang/zh.sh lang/en.sh settings.sh tests/test_runtime.sh tests/test_i18n_zh.sh tests/test_remote_exec.sh tests/test_setup_hardening.sh tests/test_deploy_reliability.sh tests/test_ops_flow_reliability.sh setup.sh deploy.sh backup.sh status.sh security.sh
python3 .codestable/tools/validate-yaml.py --file .codestable/features/2026-06-08-ops-flow-reliability/ops-flow-reliability-checklist.yaml
python3 .codestable/tools/validate-yaml.py --file .codestable/features/2026-06-08-ops-flow-reliability/ops-flow-reliability-contracts.yaml
python3 .codestable/tools/validate-yaml.py --file .codestable/roadmap/vpskit-stability-zh-hardening/vpskit-stability-zh-hardening-items.yaml
```
