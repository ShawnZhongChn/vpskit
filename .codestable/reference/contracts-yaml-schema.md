# {slug}-contracts.yaml schema

由 `cs-onboard` 复制到项目 `.codestable/reference/contracts-yaml-schema.md`。**每个 feature / roadmap 一份独立 contracts.yaml**——不做全局大文档。

修改本文件走 `cs-roadmap update`（roadmap 层共享）或 `cs-onboard` 模板升级（schema 本身演化）。

---

## 1. 路径与命名

| 上下文 | 路径 |
|---|---|
| feature | `.codestable/features/{feature}/{slug}-contracts.yaml` |
| roadmap | `.codestable/roadmap/{slug}/{slug}-contract-board.md`（markdown，不用 yaml） |

> **feature 层用 yaml**（机器可读，dispatcher 直接消费）；**roadmap 层用 markdown**（人读为主，跨 feature 共享接口口径）。两层 schema 不通用。

`{feature}` = `YYYY-MM-DD-{slug}`，`{slug}` = feature 目录的 slug 段。

---

## 2. Schema

```yaml
feature: YYYY-MM-DD-{slug}             # 必填，对齐 feature 目录名
created: YYYY-MM-DD                    # 必填，contract 首次落盘日期
contracts:
  - contract_id: {string}              # 必填，feature 内唯一，kebab-case
    module: {模块名 / 文件路径 / 函数名}  # 必填，contract 归属的代码单元
    parallelizable_with: [contract_id] # 可选，列出可并行实现的兄弟 contract
    inputs:                            # 必填，至少一条
      - name: {string}
        type: str | int | bool | dict | list | <自定义类型>
        required: true | false
        default: {value}                # 可选
        description: 一句话
    outputs:                           # 必填，至少一条
      - name: {string}
        type: <类型>
        nullable: true | false
        description: 一句话
    error_semantics:                   # 必填，至少一条
      - code: {string}                  # invalid_input / not_found / drift / ...
        when: 触发条件一句话
        recovery: 调用方如何处理一句话
    ownership: {module-name}            # 必填，实现责任方（一个模块名）
    test_probe: 最小联调探针描述         # 必填，能验证 contract 真实被实现
    status: draft | frozen | changed | done  # 必填，见第 4 节状态机
    notes: {string}                     # 可选
```

---

## 3. 字段语义

| 字段 | 用途 | 写作要点 |
|---|---|---|
| `feature` | 对齐 feature 目录 | 错对齐 = contract 找不到归属 feature |
| `created` | 审计起点 | 后续修改不动这个字段 |
| `contract_id` | feature 内唯一标识 | kebab-case，描述能力（`csv-export-renderer`）不是位置（`util-1`） |
| `module` | 代码单元 | 函数 / 类 / 文件路径都可——design 阶段定到哪一级就写到哪一级 |
| `parallelizable_with` | 并行调度依据 | dispatcher 按这字段决定起几个 sub-agent；空 = 串行 |
| `inputs` / `outputs` | 接口约束 | type 用通用类型词；description 一句话讲业务含义 |
| `error_semantics` | 错误契约 | **至少一条**——"不会出错"也要写明 `code: none / when: 永远不抛 / recovery: -` |
| `ownership` | 责任锚点 | drift 时 coordinator 找谁谈 |
| `test_probe` | 最小验证 | 一句话讲怎么验"这个 contract 真被实现了"——可以是测试用例名、可观察行为、类型签名 |
| `status` | 状态机 | 见第 4 节 |
| `notes` | 例外说明 | 已知 trade-off / 待回填项 / 跨 feature 影响 |

---

## 4. 状态机

```
draft   →  frozen  ：design 阶段用户 review 通过后翻
frozen  →  changed ：implement 阶段发现 drift 且 coordinator 决定改 contract
changed →  frozen  ：design update 重新拍板后翻回
frozen  →  done    ：accept 阶段验证 test_probe 通过
```

### 硬规则

- **draft 不能并行实现**——dispatcher 拒绝起 sub-agent
- **只有 frozen 才能并行实现**——并行的硬前置
- **changed 状态期间所有依赖 sub-agent 暂停**——等回 frozen 才继续
- **done 是终态**——回退要新加一条 contract，不改 done 的
- **sub-agent 不能改 status**——只有 coordinator + design / accept 阶段能改

---

## 5. Invariants

- 每 feature 一份 contracts.yaml，**不**做全局大文档
- `contract_id` feature 内唯一；跨 feature 同名不冲突
- `inputs` / `outputs` / `error_semantics` 缺一不能 frozen
- 改已 frozen contract 走 `cs-roadmap update`（roadmap 下子 feature）或回 `cs-feat-design`（独立 feature）
- contract drift 时 sub-agent **不许私改 contract**——见 `parallel-workflow.md` 第 4 节
- yaml 必须能被 `validate-yaml.py` 校验通过

---

## 6. 最小示例

```yaml
feature: 2026-06-15-csv-export
created: 2026-06-15
contracts:
  - contract_id: csv-export-renderer
    module: src/export/csv_renderer.py
    parallelizable_with: [csv-export-handler]
    inputs:
      - name: rows
        type: list
        required: true
        description: 待导出数据，每行 dict
      - name: columns
        type: list
        required: true
        description: 列顺序，控制输出列
    outputs:
      - name: csv_string
        type: str
        nullable: false
        description: 渲染后的完整 CSV 文本
    error_semantics:
      - code: invalid_input
        when: rows 为空 / columns 缺失关键字段
        recovery: 调用方校验后重试，不重试同样入参
    ownership: export-module
    test_probe: tests/test_csv_renderer.py::test_basic_render 必须通过
    status: frozen
    notes: BOM / 编码处理放到 handler，不在 renderer 内

  - contract_id: csv-export-handler
    module: src/export/handler.py
    parallelizable_with: [csv-export-renderer]
    inputs:
      - name: request
        type: dict
        required: true
        description: HTTP 请求 dict，含 rows / columns / filename
    outputs:
      - name: response
        type: dict
        nullable: false
        description: HTTP 响应 dict，含 status / body / headers
    error_semantics:
      - code: invalid_input
        when: request 缺 rows 或 columns
        recovery: 返回 400 + error_message
      - code: render_failed
        when: renderer 抛 invalid_input
        recovery: 转 400 透传 error_message
    ownership: export-module
    test_probe: tests/test_handler.py::test_export_endpoint 必须通过
    status: frozen
```

---

## 7. 与并行工作流的衔接

- contract 是并行实现的**唯一**协调界面——sub-agent prompt 必须包含相关 contract 完整 dump
- `parallelizable_with` 决定 dispatcher 起几个 sub-agent；同组 contract 各起一个 worktree
- 详细 dispatch / drift / 汇报口径见 `.codestable/reference/parallel-workflow.md`
