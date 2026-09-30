# Issue #393｜布置作业 AI 图片解析

## 配置

在 `backend/config/application-local.yml` 的 `app.ai` 下增加：

```yaml
image-organizer-model: 你的视觉模型名称
```

或者设置 `AI_IMAGE_ORGANIZER_MODEL`。模型必须支持图片输入，provider/base-url/api-key/protocol 沿用已有配置；为空时沿用 organizer-model。不要把只支持文本的模型当作视觉模型使用。

后端和客户端需同时更新；原 `/homework/organize` 文字接口保持可用，无数据库迁移。

## 第三方服务 HTTP 406 排障（Issue #395）

HTTP 406 表示上游服务或网关拒绝了请求；仅凭状态码不能断定模型不支持图片。
日志中的 `provider=DEEPSEEK` 可以由模型名称自动推导，不代表请求一定发给 DeepSeek 官方。
文本调用成功也不能证明该模型部署支持图片：需确认服务商在当前 base URL 上提供的模型支持
Chat Completions `image_url.url=data:image/jpeg;base64,...` 或 Responses `input_image.image_url`。

1. 按服务商公布的模型列表，把 `image-organizer-model` 配置为明确支持图片且接受 Base64 data URL 的模型 ID；不要只改 provider 名称，也不要随意为模型 ID 加 `vision` 后缀。
2. 重启后端，检查启动日志中的 `imageOrganizerModel` 是否生效。如果当前值是文本模型，可只更换图片模型，文字整理与 Tutor 模型不必更换。
3. 图片模型必须在同一 base URL / API key 下可访问；如果需要另一服务商，当前配置不能仅通过修改模型 ID 切换服务商。
4. 查看相同 requestId 的 `image_request_rejected`：`status` 为上游 HTTP 状态，`reason` 为本地固定错误类别，`responseType` 仅为 JSON/HTML/TEXT/OTHER/MISSING。
   406 默认 `REQUEST_REJECTED`；仅在上游返回已知的图片不支持错误码时报告 `IMAGE_UNSUPPORTED`。401/403 表示鉴权或权限，429 表示限流/额度，413 表示请求过大，5xx 表示上游服务不可用。
5. 向服务商反馈该 requestId 对应的时间、模型 ID、HTTP 状态与输入协议，确认网关图片限制。不要提供图片、孩子信息或 API key。

错误提示保留上游状态和可操作建议，仍以本服务 HTTP 503 返回；上游响应正文、任意错误消息、
原始错误码及原始 Content-Type 均不记录或返回。代码不因 406 自动重试、换协议或静默切换 OCR。
未取得第三方服务地址/能力说明/错误原因时，不能宣称此次 406 已通过模型调用验证修复。

## 使用与回退

1. 布置作业 → 保持「自动识别」科目和「AI图片解析」。
2. 在最上方的「作业内容」点击「拍照」或「选图片」，选择含多个科目的老师通知，检查图片预览。图片解析方式在选图后显示。
3. 点击「整理并继续」，图片经后端传给模型，结果进入原有核对发布页。
4. 核对各项科目、标题、页码、要求、预计用时、原文；只有家长确认后才发布。
5. 若效果不佳，返回布置作业，切换「文字识别」。保留同一张图片，点击「识别文字」，修改原 OCR 结果后再次「整理并继续」。也可在该模式重新拍照/选图。
6. 直接输入文字仍可整理；内容下方「科目（可选）」默认收起并显示自动识别，展开后可指定语文/数学/英语/其他，此时所有候选使用指定科目。

Issue #397 页面层级：作业内容 → 可选科目 → 待核对作业 → 导入记录。
底部固定保留「整理并继续」主动作，并提示核对后才发布；图片选择按钮不提前宣称完成识别。

## 手工验收

| 场景 | 预期 |
| --- | --- |
| 图片含语数英，不指定学科 | 各项保留不同科目，进入核对页 |
| 图片含多个科目，明确选择数学 | 候选科目统一数学 |
| 多科文字，不指定学科 | AI/本地解析保留逐项科目 |
| 切换为文字识别 | 原 Core Vision OCR 先填入可编辑文字，后续整理 |
| 模型无图片能力/未配置/网络失败 | 明确提示，原图片保留，可切换 OCR |
| 非作业通知 | 没有候选，不凭空构造作业 |
| 解析途中切换孩子 | 不覆盖新孩子草稿、不进入新孩子确认页 |
| 模糊、旋转、手写、长截图 | 逐项对比 AI 与 OCR，不猜补模糊页码 |
| Phone / Pad / 大字体 | 控件不溢出，主动作固定底部，内容限制可读宽度 |
| 开启 HTTP_LOG_PAYLOADS / AI_LOG_PAYLOADS | 图片请求、recognizedText 和图片解析响应不出现在 payload 日志 |

## 自动验证

- ImageTransportTest：真实本地 HTTP 接收两协议的多模态请求，检查图片、结构化输出和日志排除；保护旧文字输入形状。
- HomeworkImageInputTest：有效图片、错误 Base64、伪造 MIME、非图片、超限、家庭隔离、失败提示。
- ConfigurableHomeworkOrganizerModelClientTest：多科解析、缺少原文、无效科目、零作业结果。
- 既有前端导入静态门禁更新为可选科目和显式 OCR 回退；保留布局、原 OCR 和确认流程门禁。

实际模型效果与 HarmonyOS 真机/HAP 编译需要在配置好模型和 DevEco 的环境中验证。
