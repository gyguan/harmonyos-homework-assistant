# Project Context

## Product

**小伴作业 / HarmonyOS Homework Assistant**：面向一个家庭的 HarmonyOS 作业工作台。核心不是搜题，而是把老师分散在聊天、截图、文档、语音和视频里的作业统一变成学生可执行、可获得 AI 辅导、家长可跟进的结构化任务；同时为后续阅读、体育、实践、兴趣拓展等课外任务预留统一入口。

当前产品与重构基线：

- `docs/product/product-feature-list-v2.md`
- `docs/architecture/frontend-technical-design-v2.md`
- `docs/architecture/backend-technical-design-v2.md`
- `docs/architecture/system-technical-design-v2.md`
- `docs/adr/0002-v2-clean-refactor-and-migration.md`

V1 文档用于历史背景；V2 实现与后续决策以上述文档为优先基线。

## Ubiquitous language

- **Family（家庭）**：家长与一个或多个学生共享的私有空间，是数据隔离的基本边界。
- **Parent（家长）**：创建家庭、导入/确认老师作业、布置家庭课外任务、配置辅导规则、查看学生进度并验收提交的监护角色。
- **Student（学生）**：查看下一项任务、使用老师资料与 AI 辅导、完成并提交作业的执行角色。
- **Assignment（作业/任务）**：学生需要完成的一项独立任务。`assignmentType=SCHOOL` 表示课内作业，`assignmentType=EXTRA` 表示课外任务；二者共享同一领域模型、状态机、学习空间、提交与验收链路。
- **Assignment Filter（作业筛选）**：围绕类型、科目、日期、状态的统一查询条件，Phone 与 Pad 使用同一查询语义。
- **Resource（资料）**：老师或家长提供的图片、文档、音频、视频、文本等学习材料，可与 Assignment 关联。
- **Requirement（完成要求）**：某项 Assignment 的结构化完成要求，如完成题目、朗读、拍照、文字说明等。
- **Submission（提交）**：学生对某个 Assignment 提交的照片、录音、视频或文本，以及提交时间与状态。
- **Textbook（教材）**：按城市、学段、年级、学期、学科、出版社、册、单元、课组织的教材目录元数据。
- **Homework Import（作业导入）**：把用户主动提供的微信/钉钉分享内容、聊天截图、粘贴文本、文件或音视频转成候选作业。
- **Candidate Assignment（候选作业）**：AI 从非结构化内容解析出的、尚待家长确认的 Assignment。
- **Homework Confirmation（作业确认）**：家长对候选作业进行修改、拆分、合并并最终发布给学生的动作。
- **Source Evidence（来源证据）**：Candidate Assignment 与老师原始文字、截图区域、文件页码或音视频时间段之间的可追溯关系。
- **Progress（进度）**：Assignment 从未开始、进行中、暂停、待提交、已提交、完成或待订正的状态与时间记录。逾期在 V2 中优先作为基于 `dueAt + status` 的派生属性，而不是依赖定时任务修改状态。
- **Today（今天）**：学生端最核心的工作视图，重点回答“我现在应该做什么”。
- **Study Workspace（学习空间）**：学生真正完成某项 Assignment 的工作界面。Phone 为单任务沉浸式页面；Pad 只有在真实可用空间足够时才组合任务/内容/AI 多栏。
- **Tutor Session（辅导会话）**：围绕一个 Assignment 或具体问题发生的 AI 辅导上下文，带入当前作业、教材、老师要求和资料。
- **Hint（提示）**：AI Tutor 在引导模式下提供的分层帮助，从理解问题、轻提示、下一步到完整解释逐级增加信息量。
- **Tutor Policy（辅导策略）**：家长配置的 AI 辅导规则，例如引导优先、是否允许完整解释、是否允许直接答案等。
- **Parent Review（家长验收）**：家长查看 Submission 后执行通过或退回订正，并可附加 review note。
- **Parent Intervention（家长介入）**：AI 判断不适合继续自主辅导、学生主动求助或任务异常时，请求家长处理的状态/动作。
- **Weekly Review（周报）**：面向家长的周期性总结，关注完成率、用时、困难、辅导使用情况和需要关注事项，不做孩子排名。

## Product rules

1. AI 负责理解和结构化老师内容，不单方面判定学生是否真正完成作业。
2. AI 解析形成的候选作业默认经过家长确认后再发布给学生。
3. 每个 Candidate Assignment 应尽可能保留 Source Evidence，避免“AI 说了算”。
4. 微信/钉钉首版只处理用户主动提供给 App 的内容，不后台读取聊天记录。
5. 教材目录与正版教材内容分离：目录元数据可维护，受版权保护的教材全文/音视频需合法授权。
6. 学生提交与家庭数据默认属于 Family 私有空间。
7. 学生端原则：孩子少管理、多行动；首页突出下一项作业；Phone 核心流程保持单列。
8. 家长端原则：少操作、多掌握；首页聚焦完成情况、异常、待验收与导入入口。
9. AI Tutor 默认“引导优先”而不是直接给答案；数学强调过程，作文强调选材/提纲/修改而不是代写成文。
10. AI 辅导上下文优先级：老师明确要求 > 老师资料 > 当前教材 > 通用知识。
11. 家长看到的是作业进度，不做摄像头监控、键盘记录等过度监控能力。
12. SCHOOL / EXTRA 共用 Assignment，不建设两套平行业务体系。

## Technical direction

### Client

- HarmonyOS 6.0，ArkTS + ArkUI。
- Phone 与 Pad 都是一等形态，但不是两套产品。
- 导航逐步收敛到 `Navigation / NavDestination`。
- 新 V2 页面采用轻量 `Session + Repository + ViewModel`；不引入 Redux/MobX 等重型状态管理。
- `HomeworkStore` 仅作为迁移期兼容数据源，职责只减不增；新 Feature 不直接访问 `HomeworkStore.instance`。
- `AppShell` 仅负责角色、一级导航和应用级容器；业务路由与 Feature 特有状态不再继续堆入 AppShell。
- 业务页面是否多栏由实际容器可用宽度 + 内容最小可读宽度决定，不使用页面私有设备断点。
- 本地保留离线快照/弱网读取能力，服务端是跨设备共享数据的权威源。

### Backend

- Java 21 + Spring Boot 4.1.x 模块化单体。
- PostgreSQL + JPA + Flyway。
- 文件通过 `FileStorage` 抽象管理；当前可使用本地文件，未来可替换对象存储。
- 不引入 Redis、MQ、微服务、API Gateway 或工作流引擎，除非未来通过新的 ADR 明确批准。
- Assignment 是唯一作业主模型，统一支持 SCHOOL / EXTRA、subjectCode、结构化 `dueAt`、resources、requirements。
- 历史 Flyway migration 不修改，通过 V7+ 增量演进。
- Assignment 状态流转和权威计时逐步从通用 PATCH 收敛到后端 Action Command。
- `OVERDUE` 优先作为派生属性，不为此引入定时任务。

### AI

- 导入：OCR / 任务拆分 / 学科识别 / due-time extraction / textbook matching / source evidence。
- Tutor：assignment context / teacher resources / textbook context / graded hints / parent policy。
- 服务商密钥只存在后端；客户端不保存 AI Provider credential。

## V2 clean-refactor rules

这些规则是后续实现的硬约束，不因会话切换而失效：

1. V2 重构采用 **后端增量演进、前端平行替换、纵向切片迁移**。
2. 不在旧 UI 上继续堆修复补丁；进入 V2 范围的页面通过新页面结构解决根因。
3. 不允许 CI、测试数据、Preview、特定设备专用的生产代码特判。
4. 兼容逻辑只能集中在明确 migration adapter / legacy boundary，并必须有替换对象和删除条件。
5. 一个切片切换完成后，优先同步删除对应旧路由、旧页面、无引用组件、旧适配分支和过时测试，不长期保留 V1/V2 双实现。
6. 不通过 silent fallback、magic number、空 catch 掩盖未知问题；先建立可重复反馈环，确认真实数据与调用链。
7. 每个切片合入后 main 必须保持可编译、可运行、可测试、可回退。
8. 新抽象必须服务当前明确需求，不为“以后可能需要”引入复杂基础设施。

详见 `docs/adr/0002-v2-clean-refactor-and-migration.md` 与根目录 `AGENTS.md`。

## Product baseline

V2 主链路：

`Homework Import → Candidate Assignment → Parent Confirmation → Assignment → Study Workspace → Tutor Session (optional) → Submission → Parent Review → Progress`

课外任务从家长手工创建进入同一条 Assignment 后半段链路：

`Parent Create EXTRA Assignment → Assignment → Study Workspace → Submission (optional) → Parent Review / Progress`

## Migration order

默认按纵向切片推进：

1. Assignment V2 + Repository 基础 + 新学生首页；
2. 作业列表 + 科目/日期/类型筛选；
3. 作业详情 + 学习空间 + Tutor + Submission；
4. 家长首页 + Progress + Parent Review；
5. Homework Import + AI 整理 + Batch Publish；
6. 课外任务 + 日历 + Pad 多栏增强；
7. 删除剩余 V1 页面和迁移适配层。

若需要改变顺序或核心架构，先更新 ADR / 技术设计，而不是直接在代码里绕过。
