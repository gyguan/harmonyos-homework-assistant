# 小伴作业｜文档导航

本目录同时包含当前 V2 设计、架构决策和历史实现记录。为了避免后续开发被旧文档误导，所有设计和实现工作按以下优先级读取。

## 一、当前权威文档

### 1. 项目共享事实

- `../CONTEXT.md`
  - 产品边界、共享语言、技术方向、迁移顺序、clean-refactor rules。

### 2. 产品基线

- `product/product-feature-list-v2.md`
  - 当前 V2 信息架构；
  - 学生 / 家长功能清单；
  - 课内 / 课外统一 Assignment；
  - 科目 / 日期 / 状态过滤；
  - Phone / Pad 产品约束；
  - P0 / P1 / P2 范围。

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

### 6. Accepted ADR

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

`development/` 下的大部分文件属于具体 Issue、V0.x 阶段实现或验收记录。

它们可以帮助理解某项能力为什么存在，但不是总体设计 Source of Truth。若开发记录与 V2 技术设计或 Accepted ADR 冲突，以 V2 文档和 ADR 为准。

## 六、冲突处理顺序

当多个文档表述不一致时，按以下顺序处理：

1. 最新 Accepted ADR；
2. `CONTEXT.md`；
3. V2 system technical design；
4. V2 frontend / backend technical design；
5. V2 product feature baseline；
6. 当前专项架构文档；
7. development 历史记录；
8. V0.x / V1 历史设计。

如果当前实现确实需要改变 1～5 中的原则，应先更新设计 / ADR，再修改代码，不通过代码补丁绕过现行设计。
