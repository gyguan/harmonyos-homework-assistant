# Issue #478｜培训报销：计划提交与已经提交的语义区别（2026-10-09）

## 复核发现

在 P7-EX-TRAINING 原发布组（5题，2份材料）中，唯一涉及此问题的是 **R-P7-TRAINING-04**。英语邮件原文是：

- `I completed the approved project-management course on May 23`
- `EMPLOYEE CLAIM MESSAGE, JUNE 2`
- `Can you confirm the amount I should claim before I submit the form today?`

结论：Daniel 在 **6月2日尚未提交**报销申请，只是在准备当日提交，且咨询了申请金额。政策是结业后 10 个**自然日**内提交，5月23日之后的第10个自然日为6月2日，因此只能明确地回答 **“如果6月2日提交，将符合期限”**，不能把尚未发生的提交写成已发生的事实。

旧英题 `Is Daniel submitting the request within the allowed period?` 和原中文 `Daniel 是否在允许的期限内提交申请？` 语态缺乏假设限定；旧中文解析只说明6月2日为截止日，没有解释实际是否完成提交。本次统一修订为：

- 英文题干：`If Daniel submits his reimbursement request on June 2, will it meet the deadline?`
- 英文正确选项（原 B / 索引1）：`Yes, June 2 is the tenth calendar day after May 23`
- 中文题干：`如果Daniel于6月2日提交报销申请，是否符合规定的期限？`
- 中文选项B：`符合，6月2日正好是结业后的第10个自然日`
- 答题解释：`Daniel于5月23日完成课程，6月2日是此后第10个自然日。邮件表示他当日尚未提交申请，因此只有在6月2日当天提交才符合期限，不能当作已经提交。`
- 英文 evidence 增加真实材料中可直接定位的 `before I submit the form today`，避免只援引日期推断“已提交”。
- 更正后的本题已发布版本 **v1 → v2**。题目 ID、正确索引1、课程费用与学员信息、两份英文原始文章和其余四道题均不修改。旧训练历史不使用新版内容重新评分。

## 审校证据与内容一致性

用仓库既有 `reading_fingerprint` 的字段集合（组ID、5道题ID、2篇英文材料、题干、4选项、答案索引、解析、英文证据、语境改写、耗时、难度）计算指纹，先验证原主审核内容 SHA256 **`4df33dfb2437a286966908568ac9e985184176afb84eb8525b91baea2923ae4d`** 与实际未修改旧题组完全一致，再对变更后的组指纹重算为 **`7c86e1d0b1b9dadf48b4ff1d72cce555ea62853bbf275283781c4b6ecbebc0be`**。

同步四类证据：
1. `docs/product/toeic-editorial-approvals.json`（P7-EX-TRAINING 新内容指纹、AI_EDITORIAL 真实编辑更新日）。
2. `docs/product/toeic-ai-editorial-review-2026-10-08.json`（修订说明及内容指纹）。
3. `docs/product/toeic-remaining-content-review-2026-10-08.json`（已发布组的第04题英文题干、正确选项及英文证据和组指纹）。
4. `docs/product/toeic-issue478-shared-part7-first-pass-65.json`（5道共享组问题 hash 同步；仅第04题的 version / stem / options[1] / explanation / evidence / correctBasis 与错误选项排除理由同步，不动其他四题快照）。

新增 `scripts/validate_toeic_planned_submission_issue478.py`，纳入 `validate_toeic_coach.py` 必跑门禁，校验真实英语材料、221条翻译覆盖、上述实际展示的中英文新题干/正确选项、题目版本v2、审核指纹和 AI 初轮/次轮/65题一轮审校记录，同时注入六项错误回退（旧英文题干、旧中文题干、旧发布版本、旧答题解析、伪造审批 hash、过期共享审核快照），必须全部被拒绝。

## 边界说明

这是 **1道已发布题的实质语义独立复核**，不是声称65道 Part7、221条中文译文、70个拆句或300词的语言学全部复核通过。所有审批依然标记 **AI_EDITORIAL** / **AI_FIRST_PASS**，不伪装人类专家或 ETS 认证。Harmony HAP 构建和 Phone/Pad 实际朗读不在此批验证范围，Issue #478 保持 Open。
