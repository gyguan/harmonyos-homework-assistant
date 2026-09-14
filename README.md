# 小伴作业 · HarmonyOS Homework Assistant

面向一个家庭的 HarmonyOS AI 作业管家。

> 家长把老师消息丢进来，小伴自动整理；孩子打开只管完成；不会的问小伴；家长最后看结果。

## V0.1 只解决三件事

1. **收作业**：微信/钉钉截图、文本、文件 → AI 整理 → 家长确认；
2. **做作业**：孩子打开 App，只看到今天该做什么；需要时进入 AI Tutor；
3. **看进度**：家长查看未开始、进行中、已提交、已完成等状态。

## 产品边界

V0.1 按单家庭、单孩子优先设计：

- 家长是 App 的管理模式，不建设复杂 Parent / Guardian 权限体系；
- 不建设 School / Class / Teacher / Organization 组织模型；
- 不做班级社交、排行榜、题库平台、在线课堂；
- 不后台读取微信/钉钉，导入必须由用户主动分享、截图、粘贴或选择文件；
- AI 解析结果必须经过家长确认；
- AI Tutor 默认引导优先，不直接代做。

## 核心业务链路

`老师原始内容 → Candidate Assignment → 家长确认 → Assignment → 学生完成 → Submission → 家长进度`

核心数据对象控制为：

- `StudentProfile`
- `Assignment`
- `CandidateAssignment`
- `Submission`
- `TutorSession`
- `AppSettings`

## 轻量架构

保持到四层为止：

`ArkUI Pages → HomeworkStore / HomeworkService → Local Persistence → AI Ports`

保留三个可替换接口：

- `HomeworkPersistence`
- `HomeworkTextExtractor`
- `HomeworkAssignmentParser`

不引入微服务、Gateway、Event Bus、CQRS、Workflow Engine 或复杂 UseCase / Handler / Repository 层次。

## 当前工程基线

- DevEco Studio：26.0.0
- `compileSdkVersion`: `26.0.0`
- `compatibleSdkVersion`: `6.0.0(20)`
- `targetSdkVersion`: 未显式设置
- project `modelVersion`: `5.0.0`
- Hvigor / `@ohos/hvigor-ohos-plugin`: `6.26.4`
- UI：ArkTS + ArkUI，Stage model
- Devices：Phone + Tablet

## 当前实现

已经具备：

- Phone / Pad 响应式 AppShell；
- 家长导入 → 确认 → 发布；
- 学生 Today → 学习 → Mock 提交；
- 家长 Dashboard / Progress；
- Assignment 集中状态机；
- ArkData Preferences 本地持久化；
- OCR / LLM 的 Extractor / Parser Port；
- Mock AI 导入流水线；
- GitHub static gate。

## Static Gate

在仓库根目录执行：

`python scripts/validate_harmony_project.py`

Gate 除工程版本和响应式规则外，还会阻止 V0.1 重新引入 `familyId / parentId / guardianId / organizationId / classId` 等不必要的多租户复杂度，并保护 Persistence / OCR / LLM 的轻量接口边界。
