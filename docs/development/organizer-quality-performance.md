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

## P1：有界私有结果缓存与图片保真

重复文字/图片输入在当前进程复用已通过通用质量校验且无风险提示的结果；空结果、失败和仍需核对的结果不缓存。缓存只减少推理，权限检查、图片格式/尺寸检查、当前批次证据与快照保存照常执行。缓存结果仍需家长确认，质量校验通过不代表真实语义准确率已经验证。

键使用结构化 JSON 的 SHA-256，包含 family/student、完整文字（保留空白）、原始图片 data URL hash、补充文字、已核验老师标签、日期（上海时区）、年级/学期/教材、provider/endpoint/protocol/model、结构化输出/思考配置、Prompt/Schema、适用规则内容/显式版本以及当前学生全部经验的内容/版本/启用状态与检索配置。图片没有文字时也先查询经验版本；每次 lookup 都读取 DB，停用或更新不会被 TTL 延迟。推理期间规则/经验更新则放弃本次缓存写入。旧版本条目不可命中，按 TTL 清除。

不引入 Redis、新表或新的业务状态。默认进程内 LRU 128 条，UTF-8 序列化响应总计最多 8 MiB，TTL 300 秒；单条超限不缓存。过期条目在 get/put 时清理，并每 60 秒清理一次空闲进程中的过期内容。缓存中仅保存哈希键和私有响应，不保存图片、不写磁盘、不记录正文；进程重启自然失效。环境变量 `ORGANIZER_CACHE_ENABLED=false` 可回退到逐次推理，其他配置为 `ORGANIZER_CACHE_TTL_SECONDS`（上限 900）、`ORGANIZER_CACHE_MAX_ENTRIES`（上限 1024）、`ORGANIZER_CACHE_MAX_BYTES`（上限 32 MiB）。并发相同输入可能各调用一次模型，不增加等待锁或后台重试。

命中测量 `cacheHit=true`、`callCount=0`、本次新增 tokensIn/out=0；实际推理缺失 provider usage 仍为 unavailable。报告提供 HIT/MISS/UNKNOWN 分桶；性能门禁同时检查冷请求，不能用大量热命中掩盖冷推理变慢。真实比较应分别启动关闭/启用缓存的相同固定样本运行，并保留 `cacheHit` 埋点。只有热请求而没有可比冷请求时门禁为 UNAVAILABLE。

删除固定 1536px 有损缩图，客户端和后端均保留 JPEG/PNG 原始字节、EXIF 元数据和所有像素，其他 SDK 支持格式按原尺寸转成无损 PNG；超限要求用户裁剪，不静默降质（仍限 4 MiB、40MP，并先检查尺寸再完整解码）。此前的统一缩图没有覆盖小字/手写/表格的 VERIFIED 质量证据，因此不能将它当成无损性能优化。此改变可能增加视觉 Token/耗时，需与命中收益分开评测；不要宣称 P50/P95 或成本目标已达成。EXIF 自动朝向与真实阶段/取消 UX 已在后续切片补齐；按需裁剪增强和跨模型对比继续增量实施；不自动引入第二次 OCR 调用。

## P1：真实等待阶段、停止等待与超时

V2 布置作业页通过 ViewModel → ImportService → RemoteApi 展示实际客户端阶段：读取文字或准备图片 → 等待 AI 响应 → 检查已收到的响应 → 保存核对草稿。离线/普通网络失败仍明确走原有本地草稿提示。取消固定“3–8 秒”的承诺，不模拟后端 OCR/复核百分比；同步 API 未提供服务端阶段流，界面不会声称已经进行到复核。

每次点击整理创建独立操作范围和 270 秒总等待上限。此上限覆盖图片准备及后端最多两轮各 120 秒调用，organizer 原生 HTTP readTimeout 为 300 秒，其他 API 保持原有默认。用户可点“停止等待”，或离开页面时自动停止；销毁当前 native HTTP 请求、保留输入文字/图片、拒绝迟到响应，且不触发本地降级或写入新草稿。停止旧请求不会取消新请求，也不会因迟到 401 登出当前会话。图片准备若 SDK 无取消 API，会完成资源释放后在发 HTTP 前拒绝继续。

“停止等待”是客户端停止消费结果，不承诺终止服务端正在执行的模型调用或退回费用；服务端仍可能完成独立证据/快照保存。未引入后台任务、轮询状态表或工作流。网络超时/取消不自动循环重试。原有 studentId 在第一次 await 前捕获、响应写回原学生导入记录的策略保持不变。

`node scripts/test_homework_import_lifecycle.mjs` 运行实际 Operation/HttpClient/RemoteApi/ImportService，SDK 和 Repository 使用测试替身；覆盖准备阶段停止、原生请求中停止、迟到响应、总超时、立即重试隔离、本地降级及切换学生。测试不依赖真实模型，也不替代 HAP/真机验证。页面继续使用共享 theme 的可读宽度、触控尺寸和字体，不新增设备断点或第二套 Phone/Pad UI。

## P1：EXIF 自动朝向与输入身份

JPEG APP1 / PNG eXIf 的 IFD0 Orientation 采用 CIPA DC-008 的 1–8 方向约定（含镜像）。后端在同一次模型调用前校正：仅置换解码后的像素位置，不插值、不缩小、不锐化，保留每个像素与 alpha；需要校正时输出无损 PNG 并去除旧方向标记，防止重复旋转。原本正向的 JPEG/PNG 保持原始字节。参考规范：https://www.cipa.jp/std/documents/e/DC-008-2012_E.pdf 。

方向读取仅访问有界 IFD0，不追踪 GPS/缩略图指针；支持 TIFF 两种字节序，拒绝截断、溢出、非法值、重复方向元数据及错误 eXIf CRC。输入仍限 4 MiB/40MP，校正后的输出也限 4 MiB；编码缓冲在写入前检查上限且仅驻内存，不借助磁盘临时文件。若照片无法无损落入容量预算，明确要求重新导出/裁剪，不能偷偷压成 JPEG 或回退到错误方向。

内部模型适配增加可兼容的原始图片 Hash 参数。Service 校验家庭所有权后才准备图片，缓存键同时包含原始字节身份、校正后输入及处理版本；旧四参数适配仍可使用。测量增加 `imagePreparation` 的处理版本、宽高、方向和输入/输出字节数，不记录图片、元数据正文或原始 Hash。模型 usage 继续按实际 provider 返回统计，不能把像素数换算成“实际图片 Token”。

单测逐像素验证 8 个方向、小端/大端、透明像素和 JPEG 解码后像素的保真；HTTP fake-provider + PostgreSQL E2E 验证 7×3 图片以 3×7 输入到 provider、低风险仍一次推理、错误方向不发请求。以上是几何/协议验证，不代表已完成真实小字/手写/表格语义金标评测。
