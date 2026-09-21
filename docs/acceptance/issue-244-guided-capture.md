# Issue #244｜微信引导式智能采集模式独立验收

## 当前实现边界

#244 负责：

~~~text
CaptureSession
→ 系统屏幕采集
→ Frame sampling / Frame Diff
→ Core Vision OCR evidence
→ ImportBatch(RECEIVED)
~~~

#244 不负责：

- 群名识别
- 老师识别
- 时间边界
- 聊天气泡重建
- 消息去重
- 作业语义判断
- Candidate 生成

这些留给后续 Issue。

> #241 AVScreenCapture / OCR 真机 Gate 在人工确认前仍然是 PENDING。
> #244 的业务状态机可以通过 Fixture 独立验收，但不能用 Fixture 冒充 #241 真机 Gate PASS。

## 状态机

~~~text
CREATED
  ↓
WAITING_PERMISSION
  ↓ 第一张真实视频帧
CAPTURING
  ↓ 用户停止
STOPPING
  ↓
COMPLETED

拒绝/取消 → CANCELLED
异常/进程恢复 → FAILED
~~~

关键规则：

- startCapture() 返回 0 不等于已授权。
- 只有收到第一张真实视频帧才进入 CAPTURING。
- 同一时刻只允许一个 active CaptureSession。
- 终态 Session 会释放 activeSessionId。
- App/Ability 异常销毁时主动 stopCapture 并记录 FAILED。
- 进程异常退出未执行 onDestroy 时，下次启动把残留非终态 Session 恢复为 FAILED / PROCESS_RESTARTED。

## Frame 策略

Native 层继续沿用 #241 的 callback sampling。

业务层再次执行低成本 Frame Diff：

~~~text
最新 Native sampled frame
→ 96 点字节签名
→ 与上一 accepted frame 比较
→ 平均差值 < threshold：丢弃
→ 有明显变化：Core Vision OCR
~~~

不会对每个视频帧调用 OCR，更不会调用 LLM。

原始 RGBA 只存在内存，不写 CaptureSession Preferences，也不进入 ImportBatch。

## ImportBatch

成功停止后使用确定性 ID：

~~~text
capture-batch-{captureSessionId}
~~~

因此重复 finalize 不会产生第二个批次。

批次属性：

~~~text
sourceType = SCREEN_CAPTURE
status = RECEIVED
captureSessionId = CaptureSession.id
candidateCount = 0
messages = accepted frame OCR evidence
~~~

使用 RECEIVED 而不是 EMPTY，因为 #244 尚未执行作业语义判断。

## 离线 Fixture Gate

进入：

~~~text
家长 → 导入老师作业 → 屏幕采集技术诊断
~~~

点击：

~~~text
运行 #244 离线流程自测
~~~

Fixture 固定模拟：

~~~text
Frame 1: value 12  → accepted
Frame 2: value 88  → accepted
Frame 3: value 88  → rejected by Frame Diff
~~~

OCR Stub：

~~~text
17:31 王老师 今晚语文作业：第8课生字写两遍
17:32 王老师 补充：朗读第8课三遍
~~~

通过结果必须为：

~~~text
3 sampled
→ 2 accepted
→ 2 ImportedMessage
→ 1 ImportBatch
→ batch.captureSessionId == session.id
→ CaptureSession = COMPLETED
~~~

## 正式用户流程

1. 家长 → 导入老师作业。
2. 点击“抓取今日作业”。
3. 页面说明屏幕采集范围。
4. 点击“开始抓取今日作业”。
5. 同意 FloatView 权限。
6. 同意系统屏幕采集授权。
7. 切换微信目标群。
8. 手工上滑聊天。
9. 观察悬浮状态持续显示。
10. 在悬浮状态点“停止采集”。
11. 返回小伴。
12. 打开作业智能收件箱。
13. 查看状态为“已接收”的屏幕智能采集批次。

## 独立验收

### 权限与并发

- [ ] 未取得真实视频帧前 Session 保持 WAITING_PERMISSION。
- [ ] 拒绝/启动失败后 Session 进入 CANCELLED，可重新开始。
- [ ] 连续点击开始不会创建两个 active Session。
- [ ] FloatView 权限失败时不启动正式 CaptureSession。

### 采集状态

- [ ] 微信上方持续显示轻量采集状态。
- [ ] 不严重遮挡主要聊天区域。
- [ ] 状态显示 accepted changed frame 数量。
- [ ] 用户可从 FloatView 手工停止。
- [ ] 用户也可返回小伴手工停止。

### Frame Diff / 性能

- [ ] 连续静止画面不会反复增加 acceptedFrameCount。
- [ ] 手工滚动到明显新画面后 acceptedFrameCount 增加。
- [ ] 60 秒连续采集不崩溃。
- [ ] OCR 次数明显少于视频 callback 数。
- [ ] #244 运行期间不调用在线 AI/LLM。

### 停止与恢复

- [ ] 停止后 AVScreenCapture 资源释放。
- [ ] COMPLETED Session 只生成一个 ImportBatch。
- [ ] 重复进入页面不会再次 finalize 同一个 Session。
- [ ] Ability 正常销毁时 active session 被安全停止。
- [ ] 模拟异常进程恢复后残留 CAPTURING 不会继续伪装成运行中。

### 可追溯性

- [ ] CaptureSession.importBatchId 有值。
- [ ] ImportBatch.captureSessionId 等于 Session.id。
- [ ] 批次详情可看到“采集会话：capture-...”。
- [ ] 批次 sourceType=SCREEN_CAPTURE。
- [ ] 批次 status=RECEIVED。
- [ ] 批次消息是 OCR Evidence，不是 Candidate。

### 微信边界

- [ ] 不自动打开微信。
- [ ] 不自动进入群。
- [ ] 不自动点击微信。
- [ ] 不自动滚动微信。
- [ ] 不使用 Accessibility 驱动微信。
- [ ] 用户滚动是唯一的聊天浏览动作。

## 静态 Gate

~~~text
python scripts/validate_issue244_guided_capture.py
~~~

预期：

~~~text
ISSUE_244_GUIDED_CAPTURE_GATE_PASS
~~~

## #244 完成 Gate

代码/Fixture Gate 通过后，仍需同时满足：

~~~text
#241 AVScreenCapture real device = PASS
#241 Core Vision OCR real device = PASS
#244 60s real device capture = PASS
#244 FloatView manual stop = PASS
#244 one Session → one ImportBatch = PASS
~~~

否则 #244 保持 Draft/PENDING，不合入 main。
