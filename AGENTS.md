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
- 导航形态可以参考窗口尺寸；业务页面是否多栏必须根据当前容器真实可用宽度与内容最小可读宽度判断，不按设备型号硬编码。
- 涉及未成年人数据时遵循最小采集、家长授权、家庭私有优先原则。
- 微信/钉钉首版采用用户主动分享、截图识别、文本粘贴；不得依赖后台读取聊天记录。
- 后端保持 Spring Boot 模块化单体 + PostgreSQL；除非新的 ADR 明确批准，不引入 Redis、MQ、微服务、API Gateway 或工作流引擎。

## Practice content standard

任何 Agent / 开发者只要涉及以下内容之一，**必须先阅读** `docs/product/practice-question-content-standard.md`：

- 新增、删除或修改预置练习题 / 套卷；
- 修改题干、选项、答案、解析、提示语、tags、难度或题库类型；
- 修改 Practice 题库生成脚本、schema、validator；
- 修改可能影响答题、重练、练习记录、结果页或 Phone/Pad 可读性的 Practice UI。

Practice 内容维护必须遵守：

1. `backend/src/main/resources/practice/preset/` 是预置题库唯一源数据，生成的 `PresetPracticeCatalog.ets` 禁止手工编辑；
2. 已发布题目内容变化必须提升 Paper `version`，不得覆盖历史 Attempt / Result 对应版本；
3. 英语题干必须有中文引导；提示必须逐题生成并突出题干关键词，不能泄露答案；
4. 单选题必须至少 3 个有效且互不重复的选项，只能有一个明确正确答案，答案位置不得固定；
5. 教材同步题必须有明确教材/知识点依据，不能凭印象超纲；课外拓展也必须保持当前年级可理解；
6. 内容变更必须运行 `python scripts/generate_practice_catalog.py` 和 `python scripts/validate_practice_content.py`；
7. 不允许通过放宽校验、跳过 CI、测试特判或临时兼容分支绕过练习题规范。

## V2 refactor invariants

V2 是一次受控替换，不是继续修补 V1。后续任何 Agent / 开发者在修改代码前必须阅读：

- `CONTEXT.md`
- `docs/product/product-feature-list-v2.md`
- `docs/product/v2-deep-page-chrome-standard.md`
- `docs/product/v2-phone-pad-baseline-standard.md`
- `docs/architecture/frontend-technical-design-v2.md`
- `docs/architecture/backend-technical-design-v2.md`
- `docs/architecture/system-technical-design-v2.md`
- `docs/adr/0002-v2-clean-refactor-and-migration.md`

必须遵守以下规则：

1. **禁止在旧 UI 上继续堆补丁。** 已进入 V2 重构范围的页面，应通过新的页面组合 / ViewModel / Repository 实现解决根因，不新增只针对某设备、Preview、某页面或某测试用例的临时分支。
2. **禁止测试特判。** 生产代码不得根据测试数据、测试 ID、CI 环境、Preview 环境等改变业务行为；测试失败必须修业务实现或测试本身的错误假设。
3. **禁止页面私有断点。** Feature 页面不得自行硬编码 `600/840` 等设备断点来决定主从分栏；多栏必须通过统一 Layout Capability 基于真实容器空间判断。
4. **新页面不得直接依赖 `HomeworkStore.instance`。** 新 V2 Feature 通过 ViewModel / Repository 访问数据。`HomeworkStore` 只作为迁移期兼容数据源，职责只减不增。
5. **`AppShell` 职责只减不增。** 新业务路由使用 `Navigation / NavDestination`；不要再向 `AppShell` 添加业务详情状态、selectedId、返回页枚举或 Feature 特有状态。
6. **不建设第二套作业领域。** SCHOOL / EXTRA 共用 Assignment；不得新建平行的 ExtraHomework 领域模型、状态机、提交链路或同步链路。
7. **后端增量演进。** Flyway 历史 migration 不修改；通过 V7+ 增量升级数据结构。状态流转与权威计时逐步收敛到后端 Command API。
8. **兼容代码必须可删除。** 必需的迁移适配只能集中在明确的 adapter / legacy 边界，必须有明确替换对象和删除条件；不得把临时兼容散落在页面、领域模型和 Service 中。
9. **切换即清理。** 一个纵向切片切换到 V2 后，同一功能对应的旧路由、旧页面、无引用组件、旧适配分支和过时测试应在该切片或紧随其后的清理提交中删除，不长期保留 V1/V2 双实现。
10. **main 始终可运行。** 按纵向切片迁移，每个切片都必须可编译、可测试、可回退；不允许先大面积拆毁后再一次性集成。
11. **优先解决根因而非症状。** 遇到 UI / 同步 / 状态问题，先验证真实数据和调用链，再修改公共抽象；禁止连续增加 fallback、magic number、silent catch 来掩盖问题。
12. **新增抽象必须有直接用途。** 不为了“未来可能需要”建设重型框架；保持家庭级产品需要的最小复杂度。
13. **深层页面统一 page chrome。** Assignment Detail、Study Workspace、Tutor、Submission、Resource Detail、Parent Review 等二级/深层页面必须复用 `DeepPageHeader` 与 `AppTheme.DEEP_PAGE_*` token；不得在 Feature 内私有实现另一套返回 glyph、标题栏或大块顶部留白。一级 Tab / SideNav 页面不强制显示返回 Header。
14. **Phone / Pad 基础适配必须随 V2 页面一起完成。** Phone 保持紧凑可用，宽容器必须限制内容可读宽度，弹层不得无意义铺满 Pad；已迁移 Feature 不得直接消费 `WindowSizeClass` 来决定业务组合、字号或密度。需要多栏时统一使用 `LayoutPolicy` + 实际容器可用宽度。完整 Pad master-detail / split-pane 可以后续增强，但基础可读性不得延期。

## Required cleanup check before merge

涉及 V2 重构的 PR，在合并前必须检查：

- 是否新增了仅用于兼容旧页面的分支？如果是，能否直接删除旧实现而不是继续兼容？
- 是否新增 magic width / device type / Preview 特判？如果是，应改为统一能力判断。
- 是否让 `HomeworkStore` 或 `AppShell` 承担了更多职责？如果是，设计方向错误。
- 是否产生 V1/V2 两套长期并存的领域模型、API 或状态机？如果是，必须收敛。
- 已被 V2 替换的旧代码是否可以在当前 PR 一并删除？优先删除，不留“以后再清”。
- 是否存在无说明的空 `catch`、fallback 或默认值掩盖真实错误？必须消除或明确限定为 best-effort 场景。
- 如果新增或重构二级/深层页面，是否复用了 `DeepPageHeader` 和统一顶部 spacing token？如果没有，不得合并。
- 如果新增或重构 V2 页面，Phone 是否保持紧凑可用、Pad 是否限制可读宽度、弹层是否限制宽度？如果需要多栏，是否只通过 `LayoutPolicy` + 实际容器宽度判断？
