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
view_model = read("entry/src/main/ets/features/student/home/StudentHomeViewModel.ets")
home = read("entry/src/main/ets/features/student/home/StudentHomePage.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
parent_progress = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")

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

require("HOMEWORK_SNAPSHOT_SCHEMA_VERSION: number = 6" in migrator and "migrateV5ToV6" in migrator,
        "Assignment V2 client fields must use an explicit V5 -> V6 snapshot migration")
require("assignmentType: AssignmentType.SCHOOL" in migrator and "dueAtEpochMs: 0" in migrator,
        "V5 -> V6 must use deterministic historical defaults without guessing due time")

require("Subject," in store and "private subjectCode(subject: Subject)" in store,
        "HomeworkStore V2 subject mapper must import Subject explicitly for ArkTS compilation")
for field in ["assignmentType: item.assignmentType", "subjectCode: this.subjectCode(this.editSubject)",
              "dueAtEpochMs:", "dueTimezone: item.dueTimezone"]:
    require(field in parent_progress,
            f"parent assignment edit must preserve/update V2 field: {field}")
require("dueChanged ? 0 : item.dueAtEpochMs" in parent_progress,
        "editing legacy dueText must clear structured dueAt instead of keeping stale structured time")

require("interface AssignmentRepository" in repository_port,
        "V2 Student Home must depend on an AssignmentRepository port")
require("implements AssignmentRepository" in repository_impl,
        "a local-first AssignmentRepository implementation must exist")
require("HomeworkStore.instance" in repository_impl,
        "legacy Store access is allowed only inside the migration repository boundary")
require("HomeworkStore.instance" not in view_model and "HomeworkStore.instance" not in home,
        "V2 ViewModel/Page must not directly access HomeworkStore")
require("WindowSizeClass." not in home and "@Prop sizeClass" not in home and "this.sizeClass" not in home,
        "V2 Student Home must use LayoutPolicy/container capability instead of size-class business branching")
require("private PhoneHome()" in home and "private PadHome()" in home and
        "LayoutPolicy.homeFocusSummaryRequirement()" in home,
        "V2 Student Home must keep the Phone single-column fallback and the approved Pad focus/summary composition")
require("NextAssignmentHero" in home and "TodayProgress" in home and "RemainingAssignments" in home,
        "V2 Student Home must preserve the approved information hierarchy")
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
