# Issue #478｜P2 最终收口：Part 7 + 中文译文 + 拆句（2026-10-09）

## 结论

P2 内容范围已完成整批 AI 编辑二轮复核，不再保留待二轮状态。

- 原始 Part 7：**246/246**
  - **245**：`PASS_AI_SECOND_PASS`
  - **1**：`ARCHIVED_AMBIGUITY`（`R-M1-P7-094`）
- 活跃 Day14/Day19 模考 Part 7：**108/108** 继续通过现有语义门禁
  - authored：36
  - derived fresh-context review：72
- 中文题目译文：**221/221**
  - 218 二轮通过
  - 3 本批整改后通过
- 长句拆解：**70/70**
  - 68 二轮通过
  - 2 本批整改后通过

本结论表示 `AI_EDITORIAL_SECOND_PASS` 完成，不宣称人工语言专家或 ETS 官方认证。

## 1. 原始 Part 7 最终二轮复核

三份既有首轮审校台账合并为最终 246 题二轮台账：

- `toeic-issue478-part7-semantic-first-pass-71.json`
- `toeic-issue478-shared-part7-first-pass-65.json`
- `toeic-issue478-inline-verbatim-first-pass-110.json`

最终证据：
- `docs/product/toeic-issue478-p2-final-part7-review-2026-10-09.json`

每个题目最终记录：
- 当前源码绑定 SHA-256
- 唯一正确项
- 正确项依据
- 3 个干扰项逐项排除
- evidence / inference 支持
- 时间、数量、条件边界复核
- 当前版本与源文件

### 唯一保留隔离项：R-M1-P7-094

原文同时出现：
- `The south entrance will be closed Oct. 4–8.`
- `Clients arriving next week...`

由于邮件没有绝对日期，无法独立证明“next week”一定落在 Oct. 4–8。历史 v1 保留用于旧报告，但该 ID 继续从新训练队列排除，不能标记为语义通过。

此前 `R-P7-DOUBLE-1104` 已补足 `11:30–11:50 Cloud Operations`，现在可证明整场活动在 noon 前结束，本轮二次确认通过。

## 2. 本批 3 条中文题目译文修订

| ID | 问题 | 修订 |
|---|---|---|
| R-P5-VERB-0206 | `by Friday` 被译为“周五前”，错误排除周五当天 | 改为“最迟于周五（含当天）” |
| R-P7-DOUBLE-1105 | `over $100` 被译为“满100美元”，把等于100错误纳入 | 改为“订单金额超过100美元” |
| R-P7-TRIPLE-1203 | `by November 1` 被译为“11月1日前”，错误排除11月1日 | 改为“最迟能于11月1日开始工作（含当天）” |

其余 218 条译文按英文题干、选项顺序、日期、金额、否定、情态、条件与边界逐项复核通过。

最终证据：
- `docs/product/toeic-issue478-p2-final-bilingual-review-2026-10-09.json`

## 3. 本批 2 条拆句修订

| ID | 问题 | 修订 |
|---|---|---|
| S-037 | `no later than October 18` 现有中文容易理解为“只在10月18日当天联系” | 明确为“最迟于10月18日收到联系（含当天，也可能更早）” |
| S-062 | `after payment is received` 译为“付款收到后”不自然且主客关系弱 | 改为“收到付款后自动发送” |

其余 68 条拆句按主干、修饰范围、条件/否定、日期数量与中文自然度复核通过。

## 4. 活跃模考 Part 7

P2 没有重复伪造“新一轮”模考审校，而是复验已有独立证据：

- `toeic-issue478-v2-authored-part7-review-36.json`：36 authored
- `toeic-issue478-v2-derived-part7-semantic-review-72.json`：72 derived fresh-context
- 共 **108 个 active v2 Part 7**

本批只修改 WeekTwo/WeekThree 中的 S-037/S-062 拆句中文，不修改任何模考题干、文章、答案、选项、evidence 或 StudyDay 题目 ID。相应整文件 Git blob 已重新绑定，并保留显式 `sourceChangeAttestation`。

## 5. 强制防回退

新增：
- `scripts/validate_toeic_p2_final_review_issue478.py`

并接入：
- `scripts/validate_toeic_coach.py`

门禁要求：
1. 当前原始 Part7 必须保持 **246**，最终台账必须一一对应；
2. **245 PASS + R-M1-P7-094 唯一 ARCHIVED_AMBIGUITY**；
3. 每题源码 SHA、正确项、evidence、三个干扰项必须与最终台账一致；
4. `R-M1-P7-094` 必须继续退出 live queue；
5. 中文译文必须保持 **221**，拆句必须保持 **70**；
6. 最终双语台账绑定 9 个源码文件的 Git blob；
7. 3 个译文和 2 个拆句的修订必须保持，旧错误表达不得回退；
8. active v2 Part7 必须继续保持 36 authored + 72 derived 的既有审核证据。

预期关键输出：

`TOEIC_ISSUE478_P2_FINAL_PASS original_part7=246 pass=245 archived_ambiguity=1 active_v2_part7=108 authored=36 derived_second_context=72 translations=221 pass=218 corrected=3 drills=70 pass=68 corrected=2 reviewer=AI-GPT5.6-SOL expert_certification=NO`

## P2 关闭口径

从内容审核角度，P2 可在上述门禁和 CI 通过后标记为 COMPLETE。

结合此前 P1：
- 原始 Part5/6：185
- 原始 Part7：246
- 原始 Reading 总题数：431
- 词汇：300
- 拆句：70
- 中文译文：221

因此 P1 + P2 完成后，Issue #478 当前定义的内容准确性审查范围全部覆盖。
