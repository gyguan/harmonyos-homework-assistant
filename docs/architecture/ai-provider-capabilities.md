# AI Provider 能力与跨模型兼容架构

## 1. 目标

后端 AI 能力必须以 Provider Capability 为边界，而不是在业务代码中判断模型名称。

固定分层：

```text
Business
  -> Model Client
  -> AiProviderCapabilityResolver
  -> OpenAiCompatibleTransport
  -> Provider API
  -> StructuredJsonNormalizer / Canonical Contract
  -> Domain Validator
```

业务层禁止出现 `glm-*`、`deepseek-*`、`gpt-*` 等模型名分支。

## 2. Provider Capability Matrix

| Provider | 首选协议 | Chat Structured Output | Responses Structured Output | 说明 |
| --- | --- | --- | --- | --- |
| OpenAI | 跟随配置 | JSON_SCHEMA → JSON_OBJECT → TEXT | JSON_SCHEMA → JSON_OBJECT → TEXT | 强 Schema 优先 |
| DeepSeek | 跟随配置 | JSON_OBJECT → TEXT | JSON_SCHEMA → JSON_OBJECT → TEXT | 避免假设所有 Chat 模型都严格支持 Schema |
| Zhipu GLM-4.7+ | Chat Completions | JSON_SCHEMA → JSON_OBJECT → TEXT | 不作为默认能力 | GLM-4.7、4.7-Flash、5.x 统一走能力链 |
| Zhipu GLM < 4.7 | Chat Completions | JSON_OBJECT → TEXT | 不作为默认能力 | 保守兼容 |
| Generic OpenAI-compatible | 跟随配置 | JSON_OBJECT → TEXT | JSON_OBJECT → TEXT | 不猜测 Schema 能力 |

Provider Capability 只决定协议与结构化输出能力。业务 Canonical Contract、质量 Validator、发布流程不因 Provider 改变。

## 3. GLM-4.7+ 配置

智谱开放平台通用接口使用 OpenAI-compatible Chat Completions。推荐配置：

| 环境变量 | 推荐值 |
| --- | --- |
| `AI_PROVIDER` | `ZHIPU_GLM` 或 `AUTO` |
| `AI_BASE_URL` | `https://open.bigmodel.cn/api/paas/v4` |
| `AI_CHAT_COMPLETIONS_PATH` | `/chat/completions` |
| `AI_PROTOCOL` | `chat-completions` |
| `AI_TUTOR_MODEL` | `glm-4.7` 或更高版本 |
| `AI_ORGANIZER_MODEL` | 可留空，默认继承 Tutor Model |
| `AI_PRACTICE_MODEL` | 可留空，默认继承 Organizer/Tutor Model |

Z.ai 国际端点可将 `AI_BASE_URL` 配置为 `https://api.z.ai/api/paas/v4`，其余配置保持一致。

`AUTO` 会在 capability resolver 内根据 base URL / model 识别 Provider。生产环境如果通过企业代理网关转发，建议显式设置 `AI_PROVIDER=ZHIPU_GLM`，避免代理域名丢失 Provider 特征。

## 4. GLM 版本边界

以下模型按 GLM-4.7+ 能力处理：

- `glm-4.7`
- `glm-4.7-*`
- `glm-5`
- `glm-5.x`
- 后续主版本高于 5 的 `glm-*`

GLM-4.6 及更早版本默认不声明 JSON Schema 能力，走 `JSON_OBJECT → TEXT`。

## 5. Practice 结构化输出协商

Practice 生成不会通过字段别名猜测模型语义。

流程：

1. Resolver 返回当前 Provider 的 protocol + output mode 顺序。
2. 按能力顺序请求模型。
3. 每轮输出必须进入唯一 Canonical Contract。
4. Canonical 失败才切换到下一种 output mode 重新生成。
5. 所有模式均失败才向业务返回失败。

禁止新增类似 `question -> stem`、`content -> stem` 的模型字段猜测补丁。

## 6. 新 Provider 接入规则

新增 Provider 时只允许修改以下边界：

1. `AiProviderCapabilities`
2. `AiProviderCapabilityResolver`
3. 必要时扩展 Transport 协议实现
4. Provider Contract Test Matrix

不允许因为新 Provider 修改：

- Practice Domain Model
- Practice Canonical Contract
- Practice Validator
- 发布/作答流程

## 7. Contract Test Gate

每个 Provider 至少验证：

- Provider 自动/显式识别
- 首选 API protocol
- Structured Output mode 顺序
- Canonical JSON 正常解析
- 首选 mode 不满足 Contract 时的 fallback
- 未知字段/Provider 扩展元数据不会污染业务 Contract
- 错误日志不得输出 API Key

只有 Provider Contract Test 通过，才视为正式支持。
