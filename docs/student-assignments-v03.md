# 学生作业页 V0.3（历史说明）

- Status: **Superseded by V2**
- Superseded: 2026-09-16

本文只记录 V0.3 时期形成的部分业务规则，不再作为学生作业页实现规格。

仍然有效的规则：

- 下一项任务应优先考虑逾期 / 待订正 / 已开始未完成等需要处理的作业；
- 同一时间只允许一个进行中的作业；
- 切换到另一项任务时，上一项应暂停并保留累计有效学习时间。

已经被 V2 替代的内容：

- “今天”页面概念已收敛到学生 **首页**；
- 学生一级导航升级为 **首页 / 作业 / 学习 / 我的**；
- 作业页需要支持 **课内 / 课外、科目、日期、状态** 过滤；
- 详情和返回路径使用 `Navigation / NavDestination`，不再通过全局 returnRoute 枚举维护；
- `OVERDUE` 目标上作为派生属性，不作为必须持久化的独立状态。

当前实现依据：

- `docs/product/product-feature-list-v2.md`
- `docs/architecture/frontend-technical-design-v2.md`
- `docs/architecture/backend-technical-design-v2.md`
- `docs/architecture/system-technical-design-v2.md`
