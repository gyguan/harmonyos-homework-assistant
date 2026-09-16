# 小伴作业｜产品设计 V1（历史文档）

- Status: **Superseded by V2**
- Original version: V1
- Superseded: 2026-09-16

> 本文不再作为当前产品设计或实现依据。V1 的完整历史内容仍保留在 Git 历史中。

## 为什么废弃

V1 完成了产品定位和首轮闭环验证，但后续原型与真实设备验证已经改变了多项关键设计：

- 学生一级导航从“今天 / 作业 / 教材 / 我的”调整为 **首页 / 作业 / 学习 / 我的**；
- 作业需要原生支持 **课内 / 课外、科目、日期、状态** 组织；
- Phone 不再通过窗口 size class 推导多栏，而坚持核心流程单列；
- Pad 多栏由实际容器能力决定，而不是固定窗口断点；
- 前端从大 `AppShell + HomeworkStore` 逐步迁移到 `Navigation + ViewModel + Repository`；
- 云端 `family` 已成为真实的数据安全边界；
- Assignment V2 将统一 SCHOOL / EXTRA，并使用结构化 dueAt 等字段。

继续保留 V1 的详细导航、页面结构和技术原则会干扰 V2 实现，因此当前树中只保留本说明。

## 仍然有效的长期产品原则

以下原则继续有效，并已进入 V2 基线：

- 产品服务单家庭、多孩子，不扩展学校 / 班级 SaaS；
- 孩子少管理、多行动；
- 家长少操作、多掌握；
- AI 整理结果默认由家长确认后发布；
- AI Tutor 引导优先，不替孩子完成作业；
- 老师要求 / 老师资料优先于通用 AI 知识；
- 不做排行、积分商城、班级 PK 等强游戏化能力。

## 当前权威文档

请使用：

1. `CONTEXT.md`
2. `docs/product/product-feature-list-v2.md`
3. `docs/architecture/system-technical-design-v2.md`
4. `docs/architecture/frontend-technical-design-v2.md`
5. `docs/architecture/backend-technical-design-v2.md`
6. `docs/adr/0001-phone-pad-ui-composition.md`
7. `docs/adr/0002-v2-clean-refactor-and-migration.md`

如当前实现与本历史文档冲突，以 V2 文档和最新 Accepted ADR 为准。
