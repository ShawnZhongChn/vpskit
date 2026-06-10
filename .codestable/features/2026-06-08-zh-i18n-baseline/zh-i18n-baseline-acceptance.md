---
doc_type: feature-acceptance
feature: 2026-06-08-zh-i18n-baseline
status: accepted
accepted_at: 2026-06-08
tags: [i18n, chinese, cli]
---

# zh-i18n-baseline 验收报告

## 1. 接口契约核对

- [x] `lang/zh.sh` 已新增，`bash -n lang/zh.sh` 通过。
- [x] `lang/zh.sh` 先 source `lang/en.sh` 再覆盖核心中文文案，保证变量集合完整。
- [x] `lang.sh` 默认语言改为 `zh`。
- [x] `settings.sh` 的语言切换支持 `zh/fr/en`。

## 2. 行为与决策核对

- [x] 中文优先：无配置、非交互 source `lang.sh` 时 `VPSKIT_LANG_CODE=zh`。
- [x] 保留 fallback：`lang/en.sh` 和 `lang/fr.sh` 未删除。
- [x] 不完整翻译全部变量的风险通过继承 `en.sh` 控制，缺变量不会破坏运行。
- [x] 未改业务流程，只改语言加载、语言文件和设置菜单。

## 3. 验收场景核对

- [x] `lang/zh.sh bash -n` 通过。
- [x] `zh` 变量覆盖 `en` 变量集合：`bash tests/test_i18n_zh.sh` 通过。
- [x] 默认语言为 `zh`：`bash tests/test_i18n_zh.sh` 通过。
- [x] `VPSKIT_LANG=zh bash vpskit.sh` 菜单显示中文：PTY 测试通过。
- [x] `settings.sh` 语言切换包含中文、法语、英语：代码核对通过。

## 4. 术语一致性

- [x] 语言代码统一为 `zh`。
- [x] 中文语言文件路径统一为 `lang/zh.sh`。

## 5. 架构归并

- [x] [ARCHITECTURE.md](/Users/shawn/Documents/Personal/Project/vpskit/.codestable/architecture/ARCHITECTURE.md) 已记录默认语言为中文，英文和法语保留 fallback。
- [x] [ARCHITECTURE.md](/Users/shawn/Documents/Personal/Project/vpskit/.codestable/architecture/ARCHITECTURE.md) 已记录 `lang/zh.sh` 的继承覆盖策略。

## 6. requirement 回写

- [x] 本 feature 从 roadmap 起头，未关联独立 requirement；无 requirement 回写。

## 7. roadmap 回写

- [x] [vpskit-stability-zh-hardening-items.yaml](/Users/shawn/Documents/Personal/Project/vpskit/.codestable/roadmap/vpskit-stability-zh-hardening/vpskit-stability-zh-hardening-items.yaml)：`zh-i18n-baseline` 已改为 `done`。
- [x] [vpskit-stability-zh-hardening-roadmap.md](/Users/shawn/Documents/Personal/Project/vpskit/.codestable/roadmap/vpskit-stability-zh-hardening/vpskit-stability-zh-hardening-roadmap.md)：子 feature 清单已同步。

## 8. attention.md 候选盘点

- 候选：本项目默认语言为中文；新增或修改用户可见文案时优先维护 `lang/zh.sh`，同时保持 en/fr fallback。

## 9. 遗留

- `lang/zh.sh` 目前完整覆盖变量集合，但只有核心用户路径是人工中文文案；其余变量继承英文，后续可逐步补全。
- 远端脚本的所有 `RMSG_` 尚未完整人工中文化，后续 setup/deploy 加固与部署优化时继续补。
