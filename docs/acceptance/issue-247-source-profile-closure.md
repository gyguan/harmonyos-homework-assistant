# Issue #247｜班级 Source Profile 与“一键抓取今日作业”完整闭环

## 最终用户体验

首次配置一次：

~~~text
班级：二(3)班
目标群：二(3)班家长群
默认开始：15:00
老师：
- 王老师 / 别名 → 语文
- 李老师 / 别名 → 数学
- Amy / 别名 → 英语
~~~

以后每天：

~~~text
导入老师作业
→ 抓取今日作业
→ 系统授权
→ 进入目标微信群
→ 手工上滑
→ 悬浮窗自动确认群名 / 时间边界
→ 到 15:00 前消息时“一键结束并整理”
→ #245 聊天重建
→ #246 作业理解
→ 现有家长确认页
→ 批量发布
~~~

配置完成后，从导入首页点击“抓取今日作业”会自动进入 CaptureSession，不再要求额外点击一次“开始”。

## SourceProfile

~~~text
HomeworkSourceProfile
├─ id
├─ name
├─ groupTitle
├─ studentId
├─ teacherAliases[]
├─ defaultStartMinuteOfDay
├─ enabled
├─ createdAtEpochMs
├─ updatedAtEpochMs
└─ lastUsedAtEpochMs
~~~

TeacherAlias：

~~~text
displayName
aliases[]
subject
~~~

当前家庭场景采用“一个孩子一个启用中的班级 Profile”，避免引入复杂配置中心。

Profile 独立保存在：

~~~text
homework_source_profiles_v1
~~~

App 启动时在 EntryAbility 恢复。

## 首次配置与后续编辑

首次没有 Profile：

~~~text
点击“抓取今日作业”
→ 班级采集设置
→ 保存并开始抓取
→ CaptureSession
~~~

已有 Profile：

~~~text
点击“抓取今日作业”
→ 直接自动开始采集
~~~

导入首页展示：

~~~text
二(3)班家长群 · 今天 15:00 至现在
~~~

“修改设置”只保存并返回，不会叠加新的 Capture 页面。

## 群名校验

#245 重建会持续给出 groupTitle。

#247 使用确定性精确规范化匹配：

~~~text
trim
→ remove whitespace
→ lower case
→ exact compare
~~~

结果：

~~~text
MATCHED
MISMATCH
UNRECOGNIZED
~~~

### MATCHED

继续采集和自动整理。

### MISMATCH

悬浮窗立即显示：

~~~text
当前群与配置不一致
~~~

停止后：

- 原屏幕证据仍保留
- 原重建消息仍保留
- 不运行 #246 自动作业理解
- 不生成待发布 Candidate
- 明确提示进入正确群重新抓取

不会把错误群聊天自动变成作业。

### UNRECOGNIZED

OCR 无法可靠得到群标题时，不等同 MATCHED。

停止后显示：

~~~text
确认是目标班级群，继续整理
~~~

只有家长明确确认后才运行 #246。

ImportBatch 记录：

~~~text
groupValidationStatus = UNRECOGNIZED
groupConfirmedByUser = true
~~~

## 时间边界

Profile：

~~~text
defaultStartTime = 15:00
~~~

#245 检测到：

~~~text
14:58 ...
~~~

则：

~~~text
timeBoundaryReached = true
earliestDetectedTime = 14:58
~~~

用户在微信中通过 FloatView 直接看到：

~~~text
已到达今日时间范围
已看到 14:58，现在可以结束并自动整理
~~~

当前实现采用“一键结束”，而不是自动停止，避免 OCR 偶发误识别直接终止真实用户采集。

## 时间窗与证据链

15:00 以前的消息：

- 用于时间边界判断
- 保留在 ImportBatch 原始重建消息中
- 不送入 #246 语义理解

因此：

~~~text
14:58 家长B 请问明天几点到校？
~~~

仍可审计，但不会成为 UNKNOWN 待确认。

HomeworkUnderstandingService 会记录：

~~~text
TIME_RANGE_FILTERED:N
~~~

## 自动整理链路

停止采集：

~~~text
CaptureSession
→ deterministic ImportBatch
→ #245 reconstruct(startTime)
→ group validation
→ #246 understand(profile.teacherAliases, startTime)
→ ImportBatch READY / RECEIVED / EMPTY
~~~

群名 MATCHED 且生成 Candidate：

~~~text
activateBatch
→ 自动进入现有确认发布页
~~~

仍由家长最终确认，不会自动发布。

## 完整 Fixture

目标 Profile：

~~~text
groupTitle = 二(3)班家长群
startTime = 15:00
王老师 = 语文
~~~

聊天：

~~~text
18:03 王老师
另外明天记得带一本课外书

17:50 家长A
收到

17:42 王老师
练习册刚才说错了，是33页

17:31 王老师
今晚语文：生字写两遍，练习册32页

14:58 家长B
请问明天几点到校？
~~~

Fixture 必须得到：

~~~text
group = MATCHED
timeBoundaryReached = true
earliestDetectedTime = 14:58

5 reconstructed messages
→ 4 messages inside semantic time window

Candidates:
1. 生字写两遍
2. 练习册33页
3. 明日准备：带一本课外书
~~~

并验证：

- 家长A“收到”不生成 Candidate
- 14:58 消息不进入 #246
- 32页不再存在
- 33页 Candidate 同时引用原作业和更正消息
- 所有 Candidate 都有 batchId + sourceMessageIds
- MISMATCH 可识别
- UNRECOGNIZED 必须人工确认

## 发布后追溯

不复制 SourceEvidence 到 Assignment，避免双份数据漂移。

已有发布链：

~~~text
Assignment.candidateId
→ PUBLISHED ImportBatch 中保留的 Candidate
→ Candidate.sourceMessageIds[]
→ ImportedMessage
→ sourceFrameEvidenceIds[]
→ CaptureFrameEvidence
~~~

HomeworkImportInboxStore.markPublished() 只改变 Batch 状态，不删除 Candidate 快照。

## Batch 审计快照

Capture ImportBatch 额外保存：

~~~text
sourceProfileId
sourceProfileName
expectedGroupTitle
profileStartTime
groupValidationStatus
groupConfirmedByUser
~~~

因此后续修改 Profile 不会改变历史批次当时使用的群名和时间口径。

批次详情展示：

- 配置名称
- 目标群
- 今天 HH:mm 至采集结束
- 群名校验状态
- 实际 OCR 群标题
- 最早识别时间
- 时间边界
- 作业理解结果

## 隐私与控制边界

完整流程仍然：

- 不读取微信数据库
- 不 Hook 微信
- 不自动点击微信
- 不自动滚动微信
- 不用 Accessibility 驱动微信
- 用户自己进入群
- 用户自己手工滚动
- 用户自己确认发布

目标体验是：

> 点一下 → 进群 → 划几下 → 确认发布

而不是后台监控微信。

## 回归

必须继续保留：

- 手工文字导入
- 截图/OCR 导入
- 系统分享导入
- 语音布置作业
- 作业智能收件箱
- 家长确认编辑
- 批量原子发布
- 学生端 Assignment

## 独立自动化测试

完整闭环 Fixture 已迁到：

~~~text
entry/src/test/fixtures/Issue247FullClosureFixture.ets
entry/src/test/List.test.ets
~~~

Hypium Local Test 必须验证：

~~~text
group=matched
boundary=14:58
messages=5→4
32→33
homework+preparation
mixed-group=CONFLICT / blocked
~~~

生产“屏幕采集技术诊断”只用于真机 AVScreenCapture / OCR / FloatView Gate。

## 静态 Gate

~~~text
python scripts/validate_issue247_source_profile_closure.py
~~~

预期：

~~~text
ISSUE_247_SOURCE_PROFILE_CLOSURE_GATE_PASS
~~~

## 真机完成 Gate

Issue 真正关闭前仍需：

1. DevEco Studio ArkTS/HAP Build PASS
2. #241 AVScreenCapture 真机 PASS
3. #241 Core Vision OCR 真机 PASS
4. 正确群名 MATCHED 真机 PASS
5. 错误群名 MISMATCH 真机 PASS
6. OCR 群名失败 → 人工确认继续 PASS
7. 15:00 边界 FloatView 提示 PASS
8. 真实滚动聊天 30%～70% overlap 重建 PASS
9. #246 实际结果进入确认页 PASS
10. 批量发布后 Assignment→SourceEvidence 追溯 PASS

在这些真机 Gate 完成前，PR 保持 Draft，不合入 main。
