---
doc_type: feature-acceptance
feature: 2026-06-08-deploy-reliability-core
status: accepted
summary: deploy 远端执行、Caddy 失败语义、健康检查 metadata 和 rollback 提示已完成可靠性加固
tags: [deploy, reliability, healthcheck, caddy, bash]
---

# deploy-reliability-core 验收报告

> 阶段：阶段 3（验收闭环）
> 验收日期：2026-06-08
> 关联方案 doc：.codestable/features/2026-06-08-deploy-reliability-core/deploy-reliability-core-design.md

## 1. 接口契约核对

**接口示例逐项核对**：
- [x] `deploy.sh` 已加载 `lib/runtime.sh` 和 `lib/remote_exec.sh`，并通过 `run_prepared_remote_script` 统一调用 `vk_remote_prepare_script` / `vk_remote_exec`。
- [x] rollback、update、main deploy 三条远端脚本路径都使用 wrapper helper。
- [x] main deploy 远端 heredoc 写入 `.deploy-type` 和 `.deploy-health-url/status/code/message`。
- [x] Caddy validate/reload 失败路径恢复 `${CADDYFILE}.bak` 并 `exit 34`。
- [x] 失败 trap 输出 rollback 提示变量 `RMSG_DEPLOY_ERR_ROLLBACK_HINT` 和 rollback 入口。

**名词层"现状 → 变化"逐项核对**：
- [x] 旧 inline `REMOTE_TMP=$(ssh ... mktemp)` 和组合式 `chmod 700; sudo bash; rm -f` 已从 `deploy.sh` 的远端脚本执行出口移除。
- [x] Docker Compose 成功路径设置 `DEPLOY_TYPE="compose"`；Dockerfile 成功路径设置 `DEPLOY_TYPE="dockerfile"`。
- [x] 健康检查 `000` / 4xx / 5xx 记录为 `warn`，2xx / 3xx 记录为 `ok`。
- [x] `.env` 作为额外文件上传仍保留 raw `scp`，但补充 `BatchMode=yes` 和 `ConnectTimeout=10`。

## 2. 行为与决策核对

**需求摘要逐项验证**：
- [x] rollback、update、main deploy 三条远端执行链路消费 `lib/remote_exec.sh`。
- [x] Caddy 配置失败或 reload 失败不会继续 mark `step_caddy` done。
- [x] 健康检查结果持久化为 URL、status、code、message。
- [x] main deploy 写 `.deploy-type`，形成完整 deploy metadata。
- [x] update 和重部署前保存 `.last-working-commit`。
- [x] 失败 trap 提供 rollback 入口提示。

**明确不做逐项核对**：
- [x] 未引入 required healthcheck。
- [x] 未重写 deploy 交互输入为 runtime prompt。
- [x] 未改变 Docker Compose/Dockerfile 部署策略。
- [x] 未改 backup/status/security 的 metadata 消费逻辑。

**关键决策落地**：
- [x] 三条远端执行链路全部消费 wrapper。
- [x] Caddy 失败是关键失败，返回 `34`。
- [x] 健康检查先持久化 warning，不强制失败。
- [x] 元数据按 roadmap 4.7 补齐。

## 3. 验收场景核对

- [x] S1：rollback、update、main deploy 三条远端执行都使用 `vk_remote_prepare_script` / `vk_remote_exec`。
- [x] S2：`deploy.sh` 不再保留旧组合式 `chmod 700; sudo bash; rm -f` 执行行。
- [x] S3：Caddy validate/reload 失败恢复备份并退出，不写 `step_caddy` done。
- [x] S4：健康检查 `000`、`2xx/3xx`、`4xx/5xx` 映射到持久化 health status/code/message。
- [x] S5：main deploy 写 `.deploy-type`，值为 `compose` 或 `dockerfile`。
- [x] S6：metadata 写 `.deploy-health-url/status/code/message`。
- [x] S7：update 前保存 `.last-working-commit`，失败 trap 输出 rollback 命令提示。
- [x] S8：本 feature 未改变 Docker Compose/Dockerfile 部署策略，未引入 required healthcheck。

证据：`bash tests/test_deploy_reliability.sh`、`rg` 静态检查、`bash -n` 语法检查。

## 4. 术语一致性

- deploy-reliability：集中指 `deploy.sh` 的部署、更新、回滚、Caddy 和健康检查可靠性。
- deploy health result：代码中为 `HEALTH_URL`、`HEALTH_STATUS`、`HEALTH_CODE`、`HEALTH_MESSAGE`，落盘为 `.deploy-health-*`。
- deploy type：代码中为 `DEPLOY_TYPE`，落盘为 `.deploy-type`。
- rollback hint：代码中为 `RMSG_DEPLOY_ERR_ROLLBACK_HINT` 和 `bash deploy.sh  # choose rollback for $APP_NAME`。

## 5. 架构归并

- [x] `.codestable/architecture/ARCHITECTURE.md` 已补充 `deploy.sh` 消费 `lib/remote_exec.sh`。
- [x] 架构已补充 `.deploy-type` 和 `.deploy-health-url/status/code/message` 文件协议。
- [x] 架构已补充 Caddy validate/reload 失败必须恢复备份并退出 `34`。

## 6. requirement 回写

- [x] `requirement` 为空；本 feature 是 roadmap 内 deploy-reliability 技术能力，不新增独立用户愿景文档。本次跳过 requirement 回写。

## 7. roadmap 回写

- [x] items.yaml 中 `deploy-reliability-core` 已改为 `done`，feature 指向 `2026-06-08-deploy-reliability-core`。
- [x] roadmap 主文档第 5 节对应条目已同步为 `done`。
- [x] YAML 校验通过。

## 8. attention.md 候选盘点

- [x] 候选：`tests/test_deploy_reliability.sh` 通过抽取 main deploy heredoc 做静态契约验证，不需要真实 VPS。该信息适合后续 verification-harness 阶段统一沉淀。

## 9. 遗留

- `deploy.sh` 本地交互仍有多个 `read -p`，可后续单独迁移到 runtime input helper。
- required healthcheck 尚未实现；当前 `000`、4xx、5xx 仍是 warning metadata。
- `.env` 上传仍是 raw `scp`，因为当前 remote_exec wrapper 只覆盖生成脚本执行，不覆盖额外文件上传。
- `status.sh`、`backup.sh`、`security.sh` 后续需要在 ops-flow 中消费 `.deploy-health-*` metadata。

## 验证命令

```bash
bash tests/test_deploy_reliability.sh
bash tests/test_setup_hardening.sh
bash tests/test_remote_exec.sh
bash tests/test_runtime.sh
bash tests/test_i18n_zh.sh
bash -n vpskit.sh lib/runtime.sh lib/remote_exec.sh lang.sh lang/zh.sh lang/en.sh settings.sh tests/test_runtime.sh tests/test_i18n_zh.sh tests/test_remote_exec.sh tests/test_setup_hardening.sh tests/test_deploy_reliability.sh setup.sh deploy.sh backup.sh status.sh security.sh
python3 .codestable/tools/validate-yaml.py --file .codestable/features/2026-06-08-deploy-reliability-core/deploy-reliability-core-checklist.yaml
python3 .codestable/tools/validate-yaml.py --file .codestable/features/2026-06-08-deploy-reliability-core/deploy-reliability-core-contracts.yaml
python3 .codestable/tools/validate-yaml.py --file .codestable/roadmap/vpskit-stability-zh-hardening/vpskit-stability-zh-hardening-items.yaml
```
