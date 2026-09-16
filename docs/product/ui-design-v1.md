# 小伴作业｜UI 设计 V1（历史文档）

- Status: **Superseded by V2 prototype and technical baseline**
- Superseded: 2026-09-16

> 本文不再作为 UI 实现依据。旧版详细内容仍可从 Git 历史中查看。

## 为什么废弃

V1 UI 方向曾直接把 `COMPACT / MEDIUM / EXPANDED` 与页面单双栏绑定，并使用 600 / 840vp 等窗口断点决定学习工作台、导入页和主从结构。真实 Phone / Preview 验证证明，这种做法容易让业务页面在错误尺寸分类下进入 Pad 布局，产生被压缩的左右分栏。

V2 已明确改为：

- Phone 核心流程默认单列；
- 列表点击进入独立详情页；
- AI 小伴在 Phone 使用独立页 / 抽屉；
- Pad 只有在 **实际容器剩余宽度** 足以满足各 pane 最小可读宽度时才组合多栏；
- Window size class 只可用于 Shell 级导航形态，不直接决定业务布局；
- 学生一级导航调整为 **首页 / 作业 / 学习 / 我的**；
- 家长端继续使用 **首页 / 导入 / 进度 / 我的**；
- 作业页必须支持课内 / 课外、科目、日期、状态过滤；
- 视觉方向保持轻量、家庭化、HarmonyOS 原生感，不做管理后台式卡片堆叠。

## 仍然有效的视觉原则

以下原则继续有效：

- 孩子端少管理、多行动；
- 家长端少装饰、多状态；
- Phone 不桌面化；
- Pad 不只是放大 Phone；
- 儿童友好但不幼稚；
- 学科色只做辅助识别，不承担状态语义；
- AI 解析应提供 Source Evidence；
- AI Tutor 默认提示优先。

## 当前权威文档

请使用：

- `docs/product/product-feature-list-v2.md`
- `docs/architecture/frontend-technical-design-v2.md`
- `docs/adr/0001-phone-pad-ui-composition.md`
- `docs/adr/0002-v2-clean-refactor-and-migration.md`

尤其禁止从本 V1 历史文档恢复 `>840vp = 三栏`、`600–840vp = 双栏` 等业务布局规则。
