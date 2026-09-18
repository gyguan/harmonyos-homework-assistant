# 小伴作业｜V1 → V2 代码迁移与删除清单

> 状态：Implementation Inventory  
> 总跟踪：#103  
> 目的：明确 V1 代码在 V2 重构中的去向和删除条件，避免长期保留双实现、兼容补丁和无主代码。

---

## 1. 总原则

每个旧对象只能有四种结局：

1. **KEEP**：方向正确，继续使用；
2. **EVOLVE**：原地增量演进，不创建平行 V2 实现；
3. **MIGRATE**：短期作为 legacy adapter，被新架构替代后删除；
4. **DELETE**：V2 不再需要，所在 Slice 切换后直接删除。

禁止：

- `OldXxx + NewXxx/V2Xxx` 长期并存；
- “先留着以后再删”但没有删除条件；
- 为维持旧 Gate 而保留无业务调用代码；
- 旧页面和新页面长期双路由；
- `Assignment` / `AssignmentV2` 两套后端领域并存。

---

# 2. App / Navigation

| 当前对象 | V2 处理 | 目标 | 删除条件 | 最迟 Slice |
|---|---|---|---|---|
| `pages/AppShell.ets` | EVOLVE | 只保留角色、一级导航、App 级容器 | 所有 Feature 详情改用 Navigation/NavDestination 后移除业务 route state | Final Cleanup |
| `StudentRoute` | DELETE | Navigation route | 学生详情/学习/提交全部切换到 NavDestination | Slice 3 |
| `ParentRoute` | DELETE | Navigation route | Parent Review / Import flow 切换完成 | Slice 5 |
| `selectedAssignmentId` | DELETE | route param / ViewModel context | Assignment Detail/Study route 可携带 assignmentId | Slice 3 |
| `studentStudyReturnRoute` | DELETE | Navigation stack | Study/Tutor/Submission 返回链稳定 | Slice 3 |
| `parentRoute=CONFIRMATION` 等条件渲染 | DELETE | NavDestination | 导入三步流切换 | Slice 5 |
| `DemoScenario` 业务 Shell 状态 | MIGRATE | 测试/Preview fixture 边界 | V2 页面有可控 ViewModel state fixture | Slice 4 |

原则：`AppShell` 的字段数量与业务职责只减不增。

---

# 3. Responsive / Layout

| 当前对象 | V2 处理 | 目标 | 删除条件 | 最迟 Slice |
|---|---|---|---|---|
| `common/responsive/WindowSizeClass.ets` | EVOLVE | 只服务 Shell 级导航能力 | Feature 不再读取 sizeClass 决定业务多栏 | Slice 6 |
| `ResponsiveContext.resolveContent()` | MIGRATE | `LayoutCapability / LayoutPolicy` | 所有 V2 多栏改为容器可用宽度 + pane min width | Slice 6 |
| Feature `sizeClass: WindowSizeClass` Prop | DELETE | page/container capability | 对应页面切换到 V2 | 各 Slice |
| `PhoneLayout/PadLayout` 固定方法对 | DELETE | 单页面结构 + 可选组合 pane | 对应 Feature V2 切换 | 各 Slice |

允许窗口级导航策略存在，但禁止 WindowSizeClass 继续成为业务布局 API。

---

# 4. Local Data / Store

| 当前对象 | V2 处理 | 目标 | 删除条件 | 最迟 Slice |
|---|---|---|---|---|
| `data/HomeworkStore.ets` | MIGRATE | 仅保留迁移期 persistence / legacy adapter 数据源 | V2 Feature/Repository 已不直接调用 Store；继续拆除各 adapter 后删除 | Final Cleanup |
| `HomeworkStore` settings/student context | MIGRATE | `Session / StudentContext` | RoleShell/Repository 接管上下文 | Slice 4 |
| `HomeworkStore` assignment query | MIGRATE（边界完成） | `AssignmentRepository` + `AssignmentLocalDataSource` | Repository 不再直接调用 Store；待 legacy local adapter 删除 | Final Cleanup |
| `HomeworkStore` assignment transition/timer | MIGRATE（仅 demo 兼容） | backend Action Command + `AssignmentLocalDataSource` seed/demo adapter | 真实作业已走服务端 Command；移除 demo Store transition 后删除 | Final Cleanup |
| `HomeworkStore` candidate/import | MIGRATE | Import Repository/ViewModel | Import 三步流切换 | Slice 5 |
| `HomeworkStore` submission/tutor cache | MIGRATE | Submission/Tutor repository | Slice 3 闭环完成 | Slice 3/Final |
| `data/MockData.ets` | EVOLVE | 仅测试/fixture/demo seed | 不再作为 schema mismatch 恢复策略 | Slice 0 |

### 强约束

`HomeworkStore.initialize()` 当前 schema 不匹配时 seed MockData 的行为必须在 Slice 0 删除。

---

# 5. Persistence

| 当前对象 | V2 处理 | 目标 | 删除条件 | 最迟 Slice |
|---|---|---|---|---|
| `domain/model/PersistenceModels.ets` | EVOLVE | versioned snapshot DTO | 始终保留 schemaVersion | KEEP |
| `domain/port/HomeworkPersistence.ets` | KEEP | 本地快照端口 | 无 | KEEP |
| Preferences persistence adapter | KEEP/EVOLVE | Snapshot storage | migration framework 接入 | Slice 0 |
| `SNAPSHOT_SCHEMA_VERSION = 4` | EVOLVE | explicit migrator chain | migration tests 完成 | Slice 0 |

V2 不通过“默认值兼容”替代显式 snapshot migration。

---

# 6. Remote / Repository

| 当前对象 | V2 处理 | 目标 | 删除条件 | 最迟 Slice |
|---|---|---|---|---|
| `BackendHttpClient.ets` | KEEP | 通用 HTTP transport | 无 | KEEP |
| `BackendSession.ets` | KEEP/EVOLVE | auth/session 基础 | 无 | KEEP |
| `BackendAuthService.ets` | KEEP | auth service | 无 | KEEP |
| `HomeworkRemoteApi.ets` | MIGRATE | `AssignmentRemoteDataSource` | Repository 完整接管并旧 API wrapper 无调用 | Slice 3/Final |
| `HomeworkSyncService.ets` | DELETE（已完成） | sync/reconcile 已收敛到 `DefaultAssignmentRepository` | Repository 已接管跨设备刷新、冲突处理与后台合并同步 | Final Cleanup |
| `RemoteModels.ets` | MIGRATE | domain-specific DTO mapper | 新 DTO/mapper 分层稳定 | Slice 3 |
| `FamilyCloudService.ets` | MIGRATE | Student/Family repository | 家长/学生上下文迁移完 | Slice 4 |
| `StudentRemoteApi.ets` | KEEP/EVOLVE | StudentRemoteDataSource | 可原地重命名/移动，不建平行实现 | Slice 4 |
| `RemoteSubmissionApi.ets` | KEEP/EVOLVE | SubmissionRemoteDataSource | Slice 3 repository 接管 | Slice 3 |
| `RemoteSubmissionCache.ets` | MIGRATE | SubmissionRepository local cache | Progress/Review 不再直接依赖 | Slice 4 |
| `HomeworkOrganizerRemoteApi.ets` | KEEP/EVOLVE | OrganizerRemoteDataSource | Import Slice 重构时收敛 | Slice 5 |

原则：先以 adapter 包装现有 Remote API；调用者迁完后移动/重命名，不复制出两套 HTTP 实现。

---

# 7. Student Feature

| 当前页面 | V2 去向 | 删除条件 | Slice |
|---|---|---|---|
| `features/student/today/StudentTodayPage.ets` | 新 `home/StudentHomePage.ets` | 首页默认路由切换且离线/远端均通过 | Slice 1 |
| `features/student/assignments/StudentAssignmentsPage.ets` | `assignments/AssignmentListPage.ets` | Filter/List/Detail 入口切换 | Slice 2 |
| 缺失的独立 Assignment Detail | 新建 `assignment/AssignmentDetailPage.ets` | N/A | Slice 2/3 |
| `features/student/study/StudyWorkspacePage.ets` | 重构为最终 Study Workspace | 新 Navigation + Repository + Command 闭环完成 | Slice 3 |
| Tutor UI（现有 Study 内实现） | 独立 Tutor destination / Pad pane | Phone 独立路由与 Pad pane 共用 ViewModel | Slice 3 |
| Submission UI（现有 Study 内流程） | 独立 Submission destination | 提交闭环完成 | Slice 3 |
| `features/student/profile/StudentProfilePage.ets` | KEEP/EVOLVE | 按 V2 一级导航调整 | Slice 6/Final |
| 新“学习”一级页 | 新建 `features/student/learning/StudentLearningPage.ets` | N/A | Slice 6 |

新文件使用最终业务命名，不命名为 `StudentHomePageV2`。

---

# 8. Parent Feature

| 当前页面 | V2 去向 | 删除条件 | Slice |
|---|---|---|---|
| `parent/dashboard/ParentDashboardPage.ets` | `parent/home/ParentHomePage.ets` | 家长首页默认路由切换 | Slice 4 |
| `parent/progress/ParentProgressPage.ets` | `parent/progress/ParentProgressPage.ets` 重构 | Repository + Review destination 完成 | Slice 4 |
| 当前 Progress 内验收逻辑 | 独立 `ParentReviewPage.ets` / Pad pane | 验收路由切换 | Slice 4 |
| `parent/import/HomeworkImportPage.ets` | Import Step 1 / Import flow | 三步流切换 | Slice 5 |
| `parent/confirmation/HomeworkConfirmationPage.ets` | Import Step 2/3 destination | Batch publish 完成 | Slice 5 |
| `parent/settings/BackendConnectionPage.ets` | KEEP/EVOLVE | 后续整合到 Parent My | Final Cleanup |
| 课外任务创建页 | 新建，复用 Assignment | N/A | Slice 6 |

---

# 9. Shared Components

| 当前对象 | 处理 |
|---|---|
| `AppTheme.ets` | KEEP/EVOLVE，继续作为视觉 token Source of Truth |
| `AssignmentCard.ets` | REVIEW：若 V2 多页面真正复用则演进，否则删除 |
| `AssignmentListItem.ets` | KEEP/EVOLVE 为统一可访问列表项 |
| `PageStateView.ets` | KEEP/EVOLVE，支持 Loading/Empty/Error/Offline |
| 只服务旧 Pad/Phone 固定布局的组件 | 对应 Slice 切换即 DELETE |

原则：共享组件必须有至少两个真实调用场景，不为“以后可能用”建设抽象。

---

# 10. Backend

后端采用 **原地增量演进**，不建立 `v2` package。

| 当前对象 | V2 处理 |
|---|---|
| `AssignmentEntity` | EVOLVE：增加 assignmentType / subjectCode / dueAt / timezone 等 |
| `AssignmentDtos` | EVOLVE：additive DTO + compatibility default |
| `AssignmentController` | EVOLVE：保留迁移期旧 CRUD，新增 query/action endpoints |
| `AssignmentService` | EVOLVE：状态机/计时权威进一步收敛 |
| `AssignmentRepository` | EVOLVE：增加 filter/query |
| Submission module | KEEP/EVOLVE |
| Tutor module | KEEP/EVOLVE |
| Student/Auth/Family | KEEP/EVOLVE |
| Flyway V1–V6 | KEEP，永不修改 |
| Flyway V7+ | 新增 migration，不建第二套 schema |

### 旧 API 删除

旧 `PUT /assignments/{id}` 在兼容窗口内保留；删除时间由 #112 确定，至少在 Slice 3 新 Action Command 全量切换之后。

---

# 11. CI / Validator

| 当前 Gate | V2 处理 | Slice |
|---|---|---|
| `validate_responsive_navigation.py` | 重写：不再要求 600/840 必须存在于业务实现 | Slice 0 |
| `validate_harmony_ui_design.py` | 重写：不再要求旧 PhoneLayout/PadLayout 方法名 | Slice 0 + 各 Feature Slice |
| `validate_family_cloud_store_boundary.py` | 重写：允许 Repository 接管 Store 边界 | Slice 0 |
| Assignment countdown / single task timer | 保留业务行为，后续改为验证 Command 结果 | Slice 3 |
| parent review / submission / tutor Gate | 保留业务行为，不绑定旧页面文件名 | Slice 3/4 |
| V0.1/V0.2 backend gate | 逐步重命名为稳定能力 gate，不以版本号描述长期架构 | Final Cleanup |
| backend real E2E | KEEP，扩展 V7 migration / actions / filters | Slice 1–3 |

新 Gate 应验证不变量，不验证旧实现形态。

---

# 12. Development 文档

V0.x / Issue-specific development 文档继续作为历史记录，不参与当前总体架构决策。

当代码切换完成时：

- 不要求删除历史记录；
- 但不得继续从历史文档生成新实现；
- 当前行为变化需更新 `CONTEXT / V2 design / ADR / readiness` 中对应内容。

---

# 13. 每个 Slice 的 Cleanup Checklist

合并前逐项确认：

- [ ] 默认路由已经切到 V2；
- [ ] 旧页面是否仍有真实调用者；没有则删除；
- [ ] 旧 Store 方法是否仍有真实调用者；没有则删除；
- [ ] adapter 是否达到删除条件；达到则删除；
- [ ] static Gate 是否还引用被删除文件/方法；同步更新；
- [ ] import 是否残留无引用；
- [ ] 是否新增 `V2/New/Legacy` 临时命名并准备长期保留；如是，重命名；
- [ ] 是否存在 silent fallback / magic width / preview special case；如是，清理；
- [ ] 文档是否仍描述已删除旧结构；同步更新。

---

# 14. 完成状态

当以下条件全部满足，V2 migration inventory 才可关闭：

1. AppShell 不再承担业务详情路由；
2. Feature 不直接访问 HomeworkStore；
3. HomeworkStore 只剩必要 legacy/persistence 能力或已完全拆除；
4. Feature 多栏不依赖 WindowSizeClass；
5. 旧 Student/Parent V1 页面均被替换并删除；
6. 旧 assignment PATCH/timing 流程已退出；
7. 所有 migration adapter 已删除；
8. CI 不再验证 V1 文件/函数形态；
9. V0.x 历史文档仅作为历史存在；
10. main 中只有一套现行产品实现。