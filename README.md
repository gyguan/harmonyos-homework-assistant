# 小伴作业 · HarmonyOS Homework Assistant

面向一个家庭的 HarmonyOS AI 作业管家。

> 家长负责把老师作业带进来并确认；孩子只需要知道下一项做什么、完成作业、需要时问小伴；家长最后关注异常、提交和验收结果。

## 当前状态

项目已经完成一轮 V1 前后端闭环验证，当前进入 **V2 产品与 UI 全面重构阶段**。

V2 不继续围绕旧页面做局部样式修补，而采用：

> **后端增量演进 + 前端平行替换 + 纵向切片迁移 + 切换即清理**

当前 V2 设计与迁移原则统一维护在仓库文档中。发生冲突时，请按以下顺序理解：

1. `docs/adr/` 中最新 Accepted ADR；
2. `CONTEXT.md`；
3. `docs/architecture/system-technical-design-v2.md`；
4. `docs/architecture/frontend-technical-design-v2.md` / `backend-technical-design-v2.md`；
5. `docs/product/product-feature-list-v2.md`；
6. V0.x / V1 历史文档仅用于回溯，不作为当前实现依据。

完整文档入口见 `docs/README.md`。

## 产品定位

产品范围保持 **单家庭、多孩子**，不扩展为学校、班级或教师 SaaS。

核心闭环：

`老师原始内容 → OCR / AI 整理 → Candidate Assignment → 家长确认 → Assignment → 学习 / AI Tutor → Submission → 家长验收 / Progress`

课外任务复用同一个 Assignment 领域：

`家长创建 EXTRA Assignment → 学习 / 完成 → Submission（可选）→ 验收 / Progress`

核心原则：

- 孩子少管理、多行动；
- 家长少操作、多掌握；
- AI 融入流程，不占据流程；
- AI 整理结果默认经家长确认后再发布；
- AI Tutor 默认引导优先，不替孩子直接完成作业；
- SCHOOL / EXTRA 共用 Assignment，不建设两套平行业务体系；
- 不做班级社交、排行榜、题库平台、在线课堂；
- 不后台读取微信 / 钉钉，只处理用户主动提供的内容。

## V2 信息架构

学生端一级导航：

- 首页
- 作业
- 学习
- 我的

家长端一级导航：

- 首页
- 导入
- 进度
- 我的

学生作业支持按 **课内 / 课外、科目、日期、状态** 组织和筛选。

## V2 前端架构

继续使用 ArkTS + ArkUI，不引入 Redux / MobX 等重型状态管理框架。

目标结构：

```text
AppRoot / RoleShell
        ↓
Navigation / NavDestination
        ↓
Feature Page
        ↓
ViewModel
        ↓
Query / Command Service
        ↓
Repository
     ↙       ↘
Local Cache  Remote API
```

关键约束：

- 新 V2 Feature 不直接访问 `HomeworkStore.instance`；
- `HomeworkStore` 仅作为迁移期兼容数据源，职责只减不增；
- `AppShell` 逐步退出业务路由中心职责；
- Phone 核心流程保持单列；
- 业务是否多栏由 **当前容器实际可用宽度 + 内容最小可读宽度** 判断；
- Feature 页面不得自行硬编码 600 / 840 / 1080 等业务分栏断点；
- Pad 只在空间足够时提供列表 + 详情、学习内容 + AI 小伴、进度 + 验收等增强组合。

## V2 后端架构

继续采用轻量模块化单体：

```text
HarmonyOS App
    ↓
Spring Boot
    ↓
PostgreSQL / FileStorage / AI Provider
```

技术基线：

- Java 21；
- Spring Boot 4.1.x；
- PostgreSQL；
- JPA；
- Flyway；
- FileStorage 抽象；
- OpenAI-compatible AI Provider。

默认不引入：

- Redis；
- MQ；
- 微服务；
- API Gateway；
- 工作流引擎；
- CQRS。

Assignment 是唯一作业主模型，V2 逐步增加 `assignmentType`、`subjectCode`、结构化 `dueAt`、resources、requirements 等能力。历史 Flyway migration 不修改，通过 V7+ 增量升级。

## 干净重构规则

V2 实现必须遵守 `docs/adr/0002-v2-clean-refactor-and-migration.md`。核心要求：

- 不在旧 UI 上继续堆补丁；
- 不写 Preview / CI / 测试数据 / 特定设备专用业务分支；
- 不用 silent fallback、magic number、空 catch 掩盖真实问题；
- 兼容逻辑只能集中在明确 adapter / legacy boundary，并写清删除条件；
- 一个纵向切片切换到 V2 后，同功能旧路由、旧页面、旧适配和过时测试应同步清理；
- main 始终保持可编译、可运行、可测试、可回退。

## 默认迁移顺序

1. Assignment V2 + Repository 基础 + 新学生首页；
2. 作业列表 + 科目 / 日期 / 类型筛选；
3. 作业详情 + 学习空间 + Tutor + Submission；
4. 家长首页 + Progress + Parent Review；
5. Homework Import + AI 整理 + Batch Publish；
6. EXTRA Assignment + Calendar + Pad 增强；
7. 删除剩余 V1 页面、旧 AppShell 业务路由、旧 Store 业务职责和迁移 adapter。

## 当前工程基线

- DevEco Studio：26.0.0
- `compileSdkVersion`: `26.0.0`
- `compatibleSdkVersion`: `6.0.0(20)`
- project `modelVersion`: `5.0.0`
- Hvigor / `@ohos/hvigor-ohos-plugin`: `6.26.4`
- UI：ArkTS + ArkUI，Stage model
- Devices：Phone + Tablet
- Backend：Java 21 + Spring Boot + PostgreSQL + Flyway

## 已有可复用能力

V1 已验证并计划在 V2 中保留/演进的能力包括：

- 角色入口与多孩子隔离；
- 文字 / 截图 OCR 作业导入；
- Candidate + Source Evidence + 家长确认；
- Assignment 状态流转与单任务计时；
- Submission 多照片上传和鉴权读取；
- 家长通过 / 退回订正；
- Tutor session / message 与模型 fallback；
- opaque auth session；
- PostgreSQL / Flyway；
- 本地离线快照与远端同步基础；
- backend real E2E smoke。

这些能力用于 V2 增量演进，不代表旧 V1 页面结构继续作为 UI 基线。

## 常用验证

基础 HarmonyOS 静态门禁：

`python scripts/validate_harmony_project.py`

后端单元测试：

`cd backend; mvn test`

真实 PostgreSQL + Spring Boot E2E：

`python backend/scripts/e2e_smoke.py --expect-tutor-unavailable`

配置真实模型后：

`python backend/scripts/e2e_smoke.py --expect-tutor-available`

> GitHub CI 不能替代 DevEco 对 ArkUI 的真实编译、Preview / Emulator 和 Phone / Pad 视觉验收。
