# Next Session Handoff — 2026-09-20

> 先阅读根目录 `CONTEXT.md`。本文件只记录最新开发状态，旧会话历史不再作为下一步执行依据。

## 1. 当前仓库状态

- Repository: `gyguan/harmonyos-homework-assistant`
- Main 基线（PR #222 创建时）: `0855a61d9fd68f139f4ba0c1789493b923401c8c`
- 当前进行中的 PR: **#222 — refactor: 收敛作业身份、查询与交互基础能力**
- 工作分支: `refactor/sustainable-assignment-foundation`
- 合并策略: 功能分支完成 → GitHub CI 全绿 → 直接合入 `main` → 用户从 `main` 做真实 DevEco/HarmonyOS Build；如发现 CompileArkTS 问题，立即从最新 `main` 修复
- 当前没有 open issue；不要另起重复 issue/分支。

PR #222 目标不是继续叠页面补丁，而是把最近多轮问题提升为可复用的基础机制。

## 2. PR #222 已完成

### Assignment 身份显式化

- 新增 `AssignmentBacking.LOCAL_SEED / REMOTE`。
- Remote mapper 永远建立 `REMOTE` 身份。
- Demo/Seed 明确为 `LOCAL_SEED`。
- 批量发布、课外作业、语音作业创建路径显式建立 `REMOTE`。
- Repository 的 edit/action/review/delete 不再根据 `remoteVersion/candidateId` 猜身份。
- `ensureRemoteCurrent + reloadRemote` 统一真实云端任务 hydration。
- Snapshot 升级到 V8，历史身份推断只允许发生在 V7 → V8 migration 边界。

### Snapshot V8 强约束

- V8 之后 `HomeworkStore` 只复制 `source.backing`，不再“REMOTE 否则 LOCAL_SEED”。
- V8 快照缺失或包含非法 backing 时直接拒绝加载。
- `CONTEXT.md` 已同步为 V8，并明确 V4→V5→V6→V7→V8 显式迁移链。

### 查询与业务日期统一

- 新增 `AssignmentDateRange`。
- 新增 `AssignmentFilterFactory`。
- Parent Progress / Student Assignments 删除各自重复 filter/date-range 实现。
- 家长首页、学生首页、任务查询、月历统一使用 Asia/Shanghai 业务日边界。
- 修复统一日期服务中的优先级问题：
  - `晚上 8 点` → 今天；
  - `明天晚上 8 点` → 明天；
  - `后天晚上 8 点` → 后天；
  - 通用“晚上”不能覆盖明确相对/绝对日期。

### Repository 统一 UI invalidation

- Repository 提供集中 change listener。
- AppShell 统一订阅 Assignment mutation。
- create/edit/action/review/delete/applyAuthoritative 都通过 Repository 发出变更。
- AI 批量发布使用 `applyAuthoritativeBatch`，只触发一次 UI invalidation。
- 页面不再靠重复手工刷新 Assignment 变化。

### UI 基础能力收敛

- `SelectionIds` 统一多选/全选相关数组语义。
- Parent Progress 与 AI Confirmation 复用。
- `EditSheetHeader` 统一“标题 + 右上关闭”。
- Candidate 编辑与已发布任务编辑复用同一 Sheet Header。
- 固定底部业务操作保持当前已验证结构，不引入高风险 BuilderParam Scaffold。

### Gate 治理

- 新增 `validate_sustainable_assignment_foundation.py`。
- Snapshot、Execution、Review、Parent Surface、Calendar、Student Home 等旧 Gate 已调整到新的架构契约。
- Gate 不再要求已经废弃的方法名/页面私有实现。
- 新增约束：
  - 相对日期必须优先于通用“晚上”；
  - V8 backing 必须显式且合法；
  - HomeworkStore 不得在迁移后继续猜 Assignment backing。

## 3. 下一步不要再做什么

不要重新实现以下已经完成的能力：

- 不要重新用 `remoteVersion/candidateId` 判断本地/云端身份。
- 不要在页面里重新写 today/tomorrow/week date range。
- 不要恢复页面级 Assignment 手工刷新链路。
- 不要重新复制批量选择算法。
- 不要把 Sheet 右上角恢复成“完成/删除”等业务动作。
- 不要用 schema mismatch 后 seed MockData 的方式“修复”快照。
- 不要为了通过静态 Gate 修改生产逻辑；以真实业务契约和 DevEco 编译结果为准。

## 4. 合入 main 前剩余 Gate

### A. GitHub CI

最终 head 必须确认：

- `validate-project-invariants`: PASS
- `backend-real-e2e`: PASS

每次继续提交后都以最新 head 的 workflow 为准，不要引用旧 run 的 PASS。

### B. 真实 HarmonyOS / ArkTS Build（合入 main 后验证）

当前 GitHub 普通 PR workflow 不能替代真实 HarmonyOS Build；`.github/workflows/harmony-client-build.yml` 仍是手工触发的 self-hosted Windows runner。

按当前协作约定，PR 的 GitHub CI 全绿后直接合入 `main`，然后用户从最新 `main` 在 DevEco Studio 做完整 Build，重点确认：

1. 新增 `AssignmentBacking` 后没有遗漏的 Assignment object literal。
2. `EditSheetHeader` 可通过当前 modelVersion 5.0.0 ArkTS 编译。
3. `SelectionIds`、日期服务新增接口可通过 CompileArkTS。
4. Snapshot V8 migration / load 路径没有 ArkTS 类型错误。
5. 既有 `bindSheet($this...)` 修复没有回退。

如果真实 CompileArkTS 失败，以编译器错误为最终依据，从最新 `main` 拉修复分支处理并在 CI 通过后继续合入，不通过页面级临时补丁绕过。

## 5. 建议人工回归

Build 通过后重点回归：

1. 家长：未完成任务可编辑；SUBMITTED / COMPLETED 不能编辑。
2. AI 确认：批量选择/全选/批量删除；单项编辑；关闭脏编辑有提示。
3. 家长进度/学生作业：日期 + 科目查询结果一致。
4. 手机系统时区不是 Asia/Shanghai 时，业务“今天”和月历仍按 Asia/Shanghai。
5. 截止时间文本：`晚上8点`、`明天晚上8点`、`后天晚上8点`。
6. 学生作业状态变化后：首页、作业列表、家长进度无需额外全量刷新即可同步。
7. 切换孩子后不显示上一个孩子的详情或列表缓存。
8. App 原有语音作业、图片提交、Tutor 拍题链路不回归。

## 6. 下一会话直接执行

下一会话不要重新梳理历史。顺序固定：

1. 读取 `CONTEXT.md` 和本文件。
2. 检查 PR #222 最新 head 与 CI。
3. 如果用户提供 DevEco Build 错误，直接在 `refactor/sustainable-assignment-foundation` 修复。
4. GitHub CI 全绿后直接合并 PR #222 到 `main`。
5. 用户从最新 `main` 做 DevEco 完整 Build；如有真实 CompileArkTS 错误，基于 `main` 修复后继续合入。
6. 后续始终以 `main` 为唯一继续开发基线。
