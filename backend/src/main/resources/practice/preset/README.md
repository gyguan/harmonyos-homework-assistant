# Practice 预置题库维护说明

本目录是预置练习题内容的**唯一源数据目录**。

任何新增或修改 Paper / Question 前，必须先阅读：

- `docs/product/practice-question-content-standard.md`

## 维护流程

1. 确认年级、学期、科目、教材依据和题库类型。
2. 修改对应 `G2/*_SYNC.json` 或 `G2/*_EXTRA.json`。
3. 已发布 Paper 内容发生变化时提升 `version`，不要覆盖历史已发布版本。
4. 不手工修改 `entry/src/main/ets/data/practice/PresetPracticeCatalog.ets`。
5. 重新生成前端目录：

   `python scripts/generate_practice_catalog.py`

6. 运行内容质量门禁：

   `python scripts/validate_practice_content.py`

7. 提交 PR，确保 `Validate Practice content catalog` CI 通过。

## 内容红线

- 不依赖缺失图片；
- 英语题干必须有中文引导；
- 选择题选项必须属于当前题目且互不重复；
- 单选题只能有一个正确答案；
- 正确答案位置不能固定；
- 提示必须逐题生成、突出题干关键词、不能泄露答案；
- 教材同步不得凭印象超纲；
- 不直接编辑生成文件；
- 不通过跳过校验或测试特判绕过规范。
