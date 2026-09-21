#!/usr/bin/env python3
from pathlib import Path
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

profile_models = read("entry/src/main/ets/domain/model/HomeworkSourceProfileModels.ets")
profile_store = read("entry/src/main/ets/data/local/HomeworkSourceProfileStore.ets")
profile_service = read("entry/src/main/ets/application/capture/HomeworkSourceProfileService.ets")
profile_persistence = read("entry/src/main/ets/infrastructure/persistence/PreferencesHomeworkSourceProfilePersistence.ets")
entry = read("entry/src/main/ets/entryability/EntryAbility.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
import_home = read("entry/src/main/ets/features/parent/import/HomeworkImportRoutePage.ets")
capture_home = read("entry/src/main/ets/features/parent/import/HomeworkCaptureHomePage.ets")
capture_home_vm = read("entry/src/main/ets/features/parent/import/HomeworkCaptureHomeViewModel.ets")
profile_page = read("entry/src/main/ets/features/parent/import/HomeworkSourceProfilePage.ets")
capture_page = read("entry/src/main/ets/features/parent/import/HomeworkCapturePage.ets")
capture_vm = read("entry/src/main/ets/features/parent/import/HomeworkCaptureViewModel.ets")
float_page = read("entry/src/main/ets/pages/HomeworkCaptureFloatView.ets")
workflow = read("entry/src/main/ets/application/capture/HomeworkCaptureWorkflowService.ets")
group_title_policy = read("entry/src/main/ets/application/capture/DeterministicGroupTitlePolicy.ets")
understanding = read("entry/src/main/ets/application/understanding/HomeworkUnderstandingService.ets")
batch_detail = read("entry/src/main/ets/features/parent/import/HomeworkImportBatchDetailPage.ets")
reconstruction_service = read("entry/src/main/ets/application/capture/HomeworkChatReconstructionService.ets")
import_models = read("entry/src/main/ets/domain/model/ImportModels.ets")
inbox_store = read("entry/src/main/ets/data/local/HomeworkImportInboxStore.ets")
publish = read("entry/src/main/ets/application/import/HomeworkBatchPublishService.ets")
fixture = read("entry/src/test/fixtures/Issue247FullClosureFixture.ets")
spike = read("entry/src/main/ets/experimental/homeworkcapture/HomeworkCaptureSpikePage.ets")
task_extractor = read("entry/src/main/ets/application/understanding/DeterministicHomeworkTaskExtractor.ets")

for field in [
    "id: string", "name: string", "groupTitle: string", "studentId: string",
    "teacherAliases: HomeworkSourceTeacherAlias[]", "defaultStartMinuteOfDay: number",
    "enabled: boolean"
]:
    require(field in profile_models, f"SourceProfile field missing: {field}")
for field in ["displayName: string", "aliases: string[]", "subject: Subject"]:
    require(field in profile_models, f"TeacherAlias field missing: {field}")
for state in ["MATCHED", "MISMATCH", "UNRECOGNIZED", "CONFLICT"]:
    require(state in profile_models, f"group validation state missing: {state}")

require("homework_source_profiles_v1" in profile_persistence,
        "SourceProfile must have isolated Preferences persistence")
require("getActive(studentId" in profile_store and "current.enabled = false" in profile_store,
        "store must support one active profile per child")
require("markUsed" in profile_store and "lastUsedAtEpochMs" in profile_store,
        "profile usage must be traceable")
require("HomeworkSourceProfileBootstrap" in entry and
        "PreferencesHomeworkSourceProfilePersistence" in entry,
        "EntryAbility must restore SourceProfile before UI")

require("PARENT_SOURCE_PROFILE" in routes and "ParentSourceProfileRouteParam" in routes,
        "SourceProfile must have a dedicated navigation route")
require("PARENT_CAPTURE_HOME" in routes and "HomeworkCaptureHomePage" in shell,
        "daily capture must have a dedicated home route separate from manual import")
require("startCaptureAfterSave" in routes and "finishSourceProfile" in shell,
        "first-use setup and later settings edit must have different navigation semantics")
require("HomeworkSourceProfilePage" in shell,
        "SourceProfile setup page must be reachable")

require("抓取老师作业" in capture_home and "当前来源" in capture_home,
        "capture home must expose one-click daily capture and active profile summary")
require("timeWindow()" in capture_home and "今天 " in capture_home_vm and " 至现在" in capture_home_vm,
        "profile summary must show today's capture window through the capture ViewModel")
require("!this.hasSourceProfile()" in capture_home and
        "onOpenSourceProfile(true)" in capture_home,
        "first click without a profile must route through first-time setup")
require("onOpenSourceProfile(false)" in capture_home,
        "profile settings edit must not automatically stack a new capture page")
require("抓取今日作业" not in import_home and "屏幕采集技术诊断" not in import_home,
        "manual import page must not regain capture-specific entry points")

for text in ["班级与微信群", "老师与科目", "默认抓取开始时间", "保存并开始抓取"]:
    require(text in profile_page, f"SourceProfile setup UI missing: {text}")
require("Subject.CHINESE" in profile_page and "Subject.MATH" in profile_page and
        "Subject.ENGLISH" in profile_page,
        "setup must map common teachers to subjects")
require("aliases" in profile_page and "至少配置一位老师" in profile_service,
        "teacher aliases and minimum teacher validation missing")
require("parseStartTime" in profile_service and "15:00" in profile_page,
        "default start-time handling missing")

require("initializePage" in capture_page and "await this.startCapture()" in capture_page,
        "configured daily capture must auto-start after one entry click")
require("this.viewModel.start()" in capture_page and
        "this.workflow.start(this.family.getActiveStudentId())" in capture_vm,
        "capture page must start through the profile-aware workflow via ViewModel")
require("不使用 Accessibility 驱动微信" in capture_page and
        "不会自动点击或滚动微信" in capture_page,
        "formal capture must keep the no-automation privacy boundary")
require("Clipboard" not in capture_page and "Clipboard" not in workflow,
        "one-click daily capture must not require clipboard copy/paste")

require("targetStartMinuteOfDay: profile.defaultStartMinuteOfDay" in workflow,
        "live reconstruction must use SourceProfile start time")
require("groupTitlePolicy.validate(expected, detected)" in workflow and
        "validate(expected: string, detected: string)" in group_title_policy,
        "workflow must validate detected group title against profile through the shared policy")
require("SourceGroupValidationStatus.MISMATCH" in workflow and
        "SourceGroupValidationStatus.UNRECOGNIZED" in workflow and
        "SourceGroupValidationStatus.CONFLICT" in workflow,
        "mismatch, unrecognized and mixed-group states must not be conflated")
require("needsGroupConfirmation" in workflow and
        "confirmUnrecognizedAndContinue" in workflow,
        "unrecognized group must require explicit parent continuation")
require("validation === SourceGroupValidationStatus.MISMATCH" in workflow,
        "mismatched group must block automatic homework understanding")
require("profileStartEpoch" in workflow and "tryUnderstandBatch" in workflow and
        "this.inbox.activateBatch(session.importBatchId)" in workflow,
        "profile time window must flow through retry-safe understanding before confirmation activation")
require("HomeworkImportPipelineStage" in import_models and
        "pipelineStage?: HomeworkImportPipelineStage" in import_models and
        "HomeworkImportPipelineStage.ACTIVATED" in workflow,
        "capture-to-confirmation pipeline stage must be persisted for idempotent resume")
require("TIME_RANGE_FILTERED" in understanding and
        "this.inbox.importBatch(updated, allMessages, result.candidates)" in understanding,
        "out-of-window messages must be excluded from semantics but retained for audit")

require("timeBoundaryReached" in float_page and "已到达今日时间范围" in float_page,
        "FloatView must tell the user when the profile time boundary is reached")
require("当前群与配置不一致" in float_page,
        "FloatView must surface group mismatch while user is in WeChat")
require("结束并自动整理" in capture_page and "handleWorkflowResult" in capture_page,
        "capture stop must continue into automatic reconstruction/understanding")
require("!result.reconstructionSucceeded" in capture_page and
        "!result.understandingSucceeded" in capture_page,
        "capture UI must distinguish reconstruction/understanding failures from empty homework")
require("!result.understandingSucceeded" in float_page and
        "作业理解待处理" in float_page,
        "FloatView must surface understanding failure after capture")
require("onOpenConfirmation" in capture_page and "result.activated" in capture_page,
        "successful understanding must route into the existing parent confirmation page")
require("确认是目标班级群，继续整理" in capture_page,
        "unrecognized group must offer explicit user confirmation")
require("与班级采集设置不一致" in capture_page,
        "mismatched group must have a clear blocking message")

for field in [
    "sourceProfileName?: string", "expectedGroupTitle?: string", "profileStartTime?: string",
    "groupValidationStatus?: string", "groupConfirmedByUser?: boolean"
]:
    require(field in import_models, f"ImportBatch profile audit field missing: {field}")
require("班级采集范围" in batch_detail and "目标群：" in batch_detail and
        "群名校验：" in batch_detail,
        "batch detail must expose historical profile/group audit")
require("sourceProfileName" in inbox_store and "groupValidationStatus" in inbox_store,
        "Inbox persistence must preserve profile/group validation metadata")
for field in ["sourceProfileName: batch.sourceProfileName",
              "expectedGroupTitle: batch.expectedGroupTitle",
              "profileStartTime: batch.profileStartTime",
              "groupValidationStatus: batch.groupValidationStatus",
              "groupConfirmedByUser: batch.groupConfirmedByUser"]:
    require(reconstruction_service.count(field) >= 2,
            f"reconstruction success/failure must both preserve profile audit: {field}")

require("startsTaskClause" in task_extractor and "'练习册'" in task_extractor,
        "comma-separated independent tasks must split conservatively")

for text in [
    "18:03 王老师 另外明天记得带一本课外书",
    "17:50 家长A 收到",
    "17:42 王老师 练习册刚才说错了，是33页",
    "17:31 王老师 今晚语文：生字写两遍，练习册32页",
    "14:58 家长B 请问明天几点到校？"
]:
    require(text in fixture, f"#247 closure fixture missing message: {text}")
for expected in [
    "练习册33页", "生字写两遍", "明日准备：带一本课外书",
    "reconstruction.timeBoundaryReached", "reconstruction.earliestDetectedTime === '14:58'",
    "understanding.candidates.length === 3"
]:
    require(expected in fixture, f"#247 closure assertion missing: {expected}")
require("mismatchDetected" in fixture and "unrecognizedRequiresConfirmation" in fixture,
        "fixture must cover wrong-group and OCR-unrecognized group behavior")
require("mixedGroupConflictBlocked" in fixture and "conflictingGroupFrames" in fixture,
        "fixture must prove mixed-group capture is fail-closed")
require("normalizedGroupVariantMatched" in fixture and "二（3）班家长群(45)" in fixture,
        "fixture must cover common OCR/group-title bracket and member-count normalization")
require("replace(/（/g, '(')" in group_title_policy and "memberCount" in group_title_policy and
        "normalizedValues.length > 1" in group_title_policy,
        "group-title policy must normalize OCR variants before mixed-group conflict detection")

require("candidateId: candidate.id" in publish,
        "published Assignment must point back to Candidate by candidateId")
mark_start = inbox_store.find("markPublished(batchId")
mark_end = inbox_store.find("abandon(batchId", mark_start)
mark_body = inbox_store[mark_start:mark_end] if mark_start >= 0 and mark_end > mark_start else ""
require("this.candidates" not in mark_body,
        "publishing must retain Candidate snapshots for Assignment→Candidate→SourceEvidence traceability")

require("HomeworkImportPage" in import_home,
        "manual text/screenshot import entry must remain available")
require("ParentVoiceAssignmentPage" in shell,
        "existing voice assignment entry must remain available")
require("HomeworkConfirmationPage" in shell and "HomeworkBatchPublishService" in publish,
        "existing parent confirmation/atomic publish flow must remain reused")

if errors:
    print("ISSUE_247_SOURCE_PROFILE_CLOSURE_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_247_SOURCE_PROFILE_CLOSURE_GATE_PASS")
