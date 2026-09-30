# 后端日志规范

本文是小伴作业 Spring Boot 后端的日志实现基线。后端新增或修改日志时必须遵守本规范。

## 1. 目标

日志用于回答三类问题：

1. **一次请求发生了什么**：通过 `requestId / scene` 串起 HTTP、业务 Service 和外部调用。
2. **业务状态为什么变化**：记录关键业务事件，而不是记录每个方法进入/退出。
3. **失败发生在哪一层**：区分业务校验、可恢复降级、外部依赖失败和未预期异常。

日志不是业务数据副本，不用于保存作业正文、聊天内容、图片内容或认证凭据。

## 2. 统一格式

业务日志统一采用：

```text
domain event key=value key=value ...
```

示例：

```text
assignment state_changed assignmentId=a-1 studentId=s-1 action=START from=NOT_STARTED to=IN_PROGRESS
submission created assignmentId=a-1 submissionId=... photoCount=3 totalBytes=4281821
practice_generation ready generationId=... paperId=... questionCount=10 elapsedMs=1380
```

禁止使用低信息量日志：

```text
进入 create 方法
处理开始
处理成功
```

## 3. requestId / scene

HTTP 请求统一由 `AccessLogFilter`：

- 读取或生成 `X-Request-Id`；
- 读取 `X-Client-Scene`；
- 写入 MDC：`requestId`、`scene`；
- 在请求完成后清理 MDC。

控制台日志格式必须输出 MDC 中的 `requestId / scene`。

业务 Service **不要自行生成新的 requestId**，也不要把 requestId 逐层作为业务参数传递。

Scheduler / Bootstrap 等非 HTTP 链路没有 requestId 时，使用自身稳定业务键关联，例如：

- `planId`
- `runId`
- `fireAt`
- `triggerSource`

## 4. 日志级别

### INFO

记录已经发生的重要业务事实：

- Assignment 创建、状态变化、自动暂停、删除；
- Submission 创建；
- 家长验收；
- Practice 生成完成、发布、练习开始、交卷；
- 语音素材批次创建/完成；
- 定时作业执行结果；
- Tutor 成功完成一次问答；
- 登录成功。

普通 `GET / list / page / find` 不额外记录 INFO，HTTP access log 已覆盖。

### WARN

用于可恢复异常、降级或需要关注但不代表系统失效的情况：

- AI/外部服务不可用或返回空结果；
- AI 结构化结果无法解析、质量校验失败；
- 素材目录无效；
- 登录失败；
- 文件 best-effort 清理失败；
- API ServiceUnavailable。

### ERROR

只记录未预期、需要处理的异常：

- 未被业务异常模型覆盖的 500；
- 可能导致数据不一致的最终失败；
- 后台任务最终失败且无法恢复。

ERROR 应保留 Throwable 堆栈。业务参数错误、404、409 不打 ERROR。

## 5. 隐私与敏感信息

下列内容默认禁止进入日志：

- 密码、passwordHash；
- session token、Authorization、API key；
- 孩子姓名等非必要个人信息；
- 作业 title / instruction / sourceExcerpt 正文；
- reviewNote；
- Tutor 用户问题、AI 回复、会话正文；
- AI Prompt / Response 全文；
- 图片、音频内容；
- 上传文件名、原始路径；
- Practice 题干、答案、笔记正文；
- generatedJson 等完整结构化内容。

允许记录排障所需的非正文元数据：

- accountId / familyId / studentId；
- assignmentId / submissionId / attemptId / generationId；
- packageId / batchId / planId / runId；
- subjectCode / contentType / status / action；
- 数量、字节数、耗时；
- model / provider / protocol；
- exception class；
- 经过长度限制和换行清理的错误摘要。

## 6. HTTP 与 Controller

Controller 不重复打印“请求进入/请求成功”。

统一 HTTP access log 由 `AccessLogFilter` 负责：

- method
- uri
- status
- elapsedMs
- requestId
- scene
- duplicate request

业务日志应写在真正完成状态变化的 Service 层。

## 7. 外部调用

AI / HTTP / Storage 等外部调用记录：

- provider / model / path；
- 成功/失败；
- status；
- elapsedMs；
- response size 或 output chars；
- exception class。

默认不记录 payload。生产环境保持：

```yaml
app.http.log-payloads: false
app.ai.log-payloads: false
```

需要临时诊断 payload 时必须使用既有脱敏与长度限制能力，诊断结束后关闭。

## 8. 文件与媒体

不要为每个成功上传文件打印 INFO。

建议：

- 单文件保存成功：默认不打 INFO；
- 批次完成：INFO 聚合；
- 无效素材目录：WARN + reason code；
- rollback / cleanup 失败：WARN。

不要打印原始文件名和本地存储路径。

## 9. 推荐事件

| Domain | Event |
| --- | --- |
| auth | `login_success`, `login_failed` |
| assignment | `created`, `state_changed`, `auto_paused`, `deleted` |
| assignment_review | `completed` |
| submission | `created` |
| practice_generation | `started`, `ready`, `failed`, `published` |
| practice_attempt | `started`, `submitted` |
| tutor | `ask_success`, `ask_unavailable`, `ask_failed` |
| voice_material | `batch_created`, `package_registered`, `package_invalid`, `batch_completed`, `manual_create_*`, `auto_create_*` |
| scheduled_assignment | 保持现有 execution / run / retry / advance 事件 |

## 10. 合并前检查

涉及后端日志的 PR 至少确认：

- 是否能通过 requestId / 业务 ID 串起链路；
- 是否只记录了关键业务事件；
- 是否误打了正文、儿童数据、认证凭据；
- 是否把正常 4xx 当 ERROR；
- 是否给普通查询增加大量 INFO；
- 是否把外部调用 payload 默认打开；
- 是否运行 `python scripts/validate_backend_logging.py`；
- 是否运行 `mvn -f backend/pom.xml test`。
