# CodeStable 并行 Agent 工作流口径

由 `cs-onboard` 复制到项目 `.codestable/reference/parallel-workflow.md`。所有 `cs-*` skill 描述并行 dispatch 时统一引用本文件，**不自创口径**；引用方在自身 SKILL.md 写"详见 `.codestable/reference/parallel-workflow.md`"，不复制大段内容。

修改本文件走 `cs-roadmap update`（roadmap 层）或 `cs-onboard` 模板升级（共享口径层）。

---

## 1. 何时并行

并行不是越多越好——拆任务、起 agent、收口的开销也是成本。下面的判据按场景分四类。

### 判据（满足任一即默认并行）

- 任务可拆成 **2 个以上独立逻辑模块**，模块间靠 contract 解耦（不需要互相等结果）
- 同一份产物需要 **2 个以上不同视角**核对（doc / architecture / constraint；design-consistency / spec-backfill / behavior）
- 同一类工作要重复跑 **N 次不同对象**（多假设并行 hunt root cause；多 sub-feature 并行实现）
- 主会话需要 **隔离上下文** 避免污染（探索性大量 grep / 大文件 read 应丢给 Explore 子 agent）

### 不并行的反例

- 任务链条 **强串行**：A 输出是 B 输入，B 输出是 C 输入——拆 agent 反而徒增协调成本
- 改动 **同一文件同一区块**：worktree 合不回来，并行制造冲突
- 任务规模 **极小**（一个 Edit 能搞定）——起 agent 的 token 成本超过收益
- contract 还 `draft`——并行实现会按各自理解走，联调时爆炸

### 四类场景示例

| 场景 | 默认并行做法 | 触发 skill |
|---|---|---|
| **探索** | 大范围 grep / 读多份文件丢给 `subagent_type: Explore`，主会话只接结论 | 任何 skill 的 Phase 2 |
| **审计** | doc-auditor / architecture-auditor / constraint-auditor 三 agent 同时跑 | `cs-onboard` 迁移路径 |
| **实现** | 一条 feature 内多 contract 各起一个 `cs-feat-impl` 实例，worktree 隔离 | `cs-feat`（router） |
| **验收** | design-consistency / spec-backfill / behavior 三 validator 并行 | `cs-feat-accept` |

---

## 2. coordinator 角色协议

并行工作流分两层角色：**coordinator**（主会话）和 **sub-agent**（teammate / Agent tool 启动的实例）。

### 主会话默认是 coordinator

- **不进 worktree**——主会话留在原仓库做协调、综合、落盘
- **不写代码**——写代码丢给 sub-agent，主会话只读 sub-report 决定下一步
- **只在协调任务结束 / 用户打断时停下**

### 起 sub-agent 的标准调用

用 Agent tool（或 teammate teams），传以下字段：

```yaml
team_name: {语义化名字，如 doc-auditor / impl-{contract_id}}
isolation: worktree              # 写代码必选；纯读取/探索可省（见第 3 节）
subagent_type: {留空走默认 / Explore 用于纯读取}
prompt: |
  {自包含上下文 + 任务 + 引用本文件路径 + 引用对应 contract}
# model 字段：不写！sub-agent 继承当前模型，除非用户明确另指定
```

**为什么不写 `model`**：主会话用什么 model 是用户当下决策的体现，sub-agent 默认跟随是对用户当前选择的尊重。强行指定会让一次升级 / 降级模型时多处遗漏。

### coordinator 的四件事

1. **拆任务**——按 contract 边界把工作切给 sub-agent，**不交叉边界**
2. **分派上下文**——每个 sub-agent prompt 自包含：任务目标、相关 contract（contract_id + 完整 inputs/outputs/error_semantics）、引用本文件、汇报模板
3. **综合判断**——读各 sub-report，识别 drift / 冲突 / 重复，决定下一步动作
4. **决定落盘**——sub-agent 在 worktree 内改的文件由 coordinator 决定何时合回主仓库

### 任务结束的清理

- 所有 sub-agent 汇报完毕 + coordinator 已综合 → shutdown team / 清理残留 pane / 删 worktree
- **不要把僵尸 agent / worktree 留过夜**——下次启动会读到陈旧上下文

---

## 3. coder 隔离规则

| sub-agent 类型 | isolation | 说明 |
|---|---|---|
| **coder**（写代码） | `worktree` | 默认必选——并行写代码不隔离会撞文件 |
| **auditor / validator**（只读核对） | 不设 | 只读不冲突；写的 report 由 coordinator 收口 |
| **Explore**（纯探索 / grep / read） | 不设 | `subagent_type: Explore` 本身不会写文件 |

### worktree 使用要点

- worktree 路径由 Agent tool 自动管理，sub-agent prompt 不需要硬编码
- sub-agent 在 worktree 内提交一个 commit，coordinator 决定合回主分支的方式（cherry-pick / merge / 只读取 diff）
- worktree merge 失败 → **打断用户**，由用户决定如何合并

---

## 4. drift 收口流程

contract 写在 design 阶段，但实现时可能发现 spec 不准 / 漏 / 冲突。**drift 是常态，关键是收口流程统一**。

### sub-agent 发现 contract drift 时

1. **立刻停下当前实现**——不许在 sub-agent 内私改 contract
2. 在 sub-report 里**标 `contract drift`**，说明：
   - 哪个 `contract_id` drift
   - 实际遇到的 inputs/outputs/error 和 spec 差异
   - sub-agent 的建议（不是结论）
3. **不继续往下推进同 contract 后续 step**

### coordinator 收到 drift 报告

1. **暂停所有依赖该 contract 的 sub-agent**——避免按旧 contract 越走越远
2. **标 contract 为 `changed`**（contract board / contracts.yaml 同步更新）
3. **决策走哪条路**：
   - 回 `cs-feat-design` 改 contract → 该 sub-agent 等新 contract 再继续
   - 当前 step 绕开 drift（contract 改动留到 follow-up）→ sub-agent 在限定边界内继续
   - 影响范围超出当前 feature → 回 `cs-roadmap update` 改架构层契约
4. **不许在 coordinator 层私改 contract**——必须走对应 skill 的 update 流程

### 硬规则

- 只有 coordinator 能决定 contract 状态翻转（`draft` → `frozen` → `changed` → `frozen`）
- sub-agent 私改 contract = 工作流违例，coordinator 必须拒收并要求重做
- `done` 状态的 contract 已被消费过——drift 时新增 follow-up item，不回退已 done

---

## 5. 汇报模板复用

### sub-agent 用 cs-feat-impl 的 6 节模板出 sub-report

sub-agent 完成任务后输出 sub-report，**直接复用** `cs-feat-impl` "实现完成汇报"6 节模板（动了哪些文件 / 改了哪些函数 / 是否触碰方案外 / 是否引入新概念 / 反射检查 / 退出信号核对）。

**额外两项必填**（独立于 6 节，放在 sub-report 顶部）：

- **agent 名**：team_name（如 `impl-csv-export` / `doc-auditor`）
- **contract_id**：sub-agent 负责的 contract（多 contract 列多条）

### coordinator 综合各 sub-report 出主汇报

coordinator 收到所有 sub-report 后，综合出**主汇报**给用户：

- 顶部列：参与的 agent + 各 agent 负责的 contract（一行一条）
- 中部：每份 sub-report 摘要（动了哪些文件 + 是否 drift）
- 底部：coordinator 自己的综合结论（合并冲突 / 范围外发现 / 下一步建议）

主汇报**只在所有 sub-agent 完成后输出一次**，停下来等用户 review。

### 不要做的事

- 主会话自己边写边发"小汇报"——汇报频率失控，用户没法验证
- sub-agent 每完成一步就汇报一次——sub-report 是任务完成后的一次性产物
- 主汇报省略 agent / contract_id 两项——丢失追溯性，drift 时不知道谁该负责
