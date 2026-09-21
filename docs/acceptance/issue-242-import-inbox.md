# Issue #242｜Homework Import V2 独立验收

## 目标

验证统一导入底座：

~~~text
ImportBatch
  → ImportedMessage[]
  → CandidateAssignment[]
  → 现有确认发布
  → Assignment
~~~

Import Inbox 与 Assignment 生命周期分离。

## 固定 Fixture

仓库提供：

entry/src/main/ets/experimental/importinbox/Issue242ImportInboxFixture.ets

内容固定为：

- sourceType = CLIPBOARD
- 1 个 ImportBatch
- 3 条 ImportedMessage
- 2 个 CandidateAssignment
- 家长“收到”消息存在于原始消息中，但不对应 Candidate
- 两个 Candidate 各自通过 sourceMessageIds 指向老师原始消息

Fixture 不调用微信、不调用 OCR、不调用在线 AI。

## 手工验收：真实文字导入

1. 家长端 → 导入老师作业。
2. 粘贴：
   语文：第8课生字写两遍；朗读第8课三遍。
3. 点击“让小伴整理”。
4. 进入确认页，修改其中一项预计用时。
5. 返回“导入老师作业” → “作业智能收件箱”。
6. 打开最新批次。

通过标准：

- [ ] 批次来源显示文字导入。
- [ ] messageCount = 1。
- [ ] candidateCount 与整理结果一致。
- [ ] 批次详情可以看到原始文字。
- [ ] Candidate 可以看到来源 excerpt。
- [ ] 修改后的预计用时仍保存在批次 Candidate 快照。
- [ ] Candidate 的 batchId / sourceMessageIds 没有因编辑而丢失。

## 持久化验收

完成一次文字或截图导入后：

1. 完全退出 APP。
2. 重新启动 APP。
3. 家长端 → 导入老师作业 → 作业智能收件箱。

通过标准：

- [ ] 之前的 ImportBatch 仍存在。
- [ ] 原始消息仍存在。
- [ ] Candidate 快照仍存在。
- [ ] 当前 Assignment 列表不受 Import Inbox 初始化影响。

## 继续确认与发布

对状态为“待确认”的批次：

1. 收件箱 → 批次详情。
2. 点击“继续确认并发布”。
3. 应进入现有 HomeworkConfirmationPage。
4. 完成发布。

通过标准：

- [ ] 不出现第二套确认页。
- [ ] 发布仍调用现有原子 batch publish。
- [ ] 发布成功后批次状态变成 PUBLISHED。
- [ ] Candidate 历史快照与 SourceEvidence 仍可查看。
- [ ] 活跃 Candidate Draft 被清空。
- [ ] Assignment 使用现有 AssignmentStateMachine。

## 放弃批次

对 READY 批次点击“放弃这个批次”。

通过标准：

- [ ] 批次状态变成 ABANDONED。
- [ ] 该批次不再允许进入确认发布。
- [ ] 如果曾存在其它已经发布的 Assignment，它们不被删除。
- [ ] Import Inbox 代码不直接调用 Assignment 删除接口。

## 截图回归

1. 使用现有“从相册导入截图”。
2. OCR / AI 或本地 parser 完成后查看收件箱。

通过标准：

- [ ] sourceType = SCREENSHOT。
- [ ] SourceEvidence.imageRef 保留原图片 URI。
- [ ] 原有截图导入和确认页体验不退化。

## Gate

静态 Gate：

python scripts/validate_issue242_import_inbox.py

预期：

ISSUE_242_IMPORT_INBOX_GATE_PASS
