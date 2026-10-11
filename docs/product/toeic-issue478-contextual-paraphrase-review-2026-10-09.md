# Issue #478｜高频词上下文同义表达精度复核（2026-10-09）

## 审核范围与限定结论

本批以 Cambridge English Dictionary 的英文原义与词条实际例句为依据，对当前发布词条中 **5 条同义表达/释义**进行定向二轮 AI 审校修订。其余词条不因本批结构性指纹检查通过而自动获得“逐词独立语言专家认证”，尤其不得宣称 TOEIC / ETS 官方审核。

| ID | 场景 | 本批修订 | 为什么需要修订 | 英文词典证据 |
|---|---|---|---|---|
| V-123 competitive | competitive pricing | paraphrase `attractive in price` → `as good as or better than competing prices` | 竞争性报价不是绝对“便宜或吸引人”，必须与竞争者报价比较 | https://dictionary.cambridge.org/dictionary/english/competitive-price |
| V-130 efficient | efficient process | paraphrase `productive` → `achieving results without wasting resources` | productive 强调产出，efficient 限定为尽量不浪费时间、精力或资源 | https://dictionary.cambridge.org/dictionary/english/efficient |
| V-144 respondent | survey respondent | paraphrase `participant` → `person answering survey questions` | 参与活动的人未必回答调查；respondent 限定为回应/回答的人 | https://dictionary.cambridge.org/dictionary/english/respondent |
| V-146 subscription | annual subscription | paraphrase `membership plan` → `regular payment for access to a product or service` | 订阅不一定是组织会员资格；可指连续付费获得产品或服务 | https://dictionary.cambridge.org/dictionary/english/subscription |
| V-255 credential | login credentials | 义项 `身份凭证；资格证书` → `登录凭据；身份或资格证明`；paraphrase `proof of identity` → `authentication information` | 系统登录凭据可为令牌或用户名/口令等认证信息，不必是实体身份证明；同时保留资历/资格证明义项 | https://dictionary.cambridge.org/dictionary/english/credential |

## 变更风险与回归

- 修改 `ToeicVocabularyBatchTwo.ets` 中4条、`ToeicVocabularyBatchSix.ets` 中1条；**V-001 至 V-300 ID 全部维持不变**，且不更改这5条的词性、例句、美音IPA、Level、Context、Collocation和 Review Status。
- 仅为5个确有变化的词条用现有 `vocabulary_fingerprint` 重新计算 SHA256；同步更新 `toeic-editorial-approvals.json` 与 `toeic-ai-editorial-review-2026-10-08.json`；V-255 同步 `toeic-remaining-content-review-2026-10-08.json`。旧的 AI 初审文档保留名称、原审校日期，本批独立记录 `2026-10-09` 复核日期以及词典核验理由，`AI_EDITORIAL` 类型不升级成人工批准。
- 新增 `scripts/validate_toeic_contextual_synonyms_issue478.py`，在原 300词/180批次审校指纹门禁外锁定 5 处词义和原例句。设置3项真实错误注入：`efficient` 回退成 `productive`、`credential` 回退成忽略登录的词义、V-144 SHA 变为假值必须拒绝。
- 挂入 `validate_toeic_coach.py` 必跑；原发布题、221译文、70拆句、300例句、Day14/19模拟卷快照/答案、录入与记忆/历史记录未变。
- 真机 IPA 音频质量、是否使用系统 `en-US` TTS、鸿蒙 Phone/Pad HAP 编译不在本批可证明范围内，需独立设备验收。

**审校状态**：本批仅宣称 5 条上下文词义纠偏已采用词典对应的义项。其他词汇的完整语言学二轮核验，以及全部中文翻译的独立二轮复核，继续跟踪 Issue #478，Issue 不能据此关闭。
