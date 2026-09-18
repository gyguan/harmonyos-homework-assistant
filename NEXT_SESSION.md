# Next Session Handoff — 2026-09-18

> 用途：新开 ChatGPT 会话时，先读取根目录 `CONTEXT.md`，再读取本文件。  
> `CONTEXT.md` 保存长期产品/架构基线；本文件只记录本次会话增量、最新代码状态、已知风险和下一步验证重点。

## 1. 当前代码基线

仓库：`gyguan/harmonyos-homework-assistant`

本次 handoff 前的功能基线：

- `main`: `f8cdf16aecca1d9d7dc442ed1ca2be99db55aa07`
- 最新功能 PR：#196 `fix: restore valid ArkUI bindSheet syntax`
- 本次会话所有功能改动均已合入 `main`

本地更新：

```powershell
git checkout main; git pull origin main
```

注意：用户本地 HarmonyOS 工具链仍以 DevEco Studio / CompileArkTS 的真实编译结果为最终准绳。GitHub CI 当前主要是静态 Gate + Java/PostgreSQL E2E，并不能替代真实 ArkTS 编译。

用户本地已知兼容设置：

- `hvigor-config.json5`: `modelVersion` 使用 `5.0.0`
- `oh-package.json5`: `modelVersion` 使用 `5.0.0`
- `build-profile.json5`: `targetSdkVersion` 按本地 SDK 调整
- PowerShell/CMD 命令必须给单行，不使用反引号续行

---

## 2. 本次会话已完成内容

### PR #189 — 学习空间操作布局优化

目标：

1. “暂停一下”不再放在学习内容中间，移动到底部主操作区。
2. “拍题问小伴”不再作为对话区中间的独立卡片。

结果：

- Phone 正在做作业时，底部操作统一为：
  - `问小伴 | 暂停一下 | 我做完了，准备提交`
- Pad：
  - Tutor 常驻右侧，不重复显示“问小伴”
  - `暂停一下 | 我做完了，准备提交`
- Tutor 输入顺序调整为：
  - 对话历史 → 文字输入 → 拍题辅助 → 发送

---

### PR #190 — Phone 点击“开始作业”无后端请求

用户现象：

- Pad 正常
- Phone 点击“开始作业”立即前端报错
- 后端完全没有 HTTP 请求

根因：

1. Phone 可能在 AppShell 初始异步 refresh 完成前进入学习空间，本地 Assignment 的 `remoteVersion=0`。
2. 原 Repository 在 `remoteVersion<=0` 时直接前端 throw，因此不会发 HTTP。
3. `StudyWorkspaceRoutePage.aboutToAppear()` 原来还会自动 START，与初始 refresh 产生竞态。

修复：

- 删除进入学习空间自动 START。
- START 只允许用户明确点击。
- 真实 Assignment 如果 `remoteVersion<=0`：
  - 先 `GET /api/v1/assignments/{id}`（scene=`assignment.get`）
  - 补齐 authoritative version
  - 再 `POST /actions`
- 保留已有 stale-version 409 → 单条 GET → retry 一次。

---

### PR #191 — “小伴”界面整体重设计

不是局部挪动，而是重构成“学习辅导对话面板”。

结构：

1. 顶部身份区
   - “小伴学习助手”
   - “先帮你理思路，再给下一步提示”
   - 使用统一“伴”头像

2. 中间纯对话区
   - 学生：右侧蓝色气泡
   - 小伴：左侧“伴”头像 + 浅色气泡
   - 空状态提供三个快捷问题：
     - 怎么开始？
     - 检查思路
     - 提示下一步
   - 快捷项只填入输入框，不自动发送

3. 底部提问输入区
   - TextArea
   - 拍题
   - 发送
   - 三者统一为 composer

Phone / Pad 复用同一个 `TutorPane`。

---

### PR #192 — 家长每条任务独立预计时长 + 创建后可编辑

需求：

1. AI 导入后，每个 Candidate Assignment 能独立设置预计时长。
2. 已发布任务家长可编辑。

实现：

#### 确认发布阶段

每条 Candidate 独立保存 `expectedMinutes`，批量发布时逐条保留。

#### 已创建 Assignment 家长编辑

入口：

`家长 → 作业进度 → 作业详情 → 编辑任务`

可编辑：

- 标题
- 老师要求 / instruction
- 截止时间
- 预计时长
- 教材 / 页码

不可通过普通编辑修改：

- status
- started/paused timing
- Submission
- review note / 家长验收状态

状态边界：

- NOT_STARTED / IN_PROGRESS / PAUSED / READY_TO_SUBMIT / NEEDS_REWORK / OVERDUE：可编辑
- SUBMITTED / COMPLETED：锁定任务定义

新增窄 API：

```text
PUT /api/v1/assignments/{id}/details
```

scene：

```text
parent.assignment.edit
```

采用 optimistic version；冲突时客户端只 GET 当前单条 Assignment，合并家长编辑字段后重试一次，不做全量 refresh。

真实 PostgreSQL E2E 已覆盖：

- 字段持久化
- status 不变
- version 递增
- stale version → 409
- SUBMITTED 后编辑 → 400

---

### PR #193 — 学习空间可恢复提交 + Tutor 拍题 OCR 加固

用户反馈：

1. “暂停一下”底色应和“问小伴”一致。
2. 误点“我做完了，准备提交”进入选照片后，无法回退继续作业。
3. “问小伴 → 拍题”提示题目识别失败。

修复：

#### 暂停按钮

改为和“问小伴”一致：

- `AppTheme.PRIMARY_SOFT`
- `AppTheme.PRIMARY`

#### READY_TO_SUBMIT 可恢复

在准备提交阶段增加：

```text
继续作业
```

点击后：

```text
READY_TO_SUBMIT → START → IN_PROGRESS
```

并：

- 清空本次待提交照片
- 保留累计 `elapsedSeconds`

后端同时修复：
从 `READY_TO_SUBMIT` 再 START 时不再把累计用时清零。

真实 action E2E 覆盖：

```text
IN_PROGRESS → READY_TO_SUBMIT → IN_PROGRESS → READY_TO_SUBMIT
```

并校验 elapsedSeconds 不回退。

#### Tutor 拍题 OCR

原来直接使用 CameraPicker 的 `resultUri` 做 OCR，部分 Phone 上该 URI 不一定可被 fileIo/CoreVision 直接读取。

现在：

1. CameraPicker 将图片保存到 app cache `saveUri`
2. OCR 优先读 `saveUri`
3. 失败后再尝试 `resultUri`
4. 图片仍只在本机识别，发给 Tutor 后端的仍然只有文本

错误提示拆分：

- 本机文字识别暂不可用
- 无法打开系统相机
- 照片读取失败
- 其他 OCR 识别异常

---

### PR #194 — 新 APP 图标

替换：

- `AppScope/resources/base/media/app_icon.svg`
- `entry/src/main/resources/base/media/app_icon.svg`

视觉：

- 蓝青渐变
- 小伴助手形象
- 作业本
- 完成勾选
- “伴”识别符

仍使用原有 `$media:app_icon` 引用，无需修改 module/app 配置。

安装后如果仍显示旧图标，建议卸载旧 APP 后完整重新安装，避免桌面图标缓存。

---

### PR #195 — 家长确认发布页面底部弹出编辑 + 自定义时长

用户反馈：

1. 点某个作业编辑时，不应该滚到整个页面最下面。
2. 预计用时预置值全部挤在一行，Phone 超宽。
3. 应支持自定义时长。

实现：

#### 编辑方式

旧：

```text
点击 Candidate → 在整个长页面底部出现编辑器
```

新：

```text
点击 Candidate → bindSheet 从底部弹出编辑面板
```

- 弹层标题：“编辑作业”
- 显示当前科目 / 标题
- “完成”关闭
- 手工新增任务后直接打开新任务的编辑弹层
- 删除当前任务时自动关闭弹层

#### 预计用时

新增复用组件：

`CandidateDurationControl`

布局：

```text
10   15   20   分钟
30   45   [自定义]   分钟
```

自定义范围：

```text
1 ~ 240 分钟
```

列表 Candidate 卡片和底部编辑面板共用同一时长控件。

---

### PR #196 — 修复确认发布页 CompileArkTS：Cannot find name '$this'

用户本地真实错误：

```text
hvigor ERROR: Failed :entry:default@CompileArkTS...
ArkTS Compiler Error
Cannot find name '$this'
HomeworkConfirmationPage.ets:277:16
```

根因：

PR #195 的源码实际被写成：

```text
.bindSheet($this.showEditorSheet, ...)
```

而 ArkUI V1 正确双向绑定是：

```text
.bindSheet($$this.showEditorSheet, ...)
```

更深层根因：

之前通过 JavaScript `String.replace()` 生成修改时，replacement string 中的 `$$` 会按 JavaScript replace 规则解释成一个字面量 `$`，所以源码和 Gate 都被错误写成了单美元符号。

修复：

- 源码恢复为两个连续 `$`
- 已逐字符确认两个字符都是 ASCII 36
- Gate 现在：
  - 必须包含完整前缀 `.bindSheet($$this.showEditorSheet`
  - 禁止完整前缀 `.bindSheet($this.showEditorSheet`

**重要：PR #196 已合入并通过 CI，但用户尚未在本地 DevEco 再次确认 CompileArkTS 已通过。下次会话优先验证这一点。**

---

## 3. 与本次功能相关的既有基础

本次会话开始前，main 已经具备以下关键能力，排障时不要重复实现：

### Assignment action stale-version recovery

已有：

- `GET /api/v1/assignments/{id}`
- action 遇到 stale version 时：
  - 单条 GET
  - apply authoritative state
  - version 变化后 retry 一次

### API Efficiency

已完成：

- Assignment paging
- DB-side filter pushdown
- dirty assignment batch sync
- Submission latest endpoint
- Tutor history pagination
- 页面 aboutToAppear 不再反复全量 refresh
- UI invalidation 与网络 sync 分离

### API Observability

Harmony 请求自动带：

- `X-Request-Id`
- `X-Client-Scene`
- `X-Client-Request-Key`

服务端有：

- `[HTTP-REQUEST]`
- `[HTTP-REQUEST-BODY]`
- `[HTTP-RESPONSE]`
- `[HTTP]`
- `[HTTP-DUPLICATE]`

Assignment action 重点 scene：

- `assignment.action`
- `assignment.get`

家长编辑：

- `parent.assignment.edit`

---

## 4. 当前需要人工验证的重点

下次会话最优先按下面顺序验证，不要先继续扩功能。

### P0 — 本地 CompileArkTS

拉最新 main 后完整 Build：

```powershell
git checkout main; git pull origin main
```

首先确认 PR #196 后：

```text
HomeworkConfirmationPage.ets
.bindSheet($$this.showEditorSheet, ...)
```

能否通过用户本地 DevEco Studio CompileArkTS。

如果仍报错：
- 以用户本地编译器错误为最终依据
- 不要只依赖 Python Gate
- 必要时退回当前工程已验证过的 `@CustomDialog + CustomDialogController + DialogAlignment.Bottom` 实现底部弹层

### P1 — 家长确认发布 UI

Phone 实测：

1. 点任意 Candidate 是否直接底部弹出编辑，不再需要滚到底部。
2. Sheet 高度、键盘弹起后的滚动是否正常。
3. 预计用时两行是否不超宽。
4. 自定义输入 25 / 35 / 60 分钟是否稳定。
5. 点击快捷时长时是否意外触发 Candidate Card 的 `onClick` 打开弹层（事件冒泡需要实际设备验证）。

### P1 — Tutor 拍题

Phone 实测：

1. 点拍题是否能正常打开系统相机。
2. 拍照后是否能 OCR。
3. 若失败，记录新版具体提示：
   - OCR 初始化问题
   - 相机问题
   - 图片读取问题
4. 如果仍失败，优先检查 CoreVision 对 app-cache `file://` / path 的支持，不要再泛化成“拍清楚一点”。

### P1 — 学习空间提交恢复

实测：

```text
开始作业
→ 我做完了，准备提交
→ 进入照片选择
→ 继续作业
```

确认：

- 状态恢复 IN_PROGRESS
- 计时继续，不清零
- 已选照片被清空
- 再次准备提交正常

### P1 — 家长创建后编辑

验证：

- 未提交任务能编辑
- 修改 expectedMinutes / deadline 后学生端能看到
- SUBMITTED / COMPLETED 不显示或不能保存编辑

### P2 — APP 图标

卸载旧安装包后重新安装，确认桌面图标已经更新。

---

## 5. 当前设计/代码约束

### HomeworkStore 边界

除：

```text
data/HomeworkStore.ets
data/local/*.ets
```

外，Feature / Shell / application/remote / Repository 不得直接依赖 `HomeworkStore`。

### Study Workspace

- 进入页面不得自动 START。
- 用户明确点“开始作业”后才 START。
- `remoteVersion<=0` 的真实任务必须先单条 hydration，再 action。
- `READY_TO_SUBMIT` 必须可恢复为 `IN_PROGRESS`。
- 恢复时累计 elapsedSeconds 不得清零。

### Tutor

- Phone / Pad 复用同一个 TutorPane。
- 图片只在本机 OCR。
- 远端 Tutor API 只接收用户确认后的文本。
- 快捷问题只填输入框，不自动发送。

### Parent Confirmation

- Candidate 独立 `expectedMinutes`。
- 编辑使用底部弹层，不在页面尾部内联。
- 常用时长 + 自定义值同时存在。
- 自定义范围 1~240 分钟。

### Parent Assignment Edit

只允许更新任务定义字段，不允许通过普通编辑更改状态/计时/提交/验收。

---

## 6. 下次会话建议开场语

可以直接对新会话说：

> 请先阅读代码仓根目录 `CONTEXT.md` 和 `NEXT_SESSION.md`，基于最新 main 继续。先不要扩功能，第一步帮我确认上一轮 PR #196 的确认发布页面 bindSheet 编译修复，以及文档里列出的待人工验证项。

这样新会话就可以直接承接当前状态。
