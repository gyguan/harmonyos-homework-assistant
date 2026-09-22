# ADR-0003: 用户主动屏幕采集的作业导入边界

- Status: Accepted
- Date: 2026-09-21
- Related: #241, #242, #244, #245, #246, #247

## Context

V2 Homework Import 已支持用户主动提供的文字、截图/OCR 与系统分享。家庭真实场景中，老师作业也经常散落在微信群多条消息中，家长逐条复制成本高，因此需要一种比手工复制更连续、同时又不突破第三方应用隐私边界的导入方式。

本能力涉及新的工程边界：

- HarmonyOS AVScreenCapture 原始视频流；
- Core Vision OCR；
- 屏幕采集期间的跨应用生命周期与用户可控停止；
- SourceProfile 家庭私有配置；
- CaptureSession / FrameEvidence 持久化；
- ImportBatch 的重建、来源校验、理解与家长确认；
- 微信聊天内容属于家庭敏感上下文，且可能涉及未成年人。

如果把录屏、OCR、聊天重建、作业理解直接揉成一个页面流程，会出现重复执行、错误群消息混入、进程中断后不可恢复，以及生产代码为测试场景特判等问题。

## Decision

采用：

> **用户主动授权 + 用户手工浏览 + 最小证据采集 + 分阶段可恢复 Pipeline + 家长最终确认**

### 1. 第三方应用边界

允许：

- 家长主动点击“抓取今日作业”；
- 系统屏幕采集授权；
- 家长自己进入目标微信群；
- 家长自己手工滚动聊天记录；
- App 在授权期间读取当前屏幕像素并执行 OCR；
- 家长浏览完成后返回小伴，在采集页查看状态、群校验、时间边界并执行“结束采集”。

禁止：

- 读取微信数据库；
- Hook / 注入微信；
- 后台持续监听聊天；
- 自动点击或自动滚动微信；
- 使用 Accessibility 驱动微信；
- 麦克风录音；
- 绕过系统录屏授权。

### 2. 原始数据最小化

Native 层只在内存中保留最新采样 RGBA 帧。

持久化内容仅包括：

- CaptureSession 元数据；
- 变化帧的 OCR 文本和行坐标；
- FrameEvidence fingerprint；
- 重建后的 ImportedMessage；
- Candidate SourceEvidence。

不持久化原始 RGBA 视频帧，不生成屏幕录像文件。

### 3. SourceProfile

SourceProfile 是按学生隔离的家庭私有配置：

```text
studentId
groupTitle
defaultStartMinuteOfDay
teacherAliases[]
```

老师的规范化 displayName / alias 在同一 Profile 内必须全局唯一，避免同一个发送者静默匹配到两个学科。

历史 ImportBatch 保存 Profile 的审计快照，后续修改 Profile 不改写历史事实。

### 4. CaptureSession 只负责采集

CaptureSession 的职责截止到：

```text
系统授权
→ 原始流回调
→ Frame Diff
→ OCR
→ FrameEvidence
→ CAPTURED ImportBatch
```

CaptureSessionService 不执行聊天重建和作业理解。

这样可以保证录屏停止和 Native 资源释放不依赖下游语义成功。

### 5. 单一 Import Pipeline

后续由一个 Workflow 编排：

```text
CAPTURED
  ↓
RECONSTRUCTED
  ↓
SOURCE_VALIDATED
  ↓
UNDERSTOOD
  ↓
ACTIVATED
  ↓
家长确认
```

失败/阻断阶段：

```text
RECONSTRUCTION_FAILED
UNDERSTANDING_FAILED
BLOCKED_SOURCE
```

Pipeline stage 持久化在 ImportBatch 中，重复 finalize 必须复用已完成阶段，不重复覆盖 Candidate。

### 6. 来源校验必须 fail-closed

群标题结果：

- MATCHED：继续；
- MISMATCH：阻断自动理解；
- UNRECOGNIZED：要求家长明确确认后继续；
- CONFLICT：同一次采集出现多个明确群标题，直接阻断，不能通过“多数群名”或人工确认继续自动理解。

CONFLICT 的原始 Evidence 仍保留，便于审计，但用户必须从正确目标群重新采集。

### 7. 时间范围

SourceProfile 的默认时间，例如 15:00，只决定本次“今天 HH:mm 至采集结束”的语义范围。

早于开始时间的消息：

- 可以作为“已滚到时间边界”的证据；
- 继续保存在 ImportBatch；
- 不进入作业理解。

### 8. 家长是最终发布者

系统可以自动执行：

- 老师识别；
- 消息分类；
- 多消息合并；
- 更正覆盖；
- Candidate 生成。

但 Candidate 默认必须进入现有 Homework Confirmation，不能由屏幕采集流程直接发布 Assignment。

### 9. 测试边界

生产 `entry/src/main` 不允许包含：

- Issue Fixture 类；
- 测试 ID 分支；
- CI / Preview 专用业务行为。

确定性回归用例放在 `entry/src/test`，使用 Hypium Local Test。Python static gate 只用于检查工程边界，不能替代 ArkTS 业务测试实际执行。

## Consequences

### Positive

- 不依赖微信内部实现；
- 家长明确授权，并可返回小伴主动停止；
- 错误群和混合群不会静默生成作业；
- Capture 停止不被 OCR/语义后处理失败拖死；
- 进程恢复或重复回调可以按 Pipeline Stage 续跑；
- Source Evidence 保持单一追溯链；
- 生产代码与测试数据隔离。

### Cost

- 真机仍需验证不同 HarmonyOS / 微信版本的 AVScreenCapture、OCR 与后台切换/返回应用行为；
- 需要维护 SourceProfile；
- 导入 Pipeline 比单次 OCR 多一个持久化阶段模型；
- GitHub hosted runner 没有 HarmonyOS SDK 时，ArkTS Local Test 只能在 DevEco/配置了 SDK 的 CI 环境执行。

## Rejected alternatives

### 后台直接读取微信聊天数据库

拒绝。侵入第三方应用内部数据，隐私与兼容风险不可接受。

### Accessibility 自动进入群并滚动

拒绝。自动控制第三方应用不是本产品需要的能力，也扩大权限与审核风险。

### 使用 FloatView / 系统悬浮窗跨应用显示停止按钮

拒绝。FLOAT_VIEW / SYSTEM_FLOAT_WINDOW 属于受限或高敏感悬浮能力，会扩大应用权限面并增加应用市场审核风险。当前场景并不要求在微信界面上覆盖操作控件，家长浏览完成后返回小伴停止即可满足业务闭环。

### 一次录屏后直接调用大模型生成 Assignment

拒绝。缺少确定性来源重建、群校验和 Source Evidence，错误不可审计。

### 群标题冲突时选择出现次数最多的群继续

拒绝。会把其他群消息混入作业；出现多个明确群标题时必须 fail-closed。

## Source of truth

本 ADR 与以下文件共同约束实现：

- `CONTEXT.md`
- `AGENTS.md`
- `docs/architecture/frontend-technical-design-v2.md`
- `docs/acceptance/issue-244-guided-capture.md`
- `docs/acceptance/issue-245-chat-reconstruction.md`
- `docs/acceptance/issue-247-source-profile-closure.md`
