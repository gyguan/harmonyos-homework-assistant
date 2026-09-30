# ADR-0003: 作业图片 AI 直接解析与可回退 OCR

- Status: Accepted
- Date: 2026-09-30
- Spec: [Issue #393](https://github.com/gyguan/harmonyos-homework-assistant/issues/393)
- Interaction update: [Issue #399](https://github.com/gyguan/harmonyos-homework-assistant/issues/399)

## Context

家长需要对比模型直接看图与原有 Core Vision OCR 后整理的效果。一张老师通知可能包含多个科目，强制指定单一科目会覆盖模型的逐项科目判断。

## Decision

1. 布置作业科目默认自动识别，以 null 表达未指定，不把「其他」当成自动识别。明确指定时继续覆盖全部候选科目。
2. 页面默认 AI 图片解析，选择图片后预览，文字框始终可编辑，家长点击「整理并继续」才一并发送图片与补充文字。移除常驻解析方式选项；「识别图片文字」作为显式备用操作，读取成功后复用文字整理链路，也可对同图重新使用图片解析。选图、移除图片和清空文字互不删除另一种输入。
3. 新增无状态 `POST /api/v1/students/{studentId}/homework/organize-image`，输入 Base64 图片、MIME和可选text（最多12000字），返回recognizedText（仅图片原文）、assignments、mode=AI_IMAGE。原文字API和系统OCR均保留；旧客户端不传text仍可使用。
4. 服务端复用现有 Provider Transport，支持 Responses 的 input_image 和 Chat Completions 的 image_url。`AI_IMAGE_ORGANIZER_MODEL` 独立选择图片模型，未配置时沿用整理模型；provider/base URL/key/protocol 复用现有配置，不在客户端保存模型密钥。
5. 原图在客户端内存中重编码为 JPEG，长边最多3072、质量90，上传不超过4MB；后端校验 Base64、MIME、可解码内容与像素上限。图片不接受外链，不存数据库，不写临时文件，不记录 HTTP/AI payload，即使调试 payload 已开启也跳过图片链路。
6. 家庭归属校验先于模型调用。异步前捕获 studentId，迟到结果只保存原孩子导入记录，不能覆盖新孩子草稿或触发确认跳转。
7. AI 未配置、模型不支持图片、结果不完整时明确报告失败，不自动改用 OCR；这样对比结果能明确区分来自哪条路径。
8. 图片与文字均复用 Candidate Assignment / ImportBatch / Source Evidence / 家长确认 / 批量发布，不建设第二套作业模型。图片解析须同时整理补充文字，重复任务合并；图片原文和用户原始补充文字都保留在来源证据中，不只保留模型输出。

## Consequences

- 允许多科图片形成逐项候选，保留人工核对和来源追溯。
- 原图片识别链路可以随时切回，不需要撤销代码或数据库迁移。
- 解析质量需用实际部署的视觉模型和真实老师通知图片验收；文本模型不会因为支持 OpenAI 协议就自动获得图片能力。
- 临时图片可随请求释放，模型服务商对输入的处理仍取决于所配置服务商的设置与策略。
