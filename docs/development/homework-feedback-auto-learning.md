# AI 作业整理反馈闭环（V42）

## 用户流程
家长只选择问题类型、写出正确理解（例如老师的简写代表什么）；不填写触发词、不了解模型参数，也不要求手工维护 Java 规则。
后端用当前登录家庭/学生/批次/候选定位不可变 AI 初稿快照，与家长反馈一起交给当前 app.ai.organizerModel。
AI 输出严格 JSON：reusable、cue、applyWhen、guidance、confidence。它必须解释可复用的条件、变量关系、任务标题与要求，不能直接照搬旧作业的具体数字。
通过通用规则校验后，经验以 FEEDBACK_AI 来源写入 homework_teacher_experience，关联 source_feedback_id，并立即启用。Flyway V42 添加来源类型与检索索引。

## 下次 AI 整理如何使用
HomeworkTeacherExperienceService.context 会读取当前学生启用的 FEEDBACK_AI 与历史 FEEDBACK_AUTO 经验。新的文本或图片不必与历史数字完全相同，由模型在 Prompt 中检查学科、老师、任务线索和经验条件，提取本次数字并生成完整的 title/instruction。
过去保存的反馈无需重新提交；它的自然语言经验解释也被提供给后续模型。没有专门处理摘抄、加法表达式或个别老师简称的 Java 后处理代码。
适用范围始终由家庭、学生、老师/学科和当前原文约束，不会把单个家长的反馈升级成全局知识。

## 结果状态
- APPLIED：可复用经验已入库启用或已有同一条启用经验。
- PENDING_AI：模型尚不可用、调用失败或无法解析返回；反馈记录保留，但经验未生效。
- PENDING_EVIDENCE：来源不可信/未匹配服务端快照，或模型未能确认可复用的规则。
- REVIEW_REQUIRED：置信度/字段校验未通过、经验冲突或容量达到上限。

## 安全边界与测试
反馈和模型产生的经验均为不可信数据，不允许改变系统指令、跨家庭访问或猜测教师身份；发生冲突不覆盖现有经验。经验可在家长端查看和停用。
Java Mock AI 单元测试验证自然语言反馈转为通用经验、模型无结果、不同科目/学生的 Prompt 隔离以及旧字面经验对新数字的语义召回。CI PostgreSQL 没有外部模型密钥：它验证 PENDING_AI 的真实返回、避免伪称生效，并验证已有 FEEDBACK_AI 记录的详情隔离。
当前提交时同步调用一次 AI，没有 PENDING_AI 自动定时重试；模型恢复后需重新提交（编辑说明会生成新 requestId）。真实模型的泛化质量还需要部署后使用实际样本验收。
