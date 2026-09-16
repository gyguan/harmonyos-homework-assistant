# 小伴作业｜ArkUI 页面规格 V1（历史文档）

- Status: **Superseded by V2 frontend technical design**
- Superseded: 2026-09-16

> 本文不再作为 ArkUI 页面实现规格。旧版页面树、WindowSizeClass 断点、Medium/Expanded 分栏规则与 AppShell 职责仅用于历史回溯。

## 已被替代的关键设计

V1 曾采用：

- `AppShell` 集中维护角色、业务路由、selectedId、返回路径和窗口尺寸；
- `WindowSizeClass` 的 COMPACT / MEDIUM / EXPANDED 直接决定业务页面单栏 / 双栏 / 三栏；
- `StudentTodayPage`、`StudyWorkspacePage`、`HomeworkImportPage` 等根据固定断点切换主从结构；
- 页面较多直接依赖全局 Store 和手工 revision 刷新。

这些不再是 V2 目标架构。

## V2 页面实现原则

当前实现应遵循：

```text
AppRoot / RoleShell
        ↓
Navigation / NavDestination
        ↓
Feature Page
        ↓
ViewModel
        ↓
Query / Command Service
        ↓
Repository
```

并满足：

1. `AppShell` / Shell 只负责角色、一级导航和应用级容器，职责只减不增；
2. 详情和深层流程使用 `Navigation / NavDestination`；
3. 新 Feature 不直接访问 `HomeworkStore.instance`；
4. Phone 核心流程保持单列；
5. Feature 页面不自行定义 600 / 840 / 1080 等业务布局断点；
6. 多栏通过统一 Layout Capability，依据当前容器真实可用宽度和 pane 最小可读宽度判断；
7. Pad 多栏是增强组合，空间不足时必须退回单页导航；
8. UI 本地状态、领域状态、同步状态分别归属 ViewModel / Domain / Repository，不混入一个全局枚举。

## 当前权威规格

请使用：

- `docs/architecture/frontend-technical-design-v2.md`
- `docs/architecture/system-technical-design-v2.md`
- `docs/product/product-feature-list-v2.md`
- `docs/adr/0001-phone-pad-ui-composition.md`
- `docs/adr/0002-v2-clean-refactor-and-migration.md`

如果代码需要违背这些原则，应先更新 ADR，而不是恢复本 V1 页面规格中的旧结构。
