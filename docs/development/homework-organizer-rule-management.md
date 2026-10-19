# 作业整理规则数据库化（V40）

## 已迁移内容与运行机制

Flyway `V40__homework_organizer_rules.sql` 创建 `homework_organizer_rule` 并原样初始化 **10 条简写 + 3 条完整通知模板**（三段式、英语听读、黑板公示栏）。不再从 Java `DEFAULT_SHORTHAND` 或三个硬编码模板方法读取生产规则。基础 JSON 结构要求、序号解析、题目拆分、长度与字段安全校验仍然在 Java 中，**不是可执行的经验数据**。

`HomeworkOrganizerRuleService` 每次解析开始从数据库只读取一次已启用规则，按照 `priority DESC, code ASC` 排序；同一个科目和简写冲突时，优先级最高者生效。随后同一份不可变快照同时用于 **AI Prompt** 和 **确定性简写匹配、拆分与绘本去重**，避免两段用不同版本。更改数据库后下一个请求立即使用新配置，不需要重启；正在进行的请求按原快照完成。

`scope` 支持 GLOBAL、STUDENT、TEACHER。非 GLOBAL 数据必须明确属于 `family_id + student_id`；TEACHER 进一步要求原始来源明确且唯一标识对应老师；STUDENT 经验需能从来源确定唯一学科且无具体老师身份。图片来源不足以确定老师或科目时不猜测，不跨学生共享。家长主动批准的个人经验仍保存在 `homework_teacher_experience`，不复制全局种子到每个孩子。

**安全边界：** 仓库现有 API 使用家庭令牌，没有经过验证的组织级管理员 RBAC，因此暂不暴露允许任何家长修改全局 Prompt 的写接口。全局规则由受信任的数据库运维操作，历史变更须记录审计/SQL 发布。后续如需 UI 管理，应先实现独立管理员身份及鉴权。当前不新增家长维护老师的入口。

## 查询与安全调整

查看当前规则（只读）：

```sql
SELECT code, rule_type, scope, subject, trigger_text, template_key, enabled, priority, version
FROM homework_organizer_rule ORDER BY rule_type, priority DESC, code;
```

暂时关闭一个简写（立即在后续请求生效）：

```sql
UPDATE homework_organizer_rule SET enabled = false, version = version + 1, updated_at = now()
WHERE code = 'GLOBAL_SHORTHAND_08' AND version = 1;
```

恢复该规则（请使用实际当前版本作为乐观锁条件）：

```sql
UPDATE homework_organizer_rule SET enabled = true, version = version + 1, updated_at = now()
WHERE code = 'GLOBAL_SHORTHAND_08' AND version = 2;
```

改变优先级时同样递增 `version`，新增规则建议使用稳定唯一 `code`，`origin='MANUAL'`。不要编辑已经在环境中执行过的 Flyway V40 文件；以后基线种子修改使用后续新版本迁移。外部部署的 `AI_HOMEWORK_SHORTHAND` 仅为旧配置保留，不再作为生产简写来源，确保关闭数据库规则不会被环境变量偷偷重新启用。

## 验收

- 单元测试验证规则优先级、禁用后不会退回 Java 默认经验、学生/老师范围隔离。
- Java 旧案例的词典和三类模板断言改为直接读取 Flyway V40 原始种子，避免测试偷用 Java 硬编码。
- CI 在真实 PostgreSQL 执行 Flyway 后启动后端，并运行原有批量发布、定时作业、纠错 Outbox 等 E2E。
- 鸿蒙 HAP 工作流如仍 `skipped`，不能将 CI 结果描述为真机编译通过。

## 待扩展

未来可增加全局规则编辑审计（记录操作者、旧版/新版差异）、规则冲突预警、针对 VERIFIED 老师作业样本的真实解析回归；未经家长确认的数据不能标为准确率金标。
