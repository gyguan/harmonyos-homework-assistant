# ADR-0003: 作业图片 AI 直接解析与可回退 OCR

- Status: Accepted
- Date: 2026-09-30
- Spec: [Issue #393](https://github.com/gyguan/harmonyos-homework-assistant/issues/393)

## Context

家长需要对比模型直接看图与原有 Core Vision OCR 后整理的效果。一张老师通知可能包含多个科目，强制指定单一科目会覆盖模型的逐项科目判断。

## Decision

1. 布置作业科目默认自动识别，以 null 表达未指定，不把「其他」当成自动识别。明确指定时继续覆盖全部候选科目。
2. 页面默认 AI 图片解析，选择图片后预览，家长点击「整理并继续」才发送。页面告知图片会交给 AI；保留「文字识别」切换，可对当前图片复用原系统 OCR 和文字编辑/整理链路。
3. 新增无状态 `POST /api/v1/students/{studentId}/homework/organize-image`，输入 Base64 图片及 MIME，返回 recognizedText、assignments、mode=AI_IMAGE。原文字 API 和系统 OCR 均保留。
4. 服务端复用现有 Provider Transport，支持 Responses 的 input_image 和 Chat Completions 的 image_url。`AI_IMAGE_ORGANIZER_MODEL` 独立选择图片模型，未配置时沿用整理模型；provider/base URL/key/protocol 复用现有配置，不在客户端保存模型密钥。
5. 原图在客户端内存中重编码为 JPEG，长边最多3072、质量90，上传不超过4MB；后端校验 Base64、MIME、可解码内容与像素上限。图片不接受外链，不存数据库，不写临时文件，不记录 HTTP/AI payload，即使调试 payload 已开启也跳过图片链路。
6. 家庭归属校验先于模型调用。异步前捕获 studentId，迟到结果只保存原孩子导入记录，不能覆盖新孩子草稿或触发确认跳转。
7. AI 未配置、模型不支持图片、结果不完整时明确报告失败，不自动改用 OCR；这样对比结果能明确区分来自哪条路径。
8. 图片与文字均复用 Candidate Assignment / ImportBatch / Source Evidence / 家长确认 / 批量发布，不建设第二套作业模型。

## Consequences

- 允许多科图片形成逐项候选，保留人工核对和来源追溯。
- 原图片识别链路可以随时切回，不需要撤销代码或数据库迁移。
- 解析质量需用实际部署的视觉模型和真实老师通知图片验收；文本模型不会因为支持 OpenAI 协议就自动获得图片能力。
- 临时图片可随请求释放，模型服务商对输入的处理仍取决于所配置服务商的设置与策略。
