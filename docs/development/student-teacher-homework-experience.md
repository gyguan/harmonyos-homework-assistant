# AI 整理作业：按学生、老师积累经验（2026-10-19）

## 已核查的老师习惯（以仓库现有代码为证据，不能据此建立真实教师身份）

| 来源 / 老师线索 | 科目与格式 | 原始写法举例 | 解析要点 | 核验状态 |
| --- | --- | --- | --- | --- |
| “官桐羽老师”的三段式备注 | 语文通知 | 学习进度 / 常规作业 / 今日作业；课外阅读30分钟、心情日记、🌟子项 | 学习进度不生成任务但可补篇名；阅读、日记各一条；序号内不同动作可拆 | 源自既有提示词与测试，尚无独立学生关联 |
| 英语老师的短通知 | 英语 | 听读U3 / 听读课文U4 / 绘本 / 一起作业 | U数字为单元；一起作业是平台名；绘本已有定时语音任务时避免重复；并列缩写不可漏项 | 源自既有提示词与测试，老师姓名/同一人关系需核实 |
| “官士棋老师”的作业公示栏备注 | 多学科黑板表格 | 学科｜内容｜预计时长；“其他”行；国13 / 久 / 订小白 / 课外30分 | 行列定位学科；同一格序号和续行谨慎拆分；“其他”通常归语文；时长按行 | 源自既有提示词与测试，须根据实际图片及学生确认 |
| 家长补充文字 | 不固定 | 同一图片补充或纠正内容 | 后写的明确纠正覆盖对应任务；来源冲突不可臆断 | 通用规则 |

**重要身份歧义：**现有源码一处称“官桐羽老师（语文）”，另一处称“官桐羽与官士棋为同一英语老师”。没有可靠身份依据。此次仅保留“格式+学科+原文线索”，不把姓名关联当成事实，也不向全部学生写入默认老师资料。需要用户确认后方可按具体 `studentId + teacherName + subject` 创建经验。

## 现阶段实现的闭环

1. 数据：新增 `V33__homework_teacher_experience.sql`，每条经验绑定家庭/学生/老师/学科；`MANUAL` 表示明确确认过的解释，`CONFIRMED_EDIT` 表示发布前确实改过标题的历史样例。
2. 采集：AI 整理时在客户端短暂保存 AI 原始标题。**仅成功发布之后**，比较原始标题和家长最终标题；仅当来源里只出现一位明确的“某某老师”时，把差异写入同学生名下。原始识别结果直接发布、未修改、未知老师、多位老师混在同一批的情况不自动学习。
3. 使用：文本解析仅在**老师名称及触发原文都命中**时引用此学生的经验；图片解析只给出少量条件性线索，由模型看清图片内容后决定是否匹配。任何经验不得覆盖通用防猜测、保留作业条目、结构化 JSON 契约。
4. 容错：经验采集网络失败不会阻断已经成功的作业发布；经验记录总量上限80、单次提示词长度上限2100字，避免无限膨胀/显著增加 Token。
5. 纠错不直接变成规则：一次手工改标题不意味着老师永远这么写。只能作为同老师同线索的参考例子；不能凭相同姓氏将老师合并，也不能搬用旧日期、页码、单元号。

## 接口（已有家庭登录态）

- `GET /api/v1/students/{studentId}/homework/teacher-experiences`：查看此孩子已有经验。
- `POST /api/v1/students/{studentId}/homework/teacher-experiences`：添加/更新一条确认的规则。
- `DELETE /api/v1/students/{studentId}/homework/teacher-experiences/{id}`：删除错误经验。
- `POST /api/v1/students/{studentId}/homework/teacher-experiences/confirmed-edit`：记录已发布的标题纠错样例；常规用户由客户端自动调用。

创建规则示例（仅为接口格式，老师身份需真实核实）：

```json
{
  "teacherName": "王老师",
  "subject": "语文",
  "cue": "国13",
  "interpretation": "“国13”表示《国学》第13页；只展开已出现的数字，不额外推断。",
  "exampleSource": "朗读国13",
  "exampleResult": "朗读《国学》第13页"
}
```

## 还需要逐步完善的部分

- 图片没有老师署名、文字群聊不含“某某老师”时，纠错先无法归到具体老师；下一步可在导入界面提供**可选的来源老师绑定**，不增加学生端操作，不自动猜测。
- 目前只自动反馈标题修改，尚未覆盖漏拆后家长新增任务、删除任务、学科/日期/时长修改。需要保留原始 Candidate 清单并对照家长最终发布清单，形成准确的正反例。
- 需要扩充离线回归集：老师三段式10条、黑板7条、英语听读+一起作业、跨学生同缩写不同含义、空图片/无任务、重复绘本、模型缺字段、日期/题号混淆。
- 量化指标建议按学生及老师聚合：发布前改动率、漏项率、学科误判、缩写正确率、结构化解析失败率、平均请求耗时与 Token 数。发布前改动率并不等于模型准确率，不能当成唯一指标。

运行检查：`cd backend && mvn test`；部署时 Flyway 自动执行 V33。没有真实生产 API 与老师原始案例样本时，不能据单元测试宣称准确率已达到某百分比。

## 家长主动反馈（V34，2026-10-19）

家长在 AI 整理出的任一待确认任务中点击 **“反馈 AI 整理问题”**。反馈选项动态加载自数据库表
`homework_feedback_type`，客户端不内置问题类型列表，不需要修改 ArkTS 就能增加、禁用或调整排序/必填策略。

### 两张表

- `homework_feedback_type`：code / label / description / requires_comment / enabled / display_order。V34 初始化一组常见类型（遗漏、误拆、学科错误、缩写误读、内容不对、日期不对、重复、其他）；这些是**可修改的数据**而非 Java/ArkTS 枚举。
- `homework_organizer_feedback`：家庭、学生、候选任务、导入批次、可选老师、学科、反馈分类、老师原文片段、AI 初稿标题、当前标题、家长说明、状态、提交时间与客户端幂等请求 ID。建立家庭+学生索引，接口校验家庭归属。

### API

- `GET /api/v1/students/{studentId}/homework/feedback/types`：只返回启用的类型，排序与说明来自表。
- `POST /api/v1/students/{studentId}/homework/feedback`：保存反馈，幂等请求 ID 防重复提交，必填检查由类型配置驱动。
- `GET /api/v1/students/{studentId}/homework/feedback`：当前家庭该孩子最近 50 条反馈。

示例（老师可为空，无署名绝不强行归属）：

```json
{
  "clientRequestId": "ai-import-1-1760840000000",
  "candidateId": "ai-import-1",
  "batchId": "batch-1",
  "teacherName": "王老师",
  "subject": "语文",
  "feedbackTypeCode": "SHORTHAND",
  "sourceLabel": "老师通知",
  "sourceExcerpt": "朗读国13",
  "originalTitle": "朗读国13",
  "currentTitle": "朗读国13",
  "details": "国13 是《国学》第13页，朗读该页"
}
```

### 数据驱动管理示例

```sql
-- 修改某项描述、展示顺序、必填属性
update homework_feedback_type
set label = '缩写或教材解释错误', description = '请提供缩写的正确含义',
    requires_comment = true, display_order = 35, updated_at = now()
where code = 'SHORTHAND';

-- 暂停不需要的反馈分类
update homework_feedback_type
set enabled = false, updated_at = now()
where code = 'DUPLICATE';

-- 新增分类：无需改前端
insert into homework_feedback_type(code, label, description, requires_comment, enabled, display_order)
values ('BOOK_EDITION', '教材版本不对', '说明老师所用的教材版本', true, true, 55);
```

### 学习边界

反馈表是**可追溯的原始反馈证据**，默认 `processing_status=NEW`。它不会自动改写已有任务，也不被直接拼进 AI Prompt。下一阶段在 UI 增加反馈记录/纠错审核与规则转化：明确学生、老师、缩写及可靠更正后，方可转化为 `homework_teacher_experience` 的已确认经验。避免未经验证的个别意见污染全体学生。

本版反馈入口在“编辑 AI 整理任务”页面，按需从服务器加载分类，可填写老师姓名、正确含义与补充说明；不影响家长正常保存或发布。尚无后台可视化类型管理 UI，分类可先通过 SQL 管理；未实现跨多项作业的批次级漏项差异比较。

后端测试：`HomeworkOrganizerFeedbackServiceTest` 覆盖动态分类、必填、状态、幂等与家庭访问限制。


## 家长确认后转化为生效经验（V35）

本版本为反馈闭环增加显式启用与可撤销能力。不是“反馈即自动学习”：

1. `homework_feedback_type.can_become_experience` 从表中读取。V35 只为 `SHORTHAND` 初始化为 true；其他问题仍以 `NEW` 保存，等待更丰富的差异分析/验证。
2. 家长在 **反馈 AI 整理问题** 中选择可学习的类型，勾选 **同时保存为该老师的专属经验**，填入已确认的老师姓名、触发词及正确含义。例：`国*` 代表 `国13`、`国14` 等 1–3 位数字的写法。
3. 客户端先保存反馈，获取服务端反馈 ID，再通过 `POST /api/v1/students/{studentId}/homework/feedback/{feedbackId}/promote` 提交 `{"cue":"国*","interpretation":"国后的数字代表《国学》课本对应页码，不增加不存在的题目"}`。在后端事务内验证：家庭/学生访问权限、反馈归属、当前类别可学习、老师姓名明确、触发词确实与原文匹配、释义不为空。
4. 成功后生成 `homework_teacher_experience` 记录，`origin=FEEDBACK_APPROVED`、`active=true`、`source_feedback_id` 保留证据，反馈状态设为 `APPLIED`；同反馈重复调用不会生成重复经验，也不能借第二次提交悄悄覆盖历史规则。
5. 新的文字整理会验证 **当前学生 + 老师名称 + 触发词**；图片整理只传受控条数的条件性经验，要求图片同时能识别出对应老师和原文线索；无法确定老师不猜测。规则被停用后不再放入 AI Prompt。
6. 家长在同一页面 **查看或停用老师经验**；`PUT /api/v1/students/{studentId}/homework/teacher-experiences/{id}/active` 用 `{"active":false}` 可停用，`{"active":true}` 可重新启用。旧版 DELETE 经验变成**软停用**而非物理删除，以保留来源和审计信息。

数据库：`V35__homework_feedback_learning.sql` 新增 `can_become_experience`、`active`、`source_feedback_id`，保留有效反馈与规则的单一映射。家长前端从接口读取 `canBecomeExperience`，允许转经验的类型不在 ArkTS 写死。

可选 SQL 配置：允许别的反馈分类进入“明确由家长确认才生效”的流程时，可设置 `update homework_feedback_type set can_become_experience=true where code='...';`。**注意**：建议先为新增类别编写差异验证规则，避免把“漏项”“重复作业”等需要跨任务比对的结论当成单条缩写知识。

测试：`HomeworkFeedbackLearningTest` 验证数字占位符、来源精确匹配、学生/老师隔离、重复晋升幂等、非可学习类别拒绝、停用与恢复。后端 CI 完整测试 218 项通过；HarmonyOS HAP 构建未运行（需要已启用的自托管 Runner），部分既有 UI/E2E 门禁仍失败，PR 保持 Draft。

**尚待建设**：导入前可选绑定具体老师（图片可能没有署名，当前不会从姓名相似度推测）；可解释的跨多任务“漏拆/误拆/遗漏”反馈自动提炼；基于真实老师样本和模型版本的在线/离线效果回归。这些必须与本版“可撤销的家长明确规则”区分。
