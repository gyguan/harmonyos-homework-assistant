# Next Session Handoff — 2026-09-20

> 先阅读根目录 `CONTEXT.md`。本文件记录最新已合入状态；不要根据旧会话重新创建已经完成的分支或补丁。

## 1. 当前仓库状态

- Repository: `gyguan/harmonyos-homework-assistant`
- 当前唯一开发基线: **`main`**
- PR #222 `refactor/sustainable-assignment-foundation`: **已合入**
- PR #222 squash merge commit: `c3deed16f494b59e8f6a6dbfa53e098d9220207f`
- PR 合入前最终 Gate:
  - `validate-project-invariants`: PASS
  - `backend-real-e2e`: PASS
- 当前没有遗留 open issue。

协作方式保持：功能修改完成并通过 GitHub CI 后直接合入 `main`；用户从最新 `main` 做真实 DevEco/HarmonyOS Build。若 CompileArkTS 暴露问题，从最新 `main` 修复，不回退到旧 PR 分支。

## 2. 已完成的基础重构

### Assignment 身份显式化

- 使用 `AssignmentBacking.LOCAL_SEED / REMOTE` 表达任务来源。
- Remote mapper、正式发布、课外任务、语音任务显式建立 `REMOTE`。
- Demo/Seed 显式为 `LOCAL_SEED`。
- edit/action/review/delete 不再使用 `remoteVersion/candidateId` 猜任务身份。
- `ensureRemoteCurrent + reloadRemote` 统一真实云端任务 hydration。

### Snapshot V8

- Snapshot 当前 schema 为 **V8**。
- 保留 V4→V5→V6→V7→V8 显式迁移链。
- 历史身份推断仅允许存在于 migration 边界。
- V8 之后 `HomeworkStore` 直接保留显式 backing，不再“REMOTE 否则 LOCAL_SEED”。
- V8 backing 缺失或非法时直接拒绝加载，不静默伪装成本地示例任务。

### 日期与查询统一

- `AssignmentDateRange` 统一日期范围。
- `AssignmentFilterFactory` 统一查询条件构造。
- 家长首页、学生首页、任务列表、进度页、月历统一按 **Asia/Shanghai** 业务日期解释。
- 已修复日期优先级：
  - `晚上 8 点` → 今天；
  - `明天晚上 8 点` → 明天；
  - `后天晚上 8 点` → 后天；
  - 明确相对/绝对日期优先于通用“晚上”。

### Repository UI invalidation

- Assignment Repository 提供集中 change listener。
- AppShell 统一订阅 Assignment mutation。
- create/edit/action/review/delete/authoritative apply 统一触发 UI invalidation。
- AI 批量发布使用 `applyAuthoritativeBatch`，一次批量更新只触发一次 invalidation。
- 不再依赖各页面重复手工刷新 Assignment。

### UI 基础能力

- `SelectionIds` 统一批量选择语义。
- Parent Progress / AI Confirmation 共用选择逻辑。
- `EditSheetHeader` 统一 Sheet 的“标题 + 右上关闭”。
- Candidate 编辑与已发布任务编辑复用该 Header。
- 业务主操作固定在底部；右上角只保留退出动作。

### Gate

- `validate_sustainable_assignment_foundation.py` 已纳入静态 Gate。
- Snapshot、Execution、Review、Parent Surface、Calendar、Student Home 等 Gate 已按新架构契约更新。
- Gate 额外保护：
  - 不恢复 Assignment 身份推断；
  - 不恢复页面私有日期/查询实现；
  - 不恢复通用“晚上”覆盖明确日期；
  - 不允许 V8 backing 静默兜底。

## 3. 后续不要回退的实现

- 不用 `remoteVersion/candidateId` 判断本地/云端身份。
- 不在页面重新实现 today/tomorrow/week date range。
- 不恢复页面级 Assignment 手工刷新链路。
- 不复制批量选择算法。
- 不把 Sheet 右上角改成“完成/删除”等业务动作。
- 不用 schema mismatch 后 seed MockData 掩盖快照问题。
- 不为通过静态 Gate 引入生产代码特判。

## 4. 当前下一步

用户本地直接拉最新 `main`：

```powershell
git checkout main; git pull origin main
```

然后在 DevEco Studio 做完整 Build。重点关注：

1. `AssignmentBacking` 成为必填字段后是否还有遗漏的 Assignment object literal。
2. `EditSheetHeader` 在当前 modelVersion 5.0.0 下能否通过 CompileArkTS。
3. `SelectionIds`、统一日期服务接口是否存在 ArkTS 类型兼容问题。
4. Snapshot V8 migration / restore 是否存在类型错误。
5. 既有 `bindSheet($$this...)` 双向绑定是否保持可编译。

若真实 Build 报错，以 DevEco/ArkTS 编译器错误为最终依据，基于最新 `main` 继续修复。

## 5. Build 通过后的重点人工回归

1. 家长可编辑未完成任务；SUBMITTED / COMPLETED 不允许编辑。
2. AI 确认页批量选择、全选、批量删除、单项编辑、脏编辑关闭提示。
3. 家长进度与学生作业的日期 + 科目查询结果一致。
4. 设备系统时区不是 Asia/Shanghai 时，“今天”和月历仍按业务时区一致。
5. 截止时间文本：`晚上8点`、`明天晚上8点`、`后天晚上8点`。
6. 学生状态变化后，首页/作业列表/家长进度自动同步，无额外全量刷新。
7. 切换孩子后不残留上一个孩子的详情/列表状态。
8. 语音作业、图片提交、Tutor 拍题链路无回归。

## 6. 下一会话直接执行

1. 读取 `CONTEXT.md` 与本文件。
2. 以 `main` 为唯一基线，不再继续 PR #222 分支。
3. 如果用户提供 DevEco Build/运行错误，直接定位根因并修复。
4. 修复经 GitHub CI 全绿后直接合入 `main`。
