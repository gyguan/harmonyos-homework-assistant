# Issue #478｜中文时间边界与阅读拆句专项整改（2026-10-09）

## 范围与质量结论

本批检查原始 **221 条隐藏式中文题目翻译**、**70 条阅读拆句**中的高风险表达，定位了 **9 条拆句与 10 条译文**需要确定性修订的项目（约束时刻、严格金额阈值、鼓励语气与解释不应强化为事实）。该数字指真实修改的 **ID 数**，不代表其余条目均已通过外部语言专家的独立语义认证。

修订仅涉及既有教学文案，不重排题目/中文选项，不修改题目 ID、正确答案、选项、evidence、题目版本和训练日计划。历史成绩/持久化作答不会因为本批修改而重置。

## 可核查的逐项差异

| 资产 | 原英文与判断依据 | 中文修订及原因 |
|---|---|---|
| S-018 | *while electrical repairs are being completed*（维修进行期间） | “电气维修完成期间”→“电气维修进行期间”；纠正进行态 |
| S-033 | *before the end of the month* | “月底前”→“在本月结束前”，减少边界不清晰 |
| S-043 | *Employees are encouraged to retain…* | “员工应保留”→“鼓励员工保留”；不得把鼓励改成强制 |
| S-052 | *orders over $100*，严格大于100 | “满100美元”→“超过100美元”；保留100美元本身不满足的差异 |
| S-058 | *provide separate evidence* | 不把“提供证据”直接写成“证明”某人满足条件 |
| S-059 | *defines a prerequisite* | “前置课”→“先修条件”；培训条件不限于一门具体前置课程 |
| S-063 | *Customers whose orders cannot be delivered…* | 消除“订单客户”的生硬语序，明确从句修饰顾客 |
| S-066 | *before reading the rest of the paragraph again* | 删除译文凭空增添的“决定是否需要重读”，恢复原文步骤 |
| S-069 | *A repeated noun…may appear as a synonym* | 调整为“题干中的某个名词…可能以同义词形式出现”，避免“重复出现”歧义 |
| R-P5-COL-0005 | *by Friday*，含周五 | 明确最迟周五（含当天） |
| R-P7-DETAIL-0004 | *by October 10*，含10月10日 | 题干和文章译文同步使用“最迟…10月10日” |
| R-P7-TIMED-1704/1705/1706 | *samples ready by 10:00* | 三条共享译文统一改为“最迟在10:00准备好” |
| R-P7-ONBOARD-01～05 | 报名截止 *by 5:00 P.M. Jan 8*；通行证 *before 8:45 A.M.* | 五条共享译文仅修正报名截止为“最迟于1月8日17:00”（含），**保留通行证严格早于8:45** |

英文来源锚点直接取当前仓库的 `ToeicWeekOneContent.ets`、`ToeicWeekTwoContent.ets`、`ToeicWeekThreeContent.ets`、`PresetToeicContent.ets` 和 `ToeicExtraReadingBatchTwo.ets`，不是凭空重新编写答案。中文改动对应三个 SentenceDrill 源文件和两个 Translation Catalog。

## 受控修改／原发布题保护

之前试卷审校账本绑定 `ToeicWeekTwoContent.ets` / `ToeicWeekThreeContent.ets` 两份完整 Git Blob SHA。由于本次教学译文改动包含这两文件，必须重新绑定账本，不能让 CI 在源码变更后静默通过。本批实际比对 **main@274b158b** 与修复分支的三份 Week 源码：

1. 使用成对括号、字符串感知的 `new ToeicSentenceDrill(...)` 完整构造器屏蔽法；
2. 屏蔽后 WeekOne、WeekTwo、WeekThree 剩余源码逐字节相同，原始拆句数量保持 30/30/10；
3. 仅在 `toeic-issue478-active-mock-p5p6-first-pass-92.json`、`toeic-issue478-v2-derived-part7-semantic-review-72.json` 中更新 WeekTwo/WeekThree 的 Git Blob 指纹，并标注 `sourceChangeAttestation`；不更改任何题目审核答案或干扰项审校理由；
4. 原有 92 题 Part5/6 和 72 题派生 Part7 的强制动态逐题校验继续运行、原审校账本失配会 FAIL。

新增 `scripts/validate_toeic_bilingual_semantics_issue478.py`：对 221 条译文/70 条拆句做 ID 完整性核对，对 19 条实际修订资产做英中语义锚点检查，并分别进行“over→满”和“by→前”的负向篡改测试；接入 `validate_toeic_coach.py`。

## 未完成项

本批为有源语义问题的针对性整改，**不是 221+70 条所有文本的独立第二轮语言认证**。其余译文的长句逐词语义比对、300 个高频词完整 IPA/词义/搭配验证、HarmonyOS HAP 编译与 Phone/Pad 实机验收仍待继续。#478保持 OPEN。
