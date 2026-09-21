# Issue #243｜系统分享一键导入作业独立验收

## 目标链路

~~~text
来源 APP / 相册
→ 系统分享
→ 小伴作业
→ ShareExtensionAbility
→ 文本直接暂存 / 图片立即复制进小伴沙箱
→ handoff token
→ EntryAbility
→ 现有 OCR + AI/本地解析
→ #242 ImportBatch
→ 现有 HomeworkConfirmationPage
~~~

## 关键边界

- ShareExtension 不创建 Assignment。
- ShareExtension 不运行第二套 Candidate/Assignment 状态机。
- 外部图片 URI 不跨 ShareExtension 生命周期保存。
- 图片在 ShareExtension 仍持有临时访问权限时复制到小伴 filesDir。
- 只有全部 SharedRecord 均读取、OCR、解析完成后才写 ImportBatch。
- OCR/解析失败时 handoff 保留，可重试，不生成半成品 ImportBatch/Assignment。
- 成功后继续复用 #242 Import Inbox 和现有确认发布。

## 场景 A｜文本分享

从支持 HarmonyOS 系统分享的测试 APP 分享：

~~~text
王老师：
今晚语文作业：
1. 第8课生字写两遍
2. 朗读课文三遍
~~~

选择“小伴作业”。

通过标准：

- [ ] 系统分享目标中出现“小伴作业”。
- [ ] 点击后自动拉起小伴主应用。
- [ ] 不需要再复制/粘贴。
- [ ] 自动进入家长导入处理状态。
- [ ] 创建 sourceType=SHARE 的 ImportBatch。
- [ ] ImportBatch.messageCount = 1。
- [ ] 原始文本保存在 ImportedMessage / SourceEvidence。
- [ ] 识别到 Candidate 后自动进入现有“确认发布”页。
- [ ] 发布仍走现有原子 Batch Publish。

## 场景 B｜单张图片

从系统相册分享一张清晰的老师作业截图到“小伴作业”。

通过标准：

- [ ] ShareExtension 接收图片 URI。
- [ ] 在 ShareExtension 结束前复制到 filesDir/homework_share_import。
- [ ] 主应用 OCR 使用的是沙箱副本，而不是来源 APP 的临时 URI。
- [ ] OCR 成功后 sourceType=SHARE。
- [ ] SourceEvidence.imageRef 指向沙箱副本。
- [ ] Candidate 进入现有确认页。

## 场景 C｜多张图片

选择 2~3 张连续作业截图并分享到“小伴作业”。

通过标准：

- [ ] 系统允许时一次接收多张图片。
- [ ] 每张图片对应一个 ImportedMessage。
- [ ] 所有图片都成功 OCR 后才生成/覆盖最终 ImportBatch。
- [ ] 任意一张失败时不留下半成品 ImportBatch。
- [ ] 修正图片后重新分享或点击重试可恢复。

说明：是否由具体来源 APP 暴露“多张/聊天批量分享”入口属于来源 APP 能力，不作为小伴自身 Gate。

## 场景 D｜OCR 失败与重试

分享一张无法识别文字的图片。

通过标准：

- [ ] 页面明确提示“无法读取或识别分享图片，请重试”。
- [ ] 有“重试”操作。
- [ ] 失败时没有创建 Assignment。
- [ ] 失败时没有写入半成品 ImportBatch。
- [ ] handoff 和沙箱图片仍保留，重试不要求重新从来源 APP 分享。

## 场景 E｜取消

在失败状态点击“取消”。

通过标准：

- [ ] pending handoff 被删除。
- [ ] 尚未形成批次的沙箱图片做 best-effort 清理。
- [ ] 不创建 Assignment。
- [ ] 不改变原有待确认作业。
- [ ] 返回家长正常页面。

## 冷启动 / 热启动

分别验证：

1. 小伴完全未运行时，从其他 APP 分享。
2. 小伴已经运行在家长页时，从其他 APP 分享。
3. 小伴已经运行在学生页时，从其他 APP 分享。

通过标准：

- [ ] 冷启动通过 EntryAbility.onCreate 捕获 token。
- [ ] 热启动通过 EntryAbility.onNewWant 捕获 token。
- [ ] 学生页收到分享时切换到家长拥有的导入流程，不在学生身份下发布作业。
- [ ] 分享完成后进入现有家长确认/收件箱链路。

## 静态 Gate

~~~text
python scripts/validate_issue243_share_import.py
~~~

预期：

~~~text
ISSUE_243_SHARE_IMPORT_GATE_PASS
~~~

## 真机 Gate

必须使用实际 HarmonyOS 系统分享面板验证：

- Phone 真机
- 文本来源 APP
- 系统相册单图
- 系统相册多图（系统/来源支持时）
- 冷启动
- 热启动
- OCR 成功
- OCR 失败 + Retry

DevEco 编译通过或静态 Gate 通过不能替代该真机 Gate。
