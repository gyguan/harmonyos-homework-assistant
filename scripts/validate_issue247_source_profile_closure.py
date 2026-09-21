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
profile_page = read("entry/src/main/ets/features/parent/import/HomeworkSourceProfilePage.ets")
capture_page = read("entry/src/main/ets/features/parent/import/HomeworkCapturePage.ets")
float_page = read("entry/src/main/ets/pages/HomeworkCaptureFloatView.ets")
workflow = read("entry/src/main/ets/application/capture/HomeworkCaptureWorkflowService.ets")
understanding = read("entry/src/main/ets/application/understanding/HomeworkUnderstandingService.ets")
batch_detail = read("entry/src/main/ets/features/parent/import/HomeworkImportBatchDetailPage.ets")
import_models = read("entry/src/main/ets/domain/model/ImportModels.ets")
inbox_store = read("entry/src/main/ets/data/local/HomeworkImportInboxStore.ets")
publish = read("entry/src/main/ets/application/import/HomeworkBatchPublishService.ets")
fixture = read("entry/src/main/ets/experimental/homeworkcapture/Issue247FullClosureFixture.ets")
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
for state in ["MATCHED", "MISMATCH", "UNRECOGNIZED"]:
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
require("startCaptureAfterSave" in routes and "finishSourceProfile" in shell,
        "first-use setup and later settings edit must have different navigation semantics")
require("HomeworkSourceProfilePage" in shell,
        "SourceProfile setup page must be reachable")

require("抓取今日作业" in import_home and "profileSubtitle" in import_home,
        "import home must expose one-click daily capture and active profile summary")
require("今天 " in import_home and " 至现在" in import_home,
        "profile summary must show today's capture window")
require("getActiveProfile(studentId) === null" in import_home and
        "onOpenSourceProfile(true)" in import_home,
        "first click without a profile must route through first-time setup")
require("onOpenSourceProfile(false)" in import_home,
        "profile settings edit must not automatically stack a new capture page")

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
require("HomeworkCaptureWorkflowService.instance.start(studentId)" in capture_page,
        "capture page must start through the profile-aware workflow")
require("不使用 Accessibility 驱动微信" in capture_page and
        "不会自动点击或滚动微信" in capture_page,
        "formal capture must keep the no-automation privacy boundary")
require("Clipboard" not in capture_page and "Clipboard" not in workflow,
        "one-click daily capture must not require clipboard copy/paste")

require("targetStartMinuteOfDay: profile.defaultStartMinuteOfDay" in workflow,
        "live reconstruction must use SourceProfile start time")
require("validateGroupTitle(profile.groupTitle" in workflow,
        "workflow must validate detected group title against profile")
require("SourceGroupValidationStatus.MISMATCH" in workflow and
        "SourceGroupValidationStatus.UNRECOGNIZED" in workflow,
        "mismatch and unrecognized group states must not be conflated")
require("needsGroupConfirmation" in workflow and
        "confirmUnrecognizedAndContinue" in workflow,
        "unrecognized group must require explicit parent continuation")
require("validation === SourceGroupValidationStatus.MISMATCH" in workflow,
        "mismatched group must block automatic homework understanding")
require("profileStartEpoch" in workflow and "understandAndActivate" in workflow,
        "profile time window must flow into homework understanding")
require("TIME_RANGE_FILTERED" in understanding and
        "this.inbox.importBatch(updated, allMessages, result.candidates)" in understanding,
        "out-of-window messages must be excluded from semantics but retained for audit")

require("timeBoundaryReached" in float_page and "已到达今日时间范围" in float_page,
        "FloatView must tell the user when the profile time boundary is reached")
require("当前群与配置不一致" in float_page,
        "FloatView must surface group mismatch while user is in WeChat")
require("结束并自动整理" in capture_page and "handleWorkflowResult" in capture_page,
        "capture stop must continue into automatic reconstruction/understanding")
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
require("运行 #247 完整闭环自测" in spike,
        "#247 full-closure fixture must be runnable from diagnostic UI")

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
