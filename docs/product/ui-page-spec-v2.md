# 小伴作业｜UI Page Spec V2

> 状态：Implementation Baseline  
> 适用范围：HarmonyOS Phone / Pad  
> 产品基线：`product-feature-list-v2.md`  
> 前端技术设计：`../architecture/frontend-technical-design-v2.md`

---

# 1. 总体设计原则

## 1.1 学生端

目标：**孩子少管理、多行动。**

- 首页 3 秒内知道下一项作业；
- 一个页面只突出一个主动作；
- Phone 核心流程单列；
- AI 小伴融入学习流程，不占据首页；
- 不做排行榜、积分商城或高刺激游戏化；
- 学科色仅用于辅助识别。

## 1.2 家长端

目标：**家长少操作、多掌握。**

- 首页优先展示异常、待验收和导入入口；
- 不做重型管理驾驶舱；
- 导入流程按“原文 → AI 整理 → 确认发布”推进；
- Progress 聚焦状态、提交证据和是否需要家长介入。

## 1.3 Phone / Pad

- Phone 不使用固定主从左右分栏；
- 列表点击进入独立详情页；
- Pad 不是放大的 Phone；
- 多栏只在当前容器可同时满足各 pane 最小可读宽度时启用；
- 分屏 / 窄窗自动降级；
- Feature 页面不得用设备型号或 600/840/1080 等私有断点决定业务布局。

## 1.4 页面通用状态

每个页面至少考虑：

- Loading；
- Empty；
- Normal；
- Error；
- Offline / Cached；
- 长标题 / 长老师要求；
- 大字号；
- 系统返回。

涉及输入的页面额外验证软键盘不遮挡主操作。

---

# 2. 导航

## 2.1 学生端一级导航

1. 首页
2. 作业
3. 学习
4. 我的

Phone：底部导航。  
Pad：Shell 有足够空间时可使用侧边导航。

业务详情统一使用 `Navigation / NavDestination`，不把 selectedId / returnRoute 等业务状态放回 AppShell。

## 2.2 家长端一级导航

1. 首页
2. 导入
3. 进度
4. 我的

家长切换孩子属于 Shell 级上下文动作；Feature 页面只消费当前 `studentId`。

---

# 3. 学生端页面

## S01｜学生首页 Student Home

对应特性：S01-01 ～ S01-08。

### 页面目标

> 我现在应该做什么？

### 信息优先级

1. 当前学生 / 日期；
2. 今日完成度；
3. 下一项作业；
4. 逾期 / 待订正提醒；
5. 今日剩余作业；
6. 快捷入口。

### Phone 结构

```text
Page
├─ Header
│  ├─ 学生姓名 / 年级
│  └─ 日期
├─ TodayProgress
├─ AttentionBanner?          # 有异常才显示
├─ NextAssignmentHero        # 第一视觉焦点
│  ├─ 学科
│  ├─ 标题
│  ├─ 截止时间 / 预计用时
│  └─ [开始 / 继续]
├─ RemainingAssignments
└─ QuickActions              # P1
```

### 交互

- 点击 Hero 主按钮进入 Assignment Detail 或直接进入 Study Workspace；
- 点击其他作业进入 Assignment Detail；
- 不在首页直接展开完整 AI 对话；
- 已完成任务弱化显示。

### Pad 增强

Pad 可在空间充足时增加右侧“今天剩余任务/提醒摘要”，但首页核心 Hero 不被压缩。

如果组合后的任一 pane 不满足最小可读宽度，则退回单列。

### Empty

```text
今天没有待完成作业
[查看全部作业]
```

避免大面积空白或复杂统计。

---

## S02｜作业列表 Assignment List

对应特性：S02-01 ～ S02-08。

### 页面目标

> 我有哪些作业？怎么快速找到？

### Phone 顶部

```text
[日期快捷选择]              [筛选]
[全部] [语文] [数学] [英语] ...   # 横向滚动 Chip
```

复杂条件进入底部筛选面板：

- 类型：全部 / 课内 / 课外；
- 日期：今天 / 明天 / 本周 / 自定义；
- 状态；
- 科目。

### 列表项

每个 Assignment List Item 至少展示：

- 科目 / 分类；
- 标题；
- 截止时间；
- 预计用时；
- 状态；
- 课内 / 课外标识（必要时）。

整个列表行为可点击，进入独立详情页。

### 排序

建议默认：

1. NEEDS_REWORK / overdue；
2. IN_PROGRESS / PAUSED；
3. 当天截止；
4. 明天截止；
5. 其他未完成；
6. 已提交 / 已完成。

### Pad 增强

空间足够时：

```text
筛选 / 作业列表 | 作业详情
```

列表 pane 与详情 pane 必须各自满足最小可读宽度；否则保持 Phone 式列表 → 详情跳转。

---

## S03｜作业详情 Assignment Detail

对应特性：S03-01 ～ S03-08。

### 信息顺序

```text
科目 / 类型
标题
截止时间 · 预计用时
老师要求
完成要求
教材 / 页码
老师资料

[开始作业 / 继续完成]
[问小伴]
```

### 主动作

- NOT_STARTED：开始作业；
- IN_PROGRESS / PAUSED：继续完成；
- NEEDS_REWORK：继续订正；
- READY_TO_SUBMIT：去提交；
- SUBMITTED：查看提交状态；
- COMPLETED：只读回顾。

### Phone

全页单列；底部主操作保持稳定。

### Pad

可由 Assignment List 作为右侧详情 pane 复用，不建立 Pad 专用业务模型。

---

## S04｜学习空间 Study Workspace

对应特性：S04-01 ～ S04-07。

### 页面目标

> 专注完成当前这一项作业。

### Phone

```text
TopBar: 返回 | 科目 / 标题

CurrentTaskSummary
TeacherInstruction
ResourceSection
TextbookReference
Timer / Progress

AskTutorEntry

StickyBottomAction
  [完成并提交]
```

规则：

- 永远单任务；
- AI 小伴进入独立页面 / 全屏子表面 / 抽屉，不固定并排；
- 不把“今日任务列表”常驻在 Phone 学习页；
- AI unavailable 时仍可查看资料和提交。

### Pad 增强 A

空间足够时：

```text
学习内容 | AI 小伴
```

### Pad 增强 B

只有在三块内容都满足最小宽度时：

```text
今日任务 | 当前学习内容 | AI 小伴
```

禁止为了形成三栏压缩正文或 Tutor。

### 系统返回

- 从 Tutor 返回保持当前 Assignment；
- 从 Submission 返回保持当前 Assignment；
- 返回 Assignment Detail 或原入口由 Navigation stack 决定，不使用 AppShell returnRoute enum。

---

## S05｜AI 小伴 Tutor

对应特性：S05-01 ～ S05-07。

### 上下文头部

- 当前科目；
- 当前 Assignment；
- 可选教材 / 老师资料上下文提示。

### 对话区

```text
TutorContextHeader
MessageList
SuggestionChips?
Composer
  ├─ TextInput
  ├─ 拍题
  └─ 语音(P2)
```

### 辅导层级

1. 理解卡点；
2. 轻提示；
3. 下一步提示；
4. 分步讲解；
5. 完整解释；
6. 检查理解。

### 降级

AI unavailable：

```text
小伴暂时不可用
你仍然可以继续完成和提交作业
```

不让错误覆盖学习内容。

---

## S06｜提交 Submission

对应特性：S06-01 ～ S06-07。

### Phone

```text
提交说明
照片预览 Grid (1-6)
[拍照] [从相册选择]
提交检查提示
[确认提交]
```

支持：

- 删除；
- 重选；
- 顺序调整（P1 可增强）；
- 提交确认。

提交成功后进入明确结果页/状态反馈，不依赖 toast 作为唯一反馈。

### Pad

保持同一提交模型；可增加更宽的照片预览区域，不改变流程。

---

## S07｜学习 Learning

对应 V2 一级导航“学习”。

### P0 / 初期

保持轻量入口页：

- 当前学习空间；
- AI 小伴；
- 课外作业入口。

### 后续

- 错题本；
- 阅读推荐；
- 实践任务；
- 兴趣拓展。

不要在 P0 提前建设复杂内容推荐系统。

---

# 4. 家长端页面

## P01｜家长首页 Parent Home

对应特性：P01-01 ～ P01-07。

### 页面目标

> 今天是否正常？哪里需要我处理？

### Phone 信息顺序

```text
当前孩子
今日摘要：已完成 / 总数
AttentionSection?           # 逾期、待订正、待验收
RecentSubmission?

[导入老师作业]             # 核心快捷动作
[布置课外任务]             # P1

TodayAssignments
```

不使用 4～6 个 KPI 卡把首页做成驾驶舱。

### Pad 增强

空间足够时，可以把“今日作业”与“待关注/最近提交”并列；本周趋势属于 P2，不占首屏核心位置。

---

## P02｜导入 Step 1：老师原文

### Phone

输入来源：

- 粘贴老师文字；
- 截图 / OCR；
- 相册图片；
- 拍照；
- 手工录入；
- 系统分享（P1）。

页面只做“获取原文”，不要同时塞入完整候选编辑区。

主动作：

`[让小伴整理]`

---

## P03｜导入 Step 2：AI 整理

展示：

- Candidate Assignment 列表；
- 科目；
- 标题；
- 老师要求；
- 截止时间；
- 预计用时；
- 教材 / 页码；
- Source Evidence；
- 低置信字段。

支持：

- 编辑；
- 删除；
- 拆分；
- 合并。

Phone 连续页。  
Pad 只有空间足够时才组合“老师原文 | Candidate 列表”。

---

## P04｜导入 Step 3：确认发布

### 页面目标

> 确认哪些作业会真正进入孩子的任务清单。

展示发布摘要：

- 当前孩子；
- Assignment 数量；
- 科目；
- 日期；
- 低置信提醒。

主动作：

`[确认并发布]`

发布成功后返回家长首页并展示明确成功反馈。

---

## P05｜Progress

对应特性：P04-01 ～ P04-09。

### Phone

```text
当前孩子
日期选择 / 筛选
状态摘要
AssignmentProgressList
```

筛选：

- 日期；
- 科目；
- 状态。

点击进入 Parent Review / Assignment Progress Detail。

### Pad

空间足够时：

```text
作业列表 | 提交证据 / 验收详情
```

窄窗退回独立详情页。

---

## P06｜Parent Review

### 展示

- Assignment 摘要；
- 状态；
- 实际用时；
- 提交时间；
- Submission 图片；
- 可选 Tutor 使用摘要（P1）。

### 操作

```text
[通过]
[退回订正]
```

退回订正允许输入简短家长备注。

不建设打分、排名、复杂评语体系。

---

## P07｜课外任务创建（P1）

使用同一 Assignment：

```text
assignmentType = EXTRA
```

字段：

- 分类；
- 标题；
- 说明；
- 截止日期；
- 预计用时；
- 完成要求；
- 是否需要提交证据。

类别：

- 阅读；
- 朗读；
- 体育；
- 实践；
- 兴趣；
- 家务 / 生活能力；
- 自定义。

---

# 5. Layout Capability

业务页面不消费“Phone/Pad 类型”来决定单双栏。

统一思路：

```text
availableContentWidth
  >= primaryMinReadableWidth
   + secondaryMinReadableWidth
   + paneGap
   + horizontalPadding
```

才允许组合。

页面声明的是 **pane 的内容最小可读宽度**，不是设备 breakpoint。

示例组合：

- Assignment List + Detail；
- Study Content + Tutor；
- Progress List + Review；
- Import Source + Candidate。

Shell 的底部导航 / 侧边导航可以使用窗口级策略，但不得把其 size class 直接传给业务页决定布局。

---

# 6. 共享组件建议

优先建设真正跨页面复用的组件：

- AssignmentListItem；
- SubjectTag；
- AssignmentStatusTag；
- AssignmentTypeTag；
- AttentionBanner；
- SourceEvidenceView；
- ResourceList / ResourceViewer；
- LoadingState；
- EmptyState；
- ErrorState；
- OfflineBanner；
- PrimaryActionBar。

不要为了“组件化”把只出现一次的简单页面片段拆成过多组件。

---

# 7. 视觉方向

- 白 / 浅灰背景；
- 单一主品牌色；
- 学科色小面积辅助；
- 卡片减少层层嵌套；
- 文字层级优先于边框；
- 儿童友好但不幼稚；
- 家长端更克制；
- Phone 留白优先于信息堆叠；
- 主要触控目标不小于项目统一可访问尺寸。

设计 Token 继续集中在统一 Theme，不在 Feature 页面散落视觉 magic number。

---

# 8. Slice 对应关系

| Slice | UI 页面 |
|---|---|
| #105 Slice 1 | S01 学生首页 |
| #106 Slice 2 | S02 作业列表 + S03 详情基础 |
| #107 Slice 3 | S03 完整详情 + S04 学习空间 + S05 Tutor + S06 Submission |
| #108 Slice 4 | P01 家长首页 + P05 Progress + P06 Review |
| #109 Slice 5 | P02/P03/P04 导入三步流 |
| #110 Slice 6 | S07 学习增强 + P07 课外任务 + 日历 + Pad 增强 |

---

# 9. UI Slice 验收

每个 UI Slice 合并前至少确认：

1. Phone portrait；
2. Phone landscape；
3. Pad portrait；
4. Pad landscape；
5. Pad split / narrow；
6. Normal / Empty / Loading / Error；
7. Offline（涉及数据读取时）；
8. 长标题 / 长老师要求；
9. 系统返回；
10. 输入页键盘不遮挡主动作；
11. 无固定左右压缩布局；
12. 已替换的 V1 UI 同步清理。
