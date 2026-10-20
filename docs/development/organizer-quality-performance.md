# Issue #591：整理质量与性能分阶段交付

起点 main：28753b8。复用 #582 的 V36 老师注册、V37/V38 初稿与差异、V39 Outbox、V40 规则库、V42 反馈经验，不另建反馈流水或评测框架。

## P0-A：可观测基线

每次 Service 整理（含失败）输出一条 `homework_import measurement data=<JSON>`。
复用 AccessLogFilter MDC requestId，不在 Service 生成追踪 ID。importId 仅允许安全标识；不合法值记 unavailable。日志只含元数据、版本 SHA-256、风险代码、数量、耗时、actual usage；不含老师姓名、学生姓名、原文、Prompt、响应、图片或 key。整理期间强制关闭 Provider payload，即便全局调试开关开启。

- total：Service 整理、归属验证、快照写入均纳入，HTTP/反序列化时间由 replay 的 httpElapsedMs 单列。
- experienceRetrieval：规则与经验读取/拼装；imagePreparation：原始图片校验。
- localValidation：首轮解析/通用字段转换；review：旧逻辑的完整第二轮；model/reviewModel：真正 HTTP 请求耗时。
- 每次实际 HTTP 请求均进入 callCount（含失败）；usage 缺失/非法为 null，聚合只要一次缺失就为 unavailable，不以 0 或估算补齐。
- prompt/rule/experience 版本是当前生效内容指纹；P0-A 记录旧策略 LEGACY_EXPERIENCE_MATCH，**尚未实现按风险复核**。无缓存，因此 cacheHit=false。

## 离线与真实 replay

`python -m unittest discover -s scripts/tests -p test_evaluate_homework_organizer.py -v`

`python scripts/evaluate_homework_organizer.py --fixtures scripts/fixtures/homework_organizer_cases.json --predictions scripts/fixtures/homework_organizer_predictions_empty.json --report /tmp/organizer-report.json`

全为 DRAFT 时退出码 2、NO_VERIFIED_GOLD，不报告语义准确率。DRAFT 仍可输出性能数据。VERIFIED 必须来自真实老师输入、经家长人工核验，不能把测试构造样本标记成真实金标。expected 的 keywords 是**任务匹配代理**；fields 是人工标注的实际 DTO 字段精确对比，sourceEvidenceTexts 是独立原文片段标注（不依赖模型给图片块编号的方式），也支持严格 sourceBlockIds 标注。图片未提供实际图像前保持证据未标注，不能伪造块ID。关键词 P/R 与字段准确率均不能替代独立语义复核。

真实模型 baseline：在隔离测试家庭准备学生、已确认老师/经验与后端模型配置；通过环境变量 ORGANIZER_EVAL_TOKEN 提供家长 session。不要提交 key/session/真实儿童资料。固定服务器时区/日期、模型版本、原文/图片、老师/经验版本和网络；真实模型测量会消耗提供商额度。

`python scripts/run_homework_organizer_eval.py --fixtures scripts/fixtures/homework_organizer_cases.json --student-id YOUR_TEST_STUDENT --output /tmp/main-predictions.json`

图片样本必须提供实际 imagePath（相对 fixtures）；缺少时明确拒绝，不能拿手写转录替代视觉输入。当前图片示例尚无真实图片，需在私有评测集中补充。空白样本可验证 HTTP 输入拒绝；模型缺字段/数组根/重复等继续复用 Java ModelClient 测试。

`python scripts/run_homework_organizer_eval.py --predictions /tmp/main-predictions.json --logs /tmp/main-server.log --output /tmp/main-enriched.json`

`python scripts/evaluate_homework_organizer.py --fixtures PRIVATE_FIXED_GOLD.json --predictions /tmp/main-enriched.json --report /tmp/main-report.json`

在 candidate 服务对同一集合重跑，再 `--baseline /tmp/main-report.json`。内容/标注/status 指纹必须完全相同；不能只检查 case ID。最大二分匹配避免任务顺序影响评分，重复输出不能覆盖同一任务两次。关键字段漏项纳入分母；证据覆盖需引用存在且非空的源块。质量退化退出 1；无金标仍退出 2，不伪造门禁通过。

`python scripts/run_homework_organizer_eval.py --logs /tmp/server.log --output /tmp/performance.json`

汇总含 P50/P95、分阶段耗时、失败率、平均调用数、复核率、input/output Token 及用量缺失数。可选 --prices JSON 形如 `{"MODEL":{"inputPerMillion":1,"outputPerMillion":2,"currency":"CNY"}}`；仅为指定价格估算，非账单，图片/缓存计费需另行核实。baselineDeltas 是 candidate-baseline 原始差值；无同条件实测不能归因为优化收益。

## 后续边界

P0-B 独立 SourceDocument/SourceBlock 与兼容 DTO；P0-C 相关性检索/预算；P0-D 通用风险与至多一次复核。由于不合 main，后续采用串联 PR（B 基于 A、C 基于 B、D 基于 C），每个 PR 展示独立阶段增量；统一祖先是上面的 main。授权合并后按顺序更新 base 再合并，当前不执行合并。

当前未验证：真实金标准确率、真实模型延迟/成本、HAP 实际编译与真机。CI Mock/数据库通过不能证明模型语义正确。

## P0-C：经验检索与预算

复用现有家长经验仓库（每学生最多80条），DB 查询先限制 family/student，再在评分前硬过滤 active/subject/已确认老师。学科归属经验仍要求单一明确科目且无具名老师；具名老师必须显式绑定或唯一具名来源。无图片转录时不猜测老师/学科。文字线索通过字面/现有通用数字通配匹配；FEEDBACK_AI/AUTO 另允许 Unicode 数字/标点规范化，故历史数字改变仍能召回；Java 不解释这些数字。排序为匹配程度、更新时间、稳定ID，没有实际效果标注前不伪造“正确率权重”。词面无法覆盖的同义改写尚不支持，不引入向量库。

`ORGANIZER_EXPERIENCE_TOP_K` 默认4（1–8）；`ORGANIZER_EXPERIENCE_MAX_CHARS` 默认2400（256–6000）。预算包含头部，超长条目跳过不截断语义，也不影响后面较短的相关规则。每条附 ID/内容版本，更新/停用每次实时读取，未引入缓存，因此即时失效。模型声明 appliedExperienceIds，只有已检索ID、同科目且关联本次相符来源才进入 appliedExperienceIds；这仅验证证据存在，不宣称业务语义应用正确。无依据声明产生质量标记。请求级日志与批次证据保留检索/应用ID。

首轮文本输入不再同时重复传完整原文与原文块。静态指令与动态检索结果独立拼装；提供商 Prompt 缓存没有开启或假设，actual cachedTokens 若提供商返回会记录在 aiCalls.usage。实际 Token 下降仍需同集合实测，字符预算下降不能当作模型成本收益。

## P0-D：按风险进行至多一次定向复核

HomeworkQualityValidator 只生成风险标记，不改写标题/科目，不按业务词删任务，不再用 Java 按序号拆作业。检测：源块/映射/覆盖、数字证据（含通用数字区间）、日期支持、明确科目冲突、重复、疑似合并与经验声明证据。confidence 缺失的0.8只是旧契约默认值，不单独放行也不单独触发复核。

LOW：无标记，保留一次调用，即使有相关经验。MEDIUM/HIGH：按原因决定是否可纠正，必须有可辨认的独立来源才执行至多一次第二轮。不可辨认、来源完全缺失或范围过大时直接提示家长，不把任务摘录当完整图片证据，不循环重试。首轮图片后可从其独立转录查询经验；不会再次提交整张图片。

第二轮使用独立 reviewVersion=1 差异协议，仅提交风险块、明确风险候选、风险原因及相关经验；输出 corrections/additions/blockDecisions 和原因。只能修改给定候选、补充有来源的漏项、把 UNRESOLVED 分类；不能删初稿任务、改来源文字或把已知 TASK 改成 NON_TASK 隐藏遗漏。原有正确候选不会发给模型重写。任何修正必须通过完整转换、来源范围、覆盖不倒退和风险复验：风险必须减少且不能出现新风险类型。失败、矛盾、无改善均保留初稿，返回 REVIEW_* 标记及 needsReview。无法确定的重复任务也交家长确认，不通过字符串删除；没有增加任何基于“绘本”等词自动去重的策略。

最终风险级别、触发原因、复核结果及最终质量标记进入请求 measurement。API qualityFlags 指向具体 sourceBlockIds / assignmentIndexes。ArkTS 确认卡与编辑页显示原文及待核对原因，保留编辑/发布入口；可选字段通过现有草稿克隆/持久化保留，旧响应可读取。新字段是可选兼容字段，不改变本地已存在必需字段与快照版本。单测/HTTP doubles 不替代实际 HAP 构建。

性能门禁：同集合报告比较增加 `--enforce-performance`；P50/P95、失败率或总平均 Token 倒退退出1，实际usage缺失退出2，不能用缺失数据通过成本门禁。质量门禁始终独立检查任务P/R代理及关键字段，不允许提速掩盖质量退化。没有 VERIFIED 金标仍退出2，不能因Mock 1/2次调用测试通过就声称真实复核率≤15%或召回率≥98%。

已知覆盖限制：词面检索不处理任意同义改写，通用数字校验不是完整自然语言语义证明，首轮模型未识别到的图像内容仍需真实金标验证；Chinese数词/复杂跨段引用等不可宣称已穷尽。高风险复核失败仍可家长编辑发布，不把无法确认的结果称为已纠正。
