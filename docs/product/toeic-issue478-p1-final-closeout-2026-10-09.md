# Issue #478｜P1 最终收口：185 道 Part 5/6 + 300 词二轮 AI 审校（2026-10-09）

## 结论

P1 内容范围已完成整批 AI 编辑二轮审校，不再保留 `NEED_SECOND_REVIEW` / `NEED_DICTIONARY_BOUND_SECOND_PASS`。

- 原始 Part 5/6：**185/185** 已逐题复核。
  - **171**：`PASS_AI_SECOND_PASS`
  - **14**：发现历史内容风险后采用 **ARCHIVED_REPLACED**，旧 ID 保留用于历史成绩/报告，新会话不再投放。
- 词汇：**300/300** 已逐词复核词性、中文义项、业务搭配、英文释义、例句和现有美音条目。
  - **288**：`PASS_AI_SECOND_PASS`
  - **12**：历史或本轮修订后 `PASS_AFTER_CORRECTION`

本结论仅表示 **AI_EDITORIAL_SECOND_PASS 完成**，不宣称 ETS、人工语言专家或真机 TTS 认证。

## 最终题目整改

### 本批新增 5 个版本化替换

| 旧 ID | 新 ID | 问题 | 处理 |
|---|---|---|---|
| R-P5-SPRINT-1528 | R-FP1-P5-1528 | 原 paraphrase 写成 `provide themselves with ID`，与 `identify themselves` 不一致 | 新版改为身份自证语义，保留正确项 themselves |
| R-P6-SPRINT-1606 | R-FP1-P6-1606 | 干扰项 `has receive` 为非法形式 | 改成语法真实但语态错误的 `has received` |
| R-DX-P5-05 | R-FP1-DX-P5-05 | 干扰项 `has send` 为非法形式 | 改为真实形式 `had sent`，旧题退出新训练 |
| R-M2-P5-010 | R-FP1-M2-P5-010 | 干扰项 `its'` 为非法所有格 | 改为真实易混项 `it's` |
| R-M2-P6-002 | R-FP1-M2-P6-002 | 干扰项 `will arriving` 为非法形式 | 改为真实未来时干扰项 `will arrive`，保持时间从句答案 `arrive` |

### 既有 9 个历史替换纳入最终 P1 台账

- R-P5-VERB-0206 → R-FP5-VERB-0206
- R-M1-P5-022 → R-FM1-P5-022
- R-P5-SPRINT-1517 → R-FP5-SPRINT-1517
- R-P6-SPRINT-1610 → R-FP6-SPRINT-1610
- R-M2-P5-007 → R-FM2-P5-007
- R-M1-P6-033 → R-FM1-P6-033
- R-M2-P6-004 → R-FM2-P6-017
- R-M2-P6-008 → R-FM2-P6-018
- R-M2-P6-009 → R-FM2-P6-009

因此最终原始 185 题中共 **14 项 ARCHIVED_REPLACED**。

## 本批词汇边界修订

| ID | 修订 | 权威依据 |
|---|---|---|
| V-156 seminar | 不再直接写成 `workshop`；改为 `meeting for study and discussion` | Cambridge: seminar 是专家/教师与一组人共同学习讨论的场合 |
| V-157 onboarding | 从“入职培训；入职手续”扩展为“新员工入职与融入组织的流程；入职培训” | Cambridge: new employees gain knowledge/skills to become effective organization members |
| V-179 revenue | `sales income` 过窄；改为 `income received by a business or government` | Cambridge: company/government regularly received income, especially but not only sales |
| V-189 pallet | `loading platform` 过泛；改为 `flat platform for stacking and moving goods` | Cambridge: flat structure supporting heavy goods for forklift movement |
| V-285 contractor | `external service provider` 过泛；改为 `person or company hired under a contract to do work` | Cambridge: person/company paid under contract for a project/service |

外部证据：
- https://dictionary.cambridge.org/dictionary/english/seminar
- https://dictionary.cambridge.org/dictionary/english/onboarding
- https://dictionary.cambridge.org/dictionary/english/revenue
- https://dictionary.cambridge.org/dictionary/english/pallet
- https://dictionary.cambridge.org/dictionary/english/contractor

本批与之前修订合并后，最终词汇台账中标记 `PASS_AFTER_CORRECTION` 的 12 项为：
V-119、V-156、V-157、V-164、V-179、V-189、V-202、V-215、V-245、V-271、V-281、V-285。

## 审核证据与防回退

- `docs/product/toeic-issue478-p1-final-question-review-2026-10-09.json`
  - 185 个原始 Part 5/6 ID 全覆盖
  - 逐项绑定 exact content SHA256
  - 每题记录唯一答案二轮结论、3 个错误选项比较结果、历史替换 ID
- `docs/product/toeic-issue478-p1-final-vocabulary-review-2026-10-09.json`
  - V-001 ～ V-300 全覆盖
  - 绑定词性、义项、场景、搭配、释义、例句、IPA exact SHA256
- `scripts/validate_toeic_p1_final_review_issue478.py`
  - 185/300 数量及 ID 完整性
  - 源码哈希与静态审校台账一致
  - 不允许任何 P1 pending 状态
  - 14 个旧问题必须有 replacement 且旧 ID 必须退出 live queue
  - 5 个本批新 replacement 必须存在中文复盘
  - 5 个本批词汇语义边界必须保持
- `scripts/inventory_toeic_issue478_p1.py`
  - 从 pending inventory 升级为 final reviewed inventory
- AI 审核来源严格区分：
  - 历史 AI-GPT6 审核仍绑定历史 evidence
  - 本批 AI-GPT5.6-SOL 仅允许绑定本次 final vocabulary review 文件
  - 两者都不冒充 HUMAN / ETS

## P1 关闭口径

从内容审核角度，P1 的 **185 题 + 300 词** 已具备完整 AI 二轮审校和可重复防回退证据，可将 P1 标记为完成。

这不代表 #478 全 Issue 必然关闭；若 P2/P3 仍有中文翻译、句子训练或其他范围，继续按各自验收项推进。
