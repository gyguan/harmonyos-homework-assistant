# Project Context

## Product

**小伴作业 / HarmonyOS Homework Assistant**：面向深圳小学家庭的作业工作台。它不是搜题 App，核心是把老师分散在聊天、截图、文档、语音和视频里的作业统一变成学生可执行、可获得 AI 辅导、家长可跟进的结构化作业。

## Ubiquitous language

- **Family（家庭）**：家长与一个或多个学生共享的私有空间，是数据隔离的基本边界。
- **Parent（家长）**：创建家庭、导入/确认老师作业、配置辅导规则、查看学生实时进度的监护角色。
- **Student（学生）**：查看今日任务、使用老师资料与 AI 辅导、完成并提交作业的执行角色。
- **Assignment（作业）**：需要学生完成的一项独立任务，包含学科、要求、截止时间、来源、状态和关联资料。
- **Resource（资料）**：老师或家长提供的图片、文档、音频、视频、文本等学习材料，可与多个作业关联。
- **Submission（提交）**：学生对某个作业提交的照片、录音、视频或文本，以及提交时间与状态。
- **Textbook（教材）**：按城市、学段、年级、学期、学科、出版社、册、单元、课组织的教材目录元数据。
- **Homework Import（作业导入）**：把微信/钉钉分享内容、聊天截图、粘贴文本、文件或音视频转成候选作业。
- **Candidate Assignment（候选作业）**：AI 从非结构化内容解析出的、尚待家长确认的 Assignment。
- **Homework Confirmation（作业确认）**：家长对候选作业进行修改、拆分、合并并最终发布给学生的动作。
- **Source Evidence（来源证据）**：Candidate Assignment 与老师原始文字、截图区域、文件页码或音视频时间段之间的可追溯关系，用于家长快速验证 AI 解析是否正确。
- **Progress（进度）**：Assignment 从未开始、进行中、待提交、已提交到已完成的状态及时间记录。
- **Today（今天）**：学生端最核心的工作视图，只展示当前需要行动的作业。
- **Study Workspace（学习作业工作台）**：学生真正完成某项 Assignment 的工作界面，聚合老师资料、当前作业内容、AI 辅导和提交入口。Phone 以单任务为主；Pad 优先双栏同屏。
- **Tutor Session（辅导会话）**：围绕一个 Assignment 或其具体问题发生的 AI 辅导上下文，自动带入当前教材、老师要求和老师资料。
- **Hint（提示）**：AI Tutor 在引导模式下提供的分层帮助，从理解问题、轻提示、下一步到完整解释逐级增加信息量。
- **Tutor Policy（辅导策略）**：由家长配置的 AI 辅导规则，例如引导优先、是否允许完整讲解、是否禁止直接展示答案、语音能力和使用时长。
- **Parent Intervention（家长介入）**：AI 判断不适合继续自主辅导、学生主动求助或作业异常时，请求家长处理的状态/动作。
- **Weekly Review（周报）**：面向家长的周期性总结，关注按时完成率、用时、重复困难、辅导使用情况和需要关注事项，而非孩子排名。

## Product rules

1. AI 负责理解和结构化老师内容，不单方面判定学生是否真正完成作业。
2. AI 解析形成的候选作业默认经过家长确认后再发布给学生。
3. 每个 Candidate Assignment 应尽可能保留 Source Evidence，避免“AI 说了算”。
4. 微信/钉钉首版只处理用户主动提供给 App 的内容，不后台读取聊天记录。
5. 教材目录与正版教材内容分离：目录元数据可维护，受版权保护的教材全文/音视频需合法授权。
6. 学生提交与家庭数据默认属于 Family 私有空间。
7. Phone 以逐项执行为主；Pad 利用大屏进行列表/详情、资料/辅导、导入/解析结果同屏。
8. AI Tutor 默认采用“引导优先”而不是直接给答案；数学强调过程，作文强调选材/提纲/修改而不是代写成文。
9. AI 辅导上下文优先级：老师明确要求 > 老师资料 > 当前教材 > 通用知识。
10. 家长看到的是作业进度，不做摄像头监控、键盘记录等过度监控能力。

## Initial technical direction

- Client: HarmonyOS 6.0, ArkTS, ArkUI
- Layout: responsive by current window width; Phone + Pad
- Backend: Spring Boot
- Database: PostgreSQL
- Cache / lightweight jobs: Redis
- Media: object storage
- AI import pipeline: OCR / speech transcription / task splitting / subject detection / due-time extraction / textbook matching / source evidence
- AI tutor pipeline: assignment context / teacher resources / textbook context / graded hints / parent policy

## Product baseline

当前产品设计基线：`docs/product/product-design-v1.md`。

主链路：

`Homework Import → Candidate Assignment → Homework Confirmation → Assignment → Study Workspace → Tutor Session (optional) → Submission → Progress / Weekly Review`

## Open decisions

通过 GitHub Issues 与 ADR 持续明确：身份体系、教材授权策略、AI 服务选型、OCR/ASR 端云边界、家庭实时同步机制、离线能力、通知策略、Tutor Policy 细节和儿童隐私合规细节。
