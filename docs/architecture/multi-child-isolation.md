# 单家庭多孩子隔离设计

## 目标

产品仍然只服务一个家庭空间，但允许家庭内存在多个孩子。不同孩子可以属于不同年级 / 班级，作业、提交、Tutor 和进度必须严格按孩子隔离。

## 核心规则

### 前端

- `StudentProfile` 使用稳定 `studentId`；
- `activeStudentId` 是当前业务上下文；
- RawHomeworkImport、CandidateAssignment、Assignment 都显式携带 studentId；
- Submission 通过 Assignment 归属孩子；
- TutorSession 显式绑定 studentId + assignmentId；
- 家长切换孩子后，首页、导入、进度、验收全部切换到新孩子；
- 切换孩子时退出当前详情 / 学习 / 验收页面，避免沿用上一个孩子的 assignmentId；
- ViewModel / Repository 查询必须显式传 studentId，不允许依赖页面隐式全局变量。

### 后端

云端仍有一个轻量 `family` 安全边界，但不扩展为 SaaS 多租户平台。

```text
Account Session
  -> familyId
      -> Student A
          -> Assignments
          -> Submissions
          -> Tutor Sessions
      -> Student B
          -> Assignments
          -> Submissions
          -> Tutor Sessions
```

规则：

- familyId 只从服务端 Session / AuthInterceptor 获取；
- 客户端不能传入 familyId 选择其他家庭；
- Student 查询必须校验 `(familyId, studentId)`；
- Assignment / Submission / Tutor 查询必须最终校验 familyId；
- Repository 优先使用包含 familyId 的查询，不仅依赖前端隔离。

## 数据链路

```text
Family
  ├─ Student A
  │    ├─ RawImport / Candidates（客户端确认前）
  │    ├─ Assignments（云端权威）
  │    ├─ Submissions
  │    └─ Tutor Sessions
  └─ Student B
       ├─ RawImport / Candidates（客户端确认前）
       ├─ Assignments（云端权威）
       ├─ Submissions
       └─ Tutor Sessions
```

## 非目标

- 不建设 organization / school tenant；
- 不建设班级管理员权限体系；
- 不建设老师账号后台；
- family 只是当前单家庭数据安全边界，不是 SaaS 商业租户模型。

## 关联文档

- `docs/product/product-feature-list-v2.md`
- `docs/architecture/frontend-technical-design-v2.md`
- `docs/architecture/backend-technical-design-v2.md`
- `docs/architecture/system-technical-design-v2.md`
