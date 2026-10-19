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

全为 DRAFT 时退出码 2、NO_VERIFIED_GOLD，不报告语义准确率。DRAFT 仍可输出性能数据。VERIFIED 必须来自真实老师输入、经家长人工核验，不能把测试构造样本标记成真实金标。expected 的 keywords 是**任务匹配代理**；fields 是人工标注的实际 DTO 字段精确对比，sourceBlockIds 是独立证据标注。关键词 P/R 与字段准确率均不能替代独立语义复核。

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
