# Project Context

## Product

**小伴作业 / HarmonyOS Homework Assistant**：面向深圳小学家庭的作业工作台。它不是搜题 App，核心是把老师分散在聊天、截图、文档、语音和视频里的作业统一变成学生可执行、家长可跟进的结构化作业。

## Ubiquitous language

- **Family（家庭）**：家长与一个或多个学生共享的私有空间，是数据隔离的基本边界。
- **Parent（家长）**：创建家庭、导入/确认老师作业、查看学生实时进度的监护角色。
- **Student（学生）**：查看今日任务、使用老师资料、完成并提交作业的执行角色。
- **Assignment（作业）**：需要学生完成的一项独立任务，包含学科、要求、截止时间、来源、状态和关联资料。
- **Resource（资料）**：老师或家长提供的图片、文档、音频、视频、文本等学习材料，可与多个作业关联。
- **Submission（提交）**：学生对某个作业提交的照片、录音、视频或文本，以及提交时间与状态。
- **Textbook（教材）**：按城市、学段、年级、学期、学科、出版社、册、单元、课组织的教材目录元数据。
- **Homework Import（作业导入）**：把微信/钉钉分享内容、聊天截图、粘贴文本、文件或音视频转成候选作业。
- **Candidate Assignment（候选作业）**：AI 从非结构化内容解析出的、尚待家长确认的 Assignment。
- **Homework Confirmation（作业确认）**：家长对候选作业进行修改、拆分、合并并最终发布给学生的动作。
- **Progress（进度）**：Assignment 从未开始、进行中、待提交、已提交到已完成的状态及时间记录。
- **Today（今天）**：学生端最核心的工作视图，只展示当前需要行动的作业。

## Product rules

1. AI 负责理解和结构化老师内容，不单方面判定学生是否真正完成作业。
2. AI 解析形成的候选作业默认经过家长确认后再发布给学生。
3. 微信/钉钉首版只处理用户主动提供给 App 的内容，不后台读取聊天记录。
4. 教材目录与正版教材内容分离：目录元数据可维护，受版权保护的教材全文/音视频需合法授权。
5. 学生提交与家庭数据默认属于 Family 私有空间。
6. Phone 以逐项执行为主；Pad 利用大屏进行列表/详情、资料/作业、导入/解析结果同屏。

## Initial technical direction

- Client: HarmonyOS 6.0, ArkTS, ArkUI
- Layout: responsive by current window width; Phone + Pad
- Backend: Spring Boot
- Database: PostgreSQL
- Cache / lightweight jobs: Redis
- Media: object storage
- AI pipeline: OCR / speech transcription / task splitting / subject detection / due-time extraction / textbook matching

## Open decisions

通过 GitHub Issues 与 ADR 持续明确：身份体系、教材授权策略、AI 服务选型、OCR/ASR 端云边界、家庭实时同步机制、离线能力、通知策略和儿童隐私合规细节。
