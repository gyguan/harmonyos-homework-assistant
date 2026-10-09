# Issue #478｜TOEIC 高频词业务语境二轮复核（2026-10-09）

## 本批范围及实际改动

本批从 300 条已发布词汇中聚焦财务口径、系统故障、酒店经营与活动统计等容易混淆的商务语境，仅对 **5 个批次词条和1个学习卡片真实展示例句（V-056）** 做局部质量精修。AI 二次审校、静态门禁和提交审核都**不等于** 300 条词的完整人类语言专家或 ETS 官方内容认证。

| 资产 | 原词条/例句问题 | 修订内容 | 证据与说明 |
|---|---|---|---|
| V-180 `margin` / `profit margin` | `difference between revenue and cost` 没说明利润差额通常可用比例呈现，初学者容易将利润金额与利润率视作完全等价 | `difference between revenue and cost, often expressed as a percentage` | Cambridge Business English 对 margin 的差额义和“通常以百分比表示”同时说明；本批**没有**把绝对利润额与利润率断言为始终相等 https://dictionary.cambridge.org/dictionary/english/profit-margin |
| V-202 `troubleshoot` | `diagnose a problem` 只包含定位原因；修复方向被省略 | `identify a fault and seek a solution` | Cambridge Business English 含寻找原因并尝试找到解决方法，不保证每次问题已被成功解决 https://dictionary.cambridge.org/dictionary/english/troubleshoot |
| V-207 `cancellation` / `cancellation fee` | `The hotel charges a cancellation fee for late changes.` 把泛化的改期也说成“取消费” | `The hotel charges a cancellation fee when guests cancel after the deadline.` | Collins 酒店词汇：取消截止时间之后退订可能产生取消费；避免将普通修改均当取消 https://www.collinsdictionary.com/us/dictionary/english/cancellation-fee |
| V-214 `occupancy` / `occupancy rate` | `room utilization` 过于宽泛，不能给出酒店 80% 入住率的计算口径 | `percentage of available hotel rooms occupied` | STR/CoStar 商旅统计口径：期间内已售客房与可售客房之比；客房占用率并非酒店全部资源利用率 https://www.costar.com/products/str-benchmark/resources/glossary |
| V-297 `attendance` | `presence` 仅指“在场”，无法解释会议例句的 `higher attendance` 所表示人数增长 | `number of people attending an event` | Cambridge Business English 含活动出席人数与工作出勤两类用法；此处按 conference 例句限定 https://dictionary.cambridge.org/dictionary/english/attendance |
| V-056 `charge`（原 V001-V090 补充例句） | 真实学习卡片里依旧为 `The hotel will charge a cancellation fee for late changes.`，与 V-207 同一错误 | `The hotel will charge a cancellation fee if guests cancel after the cancellation deadline.` | Collins cancellation fee 仅在符合退订条款时发生；修改的是 UI 实际显示的 `ToeicVocabularyExampleCatalog.ets`，不会修改历史核心词条或审批哈希 https://www.collinsdictionary.com/us/dictionary/english/cancellation-fee |

## 稳定性与审校账本

- 修改 `ToeicVocabularyBatchThree`、`Four`、`Five`、`Seven` 这 4 个词库批次文件，并同步修复 `ToeicVocabularyExampleCatalog.ets` 中原始词 V-056 在真实学习卡片展示的例句，5 个词条继续保留原 `V-xxx` ID、词性、美音 IPA、难度、场景、搭配和发布状态；V-207 和 V-056 补充例句更正，其他 4 条只修改同义解释。
- 使用仓库既有 `vocabulary_fingerprint` 字段集（包括原文 ID、含义、词性、等级、场景、搭配、近义表达、例句、IPA），为这 5 条重算精确哈希，不触碰无关的 175 个批次词条审批指纹。
- 更新 `toeic-editorial-approvals.json` 的 5 条 `approvedAt=2026-10-09`，审核性质继续是 `AI_EDITORIAL` 而非 `HUMAN`；同步历史初审台账 `toeic-ai-editorial-review-2026-10-08.json` 的 `updatedAt`、修订说明和哈希。
- V-202、V-207、V-214、V-297 原属于 V181-300 二次审校记录，因此必须同步更新 `toeic-remaining-content-review-2026-10-08.json` 的同义项/例句/哈希，并追加修订台账；V-180 仅存在 V121-180 初轮审校账本。**没有**把 2026-10-09 修订伪装成 2026-10-08 期间已完成。
- `scripts/validate_toeic_business_context_issue478.py` 被纳入 TOEIC 必跑质量入口 `validate_toeic_coach.py`，核验五条指定审校源语义、现存例句/词性、审校哈希、证据日期及二次审校一致性，并验证恢复旧利润解释、旧“晚修改=取消费”、旧入住房间利用率、旧出席释义、伪造 V-202 审校哈希五种词条篡改及第六项 **V-056 展示例句回退成‘late changes’** 的篡改必须失败；必须直接解析 `get_supplement()` 和 300 条真实有效展示例句，不能仅检查 V-207 模拟数据。
- 不影响任何模拟卷题目、翻译中文、用户做题历史、用户单词记忆/标记记录及 TTS 服务。HAP 编译和真机发音仍未获得本批可用证明。

## 未完成的 Issue #478 范围

保留 Issue Open。继续逐词精校其他词汇的意义范围、语法与同义改写，重点核验源文对照、容易遗漏的排他/否定/日期范围以及 221 条中文题目译文与 70 拆句的剩余独立复核。全量词库指纹完整性 PASS、局部字典定向修订 PASS **不是** 300 词全部语义准确的官方保证。
