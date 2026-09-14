#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
ETS_ROOT = ROOT / "entry" / "src" / "main" / "ets"
errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def read(path: str) -> str:
    file = ROOT / path
    require(file.exists(), f"missing required file: {path}")
    return file.read_text(encoding="utf-8") if file.exists() else ""


build_profile = read("build-profile.json5")
hvigor_config = read("hvigor/hvigor-config.json5")
oh_package = read("oh-package.json5")
module_config = read("entry/src/main/module.json5")
entry_ability = read("entry/src/main/ets/entryability/EntryAbility.ets")
app_shell = read("entry/src/main/ets/pages/AppShell.ets")
responsive = read("entry/src/main/ets/common/responsive/WindowSizeClass.ets")
models = read("entry/src/main/ets/domain/model/HomeworkModels.ets")
persistence_models = read("entry/src/main/ets/domain/model/PersistenceModels.ets")
state_machine = read("entry/src/main/ets/domain/service/AssignmentStateMachine.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
confirmation_page = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
progress_page = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")
student_today = read("entry/src/main/ets/features/student/today/StudentTodayPage.ets")
study_workspace = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
parent_dashboard = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
import_page = read("entry/src/main/ets/features/parent/import/HomeworkImportPage.ets")
persistence_port = read("entry/src/main/ets/domain/port/HomeworkPersistence.ets")
persistence_adapter = read("entry/src/main/ets/infrastructure/persistence/PreferencesHomeworkPersistence.ets")
text_extractor_port = read("entry/src/main/ets/domain/port/HomeworkTextExtractor.ets")
assignment_parser_port = read("entry/src/main/ets/domain/port/HomeworkAssignmentParser.ets")
import_pipeline = read("entry/src/main/ets/application/import/HomeworkImportPipeline.ets")
import_service = read("entry/src/main/ets/application/import/HomeworkImportService.ets")
submission_service = read("entry/src/main/ets/application/submission/HomeworkSubmissionService.ets")
core_ocr = read("entry/src/main/ets/infrastructure/ai/CoreVisionHomeworkTextExtractor.ets")
local_parser = read("entry/src/main/ets/infrastructure/ai/LocalHomeworkAssignmentParser.ets")

require('"compileSdkVersion": "26.0.0"' in build_profile,
        "compileSdkVersion must match the DevEco Studio 26.0.0 toolchain")
require('"compatibleSdkVersion": "6.0.0(20)"' in build_profile,
        "compatibleSdkVersion must keep the V0.1 runtime baseline at HarmonyOS 6.0.0(20)")
require('"targetSdkVersion"' not in build_profile,
        "targetSdkVersion must remain unset for the locally verified DevEco configuration")

require('"modelVersion": "5.0.0"' in hvigor_config, "Hvigor modelVersion must be 5.0.0")
require('"modelVersion": "5.0.0"' in oh_package, "OHPM modelVersion must be 5.0.0")
require('"hvigorVersion": "6.26.4"' in hvigor_config, "Hvigor version must be pinned to 6.26.4")
require('"@ohos/hvigor-ohos-plugin": "6.26.4"' in hvigor_config,
        "Hvigor OHOS plugin must be pinned to 6.26.4")

require('"phone"' in module_config and '"tablet"' in module_config,
        "entry module must declare both phone and tablet device types")
require("Navigation(this.navPathStack)" in app_shell,
        "AppShell must keep Navigation bound to NavPathStack")
require("ResponsiveContext.resolve(this.widthVp)" in app_shell,
        "AppShell must derive size class from the shared responsive resolver")
require("this.NavText('教材'" not in app_shell and "this.SideItem('教材'" not in app_shell,
        "student V0.1 navigation must stay focused on Today / Homework / Me")

require("widthVp <= 600" in responsive and "widthVp <= 840" in responsive,
        "shared responsive breakpoints must remain 600vp / 840vp")

required_statuses = [
    "NOT_STARTED",
    "IN_PROGRESS",
    "READY_TO_SUBMIT",
    "SUBMITTED",
    "COMPLETED",
    "NEEDS_REWORK",
    "OVERDUE",
]
for status in required_statuses:
    require(status in models, f"missing assignment lifecycle status: {status}")

for core_model in ["StudentProfile", "AppSettings", "CandidateAssignment", "Assignment", "Submission", "TutorSession"]:
    require(f"interface {core_model}" in models, f"missing simplified V0.1 core model: {core_model}")

require("HomeworkImportSourceKind" in models and "resourceUri" in models,
        "RawHomeworkImport must preserve source kind and resource URI for OCR/file extraction")
require("photoUris: string[]" in models and "IMAGE = 'IMAGE'" in models and "MOCK_IMAGE" not in models,
        "Submission must store real image URIs and must not use MOCK_IMAGE")
require("familyId" not in models and "studentId" not in models,
        "single-family V0.1 domain must not carry tenant/family routing fields")
require("class AssignmentStateMachine" in state_machine,
        "assignment transitions must be centralized in AssignmentStateMachine")
require("canTransition" in state_machine,
        "AssignmentStateMachine must reject illegal transitions")
require("class HomeworkStore" in store and "static readonly instance" in store,
        "HomeworkStore singleton must own the local lifecycle state")
require("getStudent" in store and "getSettings" in store,
        "HomeworkStore must own the single-child profile and app settings")
require("replaceRawImport" in store and "replaceCandidates" in store,
        "HomeworkStore must accept a successful OCR import atomically from the application service")
require("publishCandidates" in store and "submitImages" in store and "submitMockImage" not in store,
        "HomeworkStore must support candidate publishing and real image submission")
require("SNAPSHOT_SCHEMA_VERSION: number = 3" in store,
        "real submission model change must bump the local snapshot schema to v3")
require("AssignmentStateMachine.canTransition" in store,
        "HomeworkStore transitions must delegate to AssignmentStateMachine")

require("interface HomeworkPersistence" in persistence_port,
        "local persistence must be hidden behind HomeworkPersistence")
require("HomeworkPersistence" in store and "@kit.ArkData" not in store,
        "HomeworkStore must depend on the persistence port, not ArkData")
require("class PreferencesHomeworkPersistence" in persistence_adapter,
        "V0.1 must provide a Preferences persistence adapter")
require("@kit.ArkData" in persistence_adapter and "preferences.getPreferences" in persistence_adapter,
        "Preferences adapter must use ArkData Preferences")
require("store.flush" in persistence_adapter,
        "Preferences adapter must flush snapshots to durable storage")
require("HomeworkStore.instance.initialize" in entry_ability and "PreferencesHomeworkPersistence" in entry_ability,
        "EntryAbility must restore the store before loading the UI")
require("settings: AppSettings" in persistence_models and "tutorSessions: TutorSession[]" in persistence_models,
        "HomeworkSnapshot must include settings and tutorSessions")
require("settings: parsed.settings as AppSettings" in persistence_adapter and
        "tutorSessions: parsed.tutorSessions as TutorSession[]" in persistence_adapter,
        "Preferences adapter must restore every required HomeworkSnapshot field")

require("interface HomeworkTextExtractor" in text_extractor_port,
        "OCR/text extraction must be hidden behind HomeworkTextExtractor")
require("interface HomeworkAssignmentParser" in assignment_parser_port,
        "semantic parsing must be hidden behind HomeworkAssignmentParser")
require("class HomeworkImportPipeline" in import_pipeline,
        "extractor and parser must be orchestrated by HomeworkImportPipeline")
require("class HomeworkImportService" in import_service and "selectImageAndParse" in import_service,
        "Import UI must select and process a screenshot through HomeworkImportService")
require("photoAccessHelper.PhotoViewPicker" in import_service,
        "screenshot import must use the HarmonyOS photo picker")
require("HomeworkImportService" in import_page and "选择作业截图" in import_page,
        "HomeworkImportPage must expose the real screenshot import action")
require("CoreVisionHomeworkTextExtractor" not in import_page and "LocalHomeworkAssignmentParser" not in import_page,
        "HomeworkImportPage must not depend on concrete OCR/parser adapters")

require("class HomeworkSubmissionService" in submission_service and "photoAccessHelper.PhotoViewPicker" in submission_service,
        "real submission must use a small application service around HarmonyOS PhotoViewPicker")
require("maxSelectNumber: MAX_SUBMISSION_PHOTOS" in submission_service and "MAX_SUBMISSION_PHOTOS: number = 6" in submission_service,
        "real submission must allow up to six photos")
require("HomeworkSubmissionService" in study_workspace and "选择作业照片" in study_workspace,
        "student workspace must expose real photo selection before submission")
require("submitMockImage" not in study_workspace and "submissionPhotoUris" in study_workspace,
        "student workspace must not retain the mock submission path")
require("submission.photoUris" in progress_page and "Image(uri)" in progress_page,
        "parent progress must preview real submitted photo URIs")

require("class CoreVisionHomeworkTextExtractor" in core_ocr,
        "V0.1 must provide a real Core Vision OCR extractor")
require("@kit.CoreVisionKit" in core_ocr and "textRecognition.recognizeText" in core_ocr,
        "real OCR extractor must use Core Vision textRecognition")
require("class LocalHomeworkAssignmentParser" in local_parser,
        "V0.1 must provide a local homework parser without cloud credentials")
for subject_label in ["语文", "数学", "英语"]:
    require(subject_label in local_parser, f"local parser must recognize subject marker: {subject_label}")
require("sourceEvidence" in local_parser and "input.sourceLabel" in local_parser,
        "candidate Source Evidence must come from the actual extracted text source")
require("CoreVisionHomeworkTextExtractor" in entry_ability and "LocalHomeworkAssignmentParser" in entry_ability,
        "EntryAbility must compose the real OCR extractor with the local parser")
require("MockHomeworkTextExtractor" not in entry_ability and "MockHomeworkAssignmentParser" not in entry_ability,
        "production composition root must not use the Mock import pipeline")

require("CONFIRMATION" in app_shell and "PROGRESS" in app_shell,
        "AppShell must expose parent confirmation and progress routes")
require("storeRevision" in app_shell,
        "AppShell must propagate shared store updates across role/page switches")
require("publishCandidates" in confirmation_page,
        "parent confirmation must publish candidates through HomeworkStore")
require("getSubmissionsForAssignment" in progress_page,
        "parent progress must expose submission records")
require("导入老师作业" in parent_dashboard and "Kpi(" not in parent_dashboard,
        "parent home must stay a simple family overview, not a management dashboard")

for page_name, page_text in {
    "StudentTodayPage": student_today,
    "StudyWorkspacePage": study_workspace,
    "ParentDashboardPage": parent_dashboard,
    "HomeworkImportPage": import_page,
}.items():
    require("MockData" not in page_text,
            f"{page_name} must read business state through HomeworkStore, not MockData")

forbidden_single_family_fields = ["familyId", "parentId", "guardianId", "organizationId", "classId"]

if ETS_ROOT.exists():
    for file in ETS_ROOT.rglob("*.ets"):
        text = file.read_text(encoding="utf-8")
        rel = file.relative_to(ROOT).as_posix()
        if "ContainerReader" in text:
            errors.append(f"API 26+ ContainerReader is not allowed in V0.1 runtime-compatible code: {rel}")
        if file.name != "WindowSizeClass.ets":
            if re.search(r"(?:<=|>=|<|>)\s*(?:600|840)\b", text):
                errors.append(f"responsive breakpoint duplicated outside WindowSizeClass: {rel}")
        if "@kit.ArkData" in text and "infrastructure/persistence/" not in rel:
            errors.append(f"ArkData persistence leaked outside infrastructure adapter: {rel}")
        if "@kit.CoreVisionKit" in text and "infrastructure/ai/" not in rel:
            errors.append(f"Core Vision OCR leaked outside infrastructure adapter: {rel}")
        if "@kit.MediaLibraryKit" in text and "/application/" not in f"/{rel}":
            errors.append(f"MediaLibraryKit picker leaked outside application service: {rel}")
        if "/features/" in f"/{rel}" and ("CoreVisionHomeworkTextExtractor" in text or "LocalHomeworkAssignmentParser" in text):
            errors.append(f"UI page depends on concrete OCR/parser adapter: {rel}")
        for field in forbidden_single_family_fields:
            if field in text:
                errors.append(f"single-family V0.1 contains unnecessary multi-tenant field {field}: {rel}")

required_scenarios = ["LOADING", "EMPTY", "ERROR", "OFFLINE", "TUTOR_UNAVAILABLE"]
demo_scenario = read("entry/src/main/ets/common/state/DemoScenario.ets")
for scenario in required_scenarios:
    require(scenario in demo_scenario, f"missing reproducible demo scenario: {scenario}")

if errors:
    print("STATIC_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("STATIC_GATE_PASS")
