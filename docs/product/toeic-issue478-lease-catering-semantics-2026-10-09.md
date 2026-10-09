# Issue #478｜LEASE 截止条件与 CATERING 收费人数语义复核（2026-10-09）

## 本批定位的问题（2组／10条已发布阅读题）

本轮从当前 main 的英文正式题组，逐字核对对应的 `ToeicQuestionTranslationDay17Catalog.ets`、`ToeicQuestionTranslationDay18And20Catalog.ets` 中学习者按需查看的文章译文，并穿透实际答题解析：

| 源组 | 英文原文 | 中文旧稿错误 | 订正 |
|---|---|---|---|
| P7-EX-LEASE（R-P7-LEASE-01..05） | `We can extend the rental through September 30 if the agreement is signed by August 15.` | “如果在8月15日前签署协议”含义容易排除8月15日当天，影响是否允许租期延长的条件判断 | 5条文章统一改为“如果最迟于8月15日（含当天）签署协议，我们可以将租期延至9月30日”。 |
| P7-EX-CATERING（R-P7-CATERING-01..05） | `Coffee service costs $4 per attendee served and boxed lunches cost $8 each.` | “咖啡服务按每人4美元收费”会被误解为135位出席者全部被收费，而实际按供应咖啡的参加者收费；原始账单是100份咖啡 × $4 +120份午餐 × $8 = $1,360 | 5条文章统一改为“咖啡服务按实际享用咖啡的参会者每人4美元收费，盒装午餐每份8美元”。 |

另从 `ToeicExtraReadingBatchFour.ets` 定位了真实学习者可见的 **R-P7-LEASE-04** 解题解析原句“物业回复写明8月15日前签署续租协议”，同样存在截止日期语义不清。现改为“物业回复写明续租协议最迟应于8月15日（含当天）签署。”已发布题目因此按照 `docs/product/toeic-coach-content-standard.md` **从 v1 提升至 v2**。题目 ID、英文材料、题干、答案索引=3/选项 D：August 15、证据和干扰选项全部保持不变，不用新版题目重判历史作答。

## 已有审校账本的精确同步

对原正式英语题组完整提取阅读组文档、5个问题、英文证据、解析与正确答案，采用既有 `reading_fingerprint` 字段集计算 SHA256，**先确认旧源哈希 `93fc10863a1f04b6f51c894a338df91de2d9994310464db342382b835d67744d` 与原审批账本完全相符**，再计算修订后组哈希 `f392ccd0df36893de38fb59111f3b2c9bb06ca695976f844cd435197269b354c`。

同步更改：
- `docs/product/toeic-editorial-approvals.json`（P7-EX-LEASE 改为新 SHA 和真实批准变更日期 2026-10-09）；
- `docs/product/toeic-ai-editorial-review-2026-10-08.json` 与 `toeic-remaining-content-review-2026-10-08.json`（保留旧文件名、追加 2026-10-09 差异记录，修正同组 SHA）；
- `docs/product/toeic-issue478-shared-part7-first-pass-65.json` 中 5 个 P7-EX-LEASE 共享题组快照都绑定新组哈希；**只更改第04题** `questionSnapshot.explanation`、`questionSnapshot.version=2` 和 `correctBasis`。其他四题的所有审校快照、答案、干扰项理由不变。

保留全部审核模式 `AI_EDITORIAL` / `AI_FIRST_PASS`，绝不冒充 HUMAN / ETS 认证。P7-EX-CATERING 这次**只改按需显示的中文文章译文**，英文题组和答题解析未变，因此无需伪造该组新版发布哈希。

## 强制测试与范围

新增 `scripts/validate_toeic_lease_catering_bilingual_issue478.py` 并在必跑 `scripts/validate_toeic_coach.py` 中执行：
- 验证整个发布译文目录仍有 221 条，LEASE/CATERING 各5条的实际中文文章全文完全一致，且与英语源文的 `by August 15`、`per attendee served` 定义一致。
- 对 CATERING 的 100 份咖啡、120份午餐、原价 $1,360 进行源文字面检查和数值校验，不用**预期参会人数120人**替代实际获咖啡服务人数100。
- R-P7-LEASE-04 的真实答案解析、版本 v2、英文答案及组指纹 / AI 审校快照必须一致。故意回退两篇中文文章、恢复题目 v1、伪造审批 SHA、伪造 65 题共享笔记 SHA、恢复旧版解题解析，共 6 项负向测试都必须正确失败。

修改只局限 2 个翻译目录、1个已发布题解析和对应审校记录 / 质量门禁；不更改题目英文正文、选项、答案或两个历史模拟卷。**本批是两组共10条的定向语义复核，绝不宣称全部221条译文或70条拆句完成独立专家语言审核**。HarmonyOS HAP 编译和 Phone/Pad 实机验收也需要另外证明；Issue #478 保持 Open。
