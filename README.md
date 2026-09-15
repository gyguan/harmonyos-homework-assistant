# 小伴作业 · HarmonyOS Homework Assistant

面向一个家庭的 HarmonyOS AI 作业管家。

> 家长把老师消息交给小伴整理并确认发布；孩子只管完成作业、需要时问小伴；家长最后看进度和提交结果。

## 当前产品定位

当前版本聚焦三件事：

1. **收作业**：老师文字 / 聊天截图 → OCR / 智能整理 → Candidate Assignment → 家长确认发布；
2. **做作业**：孩子进入自己的空间，只看当前孩子的作业，选择任务、计时完成、拍照提交，需要时使用 AI Tutor；
3. **看进度**：家长按孩子查看未开始、进行中、待提交、已提交、已完成、需重做等状态，并查看提交照片。

## 产品边界

当前按**单家庭、多孩子**设计，仍保持家庭工具的轻量边界：

- 不建设 School / Teacher / Organization 等学校组织体系；
- 不做班级社交、排行榜、题库平台、在线课堂；
- 不后台读取微信 / 钉钉，导入必须由用户主动截图、粘贴或选择内容；
- AI 整理结果默认经过家长确认后才发布；
- 学生进入后身份固定，不可切换到兄弟姐妹或家长空间；家长可切换当前查看的孩子；
- AI Tutor 默认“引导优先”，是否允许直接答案由家长配置；
- Raw Import / Candidate 等老师原文解析中间态保留在端侧；发布后的 Assignment / Submission 才进入可选家庭云端。

## 核心业务链路

`老师原始内容 → OCR/解析 → Candidate Assignment → 家长确认 → Assignment → 学生学习/AI Tutor → Submission → 家长验收/进度`

核心端侧对象：

- `StudentProfile`
- `Assignment`
- `CandidateAssignment`
- `Submission`
- `TutorSession`
- `AppSettings`

## 架构原则

### HarmonyOS 端

保持轻量边界：

`ArkUI Pages → HomeworkStore / Application Service → Persistence / Remote API / AI Port`

页面不直接访问 Preferences、OCR SDK 或后端 HTTP 实现。主要可替换边界包括：

- `HomeworkPersistence`
- `HomeworkTextExtractor`
- `HomeworkAssignmentParser`
- Remote API / Tutor API

### 可选家庭云端

云端采用单体架构：

`HarmonyOS App → Spring Boot → PostgreSQL / FileStorage / TutorModelClient`

约束：

- Spring Boot 模块化单体，不拆微服务；
- PostgreSQL + Flyway；
- 不引入 Redis、MQ、API Gateway、工作流引擎或 CQRS；
- Assignment 使用 `version` 做乐观并发；
- 客户端持久化 `remoteVersion / syncDirty / lastSyncedAtEpochMs`，重启后仍能正确判断是否需要上传；
- 同步冲突时不静默覆盖较新的服务端版本，最终服务端刷新为准；
- AI Provider 仅在服务端配置，App 不保存模型 API Key；
- OpenAI Responses API 适配保持 `store=false`，不依赖模型服务商保存家庭对话状态。

## 当前工程基线

- DevEco Studio：26.0.0
- `compileSdkVersion`: `26.0.0`
- `compatibleSdkVersion`: `6.0.0(20)`
- `targetSdkVersion`: 未显式设置
- project `modelVersion`: `5.0.0`
- Hvigor / `@ohos/hvigor-ohos-plugin`: `6.26.4`
- UI：ArkTS + ArkUI，Stage model
- Devices：Phone + Tablet
- Backend：Java 21 + Spring Boot + PostgreSQL + Flyway

## 当前已实现

### 家长端

- 人员入口选择与身份锁定；
- 多孩子资料管理与孩子上下文切换；
- 粘贴老师文字并智能拆分作业；
- 相册截图 + Core Vision OCR 导入；
- Candidate Source Evidence、低置信度提示、增删改与确认发布；
- Dashboard / Progress；
- 云端 Submission 元数据和照片读取；
- 对学生提交执行“通过 / 需要重做”验收；
- 家庭云端连接、会话恢复与手动同步；
- AI Tutor“引导优先 / 允许直接答案”家庭规则配置并本地持久化。

### 学生端

- “今天 / 作业 / 我的”完整导航；
- Phone / 中等窗口底部导航，Pad 大屏侧边导航；
- 从作业列表自主选择任务；
- 同一时间只允许一个进行中的作业；
- 作业倒计时 / 已用时跟踪，暂停后再次进入可继续；
- Study Workspace；
- AI Tutor 文字对话；
- 拍题图片选择 + OCR 后向 Tutor 提问；
- 1～6 张真实作业照片选择、预览和提交；
- “我的”只读展示当前学生资料、教材和家长设置的 Tutor 规则。

### 数据与云端

- ArkData Preferences 保存家庭端轻量快照；
- 单家庭多孩子数据隔离；
- Spring Boot + PostgreSQL 家庭 / Student / Assignment / Submission / Tutor 数据能力；
- opaque auth session 持久化；
- Student CRUD；
- Assignment 乐观并发与客户端持久化同步基线；
- Submission 图片上传、鉴权读取；
- Tutor session / message 服务端保存；
- OpenAI Responses API 适配与未配置模型时的 fallback。

## CI / Static Gate

GitHub Actions 会执行 HarmonyOS 静态约束和后端测试，包括：

- 工程版本与轻量架构边界；
- 文字导入、OCR / Parser / Confirmation；
- 真实照片提交；
- 多孩子隔离；
- 响应式导航与身份锁定；
- UI design-system；
- Backend V0.1 / V0.2 边界；
- 倒计时、任务选择、单任务计时；
- 家长验收；
- 学生“作业 / 我的”导航；
- 家长 Tutor 设置；
- AI 建议时长、Tutor 拍题、云端提交照片；
- Assignment 持久化同步元数据；
- Java 21 Maven tests。

单独执行基础 HarmonyOS Gate：

`python scripts/validate_harmony_project.py`

## 当前剩余验收

主链路代码已经进入 `main`。当前保留的工作主要是**真实环境验收**，不是继续扩展产品架构：

1. **DevEco 视觉验收**：本地 Build，并在 Phone / Pad / 宽屏模拟器检查所有主要页面的布局、截断和交互；
2. **家庭云端 E2E**：真实 PostgreSQL + backend + HarmonyOS App 跑一轮孩子管理、作业同步、照片提交、冲突和离线场景；
3. **AI Tutor E2E**：验证无模型配置 fallback、后端重启后 session 恢复，以及配置真实 `OPENAI_API_KEY` 后的 Responses API 调用与消息隔离。

这些验收项分别跟踪在 GitHub Issues #24、#28、#30；全部通过后即可收口 V0.1 产品基线 Issue #1。
