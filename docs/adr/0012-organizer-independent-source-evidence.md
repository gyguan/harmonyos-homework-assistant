# ADR：独立来源证据（Issue #591 P0-B）

Status: Accepted for implementation; 2026-10-19.

V37 的 AI 初稿仅有每任务 sourceExcerpt，无法表达模型漏掉的任务原文。增加可选 schemaVersion=2 SourceDocument/SourceBlock、候选 sourceBlockIds 以及 qualityFlags/needsReview，保留全部旧字段与旧请求。文字仅按物理行划分，AI 分类，后端按原文重建权威块；图片同一次模型调用独立转录所有片段、通知及不可辨认区域。补充文字也保留。一个块可以支持多项任务。

V43 新增 homework_source_evidence；以 family/student/batch 唯一隔离，保存无像素的 JSON 证据与候选 ID 映射。事务复用现有 snapshots.capture，同时提交原始候选与来源。空任务批次仍能持久化来源；相同批次不允许覆盖不同证据。新增鉴权 GET /api/v1/students/{studentId}/homework/source-evidence/{batchId}，旧 snapshot GET 保留。

回滚：先回退应用，保留新增表与 V43 版本，不删除历史证据、不修改旧 migration。未来需要删除家庭/学生时级联清除。未提供 importId 的旧客户端保持无持久化行为；不为其生成新的业务身份。旧模型数组根/旧响应可解析，但证据缺失必须 needsReview，recognizedText 绝不由任务摘录拼接。未改变家长编辑/发布流程。

边界：P0-B 检查来源引用、未覆盖块和不可辨认状态；没有纠正语义或声称检测了图上未识别的文字。真实像素完全未被首轮识别的区域仍可能缺失，须以真实金标量化。当前图片 API 一次一张，imageIndex=0；多图批次现有客户端仍逐张调用，各 importId 隔离。后续若引入单请求多图需增量契约与测试，不能假装已经支持。
