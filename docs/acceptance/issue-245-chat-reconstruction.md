# Issue #245｜微信聊天消息重建、滚动去重与时间边界识别

## 目标链路

~~~text
#244 CaptureFrameEvidence[]
→ OCR line geometry
→ Chat Region Parser
→ Message Block
→ deterministic identity
→ cross-frame overlap merge
→ Ordered ImportedMessage[]
→ ImportBatch(RECEIVED)
~~~

本 Issue 不判断老师身份、不判断作业、不生成 Candidate、不发布 Assignment。

## 为什么不用 LLM 去重

屏幕滚动天然产生重叠画面。若直接把所有 OCR 文本交给模型，重复量大、成本和时延不可控，也很难提供可审计 evidence。因此 #245 采用确定性重建。

## OCR Evidence

#244 的 CaptureFrameEvidence 现在保留：

~~~text
text
lineCount
lines[]
  value
  left
  top
  right
  bottom
~~~

旧 #244 数据没有 lines[] 时仍兼容：

~~~text
raw OCR text
→ split by newline
→ fallback pseudo geometry
→ FRAME_x_GEOMETRY_MISSING warning
~~~

不会因为升级要求用户重新采集。

## Message Block 解析

优先支持：

~~~text
17:42 王老师 A
王老师 17:42 A
~~~

同时支持：

~~~text
17:42
王老师：
A
~~~

明确时间会被解析为 minute-of-day，并基于采集当天生成 approximate epoch。

图片占位支持：

~~~text
[图片]
[图片:img_001]
~~~

其中 hash 会进入消息 identity / fingerprint。

## 去重策略

### 强匹配

可以单条直接判定为同一消息：

~~~text
normalizedText
+ sender
+ explicit minute
+ imageHash
~~~

所以不同 sender 或明确时间不同的同文消息不会合并。

### 弱匹配

缺时间时，sender + text + imageHash 只作为 overlap 候选。只有形成连续 overlap >= 2 条，才用序列上下文确认是滚动重复；单条弱匹配不直接去重。

## 跨帧重建

每帧内部按 OCR top / left 排序，跨帧寻找累计序列与当前 Frame 的最长连续 overlap。

找到后：
- overlap 节点合并 frame evidence
- overlap 前的新消息前插
- overlap 后的新消息后插
- 强重复消息只合并 provenance

没有可信 overlap 时：
- 有明确时间范围则按时间前插或后插
- 否则保留采集顺序
- 增加 NO_CONFIDENT_OVERLAP warning

若所有消息都有明确时间，最终稳定按聊天时间排序。

## Frame Evidence 追溯

去重后的 ImportedMessage 增加：

~~~text
sourceFrameEvidenceIds[]
~~~

例如 A 在 3 个 Frame 出现，最终只保留 1 条 A，但 sourceFrameEvidenceIds 数量为 3。

## 时间边界

输入：

~~~text
targetStartMinuteOfDay = 15 * 60
~~~

若识别到 14:58，则：

~~~text
timeBoundaryReached = true
earliestDetectedTime = 14:58
~~~

这里只做事实判断。自动停止策略由后续 Source Profile / #247 决定。

## ImportBatch

#244 停止采集后：

1. 先确保确定性 Capture ImportBatch 存在。
2. #245 读取 CaptureFrameEvidence。
3. 执行 deterministic reconstruction。
4. 用唯一聊天消息替换“每 Frame 一条”的临时消息。
5. Batch 继续保持 RECEIVED。
6. Candidate 数量保持 0。

新增持久化元数据：

~~~text
reconstructed
groupTitle
timeBoundaryReached
earliestDetectedTime
reconstructionWarnings[]
~~~

若重建异常：

~~~text
reconstructed = false
reconstructionWarnings = [CHAT_RECONSTRUCTION_EXCEPTION]
~~~

原始 Frame 消息继续保留，#244 的停止录屏和资源释放不受影响。

## 主 Fixture

固定 5 Frame，相邻 Frame 均有 50% 消息重叠：

~~~text
F1: 17:46 家长甲 收到 | 17:50 李老师 C
F2: 17:45 王老师 B    | 17:46 家长甲 收到
F3: 17:42 王老师 A    | 17:45 王老师 B
F4: 14:58 王老师 D    | 17:42 王老师 A
F5: 17:42 王老师 A    | 17:45 王老师 B
~~~

最终必须得到：

~~~text
14:58 王老师 D
17:42 王老师 A
17:45 王老师 B
17:46 家长甲 收到
17:50 李老师 C
~~~

A 在 F3/F4/F5 出现 3 次，输出只保留 1 条，但 evidence 数量为 3。

## 额外回归用例

- 同文不同 sender → 2 条
- 同 sender 同文不同时间 → 2 条
- 缺时间消息 + 连续 overlap → 正确去重
- 图片 hash → 正确去重
- 单 Frame OCR 失败 → 其它 Frame 继续重建
- 老 Capture Evidence 无 geometry → fallback + warning

## 自动化与 UI 验收

固定聊天重建回归已迁到：

~~~text
entry/src/test/fixtures/Issue245ChatReconstructionFixture.ets
entry/src/test/List.test.ets
~~~

由 Hypium Local Test 真正执行 5 Frame overlap、去重、时间边界与 Source Evidence 断言；Python Gate 只检查架构不变量。

真实采集完成后进入：

~~~text
作业智能收件箱
→ 智能采集批次
→ 批次详情
~~~

可看到群标题、最早识别时间、时间边界状态、reconstruction warnings，以及每条聊天消息的来源 Frame Evidence 数量。

## 静态 Gate

~~~text
python scripts/validate_issue245_chat_reconstruction.py
~~~

预期：

~~~text
ISSUE_245_CHAT_RECONSTRUCTION_GATE_PASS
~~~

## 非目标

本 Issue 明确不做：
- 老师身份判断
- 作业分类
- 多消息语义合并
- 更正覆盖
- CandidateAssignment
- Assignment 发布
- 微信自动点击
- 微信自动滚动
- Accessibility 驱动微信
- LLM 去重
