# 小伴作业｜ArkUI 页面规格 V1

> 本文将 `product-design-v1.md` 与 `ui-design-v1.md` 转换为可进入 HarmonyOS 6.0 开发的页面、组件与状态规格。

## 1. 推荐工程结构

```text
entry/src/main/ets/
├─ entryability/
│  └─ EntryAbility.ets
├─ pages/
│  └─ AppShell.ets
├─ features/
│  ├─ student/
│  │  ├─ today/
│  │  ├─ assignment/
│  │  ├─ study/
│  │  ├─ tutor/
│  │  └─ submission/
│  ├─ parent/
│  │  ├─ dashboard/
│  │  ├─ import/
│  │  ├─ confirmation/
│  │  ├─ progress/
│  │  └─ submission/
│  ├─ textbook/
│  └─ family/
├─ components/
│  ├─ navigation/
│  ├─ assignment/
│  ├─ tutor/
│  ├─ resource/
│  ├─ submission/
│  └─ state/
├─ domain/
│  ├─ model/
│  ├─ enums/
│  └─ repository/
├─ services/
│  ├─ api/
│  ├─ media/
│  └─ ai/
└─ common/
   ├─ theme/
   ├─ responsive/
   └─ util/
```

原则：页面只组合业务组件，复杂规则进入 domain / service，不把状态机散落在 UI 中。

## 2. AppShell

职责：

- 根据当前角色加载 StudentShell / ParentShell；
- 统一处理 Phone / Pad 导航形态；
- 提供顶层 `NavPathStack`；
- 提供全局 Family / Student 上下文；
- 提供窗口宽度断点状态。

建议组件树：

```text
AppShell
└─ Navigation
   ├─ CompactNavigation (Phone bottom tabs)
   └─ ExpandedNavigation (Pad side rail)
```

`Navigation` 建议使用自适应 / 分栏模式；Pad 主从页面可使用 Navigation Split；具体内容区域再根据剩余容器宽度切换布局。

## 3. 响应式基础设施

定义统一枚举：

```text
WindowSizeClass
- COMPACT   <= 600vp
- MEDIUM    600–840vp
- EXPANDED  > 840vp
```

禁止各页面自行定义不同断点。

建议封装：

```text
ResponsiveContext
- widthVp
- heightVp
- sizeClass
- isLandscape
```

复杂主从页面优先组合：

- `Navigation`
- `GridRow / GridCol`
- `ContainerReader`
- `SplitLayout`
- `Row / Column / List / Scroll`

不要通过设备型号判断 Phone / Pad。

# 4. 学生端页面规格

## S01 StudentTodayPage

Route：`student/today`

### 业务输入

- TodaySummary
- AssignmentSummary[]
- NextAssignment

### 页面组件

```text
StudentTodayPage
├─ TodayHeader
├─ TodayProgressCard
├─ NextAssignmentCard
├─ TodayAssignmentList
│  └─ AssignmentListItem × N
└─ TodayCompletionBanner
```

### Compact

单列：NextAssignment 为第一视觉焦点。

### Expanded

```text
Row
├─ AssignmentListPane  38%
└─ AssignmentPreviewPane 62%
```

点击列表仅刷新右侧预览，不跳页；点击“开始/继续”进入 Study Workspace。

### 状态

- loading
- noAssignments
- active
- allCompleted
- partiallyOffline

## S02 AssignmentDetailPage

Route：`student/assignment/:id`

组件：

```text
AssignmentDetailPage
├─ AssignmentHeader
├─ TeacherInstructionCard
├─ TextbookReferenceCard
├─ ResourceList
├─ DueTimeInfo
└─ PrimaryActionBar
```

主按钮：`开始作业 / 继续完成`

## S03 StudyWorkspacePage

Route：`student/study/:assignmentId`

这是首版最重要页面。

### Compact

```text
Column
├─ StudyHeader
├─ CurrentAssignmentPanel
├─ ResourceTabs
├─ TutorEntryCard
└─ StickyActionBar
```

AI Tutor 在 Phone 上进入独立页面或底部 Sheet，避免同时挤压作业内容。

### Medium

两栏：

```text
Row
├─ AssignmentAndResourcePane 65%
└─ TutorPane 35%
```

### Expanded

三栏：

```text
Row
├─ TodayTaskRail       20%
├─ StudyContentPane    50%
└─ TutorPane           30%
```

### StudyContentPane

- 老师要求
- 图片 / PDF / 视频 / 音频
- 教材关联
- 当前提交草稿

### TutorPane

- 当前 TutorSession
- 文字消息
- HintLevel
- 拍题 / 语音入口
- “我懂了”结束辅导

### 关键规则

- 切换任务前保存当前 SubmissionDraft。
- TutorSession 与 assignmentId 强绑定。
- AI 不可用时 Study Workspace 必须仍能完成作业与提交。

## S04 TutorPage

Route：`student/tutor/:assignmentId`

Phone 独立页；Pad 为 StudyWorkspace 子区域。

```text
TutorConversation
├─ TutorContextHeader
├─ MessageList
├─ HintLevelIndicator
├─ SuggestionChips
└─ TutorComposer
   ├─ TextInput
   ├─ VoiceAction
   └─ CameraAction
```

Tutor 状态：

- idle
- understanding
- responding
- needsClarification
- unavailable
- ended

## S05 SubmissionPage

Route：`student/submission/:assignmentId`

```text
SubmissionPage
├─ CaptureInstruction
├─ CapturedPageGrid
│  └─ CapturedPageCard × N
├─ SubmissionChecklist
└─ SubmitActionBar
```

照片状态：

- capturing
- processing
- clear
- blurry
- failed

# 5. 家长端页面规格

## P01 ParentDashboardPage

Route：`parent/dashboard`

Compact：

```text
Column
├─ ProgressHero
├─ StatusKpiGrid (2 cols)
├─ AssignmentProgressList
└─ AttentionSection
```

Expanded：

```text
Column
├─ KPI Row
└─ Row
   ├─ AssignmentProgressList 65%
   └─ WeeklySummary / Attention 35%
```

## P02 HomeworkImportPage

Route：`parent/import`

输入方式组件：

- ShareImportCard
- ScreenshotImportCard
- TextPasteImportCard
- FileImportCard
- ManualCreateCard

Compact：输入后进入解析结果页。

Expanded：

```text
Row
├─ SourceInputPane       45%
└─ CandidatePreviewPane  55%
```

解析状态：

- idle
- uploading
- extracting
- parsing
- ready
- partial
- failed

## P03 HomeworkConfirmationPage

Route：`parent/confirmation/:importId`

```text
HomeworkConfirmationPage
├─ SourceEvidencePane
└─ CandidateAssignmentPane
   ├─ CandidateAssignmentCard × N
   └─ PublishActionBar
```

每个 CandidateAssignmentCard：

- subject
- title
- instruction
- dueAt
- textbookReference
- sourceEvidence
- confidenceFlag
- edit / split / merge / delete

### Expanded

原文与候选结果并排，选中 Candidate 时左侧 Source Evidence 自动高亮对应片段。

## P04 ParentProgressPage

Route：`parent/progress`

```text
ParentProgressPage
├─ DateSelector
├─ ProgressOverview
├─ AssignmentTimeline
└─ AttentionList
```

AssignmentTimeline 展示：

- notStarted
- inProgress
- submitted
- completed
- overdue

避免把 Tutor 使用时长设计成家长考核孩子的指标；只在“需要介入”时提供必要提示。

## P05 ParentSubmissionViewerPage

Route：`parent/submission/:submissionId`

- 图片浏览
- 录音 / 视频播放（后续）
- 提交时间
- Assignment 摘要

V0.1 不提供家长打分体系。

# 6. 共享组件

## AssignmentCard

Variants：

- compact
- list
- preview
- progress

禁止每个页面复制一套作业卡。

## SubjectBadge

只表达学科，不表达完成状态。

## StatusBadge

统一状态：

- 未开始
- 进行中
- 已提交
- 已完成
- 已超时

## SourceEvidenceView

输入：

- sourceType
- sourceResourceId
- originalText
- range / page / timestamp

目标：任何 AI 生成的 Candidate Assignment 都可回溯来源。

## ResourceViewer

根据资源类型分派：

- ImageResourceView
- DocumentResourceView
- AudioResourceView
- VideoResourceView

## EmptyState / LoadingState / ErrorState

作为共享基础组件统一表现。

# 7. 导航与返回规则

- `Today -> Assignment Detail -> Study Workspace -> Submission` 为学生主链。
- Study Workspace 内打开 Tutor 不应破坏当前作业上下文。
- 家长 Import -> Confirmation -> Publish 完成后返回 Dashboard，并显示发布成功反馈。
- Pad 主从模式下，右侧详情切换不产生过深导航栈。

# 8. UI 状态与领域状态分离

例如 Assignment 领域状态：

```text
NOT_STARTED
IN_PROGRESS
SUBMITTED
COMPLETED
OVERDUE
```

页面本地 UI 状态：

```text
isLoading
selectedAssignmentId
isTutorPaneOpen
isSubmitDialogVisible
```

二者禁止混为一个枚举。

# 9. 首版 Mock 数据要求

正式接 API 前，必须构造至少以下数据：

- 3 个今日作业：完成 / 进行中 / 未开始各 1 个
- 1 个超时作业
- 1 个包含视频 + PDF 的作业
- 1 个 Candidate Assignment 低置信案例
- 1 个聊天截图解析成 3 项作业的案例
- 1 个 AI Tutor 不可用案例
- 1 个离线情况下仍可查看已缓存作业的案例

保证 UI 不是只在 Happy Path 下成立。

# 10. 开发完成定义

一个页面只有同时满足以下条件才算完成：

1. Compact / Medium / Expanded 三档可用；
2. Loading / Empty / Error 状态具备；
3. 主交互可用；
4. 不因软键盘、横竖屏切换破坏布局；
5. 可通过 Mock 数据稳定复现；
6. 关键领域规则有测试；
7. 与 `ui-design-v1.md` 一致。
