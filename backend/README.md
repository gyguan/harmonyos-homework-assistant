# 小伴作业 Backend V0.2

一个 Spring Boot 模块化单体，为家庭提供孩子资料、已确认作业、提交记录和 AI Tutor 的云端能力。继续坚持简单架构：一个 Spring Boot、一个 PostgreSQL，不使用 Redis、MQ、API Gateway、微服务或工作流引擎。

## 本地启动

前置：JDK 21、Maven 3.6.3+、Docker、Python 3.10+。

```powershell
docker compose -f backend/docker-compose.yml up -d
```

```powershell
cd backend; mvn test
```

```powershell
cd backend; mvn spring-boot:run
```

健康检查：

```powershell
curl http://localhost:8080/api/v1/health
```

默认开发账号：`parent / parent123`。部署环境必须通过 `BOOTSTRAP_PASSWORD` 修改密码，或设置 `BOOTSTRAP_ENABLED=false`。

## 真实 Backend E2E Smoke

仓库提供 `backend/scripts/e2e_smoke.py`，直接验证正在运行的真实 PostgreSQL + Spring Boot，而不是 Mock 或 H2。脚本只使用 Python 标准库，会创建独立的 `e2e-*` 学生/作业数据并覆盖以下能力：

- health、登录与 `/auth/session`；
- Student 新增、修改、删除和查询；
- Assignment 创建与更新；
- 使用旧 version 更新时必须返回 `409`；
- Assignment 状态流转；
- Tutor 对话的 fallback 或真实模型模式；
- multipart 作业照片上传；
- 未鉴权照片读取必须返回 `401`，Bearer 鉴权后可正常下载；
- Submission 查询以及提交后 Assignment 进入 `SUBMITTED`。

### 1. 无模型配置：验证主链路 + Tutor 降级

保持 PostgreSQL 与 backend 正常运行，在仓库根目录执行：

```powershell
python backend/scripts/e2e_smoke.py --expect-tutor-unavailable
```

成功结尾应看到 `BACKEND_E2E_SMOKE_PASS`。本次登录 token 会保存在 `backend/.e2e-session.json`；该文件已加入 `.gitignore`，不要复制到仓库或聊天中。

### 2. 验证 backend 重启后 session 仍有效

第一轮 smoke 成功后，仅重启 Spring Boot，不要删除 PostgreSQL volume，然后执行：

```powershell
python backend/scripts/e2e_smoke.py --session-only
```

成功结尾应看到 `BACKEND_SESSION_RESUME_PASS`。这一步直接验证 opaque Bearer token 确实持久化在 PostgreSQL，而不是进程内存。

### 3. 配置真实模型：验证 OpenAI Responses 链路

通过环境变量或 `backend/config/application-local.yml` 配置模型。PowerShell 单行启动示例：

```powershell
$env:OPENAI_API_KEY="你的Key"; $env:OPENAI_MODEL="你的可用模型"; cd backend; mvn spring-boot:run
```

随后在仓库根目录执行：

```powershell
python backend/scripts/e2e_smoke.py --expect-tutor-available
```

该模式要求 Tutor 返回 `available=true`，并至少产生一条 assistant 消息；否则 smoke 失败。服务端调用仍固定 `store=false`，API Key 不进入 HarmonyOS App。

### 4. 非默认后端地址或账号

```powershell
python backend/scripts/e2e_smoke.py --base-url http://192.168.1.10:8080 --login-name parent --password parent123
```

如果使用自定义 token 文件：

```powershell
python backend/scripts/e2e_smoke.py --token-file D:\temp\xiaoban-e2e-session.json
```

## 配置

- `DB_URL` / `DB_USERNAME` / `DB_PASSWORD`：PostgreSQL。
- `AUTH_TOKEN_TTL_HOURS`：登录会话有效期，默认 168 小时。随机 Bearer token 保存于 PostgreSQL，后端重启后仍有效。
- `APP_STORAGE_ROOT`：作业照片目录，默认 `./data/uploads`。
- `OPENAI_API_KEY`：可选。未配置时 Tutor 明确降级，作业主流程不受影响。
- `OPENAI_MODEL`：Tutor 模型，默认 `gpt-5.6-luna`。
- `OPENAI_BASE_URL`：默认 `https://api.openai.com`。

## 数据与 API 边界

端侧继续负责 OCR、老师消息解析、Candidate 家长确认；只有确认发布后的 Assignment 进入云端。

核心 API：

- `POST /api/v1/auth/login`
- `GET /api/v1/auth/session`
- `POST /api/v1/auth/logout`
- `GET /api/v1/students`
- `PUT /api/v1/students`
- `DELETE /api/v1/students/{id}`
- `GET/POST /api/v1/students/{studentId}/assignments`
- `PATCH /api/v1/assignments/{id}`
- `GET/POST /api/v1/assignments/{id}/submissions`
- `GET /api/v1/submission-photos/{photoId}`
- `GET /api/v1/assignments/{id}/tutor`
- `POST /api/v1/assignments/{id}/tutor/messages`

## AI Tutor

Tutor 链路保持简单：`TutorController → TutorService → TutorModelClient → OpenAI Responses API`。Prompt、API Key 和模型选择都只在服务端；HarmonyOS App 不包含服务商凭证。

对话历史由本项目 PostgreSQL 的 `tutor_session/tutor_message` 保存。调用 Responses API 时固定 `store=false`，不依赖服务商保存会话状态。默认策略是提示优先；未允许直接答案时，不输出可直接抄写的完整答案或作文成品。

## 同步语义

- HarmonyOS 本地 Store 仍是 UI 的缓存和离线读取来源。
- 服务端是跨设备共享数据源。
- 首次重连或没有已观察到远端版本时，服务端数据优先；不做 CRDT/复杂离线合并。
- Demo/seed Assignment 不自动上传，只有家长确认发布后的真实 Assignment 自动进入云端。
- 同设备提交保留本地照片预览；另一设备同步时显示云端提交元数据。云端照片下载端点仍要求 Bearer 鉴权，不为了图片预览暴露公开 URL。

## HarmonyOS 端

家长进入“我的”可配置后端地址、登录、同步、新增/编辑/删除孩子。登录 token 保存在 App 私有 Preferences，启动时自动恢复并向 `/auth/session` 校验。

学生进入真实云端 Assignment 后，“问小伴”会读取/继续服务端 Tutor 对话。没有网络、未登录或模型未配置时，Tutor 只显示降级提示，作业查看、完成和本地提交仍然可用。
