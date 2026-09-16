# 人员入口与角色锁定设计

## 目标

同一家庭 App 同时服务家长和孩子，但进入角色后，导航、权限和数据展示必须保持稳定，避免在业务页面里随意切换身份导致上下文混乱。

## 核心规则

- App 启动后先确定当前角色：`PARENT` 或 `STUDENT`；
- Role 只由 `RoleShell` 管理，不由具体 Feature Page 修改；
- StudentShell / ParentShell 使用同一套 Navigation 基础设施，但拥有不同一级导航；
- 当前孩子由 `activeStudentId` 表示；
- 家长可在 Shell 级切换孩子；
- 学生模式默认锁定到当前孩子，不提供普通业务页内自由切换；
- 切换孩子时必须清理当前详情页上下文，避免继续持有上一个孩子的 assignmentId；
- 业务页面只拿到 `studentId / assignmentId` 等必要上下文，不负责角色判断。

## V2 页面边界

```text
AppRoot
  -> RoleShell
      -> StudentShell
          -> Navigation / NavDestination
      -> ParentShell
          -> Navigation / NavDestination
```

RoleShell 负责：

- 当前角色；
- 当前孩子上下文；
- 一级导航；
- Phone 底部导航 / Pad 侧边导航；
- 系统返回的顶层边界。

Feature Page 不负责：

- 切换角色；
- 判断 family；
- 保存全局 selected assignment；
- 自己维护跨页面 route enum。

## 权限原则

前端角色锁定只解决交互上下文，不承担安全边界。

服务端仍必须通过 Bearer Session 得到 familyId，并对 Student / Assignment / Submission / Tutor 逐级校验归属关系。

## 关联文档

- `docs/product/product-feature-list-v2.md`
- `docs/architecture/frontend-technical-design-v2.md`
- `docs/architecture/backend-technical-design-v2.md`
