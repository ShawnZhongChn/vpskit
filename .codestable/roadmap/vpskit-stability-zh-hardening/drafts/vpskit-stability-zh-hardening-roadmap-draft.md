---
doc_type: roadmap
slug: vpskit-stability-zh-hardening
status: draft
created: 2026-06-08
last_reviewed: 2026-06-08
tags: [stability, chinese, hardening, deploy, bash]
related_requirements: []
related_architecture: [ARCHITECTURE]
---

# vpskit 稳定性、中文化、安全加固与部署流程迭代

## 1. 背景

当前 vpskit 是一个 Bash 多脚本工具，核心脚本包括 `vpskit.sh`、
`setup.sh`、`deploy.sh`、`backup.sh`、`status.sh`、`security.sh`、
`settings.sh` 和 `lang.sh`。现状已经能完成 VPS 初始化、部署、状态检查、
备份恢复和安全审计，但流程里存在几类共同风险：

- 交互输入分散在各脚本中，菜单和确认逻辑没有统一的退出、重试、默认值和
  非交互行为协议，异常时容易表现为卡住、跳过或不可恢复。
- 远端脚本创建、`scp`、`ssh` 执行、`chmod 700`、清理临时文件等逻辑在多个脚本
  重复实现，缺少统一的超时、错误码、清理和日志契约。
- `deploy.sh`、`backup.sh`、`settings.sh` 中有不少容错式 `|| true`，其中一部分是
  合理降级，一部分会吞掉关键失败，导致任务看似继续但状态已经不可信。
- 语言默认是法语，已有 `lang/en.sh` 和 `lang/fr.sh`，还没有中文消息包，也没有
  “中文为主”的文案验收标准。
- 服务器加固和应用部署能力已经有基础实现，但安全基线、部署健康检查、回滚、
  备份恢复校验和审计输出还可以系统化迭代。

本 roadmap 目标是把这些问题拆成一组可单独推进的 feature，先建立共享协议和
最小闭环，再逐步覆盖中文化、服务器加固、应用部署、备份恢复、状态审计和最终验收。

## 2. 范围与明确不做

### 本 roadmap 覆盖

- 统一交互输入、循环、退出、重试和非交互默认行为。
- 统一远端执行链路：本地临时脚本、语言注入、placeholder 替换、上传、远端执行、
  清理、超时和错误码。
- 统一任务步骤状态协议：成功、跳过、失败、可恢复失败、降级警告。
- 将面向用户的交互和输出文案迭代为中文优先，同时保留已有语言文件机制。
- 加强 `setup.sh` 的服务器加固流程和失败回滚。
- 加强 `deploy.sh` 的部署、更新、回滚、Caddy、健康检查和元数据可靠性。
- 加强 `backup.sh`、`status.sh`、`security.sh`、`settings.sh` 的异常检测和结果可解释性。
- 建立验收脚本和测试矩阵，覆盖语法、ShellCheck、非交互场景、关键工具缺失、
  远端执行失败和恢复路径。

### 明确不做

- 不把 Bash 项目重写成 Go、Python、Node 或其他语言。
- 不改变 vpskit 的核心产品边界：仍然是本地终端工具，不引入 SaaS 后端。
- 不在本 roadmap 中实现多服务器集中管理；README 里的多服务器能力属于未来独立规划。
- 不引入真实 VPS 集成测试作为必需前置；本 roadmap 先定义可用的 mock/fixture
  验收，再把真实 VPS 验证列为人工验收项。
- 不把所有旧语言立刻删除；中文优先不等于取消法语/英语 fallback。

## 3. 模块拆分（概设）

```
vpskit 稳定性、中文化、安全加固与部署流程迭代
├── runtime-core：统一输入、命令执行、错误码、步骤状态和日志
├── remote-exec：统一远端脚本生成、上传、执行、清理和超时
├── i18n-zh：中文语言包、中文默认值和文案验收
├── setup-hardening：服务器初始化、SSH/firewall/fail2ban/Docker/Caddy 加固
├── deploy-reliability：部署、更新、回滚、Caddy 和健康检查可靠性
├── ops-flows：备份恢复、状态检查、安全审计和远程备份流程
└── verification：语法、ShellCheck、fixture、非交互和人工验收矩阵
```

### runtime-core · 统一运行时与异常协议

- **职责**：提供所有脚本可复用的输入、确认、菜单、命令执行、错误码、步骤状态、
  日志和清理协议。它解决“死循环、异常不返回、失败被吞”的共同根因。
- **承载的子 feature**：`runtime-core-contracts`、`remote-exec-wrapper`、
  `deploy-reliability-core`、`ops-flow-reliability`
- **触碰的现有代码 / 模块**：新增共享脚本模块，改造所有顶层 `*.sh` 的共用逻辑。

### remote-exec · 远端执行链路

- **职责**：把 `mktemp`、语言注入、placeholder 替换、`scp`、`ssh`、`sudo bash`、
  远端清理和本地错误处理抽成一致入口。
- **承载的子 feature**：`remote-exec-wrapper`、`setup-hardening-pass`、
  `deploy-reliability-core`、`ops-flow-reliability`
- **触碰的现有代码 / 模块**：`setup.sh`、`deploy.sh`、`backup.sh`、`status.sh`、
  `security.sh`、`settings.sh`。

### i18n-zh · 中文优先语言与文案

- **职责**：新增中文语言包，设置中文优先默认行为，统一错误、提示、菜单、日志和
  远端脚本文案，保留英语/法语 fallback。
- **承载的子 feature**：`zh-i18n-baseline`
- **触碰的现有代码 / 模块**：`lang.sh`、`lang/zh.sh`、`lang/en.sh`、`lang/fr.sh`、
  所有使用 `MSG_` / `RMSG_` / `LANG_` 的脚本。

### setup-hardening · 服务器加固

- **职责**：优化 VPS 初始化和安全基线，包括 SSH、sudoers、firewall、fail2ban、
  Docker、Caddy、自动更新、MOTD，以及失败回滚和幂等恢复。
- **承载的子 feature**：`setup-hardening-pass`
- **触碰的现有代码 / 模块**：`setup.sh`、`security.sh`、`status.sh`。

### deploy-reliability · 应用部署可靠性

- **职责**：优化 Git clone/update、私有仓库 SSH、Docker Compose/Dockerfile、
  Caddy 配置、健康检查、元数据、历史记录和回滚。
- **承载的子 feature**：`deploy-reliability-core`
- **触碰的现有代码 / 模块**：`deploy.sh`、`backup.sh`、`status.sh`。

### ops-flows · 运维流程

- **职责**：优化备份、恢复、状态、安全审计和远程备份设置的异常检测、结果解释、
  数据完整性和非交互行为。
- **承载的子 feature**：`ops-flow-reliability`
- **触碰的现有代码 / 模块**：`backup.sh`、`status.sh`、`security.sh`、`settings.sh`。

### verification · 验收矩阵

- **职责**：建立本 roadmap 的测试和验收边界，避免“只跑 bash -n”不足以证明
  循环、异常返回、中文化和远端执行可靠。
- **承载的子 feature**：`verification-harness`、`roadmap-acceptance-pass`
- **触碰的现有代码 / 模块**：`.github/workflows/shellcheck.yml`、新增测试/fixture 文件。

## 4. 模块间接口契约 / 共享协议（架构层详设）

这一节是后续 feature-design 的硬约束输入。任何 feature 如果需要改变这些契约，
必须先回到 roadmap update。

### 4.1 runtime 输入与菜单契约

**方向**：所有顶层脚本 -> `runtime-core`

**形式**：Bash 函数调用

**契约**：

```bash
# 读取一行输入。
# 返回:
#   0 = 得到有效输入，结果写入变量名 result_var
#   10 = 用户选择退出
#   11 = 非交互且无默认值
#   12 = 超过最大重试次数
vk_prompt result_var prompt default validator max_attempts

# 确认型输入。
# 返回:
#   0 = yes
#   1 = no
#   10 = 用户选择退出
#   11 = 非交互且无默认值
#   12 = 超过最大重试次数
vk_confirm prompt default max_attempts

# 菜单选择。
# options 是逗号分隔编号，例如 "1,2,3,q"。
# 返回码同 vk_prompt，结果写入 result_var。
vk_menu result_var prompt options default max_attempts
```

**约束**：

- 所有交互菜单必须支持 `q`/`quit`/`exit` 返回上级或退出脚本。
- 所有 `while true` 菜单必须有退出分支，且不能依赖 `Ctrl+C` 作为唯一退出方式。
- 非交互模式不得阻塞在 `read`；必须使用默认值、参数值，或返回 `11`。
- 输入校验失败最多重试 `max_attempts` 次，默认 `3` 次；超过后返回 `12`。
- 调用方必须根据返回码决定继续、返回上级、退出或打印错误，不能忽略返回码。

### 4.2 runtime 命令执行契约

**方向**：所有脚本 -> `runtime-core`

**形式**：Bash 函数调用

**契约**：

```bash
# 执行本地命令并记录状态。
# stdout/stderr 可按参数选择透传或捕获。
# 返回真实命令退出码；禁止把关键失败默认改成 0。
vk_run step_id severity timeout_seconds command...

# 标记一个非关键降级。
# severity: warn | info
vk_degrade step_id severity message

# 统一错误输出并退出。
# code 必须来自 4.5 错误码表。
vk_fail code step_id message
```

**约束**：

- `severity=required` 的命令失败必须使当前 step 失败。
- `severity=optional` 的命令失败必须调用 `vk_degrade`，在最终摘要里显示为 warning。
- 只有明确可降级的命令允许 `|| true`；其他场景必须通过 `vk_run` 或显式 `if ! ...; then`。
- 所有网络命令必须有超时：`ssh/scp/curl/wget/git clone/git fetch/docker health curl`。

### 4.3 step 状态与进度文件契约

**方向**：setup/deploy/backup/settings/security/status -> runtime-core

**形式**：文件协议 + Bash 函数调用

**契约**：

```bash
# step 状态文件每行一个事件:
# timestamp|step_id|status|code|message
#
# status:
#   started
#   done
#   skipped
#   failed
#   degraded

vk_step_start progress_file step_id message
vk_step_done progress_file step_id message
vk_step_skip progress_file step_id message
vk_step_fail progress_file step_id code message
vk_step_degrade progress_file step_id code message
vk_step_is_done progress_file step_id
```

**约束**：

- 旧的只写 `step1` / `step_docker` 形式可以通过兼容读取保留，但新写入必须使用事件格式。
- `done` 只能在本 step 必需动作全部成功后写入。
- `degraded` 不能让最终摘要显示为完全成功。
- 部署成功后可删除 `.deploy-progress`，但失败和 degraded 必须保留可诊断信息。

### 4.4 远端执行契约

**方向**：setup/deploy/backup/status/security/settings -> remote-exec

**形式**：Bash 函数调用 + 文件协议

**契约**：

```bash
# 创建远端脚本、注入语言、替换 placeholder、上传并执行。
# 返回:
#   0 = 远端脚本成功
#   20 = 本地脚本生成失败
#   21 = placeholder 替换失败
#   22 = 远端 mktemp 失败
#   23 = scp 上传失败
#   24 = chmod/sudo/执行失败
#   25 = 远端清理失败，但主执行成功
vk_remote_exec script_path ssh_user host ssh_key sudo_mode timeout_seconds
```

**约束**：

- 远端临时文件必须使用 `mktemp /tmp/vps-XXXXXXXXXX.sh`，权限必须设为 `700`。
- 主执行完成后必须尝试删除远端临时文件；清理失败只能是 `25` 或 warning，不能掩盖主执行失败。
- `sudo_mode=true` 时必须执行 `sudo bash`；非 sudo 模式执行 `bash`。
- `ssh` 和 `scp` 必须带 `BatchMode=yes`、连接超时和总体超时。
- 所有用户输入进入远端脚本前必须经过 `sed_escape` 或未来等价安全替换函数。

### 4.5 错误码契约

**方向**：runtime-core -> 所有脚本和最终摘要

**形式**：约定错误码

**契约**：

```
0   success
1   general_failure
2   invalid_argument
3   missing_dependency
4   invalid_input
5   user_cancelled
6   non_interactive_missing_input
10  prompt_quit
11  prompt_non_interactive_no_default
12  prompt_max_attempts
20  remote_generate_failed
21  remote_placeholder_failed
22  remote_mktemp_failed
23  remote_upload_failed
24  remote_execute_failed
25  remote_cleanup_failed
30  network_timeout
31  ssh_connect_failed
32  git_failed
33  docker_failed
34  caddy_failed
35  healthcheck_failed
40  security_baseline_failed
50  backup_failed
51  restore_failed
```

**约束**：

- 每个失败路径必须输出错误码、当前 step、用户可执行的下一步。
- 如果一个 workflow 产生 degraded warning，最终摘要必须明确列出 warning。

### 4.6 中文语言契约

**方向**：所有脚本 -> i18n-zh

**形式**：语言文件变量

**契约**：

```bash
lang/zh.sh
  MSG_*   # 本地脚本消息
  RMSG_*  # 注入远端脚本消息
  LANG_*  # 通用提示/标签
```

**约束**：

- `lang.sh` 默认语言改为中文：无配置且交互时优先展示中文选项；非交互无配置时使用 `zh`。
- `lang.sh` 必须验证语言文件 `bash -n` 后再 source。
- 所有新增或修改的用户可见文案必须进入语言文件，不在脚本里硬编码中文长句。
- 保留 `en` 和 `fr` fallback；缺失 `zh.sh` 时按 `en` 或 `fr` 可用文件降级，并打印 warning。

### 4.7 部署健康检查契约

**方向**：deploy-reliability -> deploy/status/security/backup

**形式**：文件协议 + Bash 函数调用

**契约**：

```bash
# 应用元数据文件
~USER/apps/APP/.deploy-domain
~USER/apps/APP/.deploy-port
~USER/apps/APP/.deploy-branch
~USER/apps/APP/.deploy-type       # compose | dockerfile
~USER/apps/APP/.deploy-health-url # optional, default http://localhost:PORT

# 健康检查结果
status: ok | warn | failed
http_code: 000 | 2xx | 3xx | 4xx | 5xx
message: human-readable localized text
```

**约束**：

- `deploy.sh` 不能只凭容器启动成功判定部署成功；必须执行健康检查并记录结果。
- `000` 或 `5xx` 至少是 warning；如果用户启用了 required healthcheck，则必须失败并保留 rollback 入口。
- 更新前必须保存当前 commit；失败时必须提示可执行 rollback 命令。
- Caddy 配置变更必须先备份，`caddy validate` 失败必须恢复备份并把 step 标为 failed。

## 5. 子 feature 清单

1. **runtime-core-contracts** — 建立共享运行时、输入/菜单/错误码/步骤状态契约，并先改造 `vpskit.sh` 和一个最小 workflow 验证退出与异常返回。
   - 所属模块：runtime-core
   - 依赖：无
   - 状态：planned
   - 对应 feature：未启动
   - 备注：最小闭环。做完后至少能证明菜单不会无出口循环，非交互不会卡住，关键失败会返回错误码。

2. **remote-exec-wrapper** — 抽出远端脚本生成、语言注入、placeholder 替换、上传、执行、清理和超时的统一包装。
   - 所属模块：remote-exec
   - 依赖：`runtime-core-contracts`
   - 状态：planned
   - 对应 feature：未启动
   - 备注：为 setup/deploy/backup/status/security/settings 后续改造提供统一入口。

3. **zh-i18n-baseline** — 新增中文语言包，调整默认语言为中文优先，并完成核心菜单、setup、deploy、status、security、backup 的中文文案基线。
   - 所属模块：i18n-zh
   - 依赖：`runtime-core-contracts`
   - 状态：planned
   - 对应 feature：未启动
   - 备注：可以和 `remote-exec-wrapper` 并行，但要遵守语言契约。

4. **setup-hardening-pass** — 优化服务器初始化和安全加固流程：步骤失败检测、SSH 配置回滚、firewall/fail2ban/Docker/Caddy/auto-update 幂等性和最终摘要。
   - 所属模块：setup-hardening
   - 依赖：`remote-exec-wrapper`, `zh-i18n-baseline`
   - 状态：planned
   - 对应 feature：未启动
   - 备注：覆盖用户提到的服务器加固配置优化。

5. **deploy-reliability-core** — 优化部署、更新、回滚、Caddy、健康检查、GitHub SSH 和元数据写入，避免关键失败被吞并。
   - 所属模块：deploy-reliability
   - 依赖：`remote-exec-wrapper`, `zh-i18n-baseline`
   - 状态：planned
   - 对应 feature：未启动
   - 备注：覆盖用户提到的应用部署优化。

6. **ops-flow-reliability** — 优化备份、恢复、状态检查、安全审计和远程备份设置的异常检测、降级说明和结果摘要。
   - 所属模块：ops-flows
   - 依赖：`remote-exec-wrapper`, `zh-i18n-baseline`
   - 状态：planned
   - 对应 feature：未启动
   - 备注：可以与 setup/deploy 后半段并行，但需要共享错误码和远端执行契约。

7. **verification-harness** — 建立 Bash 语法、ShellCheck、语言变量完整性、非交互输入、mock ssh/scp/curl/docker/caddy/git 的测试矩阵。
   - 所属模块：verification
   - 依赖：`runtime-core-contracts`, `remote-exec-wrapper`, `zh-i18n-baseline`
   - 状态：planned
   - 对应 feature：未启动
   - 备注：后续每条功能都必须把自己的验收命令接入这里。

8. **roadmap-acceptance-pass** — 对本 roadmap 的所有 workflow 做最终验收：循环退出、异常返回、中文文案、服务器加固、部署可靠性、备份恢复和安全审计。
   - 所属模块：verification
   - 依赖：`setup-hardening-pass`, `deploy-reliability-core`, `ops-flow-reliability`, `verification-harness`
   - 状态：planned
   - 对应 feature：未启动
   - 备注：收尾验收和文档/architecture 回写。

**最小闭环**：第 1 条 `runtime-core-contracts` 做完后，至少能端到端演示一个交互菜单：
用户可退出、输入错误有重试上限、非交互不阻塞、关键失败能返回约定错误码。

## 6. 排期思路

先做 `runtime-core-contracts`，因为它直接解决循环和异常返回的共同协议，是后续所有脚本
改造的基础。随后做 `remote-exec-wrapper`，收敛远端执行链路，避免 setup/deploy/backup/status/security/settings
重复修同一类 bug。`zh-i18n-baseline` 可以在 runtime 契约稳定后并行推进。之后按用户价值和风险分成三条：
服务器加固、应用部署、运维流程。最后用 verification 和 acceptance 收束，避免每条 feature
只修局部但整体仍不可验证。

## 7. 观察项

- `.codestable/attention.md` 目前还是 onboard 最小骨架，建议后续用 `cs-note` 写入中文优先、
  Bash 检查命令、安全文件权限和远端执行规则。
- `CONTRIBUTING.md` 仍写着用户可见文案是法语；中文化 roadmap 确认后应另起 decision 或 guide
  更新长期规约。
- `docs/architecture.md` 只覆盖 `setup.sh`，后续 acceptance 时应把共享 runtime/remote-exec 的已落地结构
  回写到 architecture。
- `setup.sh` 当前用 `curl -fsSL https://get.docker.com | sh` 安装 Docker；这是否保留还是改为
  发行版包管理器/官方 repo，需要在 `setup-hardening-pass` 里做明确决策。
- 真实 VPS 集成验证成本高，本 roadmap 先要求 mock/fixture 验收；发布前仍建议人工跑一台测试 VPS。
