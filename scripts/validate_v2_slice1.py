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


migration = read("backend/src/main/resources/db/migration/V7__assignment_v2_core.sql")
entity = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentEntity.java")
dtos = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentDtos.java")
controller = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentController.java")
service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
models = read("entry/src/main/ets/domain/model/HomeworkModels.ets")
migrator = read("entry/src/main/ets/domain/service/HomeworkSnapshotMigrator.ets")
repository_port = read("entry/src/main/ets/domain/port/AssignmentRepository.ets")
repository_impl = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
remote_api = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
view_model = read("entry/src/main/ets/features/student/home/StudentHomeViewModel.ets")
home = read("entry/src/main/ets/features/student/home/StudentHomePage.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")

for column in ["assignment_type", "subject_code", "due_at", "due_timezone"]:
    require(column in migration, f"V7 missing Assignment V2 column: {column}")
require("set assignment_type = 'SCHOOL'" in migration,
        "V7 must deterministically classify historical assignments as SCHOOL")
for legacy, code in [("语文", "CHINESE"), ("数学", "MATH"), ("英语", "ENGLISH")]:
    require(f"when '{legacy}' then '{code}'" in migration,
            f"V7 missing deterministic subject mapping: {legacy} -> {code}")
require("else 'OTHER'" in migration, "V7 must map unknown historical subjects to OTHER")
require("due_text" not in migration.lower(),
        "V7 must not infer structured due_at from historical dueText")

for field in ["assignmentType", "subjectCode", "dueAt", "dueTimezone"]:
    require(field in entity, f"backend entity missing V2 field: {field}")
for field in ["assignmentType", "subjectCode", "dueAtEpochMs", "dueTimezone"]:
    require(field in dtos, f"backend DTO missing V2 field: {field}")
    require(field in models, f"client Assignment missing V2 field: {field}")
require("assignments/summary" in controller and "TodaySummary" in dtos and "todaySummary" in service,
        "backend must expose the Student Home summary query")
require("undated" in dtos and "assignment.dueAt == null" in service,
        "historical undated tasks must stay explicit instead of receiving guessed dates")

require("HOMEWORK_SNAPSHOT_SCHEMA_VERSION: number = 9" in migrator and
        "migrateV5ToV6" in migrator and
        "migrateV7ToV8" in migrator and
        "migrateV8ToV9" in migrator,
        "Assignment V2 client fields must retain V5 -> V6 while later schemas advance through V9")
require("assignmentType: AssignmentType.SCHOOL" in migrator and "dueAtEpochMs: 0" in migrator,
        "V5 -> V6 must use deterministic historical defaults without guessing due time")

require("Subject," in store and "private subjectCode(subject: Subject)" in store,
        "HomeworkStore V2 subject mapper must import Subject explicitly for ArkTS compilation")
# Parent Progress no longer owns assignment editing in Slice 4. Preserve the original Slice 1
# invariant at the durable API boundary instead of requiring old page-local edit state.
for field in ["assignmentType: assignment.assignmentType", "subjectCode: assignment.subjectCode",
              "dueAtEpochMs: assignment.dueAtEpochMs", "dueTimezone: assignment.dueTimezone"]:
    require(field in remote_api,
            f"Assignment remote update/create must preserve V2 field: {field}")
require("dueAtEpochMs: number" in remote_api and "dueTimezone: string" in remote_api,
        "remote Assignment request DTOs must keep structured due fields")

require("interface AssignmentRepository" in repository_port,
        "V2 Student Home must depend on an AssignmentRepository port")
require("implements AssignmentRepository" in repository_impl,
        "a local-first AssignmentRepository implementation must exist")
local_data_source = read("entry/src/main/ets/data/local/AssignmentLocalDataSource.ets")
require("HomeworkStore.instance" not in repository_impl and "../HomeworkStore" not in repository_impl and
        "AssignmentLocalDataSource" in repository_impl,
        "AssignmentRepository must depend on the local data source boundary instead of HomeworkStore")
require("DefaultAssignmentLocalDataSource" in local_data_source and
        "HomeworkStore.instance" in local_data_source,
        "legacy Store access must be isolated inside AssignmentLocalDataSource")
require("HomeworkStore.instance" not in view_model and "HomeworkStore.instance" not in home,
        "V2 ViewModel/Page must not directly access HomeworkStore")
require("WindowSizeClass." not in home and "@Prop sizeClass" not in home and "this.sizeClass" not in home,
        "V2 Student Home must use LayoutPolicy/container capability instead of size-class business branching")
require("private PhoneHome()" in home and "private PadHome()" in home and
        "LayoutPolicy.homeFocusSummaryRequirement()" in home,
        "V2 Student Home must keep the Phone single-column fallback and the approved Pad focus/summary composition")
# Student Home is a strict Today surface with direct task actions. Summary cards and the
# subject accordion were removed because they delayed the grade-two student's primary action.
require("private TodayTasks()" in home and "StudentTodayTaskCard" in home and
        "todayActionableAssignments()" in view_model and "AssignmentAction.START" in home,
        "V2 Student Home must preserve the simplified Today task hierarchy and command path")
require("StudentHomeMetricCard" not in home and "StudentSubjectTaskGroupCard" not in home,
        "V2 Student Home must not restore summary-card or subject-accordion friction")
require("dueAtEpochMs <= 0" in view_model and "dueText" not in view_model,
        "V2 Student Home must use structured dueAt for Today and leave undated work to Assignments")
require("StudentHomePage" in shell and "StudentTodayPage" not in shell,
        "AppShell must cut over to V2 Student Home")
require("HOME = 'HOME'" in shell and "TODAY = 'TODAY'" not in shell,
        "legacy Today route must be removed after Student Home cutover")
require(not (ROOT / "entry/src/main/ets/features/student/today/StudentTodayPage.ets").exists(),
        "superseded V1 StudentTodayPage must be deleted after cutover")

if errors:
    print("V2_SLICE1_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_SLICE1_GATE_PASS")
