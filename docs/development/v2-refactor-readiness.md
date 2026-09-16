# 小伴作业｜V2 重构开工门禁

> 状态：Pre-implementation Gate  
> 总跟踪：GitHub Issue #103  
> 目的：在进入 V2 产品编码前，确保 Source of Truth、任务体系、测试门禁、数据迁移、兼容策略、回滚与人工验收都已准备完成。

---

## 1. 为什么需要单独的 Readiness Gate

V2 不是一次普通样式调整，而是一次受控架构迁移：

- 前端从 `AppShell + HomeworkStore + 页面直连状态` 逐步迁移到 `Navigation/NavDestination + Session + Repository + ViewModel`；
- Assignment 从早期字段模型升级到支持结构化日期、课内/课外、资源和要求的统一模型；
- 状态流转与权威计时逐步从客户端 PATCH 收敛到服务端 Command；
- Phone / Pad 从 WindowSizeClass 直接决定业务布局，迁移到容器真实可用空间驱动的 Layout Capability；
- 旧页面会被逐个替换并清理，而不是长期双轨。

如果直接进入功能编码，最容易出现四类问题：

1. 旧 CI Gate 反向要求保留 V1 代码；
2. 本地快照升级导致用户数据丢失；
3. 新旧客户端/后端组合的兼容语义不明确；
4. 每个 Slice 使用不同设备和不同验收口径。

因此 Readiness Gate 全部通过后，才进入 Slice 1。

---

# 2. 当前已经完成

## R0｜V2 Source of Truth

状态：**完成，待 PR #102 合入 main**。

已形成：

- `AGENTS.md`
- `CONTEXT.md`
- `docs/README.md`
- `docs/product/product-feature-list-v2.md`
- `docs/architecture/frontend-technical-design-v2.md`
- `docs/architecture/backend-technical-design-v2.md`
- `docs/architecture/system-technical-design-v2.md`
- `docs/adr/0001-phone-pad-ui-composition.md`
- `docs/adr/0002-v2-clean-refactor-and-migration.md`

V0.x / V1 总体设计已经标记为 Superseded，不再作为实现依据。

## R1｜旧 Issue 清理

状态：**完成**。

以下旧任务已关闭或历史化：

- #1 V0.1 产品基线；
- #24 V0.1 UI 整改；
- #28 V0.1 后端同步；
- #30 V0.2 云端/Tutor；
- #90 旧 UI 原生化整改。

当前统一入口：#103。

## R2｜重构前代码基线

状态：**完成**。

已创建：

`archive/v1-before-v2-refactor`

基于重构前 `main` 提交：

`50765f67d8f582fbaeb2da239bc5818a8a42c86d`

用途只包括：

- 行为对照；
- diff；
- 紧急代码回退参考。

不得在该分支继续开发 V1。

---

# 3. 编码前阻塞项

## R3｜CI Gate V2 化

状态：**未完成，阻塞 Slice 1**。  
跟踪：#104。

### 已识别问题

当前部分 Gate 仍然验证旧代码形态，例如：

- `validate_responsive_navigation.py` 要求 `600/840vp` 断点必须存在；
- `validate_harmony_ui_design.py` 要求旧页面保留 `PhoneLayout / PadLayout / CompactWorkspace / PadWorkspace`；
- `validate_family_cloud_store_boundary.py` 要求远端学生列表必须通过 `HomeworkStore.instance.replaceStudents()` 应用。

这些规则会阻止正确的 V2 迁移。

### 改造原则

Gate 应优先验证：

1. 业务行为；
2. 架构边界；
3. 安全/隔离不变量；
4. 禁止反模式。

不要验证：

- 某个旧函数名必须存在；
- 某个 V1 页面必须存在；
- 某个旧布局方法必须存在；
- 某个 magic breakpoint 必须存在。

### 新增 Clean-refactor Gate

至少阻止：

- 新 V2 Feature 直接引用 `HomeworkStore.instance`；
- Feature 页面新增 `600/840/1080` 等私有业务布局断点；
- `isPreview / CI / deviceModel` 业务特判；
- AppShell 新增 Feature 特有 selectedId / returnRoute / business state；
- 新建 `ExtraHomework` 平行领域；
- 空 catch / silent fallback 用于掩盖正常业务错误。

---

## R4｜HarmonyOS Snapshot Migration

状态：**未完成，最高优先级阻塞项**。  
跟踪：#104、#113。

### 当前风险

当前本地快照：

```text
HomeworkSnapshot.schemaVersion
当前版本 = 4
```

但 `HomeworkStore.initialize()` 的行为是：

```text
schemaVersion == 当前版本
  -> restore
else
  -> seedFromMockData
  -> save
```

这意味着一旦 Assignment V2 提升 schemaVersion，而没有 migration，真实家庭本地数据可能被 MockData 覆盖。

### 必须先建设

```text
Snapshot V4
  -> migrateV4ToV5()
  -> Snapshot V5
```

后续形成逐版本 migration chain。

要求：

- 不允许 unknown/older schema 静默 reset；
- migration 失败不得覆盖原快照；
- settings / students / assignments / candidates / submissions / tutorSessions 全量保留；
- migration 必须可自动化测试；
- 新字段默认值必须有业务语义，而不是随意填空。

---

## R5｜PostgreSQL V7 Migration Plan

状态：**未完成，Slice 1 开始前必须完成设计**。  
跟踪：#113、#105。

当前 Flyway：V1–V6。

V7 预计增量增加：

- `assignment_type`
- `subject_code`
- `due_at`
- `due_timezone`
- 后续 Resource / Requirement 所需结构

原则：

1. 不修改 V1–V6；
2. 新字段优先 add -> backfill -> verify -> 后续再收紧约束；
3. 迁移窗口内保留旧字段；
4. 破坏性删除单独延后；
5. migration 后必须有数据验证 SQL / E2E；
6. 数据回滚以 DB backup + forward-fix 为主，不依赖 Flyway down migration。

---

## R6｜回归行为矩阵

状态：**未完成**。  
跟踪：#112。

### 必须保留

- Family / Student 严格隔离；
- 多孩子切换不串上下文；
- 一个学生同时最多一个 IN_PROGRESS；
- 乐观锁冲突不静默覆盖；
- 离线可以读取已有缓存；
- Candidate 不重复发布为多个 Assignment；
- Submission 图片鉴权；
- Tutor 与 studentId + assignmentId 绑定；
- AI unavailable 不阻塞普通作业；
- auth session 后端重启可恢复。

### 允许改变

- V1 页面结构；
- AppShell 业务路由；
- WindowSizeClass 直接决定 Feature 布局；
- UI 直接访问 HomeworkStore；
- `dueText` 参与真实日期查询；
- 客户端直接 PATCH status/timing；
- OVERDUE 必须持久化的旧假设。

每个 Slice 必须明确新增的“允许改变项”。

---

## R7｜API Compatibility Window

状态：**未完成**。  
跟踪：#112。

必须在 Slice 1 前明确支持矩阵：

| 客户端 | 后端 | 是否支持 |
|---|---|---|
| V1 | V1 | 历史基线 |
| V1 | V2 迁移期 | 待确认 |
| V2 | V1 | 待确认 |
| V2 | V2 | 目标 |

默认建议：

- V2 后端在短期兼容 V1 client 所需旧字段/endpoint；
- V2 client 不要求兼容旧 backend，若当前部署方式可以确保后端先升级；
- 兼容窗口必须设置删除 Slice，不允许永久存在。

最终策略以 #112 结论为准。

---

## R8｜DevEco 人工验收矩阵

状态：**未完成**。  
跟踪：#111。

固定至少：

1. Phone portrait；
2. Phone landscape；
3. Pad portrait；
4. Pad landscape；
5. Pad split / narrow window。

每个 UI Slice 至少覆盖：

- Normal；
- Empty；
- Loading；
- Error / AI unavailable；
- Offline；
- 长文本；
- 系统返回；
- 多孩子切换（家长页）；
- 键盘 / 大字号相关页面。

CI 不可以替代这一步。

---

# 4. Slice 开发流程

每个 Slice 采用统一流程：

```text
Issue / DoR
  ↓
Domain / DTO
  ↓
Migration / API
  ↓
Repository / ViewModel
  ↓
Feature UI
  ↓
Automated Test
  ↓
DevEco Acceptance
  ↓
Switch default route
  ↓
Delete old implementation
  ↓
Merge
```

禁止流程：

```text
先复制 V1 页面
  ↓
继续增加兼容 if
  ↓
V2 新页面和 V1 旧页面长期并存
  ↓
以后再清理
```

---

# 5. Definition of Ready

一个业务 Slice 开始编码前必须满足：

- [ ] 产品范围明确；
- [ ] 非目标明确；
- [ ] DTO/API 影响明确；
- [ ] DB / Snapshot migration 影响明确；
- [ ] 必须保留行为明确；
- [ ] 允许改变行为明确；
- [ ] compatibility adapter 删除条件明确；
- [ ] 旧实现删除范围明确；
- [ ] 自动化 Gate 口径明确；
- [ ] DevEco 验收场景明确。

---

# 6. Definition of Done

一个业务 Slice 完成必须同时满足：

- [ ] 新纵向链路可以独立运行；
- [ ] 自动化测试全绿；
- [ ] DevEco 指定设备矩阵验收通过；
- [ ] main 可运行；
- [ ] 不新增 V2 反模式；
- [ ] 兼容层仍存在时写明删除时间；
- [ ] 默认路由已切到 V2；
- [ ] 不再使用的 V1 页面/方法/Gate 已删除；
- [ ] 文档与实际代码一致。

---

# 7. Go / No-Go

## No-Go

以下任一存在时，不开始 Slice 1 产品编码：

- PR #102 尚未合入 Source of Truth；
- CI Gate 仍强制保留 V1 UI/Store 代码形态；
- Snapshot schema mismatch 仍会 reset 数据；
- API compatibility strategy 未确定；
- V7 migration 回填方案未确定；
- DevEco 最低验收矩阵未确认。

## Go

Readiness Gate 全部满足后，从 #105 开始 Slice 1：

> Assignment V2 + Repository 基础 + 新学生首页

此后按 #103 顺序推进，不开启平行的大重构分支。