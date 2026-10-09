# Issue #478｜多文档阅读中 by / through 时间边界与中文答题解释的独立复核（2026-10-09）

## 本批复核范围与实际风险

从当前 main 对照真实英语阅读原文、实际绑定中文翻译目录和学习者可见的答题解析，发现 **3组/15题共享的阅读译文**把包含截止日/截止时刻的 **by** 或 **through** 写成语义可能排除截止时刻的“前”；此外两条**学习者实际可见的答案辅助文本**存在同样问题：

- **P7-EX-DELIVERY（5题 R-P7-DELIVERY-01..05）**：英语 *The express upgrade must be requested by 4 P.M. on October 10*，含10月10日下午4点这一时刻。中文共享材料从“加急升级必须在10月10日下午4点前提出”改为“加急升级申请最迟须于10月10日下午4点（含该时刻）提出”。原文 `ToeicExtraReadingContent.ets`；学习资料 `ToeicQuestionTranslationSupplementaryCatalog.ets` 的 `deliveryPassage`。
- **P7-EX-FILTER（5题 R-P7-FILTER-01..05）**：英语 *The original invoice can remain unchanged if the balance arrives by October 10*，**10月10日当天到达仍符合条件**。中文共享材料“如果余货于10月10日前到达”改为“如果余货最迟于10月10日（含当天）到达”。**同步修正 R-P7-FILTER-04 中文正确选项（B）**：不再称“期限前”，而是“余货保证最迟于10月10日送达”。英文 `ToeicExtraReadingBatchTwo.ets` 原文不变。
- **P7-EX-CATERING（5题 R-P7-CATERING-01..05）**：英语 *Catering orders may be changed through October 8 at 5 P.M.*，包含截止时刻10月8日17:00。5条重复引用的共享中文文章统一从“餐饮订单最迟可在10月8日下午5点前修改”改为“餐饮订单可在10月8日下午5点及之前修改（含截止时刻）”。英文 `ToeicExtraReadingBatchSix.ets` 原文不变。

**真实答题解析一致性补救**：`R-P7-CATERING-04` 在 `ToeicExtraReadingBatchSix.ets` 中的原中文解释“10月8日17点前可更改”也排除了截止时刻，已修订为“最迟在10月8日17点（含该时刻）修改订单，服务方已于10月7日16点确认并接受修改”。原英文题干、四个选项、答案索引=2、证据与同义改写完全不变；因已发布题目解释变化，**R-P7-CATERING-04 从 v1 升级为 v2**，并对应维护 65 题首轮审校账本中的该题 `questionSnapshot.version`，不覆盖旧版本历史作答。

## 变更边界与账本

本批只修改：
1. `ToeicQuestionTranslationSupplementaryCatalog.ets`：2个原始共享译文变量 + FILTER-04 的中文正确选项；
2. `ToeicQuestionTranslationDay18And20Catalog.ets`：5条 CATERING 中文文章重复文本；
3. `ToeicExtraReadingBatchSix.ets`：仅 R-P7-CATERING-04 的中文答题解析。

**阅读题组审批指纹必须跟源码保持一致**：通过已有 `reading_fingerprint` 同等字段重新计算前，确认原 P7-EX-CATERING 文件真实内容所对应的 SHA256 恰与账本 **`a99bf569b6d2ec708d35f21929c4294b12f36851830f9a4e3fe2a89a55fe323b`** 相同。只改该中文解释后，题组指纹更新为 **`e1c48565c2c4ec5a9d46f02ff12afb1f3bfc9d3335b54d7f076929e1eae5d4b5`**，同步三套独立路径：`toeic-editorial-approvals.json`、`toeic-ai-editorial-review-2026-10-08.json`、`toeic-remaining-content-review-2026-10-08.json`。`approvedAt=2026-10-09`，明确为 **AI_EDITORIAL**，不冒充独立人工或 ETS 审核。

**历史一轮阅读审校账本联动**：既有 `docs/product/toeic-issue478-shared-part7-first-pass-65.json` 还按 65 道原题记录了 `questionSnapshot.explanation` 和组级内容指纹。本次在旧来源哈希完整核对的前提下，仅为 5 个 P7-EX-CATERING 第一轮 AI 笔记重绑定组级指纹；只更新 R-P7-CATERING-04 的 `questionSnapshot.explanation`、`questionSnapshot.version`（v1→v2）及 `correctBasis`，另外四道题内容快照及三项干扰项排除理由均保持不变；追加明确的 AI_FIRST_PASS 修订说明，不将审校升级为专家认证。门禁 `validate_toeic_shared_part7_first_pass.py` 不放宽，继续阻断伪造或陈旧快照。

增设 `scripts/validate_toeic_reading_deadlines_issue478.py`，挂入必跑入口 `scripts/validate_toeic_coach.py`。从实际 `ToeicExtraReadingContent.ets`、`ToeicExtraReadingBatchTwo.ets`、`ToeicExtraReadingBatchSix.ets` 取 3 条英语起点，透过运行时引用的 `deliveryPassage/filterPassage` 与重复的五条 CATERING 文本核对 **15个现存翻译 ID**，检查正确选项和真实题目解释、校验完整题组指纹及三套 AI 审校记录。增加6种真正的故意篡改：3个共享译文误译、1个中文正确选项误译、1个答题解释误译、1个伪造审批 SHA 均应被拒绝。

## 不变资产与未完成内容

431道旧题的全部英文题干、四选项与正确答案不变；不重排题目、不改阅读文章或英文证据、不覆盖既有 v1 作答历史与用户记录；R-P7-CATERING-04 后续以 v2 内容参与新训练，译文显隐逻辑和模拟卷禁显译文设计不变。

这只是三个跨文档阅读题组 **15题**和两条学习辅助文本的可核查局部审查，不是全部 **221 条译文 + 70 条拆句**独立专家认证。Issue #478 保持 OPEN。鸿蒙 HAP 编译与 Phone/Pad 实机验收同样不因 CI 的 Python/后端成功而被宣称完成。
