# Issue #478｜发件日期不能证明收件日期：VENUE 跨文档证据复核（2026-10-09）

## 发现的事实推断错误

本批逐一对照 P7-EX-VENUE 两份英文原始阅读材料、5道正式题、按需展开的中文题目及实质答题解析。发现 **R-P7-VENUE-05（已发布 v1）** 的错误并非简单译文措辞，而是题干和正确答案证据不充分：

- 预订指南原文：`Requests to change rooms must reach the venue coordinator by September 12.`（换厅申请必须 **最迟9月12日送达协调员**，含当天）。注意动词 **reach**，并非仅“send”。
- 第二文档：`DOCUMENT 2 — EMAIL, SEPTEMBER 10`，邮件写明希望从 Maple Room 调整到 Cedar Hall，并未提供**实际送达或协调员确认收到的时间**。
- 旧题干：`Was the request for a different room sent by the stated deadline?`；旧正确选项：`Yes, it was emailed on September 10`，旧中文解释：“指南要求9月12日前提出调整，邮件日期为9月10日。”这组内容把邮件日期等同于达到“送达协调员”截止要求，**超出可证实信息**。

## 修复内容

将 R-P7-VENUE-05 改为真正尊重**不可证实事实**的跨文档推理题：

- 英文题干：`What is supported about the room-change request by the two documents?`
- 四选项（保留正确答案C/索引2）：
  A. `The coordinator approved Cedar Hall on September 10`
  B. `The request was received after September 12`
  C. `The email is dated September 10, but no receipt date is stated`
  D. `The room change adds no rental charge`
- 中文题干：`综合预订指南和邮件，关于换厅申请，哪项说法有资料支持？`
- 中文正确选项：`邮件标注日期为9月10日，但材料未注明协调员的收件日期`（其他选项逐一对齐英文）。
- 实际学习者可见的中文解析：`指南要求换厅请求最迟于9月12日送达协调员，但9月10日只是邮件标注日期，材料未给出实际送达或协调员确认收到的时间，不能断言已满足送达截止日。`
- 保留从两篇原文直接可定位的英语证据 `Requests to change rooms must reach ... by September 12 || DOCUMENT 2 — EMAIL, SEPTEMBER 10`；同义提示更新为“email date is not proof of receipt; requests must reach the coordinator by September 12”。
- 已发布题的 **version 1→2**。题目ID、跨文档技能分类、正确选项**索引2**、原两篇英文文章及其余四题全部保持不变；不覆盖历史作答或用 v2 重判旧记录。

## 内容指纹与审校溯源

- 在修订后重新签署前，完整提取原 P7-EX-VENUE 题组的 2 篇文档与5个正式题的词句、解释、证据、同义提示、难度等 fingerprint 字段，使用等效 `reading_fingerprint` 计算并**逐字验证旧 SHA `5f17c7567e2a09dd390e8ca75d9066abd4b55c7fae4c595ce77e8ace7f4ad522` 完全匹配主审批账本**。只对 VENUE-05 修改发布内容后，新 SHA 为 `1e1385c53112eb62795e89938961f04ef0cc8f403b136f1dc466c6873e49f78d`。
- 对 `docs/product/toeic-editorial-approvals.json` 和 `docs/product/toeic-ai-editorial-review-2026-10-08.json` 的该题组做 AI-only 内容重绑定及2026-10-09准确日期记录；对 `docs/product/toeic-issue478-shared-part7-first-pass-65.json` 中五条 VENUE 题组同步新 SHA，其中只更新 VENUE-05 的完整 v2 题目快照、正确依据和三项干扰项解释。旧的一轮审校门禁没有放宽。
- `docs/product/toeic-remaining-content-review-2026-10-08.json` 本就不覆盖 P7-EX-VENUE，该账本**没有伪造新增 VENUE 记录**。所有既有审批身份仍明确 `AI_EDITORIAL` / `AI_FIRST_PASS`，**不是**人工语言专家或 ETS 官方认证。

## 防回退与限制

新增 `scripts/validate_toeic_venue_receipt_issue478.py` 并强制从 `scripts/validate_toeic_coach.py` 执行，严格验证两份**实际英文源材料**、5题发布组、真实中文目录全部221译文、VENUE-05中英文题干/4选项/正确索引2、学习者可见解释、发布 v2、真实审批SHA及65条共享首次审校记录。7个故意引入错误的负向对照分别恢复旧英文题干、旧中文题干、旧正确中文选项、旧v1、伪造审批SHA、旧审校快照及在原英语材料中人为新增“已确认收件”的情形，必须被检测失败（最后一种提醒源文变化后不能沿用“收件日期未知”的旧结论）。

**该批只代表1道题的真实证据闭环审校**；不是全部221条译文/70拆句/300词或全部65个新阅读题完成独立专家检视。HarmonyOS HAP 未在本次 GitHub 自动任务中实际编译，Phone/Pad 实机发音与交互仍需后续单独验收。Issue #478 保持 OPEN。
