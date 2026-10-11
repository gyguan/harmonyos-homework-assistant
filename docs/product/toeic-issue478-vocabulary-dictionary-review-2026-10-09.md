# Issue #478｜300词完整性复核与权威词典抽核（2026-10-09）

## 本批实际处理和结论

本批核对已经发布的 V-001～V-300 单词 ID 与美音元数据的存在性、V-121～V-300 共 180 个有签署记录的单词的**精确内容 SHA256**，并对两处语义边界问题作权威词典对照修订；另外抽核 8 个容易混淆的美式音标及词性读音条目。

**切勿将“300词结构校验通过”“180词指纹匹配”或“8个抽核项通过”写成 300 个单词的全部 IPA/词义/搭配已获独立语言专家认证。** 本批仍属于 AI 主导的可追溯针对性复核，后续还需完成余下逐词语言质量审阅和鸿蒙语音真机验收。

| 资产 | 修订前内容 | 修订后内容 | 核验与依据 |
|---|---|---|---|
| V-164 contingency（名词） | 意义：“应急准备；意外情况”；同义表达“backup arrangement” | 意义：“可能发生的意外情况；应急安排”；同义表达“possible future event” | Cambridge: contingency 首义是未来可能发生的情况（常需制定对策）；Business English 还可表示应对未来事件的安排。避免将 contingency 本词无条件等同 backup plan |
| V-245 enclosure（名词） | “随函附件；围栏” | “随函附件；围起来的区域” | Cambridge: 在商务函件中为随函寄送的文件；另一名词义是被围起的独立区域，不是指围栏本身 |

两项都保留原稳定ID、词性、例句、发音、场景与难度。V-164 保留真实常用搭配 `contingency plan`，但不能由该搭配推导 `contingency=backup arrangement` 是普遍同义。修订不影响任何题目、题目版本、用户作答或历史学习记录。

## 词典证据（外部来源）

- V-164：<https://dictionary.cambridge.org/dictionary/english/contingency>
- V-245：<https://dictionary.cambridge.org/dictionary/english/enclosure>
- V-014 refund 名词、动词重音不同：<https://dictionary.cambridge.org/pronunciation/american-english/refund>
- V-038 transfer 美音动词既有首音节重音 /ˈtrænsfɝː/，也见第二音节重音 /trænsˈfɝː/；名词首音节重音。不能将第二种美音变体错误当作唯一美音，也不能省略该变体：<https://dictionary.cambridge.org/pronunciation/english/transfer>
- V-082 upgrade 名词、动词重音不同：<https://dictionary.cambridge.org/pronunciation/english/upgrade>
- V-051 estimate 名词、动词读法不同：<https://dictionary.cambridge.org/pronunciation/english/estimate>
- V-033 résumé 要使用重音语义避免 TTS 念成 resume（继续）：<https://dictionary.cambridge.org/pronunciation/english/resume>
- V-238 arrears 为复数名词、V-283 refreshments 为复数名词，V-300 per diem 为名词津贴：<https://dictionary.cambridge.org/dictionary/english/arrears>、<https://dictionary.cambridge.org/dictionary/english/refreshment>、<https://dictionary.cambridge.org/dictionary/english/per-diem>

本批 V-164、V-245 修改词义；V-038 补充已有美音动词的另一重音变体。TTS 仍由系统 en-US 引擎负责，显示双变体不保证真实语音一定按指定变体发声。其余已核对的音标和现有 TTS 消歧规则保持原样。辞典中的异体读音可能并存，不应以单一音标字符串宣称所有方言发音唯一正确。

## 审核快照与可重复的回归门禁

- V-164、V-245 重新按 `vocabulary_fingerprint`（含词性、义项、场景、搭配、例句、IPA）计算 exact SHA256，并同步 `toeic-editorial-approvals.json` 和 `toeic-ai-editorial-review-2026-10-08.json` 的对应条目；记录本次 `updatedAt=2026-10-09`，`approvedAt=2026-10-09`，审核性质继续显式 `AI_EDITORIAL`。
- V-245 同步原来 120 词二次审校报告 `toeic-remaining-content-review-2026-10-08.json` 的实际词义、SHA256 和修订记录。历史文件名/首轮日期仍保留，以新增修订记录承接新版，避免假装原审校时已经修正。
- `scripts/validate_toeic_vocabulary_dictionary_issue478.py` 与 `validate_toeic_coach.py` 集成：覆盖 300 ID、300 IPA、180 批次词精确审批内容哈希、2 个释义更正 ID 和 8 个词性/音标哨兵；并验证“恢复旧同义释义”“抹掉 refund 动词 IPA”两类负向篡改必须失败。
- 既有 `validate_toeic_editorial_content.py`、`test_toeic_remaining_editorial.py` 的原始内容快照验证继续生效，不对审校门禁作旁路或关停。

## 未完成项目

- 300 词中除本批针对性修订及发音抽核之外的全部词条，还需逐词校对与权威词典证据收集。V-001～V-120 原始内置词仅通过覆盖和现有学习流程检验，不能冒称已签署与 V-121～V-300 同等级别的编辑批准。
- IPA 真音频与系统 `en-US` TTS 的设备读音、连续复现、Phone/Pad ArkTS HAP 构建均未由静态审查证明。
- #478 继续保持 OPEN，优先处理更多词义/释义异义项、词性匹配及原始 221 中文译文与 70 拆句的剩余独立专项二轮抽核。
