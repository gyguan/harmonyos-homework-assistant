# Issue #478｜Day14/19 新版 Part5/Part6 逐题首轮复核（第八批）

**审校日期：2026-10-09**。审核对象为实际学习计划组装的两个新版100题模考：每套 Part5 30题 + Part6 16题，**两套共92道**。不同于按旧ID计数，本次区分实际活动题ID、历史原始题ID与新造的替代题ID。

## 复核结果

- 92 道 Part5/6 已逐题记录**正确选项推理依据92条、其他三项排除理由276条**，分别对应现行两套卷子的真实题目顺序。
- 记录：`docs/product/toeic-issue478-active-mock-p5p6-first-pass-92.json`，另保留 `...active-mock-p5-review-notes-60.txt`、`...active-mock-p6-review-notes-32.txt` 的简明逐题编辑稿。台账保存实际新旧来源、卷内位置、英文文章、题干、四选项、正确答案、原解析、版本以及来源Git blob指纹。
- 审校门禁：`scripts/validate_toeic_active_mock_p5p6_issue478.py` 每次运行重建新版46+46题的题号/答案/选项/释义快照，检查92条记录、276条排除说明以及关键源码的7个Git blob摘要。源码、组卷规则、选项或者审校记录修改后都需重新复核；附负向答案篡改检查。
- **范围界限**：这仍是AI第一轮复核，不是两位独立教师审稿、ETS权威认证或真机运行证明。结构校验也不能自动证明所有英语内容百分之百无争议。

## 新发现的两处实质性多解风险

Day19的两道 Part6：

1. **`R-FM2-P6-004`**：句子 `We expect the work to be _____ by noon.`；`complete` 与 `completed` 均可以成立（形容词表语/被动过去分词）。新版以 **`R-FM2-P6-017`** 替换，只保留 `completed`（B）及不具相同表达合法性的其他干扰项。
2. **`R-M2-P6-008`**：句子 `... while these improvements are _____`；`complete` 与 `completed` 均可能成立（状态形容词/被动谓语）。新版以 **`R-FM2-P6-018`** 替换，保留 `completed`（B），删除 `complete` 干扰项。

发布调整：新增 `ToeicMockDay19Part6CompletionContent.ets`，通过 `PresetToeicContent.studyDays()` 仅为**新Day19考试会话**替换卷内索引33、37，旧两个ID、版本1及历史作答完全保留。通过 `liveTrainingQuestions()` 排除旧版两道双解题，确保正常练习、错题、慢题和补弱队列不会再次使用。新版Day14/19都维持100题、P5=30/P6=16/P7=54。

## 尚待完成

后续针对72道新版Part7派生题逐题审查证据/干扰项新组合是否仍唯一；以及300个单词音标、词性、中文义项、搭配、发音与例句，221条隐藏翻译与70条拆句的专项准确性复核。HAP编译及Phone/Pad真机测试仍需由实际HarmonyOS SDK环境验收。

Issue #478 继续保持 OPEN。
