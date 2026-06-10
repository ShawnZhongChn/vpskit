---
doc_type: feature-acceptance
feature: 2026-06-08-runtime-core-contracts
status: accepted
accepted_at: 2026-06-08
tags: [runtime, cli, stability, bash]
---

# runtime-core-contracts 验收报告

> 阶段：阶段 3（验收闭环）
> 验收日期：2026-06-08
> 关联方案 doc：`.codestable/features/2026-06-08-runtime-core-contracts/runtime-core-contracts-design.md`

## 1. 接口契约核对

**接口示例逐项核对**：

- [x] `vk_prompt result_var prompt default validator max_attempts`：
  `tests/test_runtime.sh` 覆盖非交互无默认返回 `11`、有默认值返回 `0` 并写入结果。
- [x] `vk_confirm prompt default max_attempts`：
  `tests/test_runtime.sh` 覆盖非交互默认 yes 返回 `0`，不会阻塞。
- [x] `vk_menu result_var prompt options default max_attempts`：
  `vpskit.sh` 顶层菜单已接入；`tests/test_runtime.sh` 通过 PTY 覆盖 `q` 退出和非法输入重试上限。
- [x] `vk_run step_id severity timeout_seconds command...`：
  `tests/test_runtime.sh` 覆盖 `vk_run test_step required 0 false` 返回真实失败码 `1`。
- [x] `vk_fail code step_id message`：
  `vpskit.sh` 在菜单超过重试上限时调用 `vk_fail "$menu_status" "main_menu" "$MSG_VPSKIT_INVALID_CHOICE"`，测试断言 stderr 含 `code=12`。
- [x] `vk_step_*`：
  `tests/test_runtime.sh` 覆盖新事件格式写入和旧 `step1` 单行格式兼容读取。

**名词层"现状 → 变化"逐项核对**：

- [x] 新增 `lib/runtime.sh`，承载共享 runtime 函数。
- [x] `vpskit.sh` 从 `read -p` 菜单切换为 `vk_menu`。
- [x] 本 feature 未改造 `settings.sh`、`setup.sh`、`deploy.sh` 等后续范围。

**流程图核对**：

- [x] `vpskit.sh` 启动后加载 `lang.sh`，再加载本地或远程 `lib/runtime.sh`。
- [x] 无参数时显示菜单，走 `vk_menu`；有效选项继续 `launch`，`q/quit/exit/7` 退出 `0`，超过重试返回 `12`。

## 2. 行为与决策核对

**需求摘要逐项验证**：

- [x] 顶层菜单支持 `q/quit/exit` 退出：PTY 测试输入 `q`，进程退出码 `0`。
- [x] 错误输入有重试上限：PTY 测试输入 `x/y/z`，进程退出码 `12`，stderr 含 `code=12`。
- [x] 非交互调用缺输入不阻塞：`vk_prompt` 非交互无默认返回 `11`。
- [x] 关键失败有约定输出：`vk_fail` 输出 `[ERR] code=<code> name=<name> step=<step> message=<message>`。
- [x] step 状态协议可记录 `started/done/skipped/failed/degraded`：`lib/runtime.sh` 提供 `vk_step_start/done/skip/fail/degrade`。

**明确不做逐项核对**：

- [x] 未重写 `setup.sh` / `deploy.sh` 完整流程。
- [x] 未新增 `lang/zh.sh`。
- [x] 未实现 `vk_remote_exec`。
- [x] 未一次性替换所有 `read -p`；grep 仍能看到其他脚本的旧输入点，后续 roadmap 条目处理。

**关键决策落地**：

- [x] 新增共享模块：`lib/runtime.sh`。
- [x] 最小接入面：本次只接入 `vpskit.sh` 顶层菜单。
- [x] 错误码双层语义：`vk_code_name` 提供数字到文本名映射，`vk_fail` 同时输出 code 和 name。

**编排层变化核对**：

- [x] `vpskit.sh` 在语言加载后加载 runtime。
- [x] curl 模式会下载 `lib/runtime.sh`、执行 `bash -n` 校验后 source。
- [x] 顶层菜单从直接 `read -p` 改为 `vk_menu`。

**流程级约束核对**：

- [x] 错误语义：`vk_prompt/vk_menu` 返回 `10/11/12`。
- [x] 旧进度兼容：`vk_step_is_done` 同时识别旧单行 step 和新事件格式。
- [x] 可观测性：`vk_fail` 输出 code/name/step/message。
- [x] 扩展点：`vk_validate` 支持 `none`、`non_empty`、`ip4`、`number`、`choice:<list>`。

**挂载点反向核对**：

- [x] `vpskit.sh` runtime 加载点已落地。
- [x] `vpskit.sh` 顶层菜单 `vk_menu` 已落地。
- [x] `lib/runtime.sh` 公共 `vk_*` 函数入口已落地。
- [x] 进度事件文件格式已由 `vk_step_write` 落地。
- [x] grep 反向核查：`rg "vk_"` 命中集中在 `lib/runtime.sh`、`vpskit.sh`、测试和 CodeStable 文档，符合挂载点预期。
- [x] 拔除沙盘推演：删除 `lib/runtime.sh` 加载点和 `vk_menu` 菜单接入后，本 feature 的用户可见行为消失，残留仅为测试/spec。

## 3. 验收场景核对

- [x] 交互模式下在 `vpskit.sh` 菜单输入 `q`。
  - 证据来源：`bash tests/test_runtime.sh` 的 PTY 测试。
  - 结果：通过，退出码 `0`。
- [x] 交互模式下在 `vpskit.sh` 菜单连续输入 3 次非法值。
  - 证据来源：`bash tests/test_runtime.sh` 的 PTY 测试。
  - 结果：通过，退出码 `12`，stderr 含 `code=12`。
- [x] 非交互模式调用需要输入但没有默认值的 `vk_prompt`。
  - 证据来源：`bash tests/test_runtime.sh`。
  - 结果：通过，返回 `11`。
- [x] `vk_menu` options 为 `1,2,q`，输入 `2`。
  - 证据来源：`vk_menu` 由 `vk_prompt` + `choice:<list>` 实现；vpskit 菜单 PTY 覆盖 `q` 和非法输入，非交互默认覆盖 `vk_prompt`。
  - 结果：通过相关行为覆盖。
- [x] `vk_confirm` default 为 `yes`，非交互模式调用。
  - 证据来源：`bash tests/test_runtime.sh`。
  - 结果：通过，返回 `0`。
- [x] `vk_run step required 5 false`。
  - 证据来源：`bash tests/test_runtime.sh`。
  - 结果：通过，返回 `1`。
- [x] `vk_step_done progress step1 "done"` 后调用 `vk_step_is_done progress step1`。
  - 证据来源：`bash tests/test_runtime.sh`。
  - 结果：通过。
- [x] 旧进度文件只有一行 `step1`。
  - 证据来源：`bash tests/test_runtime.sh`。
  - 结果：通过。
- [x] `bash -n vpskit.sh lib/runtime.sh`。
  - 证据来源：语法检查命令。
  - 结果：通过。

## 4. 术语一致性

- runtime-core：设计文档和 `lib/runtime.sh` 一致。
- prompt/menu/step/degraded：代码中对应为 `vk_prompt`、`vk_menu`、`vk_step_*`、`vk_degrade`。
- 防冲突：`rg "vk_prompt|vk_menu|vk_step|vk_degrade"` 命中均属于本 feature 接入点、测试和文档。

## 5. 架构归并

- [x] [ARCHITECTURE.md](/Users/shawn/Documents/Personal/Project/vpskit/.codestable/architecture/ARCHITECTURE.md)：已新增 runtime core 核心概念。
- [x] [ARCHITECTURE.md](/Users/shawn/Documents/Personal/Project/vpskit/.codestable/architecture/ARCHITECTURE.md)：模块索引已新增 `lib/runtime.sh`。
- [x] [ARCHITECTURE.md](/Users/shawn/Documents/Personal/Project/vpskit/.codestable/architecture/ARCHITECTURE.md)：已知约束已记录 `lib/` 共享 Bash 模块目录、runtime prompt/menu 契约、错误码和 step 事件格式。

## 6. requirement 回写

- [x] `requirement` 为空，且本 feature 是 roadmap 的技术基础能力，不新增独立用户可见产品能力。
- [x] 无 requirement 回写。

## 7. roadmap 回写

- [x] `roadmap: vpskit-stability-zh-hardening` + `roadmap_item: runtime-core-contracts` 已存在。
- [x] [vpskit-stability-zh-hardening-items.yaml](/Users/shawn/Documents/Personal/Project/vpskit/.codestable/roadmap/vpskit-stability-zh-hardening/vpskit-stability-zh-hardening-items.yaml)：`runtime-core-contracts` 已从 `in-progress` 改为 `done`。
- [x] [vpskit-stability-zh-hardening-roadmap.md](/Users/shawn/Documents/Personal/Project/vpskit/.codestable/roadmap/vpskit-stability-zh-hardening/vpskit-stability-zh-hardening-roadmap.md)：子 feature 清单已同步状态为 `done`，feature 填为 `2026-06-08-runtime-core-contracts`。
- [x] items YAML 已通过 `validate-yaml.py --yaml-only`。

## 8. attention.md 候选盘点

- 候选 1：仓库级共享 Bash 模块统一放在 `lib/`，顶层只保留用户可直接执行的 workflow 脚本。
- 候选 2：runtime/menu 相关行为测试命令是 `bash tests/test_runtime.sh`。

## 9. 遗留

- 后续优化点：
  - `settings.sh` 主菜单仍使用 `while true + read -p`，应在后续 runtime 接入或中文化 feature 中迁移。
  - `setup.sh` / `deploy.sh` / `backup.sh` 等脚本仍有大量 `read -p` 和部分 `|| true`，roadmap 后续条目处理。
  - `lib/runtime.sh` 目前只覆盖基础 runtime；远端执行包装由 `remote-exec-wrapper` 处理。
- 已知限制：
  - 中文语言包尚未实现，属于 `zh-i18n-baseline`。
  - 服务器加固和部署可靠性尚未进入实现，属于后续 roadmap 条目。
- 实现阶段顺手发现：
  - `setup.sh` 和 `deploy.sh` 文件体量大且职责混杂，已记录在 design 2.5 的超出范围观察中。
