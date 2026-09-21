# Issue #246｜老师识别、作业分类、多消息合并与更正覆盖

## 正式链路

~~~text
#245 ImportedMessage[]
→ Teacher Resolver
→ Homework Classifier
→ Context Grouper
→ Revision Resolver
→ Task Extractor
→ CandidateAssignment[]
→ #242 ImportBatch
→ 现有家长批量确认 / 编辑 / 发布
~~~

#246 不创建第二套 Assignment 生命周期，也不直接发布作业。

## Teacher Resolver

老师配置是显式输入，后续 #247 再负责 Source Profile 持久化。

~~~text
TeacherDirectoryEntry
├─ teacherId
├─ displayName
├─ aliases[]
└─ subject
~~~

支持：
- 精确名称
- 别名
- 老师 → 科目映射
- 无法匹配返回 UNKNOWN

UNKNOWN 不根据“王/李”等姓氏猜科目。

## 六类消息

~~~text
HOMEWORK
HOMEWORK_REVISION
PREPARATION
NOTICE
CHAT
UNKNOWN
~~~

规则优先：
- 家长“收到 / 好的 / 谢谢老师” → CHAT
- 已识别老师 + 作业动作 → HOMEWORK
- 更正关键词 → HOMEWORK_REVISION
- 明天带书/准备材料 → PREPARATION
- 家长会/缴费/放学/接龙等 → NOTICE
- 无法确认 → UNKNOWN

UNKNOWN 不生成普通作业，进入 pendingReviewMessageIds。

## Context Grouper

只有已识别老师的：

~~~text
HOMEWORK
HOMEWORK_REVISION
PREPARATION
~~~

进入任务上下文。

分组键：

~~~text
teacherId + subject
~~~

因此语文更正不会修改数学任务。

## Revision Resolver

### 页码更正

~~~text
练习册32页
→ 刚才说错了，练习册是33页
→ 最终：练习册33页
~~~

最终 Candidate 的 sourceMessageIds 同时保留原消息和更正消息。

### 删除

~~~text
1. 生字
2. 朗读
3. 练习册
→ 第三题不用做
→ 最终删除第3项
~~~

### 补充

~~~text
补充一下：默写第8课生字
~~~

作为同一科目上下文的新任务加入。

### 改成

~~~text
朗读第8课
→ 改成朗读第9课三遍
~~~

替换当前科目最近任务。

### 以这条为准

~~~text
以这条为准：
1. 生字写三遍
2. 朗读第9课
~~~

用新列表替换当前科目的既有 Homework 任务。

找不到更正目标时不会静默猜测，会输出 REVISION_* warning。

## PREPARATION

例如：

~~~text
明天带一本课外书
~~~

分类为 PREPARATION，候选项标题：

~~~text
明日准备：带一本课外书
~~~

仍进入家长确认页，不直接发布。

## ImportBatch 状态

理解成功后：

~~~text
有 Candidate
→ READY

无 Candidate + 有 UNKNOWN
→ RECEIVED + pendingReviewMessageIds

无 Candidate + 无 UNKNOWN
→ EMPTY
~~~

因此 NOTICE / CHAT 已经明确“不是作业”时不会一直停留在 RECEIVED。

## 失败隔离

HomeworkUnderstandingService 采用“先计算、后一次性写回”。

若理解阶段异常：

~~~text
understood = false
understandingWarnings += HOMEWORK_UNDERSTANDING_EXCEPTION
~~~

并保留：
- 原 ImportedMessage[]
- 现有 Candidate[]
- 原 ImportBatch
- reconstruction metadata

因此可安全重试。

当前 #246 确定性核心不硬依赖在线 AI；未来如增加 LLM enhancer，也必须挂在相同失败隔离边界内。

## Source Evidence

每个 Candidate 必须保留：

~~~text
batchId
sourceType
sourceMessageIds[]
rawText
capturedAtEpochMs
~~~

例如 32→33：

~~~text
Candidate: 练习册33页
sourceMessageIds:
- 原始32页消息
- 更正33页消息
~~~

## 20 组固定 Fixture V1.0

覆盖：

1. 单条语文作业
2. 单条数学作业
3. 英语老师别名
4. 家长“收到”
5. 老师补充
6. 32页→33页
7. 第三题不用做
8. 明日准备
9. 普通通知
10. 同老师连续多条
11. UNKNOWN sender
12. 老师别名
13. 精确老师名称
14. 多科目
15. 改成……
16. 以这条为准
17. Homework + Preparation
18. Notice + Homework
19. 家长“谢谢老师”
20. 已知老师但语义不确定

## 质量指标

Fixture 固定输出：

~~~text
classificationAccuracy
groupingPassed / groupingTotal
revisionPassed / revisionTotal
taskExtractionPassed / taskExtractionTotal
evidencePassed / evidenceTotal
~~~

本阶段 Gate 要求固定 Fixture 全部通过。

## 应用内自测

进入：

~~~text
家长
→ 导入老师作业
→ 屏幕采集技术诊断
→ 运行 #246 作业理解自测
~~~

PASS 会显示：
- case count
- classification %
- grouping
- revision
- extraction

## UI

批次详情新增“作业理解”区：

- 是否理解完成
- classification summary
- 待人工确认消息数
- understanding warnings

Candidate 仍进入原有：

~~~text
确认发布
→ 编辑
→ 批量管理
→ 原子 Batch Publish
~~~

## 静态 Gate

~~~text
python scripts/validate_issue246_homework_understanding.py
~~~

预期：

~~~text
ISSUE_246_HOMEWORK_UNDERSTANDING_GATE_PASS
~~~

## 非目标

#246 不做：
- Source Profile 持久化
- 自动判断目标微信群
- 自动配置老师
- 时间范围自动停止
- 微信自动点击/滚动
- Accessibility 驱动微信
- 自动发布

这些留给 #247。
