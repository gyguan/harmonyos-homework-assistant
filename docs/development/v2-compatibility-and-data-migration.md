# 小伴作业｜V2 API 兼容与数据迁移决策

> 状态：Accepted for implementation  
> 对应：#112、#113  
> 生效：Slice 1 起  
> 前置：#104 已完成 Snapshot migration framework 与 V2 CI Gate

---

## 1. 结论摘要

V2 采用 **后端先升级、客户端后升级、短窗口向后兼容、到期即删除** 的策略。

核心结论：

1. V1 客户端在迁移窗口内可连接 V2 后端；
2. V2 客户端不承诺连接 V1 后端；部署顺序固定为 backend first；
3. V1 Assignment 写接口/旧字段只保留到 **Slice 5 完成**；
4. `dueText` 在兼容期继续返回，但所有 V2 日期查询只使用 `dueAt`；
5. 现有 Assignment 全部回填为 `assignmentType=SCHOOL`；
6. 历史 `dueText` **不自动推断** `dueAt`，无法确定的历史日期保持 `dueAt = null`；
7. Snapshot 当前版本为 V5；Slice 1 引入 Assignment V2 字段时升级为 V6，并通过显式 migration；
8. PostgreSQL 只做 forward migration，不修改 V1–V6，不依赖 down migration；
9. 破坏性删除只能在兼容窗口结束后的独立 cleanup 中进行。

---

# 2. 必须保留的回归行为

以下行为属于 V2 重构期间的稳定契约，任何 Slice 不得静默改变：

- Family / Student 数据严格隔离；
- 家长切换孩子后 Assignment / Submission / Tutor 不串上下文；
- 一个学生同一时间最多一个 `IN_PROGRESS`；
- optimistic version 冲突不能静默覆盖；
- 离线时仍可读取已有本地快照；
- Candidate 发布不能重复生成多个 Assignment；
- Submission 图片必须鉴权读取；
- Tutor 必须绑定 familyId + studentId + assignmentId；
- AI unavailable 不影响作业查看、学习和提交；
- auth session 在仅重启 backend、保留 PostgreSQL 后可恢复；
- migration 失败不得覆盖原始本地快照；
- migration 前后 Assignment / Submission / Tutor 数量不得无原因减少。

这些行为应优先通过行为测试/E2E 验证，不通过旧函数名或旧页面结构验证。

---

# 3. 允许改变的 V1 行为

以下属于重构目标，不作为兼容契约：

- V1 页面结构和导航枚举；
- `WindowSizeClass` 直接决定 Feature 单/多栏；
- `AppShell` 保存 selectedAssignmentId / returnRoute 等业务状态；
- Feature UI 直接访问 `HomeworkStore.instance`；
- `dueText` 参与日期筛选；
- 客户端直接写 status / startedAt / elapsedSeconds；
- `OVERDUE` 作为长期持久化 canonical status；
- 旧 PhoneLayout / PadLayout builder 名称；
- V1 静态 Gate 对旧类名/函数名的依赖。

---

# 4. API 兼容矩阵

| 客户端 | 后端 | 支持策略 |
|---|---|---|
| V1 | V1 | 历史基线，不再演进 |
| V1 | V2 | **迁移期支持，到 Slice 5 完成结束** |
| V2 | V1 | **不支持** |
| V2 | V2 | 目标组合 |

## 4.1 为什么不支持 V2 Client -> V1 Backend

V2 Client 会依赖：

- `assignmentType`；
- `subjectCode`；
- structured dueAt；
- Summary / Filter Query；
- 后续 Assignment Action Command。

让新客户端反向兼容旧后端会在客户端重新引入大量 fallback 和分支，与 clean-refactor 原则冲突。

因此发布/开发顺序固定为：

```text
V2 Backend compatible mode
        ↓
V2 Client
        ↓
完成 Slice 5
        ↓
移除 V1 write compatibility
```

Slice 1 增加后端 contract/capability version。V2 客户端连接低于 V2 contract 的 backend 时，应明确提示“家庭云端需要升级”；本地已有缓存仍可读取，不通过 silent fallback 伪装成云端正常。

---

# 5. 兼容窗口生命周期

## Slice 1–2

V2 Backend：

- 接受旧 Assignment create/update payload；
- 新字段对旧请求应用确定性默认值；
- 响应继续包含旧展示字段；
- 新 Query API 与旧 API 并存。

## Slice 3–4

- V2 学生执行链切换到 Action Command；
- 新客户端不再写权威 timing/status；
- legacy status/timing update 标记 deprecated，但仍服务尚未迁移的 V1 客户端。

## Slice 5

Homework Import / Batch Publish 完成 V2 切换后：

- V2 所有主链均不再需要 V1 Assignment write contract；
- 结束 V1 Client -> V2 Backend 兼容窗口；
- 删除 legacy write adapter / status-timing compatibility；
- `dueText` 可继续作为只读显示字段，直到独立 cleanup 证明无调用再删除。

禁止把 Slice 5 的删除条件改成“以后再清理”。

---

# 6. Assignment V2 历史数据语义

## 6.1 assignmentType

现有所有 Assignment 均来自老师/家长的校内作业闭环，因此历史记录统一回填：

```text
assignmentType = SCHOOL
```

不通过标题、科目、来源文本猜测 EXTRA。

从 V2 起，只有显式创建课外任务时才能产生：

```text
assignmentType = EXTRA
```

## 6.2 subjectCode

旧 `subject` 精确映射：

| legacy subject | subjectCode |
|---|---|
| 语文 | CHINESE |
| 数学 | MATH |
| 英语 | ENGLISH |
| 其他/未知 | OTHER |

迁移不做模糊 NLP 判断。

## 6.3 dueAt

历史 `dueText` 是自由文本，可能缺少年份、时区或明确日期。

**禁止批量猜测历史 dueAt。**

V7 迁移策略：

```text
legacy dueText 保留
dueAt = null
dueTimezone = Asia/Shanghai
```

之后：

- 新建/重新确认的 Assignment 写入结构化 dueAt；
- 用户明确编辑历史作业日期时可补齐 dueAt；
- 日期筛选只查询 dueAt；
- `dueAt = null` 的旧记录进入“未结构化日期/历史”语义，不伪造具体日期。

---

# 7. PostgreSQL V7 计划

V1–V6 **永久不修改**。

Slice 1 的 V7 按以下顺序：

```sql
ALTER TABLE assignment ADD COLUMN assignment_type varchar(16);
ALTER TABLE assignment ADD COLUMN subject_code varchar(32);
ALTER TABLE assignment ADD COLUMN due_at timestamptz;
ALTER TABLE assignment ADD COLUMN due_timezone varchar(64) DEFAULT 'Asia/Shanghai';
```

随后确定性回填：

```text
assignment_type: 全部历史行 -> SCHOOL
subject_code:
  语文 -> CHINESE
  数学 -> MATH
  英语 -> ENGLISH
  其他 -> OTHER
due_at: 不回填，保持 null
due_timezone: Asia/Shanghai
```

回填验证通过后：

- `assignment_type` -> NOT NULL + DEFAULT `SCHOOL`（兼容旧 create payload）；
- `subject_code` -> NOT NULL + DEFAULT `OTHER`；
- `due_at` 保持 nullable；
- `due_timezone` -> NOT NULL + DEFAULT `Asia/Shanghai`。

索引不在 V7 盲目增加。Slice 2 根据真实 Query 增加：

- student + dueAt；
- student + assignmentType；
- 必要时 student + subjectCode。

---

# 8. PostgreSQL Migration Verification

V7 至少验证：

```text
migration 前后 assignment 总数一致
assignment_type null = 0
subject_code null = 0
历史 assignment_type != SCHOOL = 0
旧 subject 三个已知值映射正确
未知 subject -> OTHER
due_text 原值未被覆盖
V7 不因猜测日期批量写 due_at
version / family_id / student_id 未变化
Submission / Tutor 外键关联数量未减少
```

真实 PostgreSQL E2E 必须从 V1–V6 schema 顺序执行到 V7，不只验证全新数据库最终 DDL。

---

# 9. OVERDUE 迁移策略

Slice 1 / Slice 2 暂不重写历史 status，避免模型迁移和状态机迁移混在同一个数据库变更。

当 Slice 3 正式切换“OVERDUE 为派生状态”时：

```text
legacy OVERDUE + elapsedSeconds > 0 -> PAUSED
legacy OVERDUE + elapsedSeconds = 0 -> NOT_STARTED
```

理由：

- 当前状态机允许 NOT_STARTED / IN_PROGRESS / PAUSED -> OVERDUE；
- 已有有效用时说明任务曾开始，恢复为 PAUSED 最接近原业务事实；
- 没有有效用时则恢复为 NOT_STARTED；
- overdue 之后由 dueAt + canonical status 动态派生。

该转换必须单独 migration/test，不塞入 V7。

---

# 10. HarmonyOS Snapshot Migration

#104 已建立：

```text
V4 -> V5
```

V5 只引入 migration framework，不改变业务字段。

Slice 1 引入 Assignment V2 字段时：

```text
V5 -> V6
```

确定性默认语义与数据库保持一致：

```text
assignmentType = SCHOOL
subjectCode = exact legacy subject mapping / OTHER
dueAt = 未设置
dueTimezone = Asia/Shanghai
dueText = 原值保留
```

不得通过 `dueText` 猜测 dueAt。

Snapshot migration 必须保留：

- settings / students；
- rawImports；
- assignments；
- candidates；
- submissions；
- tutorSessions；
- submissionSequence；
- sync metadata。

迁移失败：

- 抛出错误；
- 不保存新 snapshot；
- 不 seed MockData 覆盖；
- 保留 migration 前原始快照 backup。

---

# 11. Backup 与回滚

## 11.1 HarmonyOS

在首次跨 schema 成功保存前，Preferences adapter 保存一份：

```text
homework_snapshot_pre_migration_backup
```

规则：

- 只有 schema 发生变化时创建；
- 不用每次普通 save 重写 backup；
- migration 失败时原始主 key 不覆盖；
- backup 属于恢复保险，不作为双写数据源。

## 11.2 PostgreSQL

策略：

- migration 前可备份数据库；
- Flyway 只 forward；
- 出问题优先 forward-fix；
- 不实现自动 down migration；
- 破坏性 DROP 必须等兼容窗口结束并单独 review。

代码回退参考：

`archive/v1-before-v2-refactor`

代码回退不能替代数据库恢复策略。

---

# 12. #112 / #113 完成定义

以下条件满足后可关闭两项准备 Issue：

- API compatibility matrix 已确定；
- V1 compatibility 最迟删除 Slice 已确定；
- assignmentType / subjectCode / dueAt 历史语义无歧义；
- OVERDUE 后续转换规则确定；
- Snapshot V5 -> V6 默认语义确定；
- Preferences migration backup 进入代码；
- V7 执行顺序和 verification 明确；
- rollback / forward-fix 原则明确。

之后进入 #111 DevEco 本地基线确认；确认通过才开始 #105。
