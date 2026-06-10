---
doc_type: feature-acceptance
feature: 2026-06-08-remote-exec-wrapper
status: accepted
summary: 统一远端执行 wrapper 已落地，并以 status workflow 完成首个接入验证
tags: [remote-exec, ssh, stability, bash]
---

# remote-exec-wrapper 验收报告

> 阶段：阶段 3（验收闭环）
> 验收日期：2026-06-08
> 关联方案 doc：.codestable/features/2026-06-08-remote-exec-wrapper/remote-exec-wrapper-design.md

## 1. 接口契约核对

**接口示例逐项核对**：
- [x] `vk_remote_prepare_script "$TMPSCRIPT" "__USERNAME__" "$USERNAME"`：已在 `status.sh` 接入；测试覆盖 placeholder 特殊字符和参数错误。
- [x] `vk_remote_exec "$TMPSCRIPT" "$USERNAME" "$VPS_IP" "$SSH_KEY" true 900 auto`：已在 `status.sh` 接入；测试覆盖成功和 `22/23/24/25` 失败阶段。

**名词层"现状 → 变化"逐项核对**：
- [x] `lib/remote_exec.sh` 新增 `vk_remote_prepare_script`、`vk_remote_replace_placeholder`、`vk_remote_exec`。
- [x] `lib/runtime.sh` 新增 `20-25` 远端错误码 code name。
- [x] `status.sh` 从 inline `ssh/scp` 远端执行块切换为 wrapper。

**流程图核对**：
- [x] prepare → mktemp → upload → execute → cleanup 的节点均有代码落点。

## 2. 行为与决策核对

**需求摘要逐项验证**：
- [x] 远端 `mktemp`、`scp`、执行、cleanup 分阶段返回：`tests/test_remote_exec.sh` 覆盖。
- [x] 上传和执行失败不被 cleanup 覆盖：执行失败返回 `24`，cleanup-only 失败返回 `25`。
- [x] `ssh/scp` 使用 `BatchMode=yes` 和 `ConnectTimeout=10`：fake command log 验证。
- [x] 第一批只接入 `status.sh`：grep 确认其他 workflow 仍待后续 feature 扩面。

**明确不做逐项核对**：
- [x] 未批量替换 `setup.sh`、`deploy.sh`、`backup.sh`、`security.sh`、`settings.sh` 的远端执行块。
- [x] 未改变 status 远端脚本采集内容。
- [x] 未新增真实 VPS 集成测试硬依赖。

**关键决策落地**：
- [x] 新增共享模块 `lib/remote_exec.sh`。
- [x] 执行和 cleanup 拆成两个远端命令。
- [x] `status.sh` 作为只读状态 workflow 先接入。
- [x] timeout 兼容 `timeout/gtimeout`，不存在时仍保留 SSH ConnectTimeout。

**挂载点反向核对**：
- [x] `lib/remote_exec.sh`、`lib/runtime.sh` 远端错误码、`status.sh` source/调用点、`tests/test_remote_exec.sh` 均存在。
- [x] grep `status.sh` 未命中旧 `REMOTE_TMP=`、`SSH_TTY_FLAG` 和组合式 `sudo bash ...; rm -f` 执行行。
- [x] 拔除沙盘：移除 `status.sh` 两个 `vk_remote_*` 调用会让 status workflow 回到无 wrapper 的上传/执行缺口，挂载点完整。

## 3. 验收场景核对

- [x] S1 本地脚本不存在或为空 → `vk_remote_exec` 返回 `20`。
- [x] S2 sed 特殊字符 placeholder → prepare 成功且 `bash -n` 通过。
- [x] S3 远端 `mktemp` 失败 → 返回 `22`。
- [x] S4 `scp` 上传失败 → 返回 `23`，并尝试 cleanup。
- [x] S5 `chmod` 或远端执行失败 → 返回 `24`，并尝试 cleanup。
- [x] S6 主执行成功但 cleanup 失败 → 返回 `25`。
- [x] S7 成功路径 fake 日志包含 BatchMode、ConnectTimeout、mktemp、chmod、sudo bash、rm。
- [x] S8 `status.sh` 通过 wrapper 发送和执行远端脚本。

证据：`bash tests/test_remote_exec.sh`、`rg` 静态检查、`bash -n` 语法检查。

## 4. 术语一致性

- remote-exec：代码中集中在 `lib/remote_exec.sh` 和 feature 文档，含义一致。
- prepared script：实现为 `vk_remote_prepare_script` 原地准备本地脚本。
- placeholder：实现为 `vk_remote_replace_placeholder`，测试覆盖特殊字符。
- cleanup failure：实现为 `VK_REMOTE_CLEANUP_FAILED=25`，不会掩盖执行失败。

## 5. 架构归并

- [x] `.codestable/architecture/ARCHITECTURE.md` 已加入 remote execution core 概念。
- [x] 模块索引已加入 `lib/remote_exec.sh`。
- [x] 已知约束已加入 `20-25` 远端错误码、cleanup 不掩盖主执行失败、`status.sh` 为首个接入点。

## 6. requirement 回写

- [x] `requirement` 为空；本 feature 是 roadmap foundation 技术能力，不新增独立用户愿景文档。本次跳过 requirement 回写。

## 7. roadmap 回写

- [x] `.codestable/roadmap/vpskit-stability-zh-hardening/vpskit-stability-zh-hardening-items.yaml` 中 `remote-exec-wrapper` 已改为 `done`，feature 指向 `2026-06-08-remote-exec-wrapper`。
- [x] roadmap 主文档第 5 节对应条目已同步为 `done`。
- [x] YAML 校验通过。

## 8. attention.md 候选盘点

- [x] 候选：远端执行 wrapper 首个接入点是 `status.sh`，其他 workflow 仍保留 legacy inline 块，需要后续按 roadmap 扩面。该信息已写入 architecture；是否放入 attention.md 可在 roadmap 后续阶段再决定。

## 9. 遗留

- 后续优化点：`setup.sh`、`deploy.sh`、`backup.sh`、`security.sh`、`settings.sh` 仍有 legacy 远端执行块，按 roadmap 后续 feature 分别接入。
- 已知限制：本 feature 未覆盖额外文件上传场景，例如 deploy `.env` 和 backup restore tarball。
- 顺手发现：无方案外修复。

## 验证命令

```bash
bash tests/test_remote_exec.sh
bash tests/test_runtime.sh
bash tests/test_i18n_zh.sh
bash -n vpskit.sh lib/runtime.sh lib/remote_exec.sh lang.sh lang/zh.sh settings.sh tests/test_runtime.sh tests/test_i18n_zh.sh tests/test_remote_exec.sh setup.sh deploy.sh backup.sh status.sh security.sh
python .codestable/tools/validate-yaml.py --file .codestable/features/2026-06-08-remote-exec-wrapper/remote-exec-wrapper-checklist.yaml --yaml-only
python .codestable/tools/validate-yaml.py --file .codestable/features/2026-06-08-remote-exec-wrapper/remote-exec-wrapper-contracts.yaml --yaml-only
python .codestable/tools/validate-yaml.py --file .codestable/roadmap/vpskit-stability-zh-hardening/vpskit-stability-zh-hardening-items.yaml --yaml-only
```
