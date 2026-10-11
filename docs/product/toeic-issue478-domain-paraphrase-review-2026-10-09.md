# Issue #478 第十五批｜行业语境同义词精度复核（2026-10-09）

## 审核范围与结论边界

本批继续对已发布 V-001–V-300 高频词进行局部语义审校，重点检查**词汇搭配、词义指代范围、词性与英文例句是否一致**。仅对下表 8 条原先同义表达过宽或缺少关键条件的词进行修改。此处的 AI 复核和词典来源对照不是人类语言专家或 TOEIC/ETS 官方认证，不得据此宣称 300 词语言学全面合格。

| 资产 | 原同义表达 | 现同义表达 | 为什么改 / 权威依据 |
|---|---|---|---|
| V-124 bid（投标） | `offer` | `offer to provide goods or work at a stated price` | 正文中供应商竞标维修合同，bid 应含“以报价竞争某合同/工作”义项，offer 泛指提供，过宽。Cambridge https://dictionary.cambridge.org/dictionary/english/bid |
| V-125 subcontractor（分包商） | `outside contractor` | `contractor carrying out part of another contractor's work` | 普通外部承包商不必承担他方合同的部分工作；subcontractor 明确承接另一方负责工作的组成部分。Cambridge https://dictionary.cambridge.org/dictionary/english/subcontractor |
| V-215 utilities（水电燃气等公用事业） | `water and electricity services` | `essential services such as electricity, gas, and water` | 原英解遗漏常见燃气，并与中文“水电燃气”的范围不一致。Cambridge https://dictionary.cambridge.org/dictionary/english/utility |
| V-264 accessibility（网站无障碍） | `ease of access` | `ability of people with disabilities to use a website` | 示例是键盘用户的网站无障碍，强调包容残障人士的真实使用能力，不是仅指容易进入。Cambridge https://dictionary.cambridge.org/dictionary/english/accessibility ；W3C https://www.w3.org/WAI/fundamentals/accessibility-principles/ |
| V-276 shuttle（机场接驳车） | `transfer bus` | `vehicle making regular trips between two places` | 不只是单次转运巴士，shuttle 包含固定两地间反复往返的车辆服务。Cambridge https://dictionary.cambridge.org/dictionary/english/shuttle |
| V-277 commute（通勤） | `travel to work` | `travel regularly between home and work` | 例句员工经常乘列车往返工作地，commute 应含规律性和家/工作地关系，而非任意上班出行。Cambridge https://dictionary.cambridge.org/dictionary/english/commute |
| V-284 amenity（酒店便利设施或服务） | `guest facility` | `hotel facility or service that improves comfort` | 英文例句是“免费 Wi-Fi 属于酒店 amenities”，不可将 amenity 仅限物理 guest facility；Cambridge Learner's Dictionary 明确包括 service。https://dictionary.cambridge.org/us/dictionary/learner-english/amenity |
| V-298 roster（值班人员名单） | `list of assigned staff` | `staff list with assigned duties or shifts` | 周末班次语境下需要保留 duty roster 的岗位/排班维度，非只是人名。Cambridge https://dictionary.cambridge.org/dictionary/english/roster |

## 完整性和版本约束

- 代码只改 `ToeicVocabularyBatchTwo.ets`（2条）、`ToeicVocabularyBatchFive.ets`（1条）、`ToeicVocabularyBatchSix.ets`（1条）、`ToeicVocabularyBatchSeven.ets`（4条）的 `synonyms` 字段，原有 V-ID、英文单词、词性、中文义项、例句、场景、难度、发音和记忆数据均保持不变。
- 按既有 `vocabulary_fingerprint` 重新计算 8 个精确内容 SHA256，并在写入新值前逐一重算原内容 SHA、验证与原审批账本**完全匹配**，避免凭空替换已签署哈希。
- 同步更改 `docs/product/toeic-editorial-approvals.json` 的8项内容指纹与批准更新日 2026-10-09；`docs/product/toeic-ai-editorial-review-2026-10-08.json` 的相应指纹、`updatedAt` 以及原始来源；V-215/264/276/277/284/298 的120词二次复核记录同步修改对应同义表达与指纹。保持 `AI_EDITORIAL` 模式，绝不写成独立人工或ETS批准。
- `scripts/validate_toeic_domain_paraphrases_issue478.py` 挂入 `scripts/validate_toeic_coach.py`，锁定8条完整的 ID/词性/搭配/同义表达/原英文例句、全部300条IPA映射、8条 AI 审批与首轮/二轮一致性。负向恢复8个旧同义表达和伪造1条批准 SHA 应分别全部失败（共9项）。
- 保留已建立的 300 例句实际展示检查、221 译文、70 拆句及全量模拟题原内容门禁，不能把源文件行数检查或指纹一致性冒称“全部语义已独立认证”。
- HarmonyOS HAP 编译及 Phone/Pad 真机发音本批未实测，原系统端 `en-US` 读音路径保持不变。

## 后续工作

Issue #478 继续保持 Open。继续寻找未验证词义/IPA/搭配/例句的实际错误，并单独对 221 题目中文译文与 70 拆句做语义复核；静态通过不代替后续 HAP 构建和设备级验证。
