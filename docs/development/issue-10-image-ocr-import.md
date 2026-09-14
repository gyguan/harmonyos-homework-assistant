# Issue #10｜相册截图 OCR 导入

## 目标

把“收作业”从 Mock 流程变成第一条真实可用链路：

`相册截图 → PhotoViewPicker → Core Vision OCR → LocalHomeworkAssignmentParser → CandidateAssignment → 家长确认`

## 关键实现

- `CoreVisionHomeworkTextExtractor`
  - 使用 `@kit.CoreVisionKit` 的 `textRecognition`。
  - 图片 URI 通过 `fileIo + image.createImageSource + PixelMap` 转成 OCR 输入。
  - 已有纯文本时直接返回文本，便于当前 Mock seed 和后续粘贴文本复用同一 Pipeline。
- `LocalHomeworkAssignmentParser`
  - 不需要云端账号和 API Key。
  - 当前识别语文、数学、英语三个科目标记。
  - Candidate 的 Source Evidence 直接引用 OCR 原文片段。
- `HomeworkImportService`
  - 使用 `photoAccessHelper.PhotoViewPicker` 选择单张截图。
  - OCR/解析全部成功后才替换 Store 中当前导入与 Candidate，失败不会覆盖已有结果。
- `HomeworkImportPage`
  - 主入口为“选择作业截图”。
  - 展示 OCR 原文与整理后的 Candidate。
  - 保留“重新整理当前文字”作为低成本重试入口。

## 为什么暂时不用云端 LLM

V0.1 只管理一个家庭，优先把最短闭环跑通。本地 Parser 足够验证真实 OCR、Source Evidence、家长确认与发布链路。后续需要更复杂的自然语言理解时，只替换 `HomeworkAssignmentParser` 实现即可，不改 OCR、页面和作业状态机。

## 手工验收

1. 家长空间 → 导入。
2. 点击“选择作业截图”。
3. 选择包含类似以下文本的截图：
   - 语文背诵第12课古诗两首；
   - 数学练习册32页；
   - 英语听读U4，明天检查。
4. 确认识别原文出现在左侧/上方。
5. 确认生成 3 项 Candidate，且“原文”来自 OCR 文本。
6. 家长确认并发布。
7. 学生 Today 可以看到新发布作业。

## 当前边界

本期不做相机拍照、多图、PDF/Word、语音和云端 LLM。
