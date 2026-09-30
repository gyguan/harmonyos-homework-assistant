# TOEIC 高效备考模块｜内容与训练质量规范

> 状态：Active  
> 适用范围：`entry/src/main/ets/toeic/` 下所有 TOEIC 词汇、题目、文章、训练计划、解析，以及未来 Listening 音频脚本与音频资产。

## 1. 最高原则

1. **内容准确性优先于题量。** 宁可少发布，也不发布答案、语法、证据或解析存在争议的内容。
2. **学习效率优先于功能数量。** 每个功能必须能减少无效重复、缩短判断时间、定位薄弱点或提高正式考试完成度。
3. **方法来源与题目来源分离。** 米小勒等高分备考经验用于提炼训练重点、提速方法与取舍策略；ETS / IIBC 用于校准考试结构与能力边界；正式题目、文章、解析和未来音频脚本均为自建内容。
4. **TOEIC 模块保持可剥离。** 不依赖 HomeworkStore、Assignment、Practice、StudentProfile 等小伴作业业务领域。

## 2. 内容生命周期

```text
DRAFT -> VALIDATED -> REVIEWED -> PUBLISHED
                           |
                           -> RETIRED
```

只有 `PUBLISHED` 内容可以进入正式诊断或训练。已产生用户 Attempt 的题目不得直接覆盖答案；修复内容时提升 version。

## 3. 通用题目门禁

正式题目至少包含：
- 唯一 id；
- section / part / skill；
- difficulty / scoreValue；
- recommendedSeconds；
- 3–4 个有效选项；
- 唯一正确答案；
- explanation；
- version；
- reviewStatus。

Reading 与 Listening 使用同一个内容模型。

## 4. Part 5 / Part 6

Part 5：
- 一个且只有一个正确选项；
- 不允许两种自然语法解释；
- 解析先写“最快判断方法”；
- 高频基础考点优先，不用生僻规则制造假难度。

Part 6：
- 上下文自然完整；
- 连接词逻辑唯一；
- 代词有明确指代；
- 不能把信息缺失造成的歧义当作难度。

## 5. Part 7

每道正式 Part 7 题必须保存明确 `evidence`。

- Detail：答案可由原文直接支持；
- Purpose / Main Idea：对应材料整体目的；
- Paraphrase：保存原文和题目表达的替换关系；
- Inference：只做文本可以合理推出的最小推断；
- Cross-document：明确需要组合的信息。

**找不到证据的 Part 7 题不得发布。**

## 6. Listening 预留门禁

未来发布 Listening Part 1–4 时必须额外满足：
- 有 transcript；
- 有正式 audioAssetId；
- 音频与 transcript 一致；
- 答案在音频中有明确证据；
- 记录 evidence 时间段；
- 人名、数字、时间、金额经过人工试听；
- 停顿、重音和语速不能意外泄露答案。

## 7. 学习效率

系统同时记录正确性与用时：

- FAST_CORRECT
- SLOW_CORRECT
- FAST_WRONG
- SLOW_WRONG

SLOW_CORRECT 不直接视为完全掌握。

Daily Training Queue 优先：
1. 做错题；
2. 做对但偏慢；
3. 当前薄弱能力；
4. 当日新内容；
5. 低价值难题。

## 8. 350+ 题目价值

- MUST_GET：优先保证的基础/中等题；
- NORMAL：正常训练；
- OPTIONAL：高耗时难题，训练取舍意识。

训练结果优先呈现 MUST_GET 失分。

## 9. 第三方内容边界

米小勒、高分考生经验等用于提炼：
- 高频重点；
- 提速方法；
- 时间管理；
- 难题取舍；
- 短期训练顺序。

不得直接复制第三方受版权保护题目、文章或讲义进入预置题库。

## 10. 合并前检查

- [ ] Content Validator 通过；
- [ ] 正确答案和解析已复核；
- [ ] Part 7 每题都有 evidence；
- [ ] 解析能回答“下次如何更快判断”；
- [ ] 推荐用时与 scoreValue 合理；
- [ ] 新内容为原创或具备明确授权；
- [ ] 新增 Listening 时通过 transcript / audio / evidence 一致性检查。


## 11. 词汇音标与发音

- 当前 Reading 词汇默认使用 **en-US 美式 IPA**；
- 每个正式词汇必须维护 `ipa`、`pronunciationLocale` 与 `pronunciationText`；
- IPA 属于内容资产，禁止在 UI 临时拼接或由模型运行时猜测；
- 同形异音词必须按当前词性显式标注，例如 résumé、refund、estimate、upgrade；
- 点击发音通过 HarmonyOS Core Speech Kit TextToSpeech 播放，当前使用 en-US 英语音色；
- 发音能力不可用时必须降级为可学习的音标与文字内容，不得阻塞词汇页面；
- 后续 Listening 增加英/加/澳口音时，复用 pronunciationLocale 扩展，不复制第二套词汇资产。
