# 单家庭多孩子隔离设计

## 目标

家庭仍然是一个本地家庭空间，但允许多个孩子。不同孩子可以属于不同年级/班级，作业数据必须按孩子隔离。

## 核心规则

- 不引入 familyId / tenant / organization 等多租户模型。
- `StudentProfile` 是家庭内孩子身份，使用稳定 `studentId`。
- `RawHomeworkImport`、`CandidateAssignment`、`Assignment` 显式携带 `studentId`。
- `Submission` 通过 `assignmentId` 归属 Assignment；`TutorSession` 显式携带 `studentId`，避免未来辅导上下文串孩子。
- `AppSettings.students[]` 保存家庭内孩子；`activeStudentId` 保存当前操作孩子。
- 家长切换孩子后：首页、导入、确认、进度都只看到当前孩子数据。
- 学生模式同样只展示当前孩子数据；切换孩子时离开当前作业详情，避免使用上一个孩子的 assignmentId。
- 新导入的老师文字/截图永远绑定“当前孩子”，班级仅作为孩子资料和 UI 提示，不参与权限系统。

## 数据链路

```text
Family App
  ├─ Student A (三年级2班)
  │    ├─ RawImport A
  │    ├─ Candidates A
  │    ├─ Assignments A
  │    └─ Submissions A
  └─ Student B (一年级5班)
       ├─ RawImport B
       ├─ Candidates B
       ├─ Assignments B
       └─ Submissions B
```

所有 Store 查询默认以 `activeStudentId` 为上下文过滤。
