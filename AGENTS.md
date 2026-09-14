# Agent Guide

## Agent skills

### Issue tracker

本项目使用 GitHub Issues 作为需求、规格与开发任务的唯一跟踪入口。见 `docs/agents/issue-tracker.md`。

### Domain docs

本项目采用 single-context 领域文档布局：根目录 `CONTEXT.md` 维护共享语言，架构决策记录在 `docs/adr/`。见 `docs/agents/domain.md`。

### Engineering skills

项目采用 `mattpocock/skills` 的工程方法。优先使用以下流程：

1. `grill-with-docs`：新功能或关键设计前进行需求澄清，并同步项目共享语言。
2. `to-spec`：把已经讨论清楚的需求整理成可实现规格。
3. `domain-modeling`：稳定 Assignment、Resource、Submission、Textbook、Family 等领域模型。
4. `prototype`：对交互或状态设计存在不确定性时先做可丢弃原型。
5. `codebase-design`：在实现前保持模块边界清晰、接口足够小。
6. `tdd`：关键业务规则按 red-green-refactor 开发。
7. `diagnosing-bugs`：复杂缺陷先建立可重复反馈环，再修复。
8. `code-review`：提交前同时检查工程标准和规格一致性。

安装与版本约定见 `docs/agents/matt-pocock-skills.md`。

## Project constraints

- 目标平台：HarmonyOS 6.0，ArkTS + ArkUI。
- Phone 与 Pad 都是一等设备形态，禁止仅放大手机 UI 作为 Pad 适配。
- 根据当前窗口宽度做响应式布局，不按具体设备型号硬编码。
- 涉及未成年人数据时遵循最小采集、家长授权、家庭私有优先原则。
- 微信/钉钉首版采用用户主动分享、截图识别、文本粘贴；不得依赖后台读取聊天记录。
