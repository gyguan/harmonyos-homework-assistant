# 小伴作业｜文档导航

本目录同时包含当前 V2 设计、架构决策和历史实现记录。为了避免后续开发被旧文档误导，所有设计和实现工作按以下优先级读取。

## 一、当前权威文档

### 1. 项目共享事实

- `../CONTEXT.md`
  - 产品边界、共享语言、技术方向、迁移顺序、clean-refactor rules；
  - V2 数据迁移和新旧版本兼容的默认语义。

### 2. 产品基线

- `product/product-feature-list-v2.md`
  - 当前 V2 信息架构；
  - 学生 / 家长功能清单；
  - 课内 / 课外统一 Assignment；
  - 科目 / 日期 / 状态过滤；
  - Phone / Pad 产品约束；
  - P0 / P1 / P2 范围。
- `product/ui-page-spec-v2.md`
  - V2 页面级信息层级、路由、状态、Phone/Pad 组合和验收规则；
  - 学生首页、作业、详情、学习空间、Tutor、Submission；
  - 家长首页、导入三步流、Progress、Parent Review、课外任务入口；
  - Layout Capability 与 Slice 映射。

### 3. 总体技术设计

- `architecture/system-technical-design-v2.md`
  - 前后端总体架构；
  - 数据所有权；
  - API / DTO 契约；
  - 导入、学习、提交、验收、Tutor 时序；
  - 同步和纵向切片实施顺序。

### 4. 前端技术设计

- `architecture/frontend-technical-design-v2.md`
  - `Navigation / NavDestination`；
  - `Session + Repository + ViewModel`；
  - AssignmentFilter；
  - Phone 单列；
  - Pad 基于真实容器能力增强；
  - V1 → V2 迁移与 cleanup。

### 5. 后端技术设计

- `architecture/backend-technical-design-v2.md`
  - Spring Boot 模块化单体；
  - Assignment V2；
  - SCHOOL / EXTRA；
  - 结构化 dueAt；
  - Action Command；
  - Progress Query；
  - Flyway V7+。

### 6. 重构开工与迁移基线

- `development/v2-refactor-readiness.md`
  - 正式进入 V2 业务编码前必须满足的 Go / No-Go 条件；
  - CI Gate V2 化；
  - HarmonyOS Snapshot migration；
  - PostgreSQL V7 migration；
  - 回归行为矩阵；
  - API compatibility window；
  - DevEco Phone / Pad / 分屏人工验收矩阵；
  - 每个 Slice 的 Definition of Ready / Definition of Done。
- `development/v2-migration-inventory.md`
  - V1 对象的 KEEP / EVOLVE / MIGRATE / DELETE 分类；
  - 删除条件与最迟 Slice；
  - 防止 V1/V2 双实现长期共存。
- `development/v2-compatibility-and-data-migration.md`
  - V1/V2 客户端与后端兼容矩阵；
  - 兼容窗口结束 Slice；
  - 历史 Assignment 的 SCHOOL / subjectCode / dueAt 确定性迁移规则；
  - Snapshot V5+ 与 PostgreSQL V7+ 迁移、备份、验证和回滚原则；
  - OVERDUE 后续派生化的精确转换规则。

当前总跟踪 Issue：`#103`。Readiness Gate 未完成前，不进入 Slice 1 产品编码。

### 7. Accepted ADR

- `adr/0001-phone-pad-ui-composition.md`
  - 导航 size class 与业务内容布局解耦；
  - 多栏由容器能力决定。
- `adr/0002-v2-clean-refactor-and-migration.md`
  - 后端增量演进；
  - 前端平行替换；
  - 纵向切片迁移；
  - 切换即清理；
  - 禁止补丁式实现。

## 二、开发 Agent 必读

仓库根目录：

- `AGENTS.md`

其中定义 V2 实现硬约束，包括：

- 禁止继续修补旧 UI；
- 禁止 Preview / CI / 测试专用生产代码；
- 禁止 Feature 私有业务断点；
- 新 Feature 不直接依赖 `HomeworkStore.instance`；
- `AppShell` / `HomeworkStore` 职责只减不增；
- 兼容层必须有删除条件；
- Feature 切换后必须清理旧实现。

## 三、当前专项架构说明

以下文档仍然有效，但其内容必须服从 V2 总体设计与 ADR：

- `architecture/multi-child-isolation.md`
- `architecture/person-entry-role-lock.md`

## 四、历史文档

以下文件已经被 V2 替代，**不得作为当前实现依据**：

- `product/product-design-v1.md`
- `product/ui-design-v1.md`
- `product/arkui-page-spec-v1.md`
- `product/v0.1-single-family-scope.md`
- `student-assignments-v03.md`

这些文件当前只保留历史说明和 V2 跳转入口。需要查看旧版完整内容时，请通过 Git 历史读取，不要从历史设计中恢复已废弃的实现方式。

## 五、开发记录 / 历史验收

`development/` 中明确标记为 V2 Source of Truth 的文件属于当前实施基线；其余大部分文件属于具体 Issue、V0.x 阶段实现或验收记录。

历史开发记录可以帮助理解某项能力为什么存在，但不是总体设计 Source of Truth。若历史记录与 V2 技术设计、迁移基线或 Accepted ADR 冲突，以当前 V2 文档和 ADR 为准。

## 六、冲突处理顺序

当多个文档表述不一致时，按以下顺序处理：

1. 最新 Accepted ADR；
2. `CONTEXT.md`；
3. `development/v2-refactor-readiness.md`（决定是否允许开工）；
4. `development/v2-compatibility-and-data-migration.md`（决定数据与版本兼容语义）；
5. `development/v2-migration-inventory.md`（决定旧代码删除边界）；
6. V2 system technical design；
7. V2 frontend / backend technical design；
8. V2 product feature baseline + `ui-page-spec-v2.md`；
9. 当前专项架构文档；
10. development 历史记录；
11. V0.x / V1 历史设计。

如果当前实现确实需要改变 1～8 中的原则，应先更新设计 / ADR，再修改代码，不通过代码补丁绕过现行设计。
