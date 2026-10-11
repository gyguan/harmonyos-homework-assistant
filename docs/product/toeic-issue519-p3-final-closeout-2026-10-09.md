# Issue #519｜P3 发布态独立终验收口（2026-10-09）

## 结论

P3 已对当前学生实际可进入的新训练内容完成发布态独立终验。

- active v2 Part 7：**108/108** 先隐藏既有答案独立解题，再与仓库答案对账；**108 一致 / 0 答案差异**。
- P1/P2 期间 14 个 replacement：**14/14** 重新复核；13 个直接通过，1 个再次版本化。
- 高风险边界表达：对 by / before / until / through / within / no later than / over / at least / up to / unless / except / only / not / may / must / can 做全量定向扫描。
- 分层抽样：词汇30、中文译文30、拆句15、普通P5/P6 30，未发现新的系统性缺陷。
- 本轮识别并整改 **4 个发布态精度问题**。

## 4 个 P3 版本化整改

| 历史/当前 ID | P3 ID | 风险 | 处理 |
|---|---|---|---|
| R-FP1-P5-1528 | R-FP3-P5-1528 | Each applicant + himself/themselves 在不同语法口径下不够绝对唯一 | 改为 All applicants，使 themselves 成为唯一回指 |
| R-FM1-P7-M2-03 | R-FP3-FM1-P7-M2-03 | “I do not need express”不足以严格推出“prefer standard” | 改问本订单哪种配送可免费获得，以 $92 + $80 门槛直接作证 |
| R-FM1-P7-S09-01 | R-FP3-FM1-P7-S09-01 | “badge holders”比原文“employees with active staff badges”范围更宽 | 收窄题干到原文对象 |
| R-FM2-P7-S07-03 | R-FP3-FM2-P7-S07-03 | 原插句在 [3]/[4] 间存在一定语篇可接受空间 | 增加 “that collection” 回指，使 [4] 唯一衔接 |

所有旧 ID 保留用于历史草稿、报告和既有成绩；新会话通过 P3 overlay 路由到新版 ID，不静默重判历史结果。

## 盲审方法

审核顺序固定为：

1. 只读取当前运行态 passage / stem / options；
2. 不读取既有 correctIndex，先独立求解；
3. 记录独立答案；
4. 再揭示仓库 correctIndex 做差异对账；
5. 对题干范围、证据充分性、3个干扰项、时间/金额/数量/条件边界做编辑终验。

108 道 active v2 Part7 的独立答案与现有答案全部一致，因此本轮 4 个整改属于**唯一性和证据精度提升**，不是改错答案。

## 防回退

新增：

- `docs/product/toeic-issue519-p3-final-blind-review-2026-10-09.json`
- `scripts/validate_toeic_p3_final_review_issue519.py`

门禁要求：

- 108 个 active v2 Part7 的 blind-answer 台账完整且答案全部匹配；
- 14 个 replacement 必须全部有终验结论；
- 4 个 P3 新 ID、精确题干、证据和路由必须存在；
- 被替换 ID 必须退出新训练 live queue；
- FM1-G2 的共享文章关系必须继续包含 P3 新题；
- 4 个 P3 新题必须具有中文复盘；
- 抽样数量和高风险边界扫描结论不得丢失；
- P2 已纠正的 by / over / no later than 等边界不得回退。

## 后续口径

本轮完成后，不建议继续做第四轮、第五轮存量全量复核。后续转为：

**新增/修改内容增量盲审 + CI 防回退。**

P3 仍是 AI editorial blind review，不代表 ETS 官方认证或人工语言专家认证；按当前内容验收口径，HAP / Phone / Pad 真机验证不作为本 Issue 关闭阻塞项。
