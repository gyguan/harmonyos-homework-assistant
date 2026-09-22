# Issue #241｜微信作业智能采集技术可行性 Spike

分支：spike/issue-241-homework-capture-feasibility

> 本文只记录技术 Gate。真机测试完成前，AVScreenCapture / OCR 均不得写成 PASS。应用市场版本不再依赖 FloatView。

## 1. 这版代码验证什么

链路：

~~~text
家长端
→ 导入老师作业
→ 实验：抓取今日作业
→ OH_AVScreenCapture 启动主屏 RGBA 原始码流
→ 用户进入微信测试群并手工上滑
→ 浏览完成后返回小伴
→ 在采集页点“结束并整理”
→ 读取最后一张内存 RGBA 帧
→ Core Vision OCR
→ 展示 OCR 全文 + 每行坐标
~~~

边界：

- 不读取微信数据库。
- 不 Hook / 注入微信。
- 不使用 Accessibility 自动点击或滚动。
- 不自动进入微信群。
- 不录音，不申请麦克风权限。
- 不把聊天画面写文件；Native 层只保留最新一张采样帧。
- 不创建 Candidate / Assignment。

## 2. 为什么改为返回小伴停止采集

跨应用 FloatView 会引入受限悬浮窗权限，应用市场审核风险高，而业务只需要用户能够明确结束采集，不要求在微信界面叠加控制按钮。

当前推荐操作是：

~~~text
微信聊天页面
→ 上滑 3~5 屏
→ 保持约 30 秒
→ 返回小伴
→ 点击“结束并整理”
→ 读取最后一张有效微信画面并执行 OCR
~~~

采集层应以最后一张有效变化帧作为证据，不应因为用户返回小伴而用应用自身页面覆盖最后一张已接受的微信证据。

构建 ABI：arm64-v8a（真机）+ x86_64（模拟器）；#241 最终 Gate 仍以真机为准。

## 3. 真机 Fixture

请在测试群准备或找到一段等价内容：

~~~text
二(3)班家长群
17:31 王老师
今晚语文作业：
1. 生字词每个写两遍
2. 朗读第8课三遍
~~~

## 4. 场景 A｜AVScreenCapture

步骤：

1. DevEco Studio 安装本分支到真机。
2. 家长身份 → “导入老师作业”。
3. 点击“实验：抓取今日作业”。
4. 点击“开始真机采集实验”。
5. 系统出现屏幕采集隐私提示后同意。
6. 切到微信测试群。
7. 连续上滑 3~5 屏并保持采集至少 30 秒。
8. 返回小伴。
9. 点击“结束并整理”。

验收：

- [ ] 未同意系统屏幕采集授权时没有有效视频帧。
- [ ] 同意后 callbackCount > 0。
- [ ] sampledFrameCount > 0。
- [ ] 连续 30 秒没有崩溃。
- [ ] 返回小伴并结束后 isCapturing=false。
- [ ] 停止后回调计数不再增长。
- [ ] 退出实验页后再次进入可以重新启动，未出现资源占用/实例上限错误。

## 5. 场景 B｜Core Vision OCR

停止采集并返回小伴后点击“读取最近一帧并执行 OCR”。

验收：

- [ ] 页面显示有效帧尺寸，例如 xxxx×xxxx。
- [ ] OCR 全文包含群标题主要文字。
- [ ] OCR 全文包含老师消息主要正文。
- [ ] 能识别时间文本 17:31 或等价时间。
- [ ] “OCR 行坐标证据”非空。
- [ ] 群标题与聊天正文的坐标区域有明显纵向差异，可支撑后续 #245 的聊天区域解析。

## 6. 场景 C｜跨应用切换与返回停止

验收：

- [ ] 不申请 FLOAT_VIEW / SYSTEM_FLOAT_WINDOW。
- [ ] 切换微信后采集仍继续。
- [ ] 微信界面没有小伴悬浮层遮挡。
- [ ] 返回小伴后采集页仍能恢复当前会话状态。
- [ ] 点击“结束并整理”后采集停止并释放资源。

## 7. 结果记录

请完成真机测试后把以下内容回填到 Issue #241：

~~~text
AVScreenCapture: PASS / FAIL
OCR: PASS / FAIL
Return-to-app stop: PASS / FAIL

Target HarmonyOS version:
Target device:
Target WeChat version:

Screen capture:
- duration:
- callbackCount:
- sampledFrameCount:
- final state:
- lastError:

OCR:
- frame size:
- block count:
- line count:
- group title recognized: YES / NO
- timestamp recognized: YES / NO
- homework body recognized: YES / NO

Return-to-app stop:
- capture continues after switching to WeChat: YES / NO
- capture page resumes after returning: YES / NO
- stop button works: YES / NO

Known limitations:

Recommendation:
PROCEED / ADJUST / STOP
~~~

## 8. Gate 规则

只有以下两个条件同时成立，#244 正式“微信引导式智能采集模式”才可以按当前技术路线继续：

~~~text
AVScreenCapture = PASS
Core Vision OCR = PASS
~~~

停止交互以“返回小伴后结束并整理”为正式方案，不依赖跨应用悬浮能力。

## 9. 当前状态

~~~text
Static implementation: IMPLEMENTED
Static repository gate: IMPLEMENTED
AVScreenCapture real-device gate: PENDING
Core Vision OCR real-device gate: PENDING
Return-to-app stop real-device gate: PENDING
~~~

本文件不以代码可编译或 API 文档存在来替代真机 Gate。
