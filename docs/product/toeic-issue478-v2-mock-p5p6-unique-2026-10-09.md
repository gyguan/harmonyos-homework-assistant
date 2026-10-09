# Issue #478｜新版 Day14/19 模考 Part5/6 三处双答案风险修复

日期：2026-10-09。此报告针对实际出版的新版模拟卷与旧版归档数据，两者不能互相覆盖。

## 逐题结论

| 旧题（必须保留 v1 历史） | 歧义原因 | 现行模考新 ID | 唯一答案与排除原则 |
|---|---|---|---|
| R-M2-P5-007 | `visits` 可表达已排程的下周行程，并非仅 `will visit` 正确 | R-FM2-P5-007 | 保留正确项 `will visit`（C）；A 改为缺第三人称单数变化的 `visit`，其余分别是过去/完成时 |
| R-M1-P6-033 | `IT team ... and they/it will reconnect` 中，集合名词 `team` 允许单数和成员复数两种语义回指 | R-FM1-P6-033 | 保留 `they`（A）；另三项改为 `them/their/themselves`，均不能单独作此处主语 |
| R-M2-P6-009 | 新培训日期通知未提供发文时刻，`needed` 和 `will need` 均有可能表达讲师参会需要 | R-FM2-P6-009 | 改为被动 `was required to attend`（B），其余选择在单复数、语态或非谓语结构上不成立 |

三题旧ID、题干、选项、正确答案和 **version=1 完全保留**，只用于历史草稿/答卷恢复，不再参与日常错题与慢题新训练。新增题全部使用新ID、正式发布状态及 version=1；不修改 P7，亦不更改新试卷每卷 Part5=30、Part6=16、Part7=54 的结构。

## 生产代码更新

- `ToeicMockDay19Part5V2Content.ets`：Day19新版第7道 Part5 的新ID唯一答案题。
- `ToeicMockPart6V2RepairContent.ets`：Day14第3道 Part6、Day19第9道 Part6 的新ID修正题，从旧题读取相同文章，修正选项与解释。
- `PresetToeicContent.ets`：Day14的第33题（数组索引32）、Day19的第7/39题（索引6/38）仅在新版学习计划中替换。归档publishedQuestions仍可查询旧题；liveTrainingQuestions统一过滤三道旧双答案题。
- `scripts/validate_toeic_mock_p5p6_unique_issue478.py`：强制校验原版不变、新版题号与选项确实唯一、正确项位置不变、真实学习计划只接入新题且训练不重入旧题；纳入统一TOEIC质量闸。

本报告是AI审阅与结构回归，不是两名独立专业审稿人或ETS认证。其他Part5/6题仍需要逐题审核记录；修复后的HarmonyOS HAP/Phone/Pad须单独编译验收。Issue #478继续Open。
