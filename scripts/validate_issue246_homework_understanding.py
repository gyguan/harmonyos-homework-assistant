#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

def read(path: str) -> str:
    file = ROOT / path
    if not file.exists():
        errors.append(f"missing required file: {path}")
        return ""
    return file.read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)

models = read("entry/src/main/ets/domain/model/HomeworkUnderstandingModels.ets")
teacher = read("entry/src/main/ets/application/understanding/DeterministicTeacherResolver.ets")
classifier = read("entry/src/main/ets/application/understanding/DeterministicHomeworkClassifier.ets")
grouper = read("entry/src/main/ets/application/understanding/DeterministicHomeworkContextGrouper.ets")
extractor = read("entry/src/main/ets/application/understanding/DeterministicHomeworkTaskExtractor.ets")
revision = read("entry/src/main/ets/application/understanding/DeterministicHomeworkRevisionResolver.ets")
pipeline = read("entry/src/main/ets/application/understanding/HomeworkUnderstandingPipeline.ets")
service = read("entry/src/main/ets/application/understanding/HomeworkUnderstandingService.ets")
import_models = read("entry/src/main/ets/domain/model/ImportModels.ets")
inbox_store = read("entry/src/main/ets/data/local/HomeworkImportInboxStore.ets")
inbox_service = read("entry/src/main/ets/application/import/HomeworkImportInboxService.ets")
detail = read("entry/src/main/ets/features/parent/import/HomeworkImportBatchDetailPage.ets")
fixture = read("entry/src/main/ets/experimental/homeworkcapture/Issue246HomeworkUnderstandingFixture.ets")
spike = read("entry/src/main/ets/experimental/homeworkcapture/HomeworkCaptureSpikePage.ets")
reconstruction = read("entry/src/main/ets/application/capture/HomeworkChatReconstructionService.ets")
schema = read("docs/contracts/homework-understanding/v1/schema.json")
prompt = read("docs/contracts/homework-understanding/v1/prompt.md")
rules = read("docs/contracts/homework-understanding/v1/rules.md")

for value in [
    "HOMEWORK", "HOMEWORK_REVISION", "PREPARATION", "NOTICE", "CHAT", "UNKNOWN"
]:
    require(value in models, f"message classification missing: {value}")
require("TeacherResolutionStatus" in models and "RESOLVED" in models and "UNKNOWN" in models,
        "teacher resolution status missing")
require("aliases: string[]" in models and "subject: Subject" in models,
        "teacher directory alias/subject mapping missing")
require("pendingReviewMessageIds" in models,
        "understanding result must expose pending review messages")
for version in ["rules-v1.0", "schema-v1.0", "prompt-v1.0"]:
    require(version in models, f"version constant missing: {version}")
require('"const": "schema-v1.0"' in schema and "sourceMessageIds" in schema,
        "versioned enhancement schema missing evidence contract")
require("prompt-v1.0" in prompt and "do not guess" in prompt.lower(),
        "versioned optional enhancer prompt missing")
require("rules-v1.0" in rules and "teacherId + subject" in rules,
        "versioned deterministic rules contract missing")

require("matchesEntry" in teacher and "entry.aliases" in teacher,
        "teacher resolver must support exact aliases")
require("TeacherResolutionStatus.UNKNOWN" in teacher,
        "teacher resolver must return UNKNOWN rather than guessing")

require("isChatAcknowledgement" in classifier,
        "parent acknowledgement classification missing")
require("HOMEWORK_REVISION" in classifier and "PREPARATION" in classifier and
        "NOTICE" in classifier,
        "required semantic classes missing from classifier")
require("刚才说错了" in classifier and "改成" in classifier and
        "第三题" not in classifier,
        "classifier should identify revision intent without hard-coding one fixture ordinal")

require("teacherId" in grouper and "subject" in grouper,
        "context grouper must isolate teacher/subject contexts")
require("CHAT" in grouper and "NOTICE" in grouper and "UNKNOWN" in grouper,
        "non-task messages must not enter task groups")

for expression in ["刚才说错了", "补充一下", "以这条为准"]:
    require(expression in classifier or expression in revision or expression in extractor,
            f"revision expression missing: {expression}")
require("cancelledTaskIndex" in extractor and "不用做" in extractor,
        "task deletion parsing missing")
require("pageCorrection" in extractor and "replacePage" in extractor,
        "page correction parsing missing")
require("genericReplacement" in extractor,
        "generic change-to replacement missing")
require("REVISION_PAGE_TARGET_NOT_FOUND" in revision and
        "REVISION_CANCEL_TARGET_NOT_FOUND" in revision,
        "revision failure warnings missing")
require("sourceMessageIds" in revision and "addEvidence" in revision,
        "revision must append correction message evidence")

for stage in [
    "teacherResolver.resolve", "classifier.classify", "grouper.group",
    "revisionResolver.apply", "extractor.extractHomework"
]:
    require(stage in pipeline, f"pipeline stage missing: {stage}")
require("pendingReviewMessageIds.push" in pipeline,
        "UNKNOWN messages must go to pending review")
require("CandidateAssignment" in pipeline and "sourceMessageIds: task.sourceMessageIds.slice()" in pipeline,
        "task extraction must reuse CandidateAssignment and preserve message evidence")
require("AssignmentRepository" not in pipeline and "HomeworkBatchPublishService" not in pipeline,
        "#246 pipeline must not publish or own Assignment lifecycle")
require("HomeworkOrganizerRemoteApi" not in pipeline and "HomeworkOrganizerRemoteApi" not in classifier,
        "#246 deterministic core must not hard-depend on AI service")

require("understandBatch" in service and "understandAndActivate" in service,
        "understanding service must write to batch and reuse existing confirmation activation")
require("tryUnderstandBatch" in service and "recordFailure" in service and
        "HOMEWORK_UNDERSTANDING_EXCEPTION" in service,
        "understanding failure must preserve retryable batch")
require("this.inbox.getMessages(batchId)" in service and
        "this.inbox.getCandidates(batchId)" in service,
        "failure isolation must retain original messages/candidates")
require("ImportBatchStatus.EMPTY" in service and "ImportBatchStatus.RECEIVED" in service,
        "understood-empty and pending-review states must be distinguished")

for field in [
    "understood?: boolean", "understandingVersion?: string", "pendingReviewMessageIds?: string[]",
    "understandingWarnings?: string[]", "classificationSummary?: string"
]:
    require(field in import_models, f"ImportBatch understanding metadata missing: {field}")
require("understandingWarnings" in inbox_store and "classificationSummary" in inbox_store and
        "understandingVersion" in inbox_store,
        "Inbox store must persist understanding metadata/version")
require("understandingWarnings" in inbox_service and "classificationSummary" in inbox_service,
        "Inbox service must preserve understanding metadata")
require("understood: batch.understood" in reconstruction,
        "reconstruction retry must preserve understanding metadata")

case_ids = re.findall(r"id: 'C\d{2}[^']*'", fixture)
require(len(case_ids) >= 20, f"expected at least 20 fixed fixtures, found {len(case_ids)}")
require("VERSION: string = '1.0'" in fixture,
        "fixture version must be explicit")
for metric in [
    "classificationAccuracy", "groupingPassed", "revisionPassed",
    "taskExtractionPassed", "evidencePassed"
]:
    require(metric in fixture, f"quality metric missing: {metric}")

for required_case in [
    "C01-SINGLE-CHINESE", "C04-PARENT-ACK", "C05-SUPPLEMENT",
    "C06-CORRECTION-32-33", "C07-CANCEL-THIRD", "C08-PREPARATION",
    "C09-NOTICE", "C10-CONSECUTIVE", "C11-UNKNOWN-SENDER",
    "C14-MULTI-SUBJECT", "C15-GENERIC-REPLACE", "C16-AUTHORITATIVE"
]:
    require(required_case in fixture, f"required fixture missing: {required_case}")
require("ids.length === 2" in fixture,
        "32→33 revision fixture must prove original+revision evidence")
require("expectedPendingReview: 1" in fixture,
        "UNKNOWN fixture must require pending review")

require("运行 #246 作业理解自测" in spike,
        "#246 benchmark must be runnable from diagnostic UI")
require("作业理解" in detail and "待人工确认消息：" in detail and "理解提示：" in detail,
        "batch detail must expose understanding status/pending review/warnings")

if errors:
    print("ISSUE_246_HOMEWORK_UNDERSTANDING_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_246_HOMEWORK_UNDERSTANDING_GATE_PASS")
