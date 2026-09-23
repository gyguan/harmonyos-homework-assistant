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


models = read("entry/src/main/ets/domain/model/HomeworkModels.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
mock_data = read("entry/src/main/ets/data/MockData.ets")
import_service = read("entry/src/main/ets/application/import/HomeworkImportService.ets")
parser = read("entry/src/main/ets/infrastructure/ai/LocalHomeworkAssignmentParser.ets")
ocr = read("entry/src/main/ets/infrastructure/ai/CoreVisionHomeworkTextExtractor.ets")
persistence = read("entry/src/main/ets/domain/model/PersistenceModels.ets")
migrator = read("entry/src/main/ets/domain/service/HomeworkSnapshotMigrator.ets")
app_shell = read("entry/src/main/ets/pages/AppShell.ets")
switcher = read("entry/src/main/ets/components/family/StudentSwitcherDialog.ets")
assignment_repository = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
parent_home = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")

require("students: StudentProfile[]" in models, "AppSettings must store multiple children")
require("activeStudentId: string" in models, "AppSettings must store the active child")
require("className: string" in models, "StudentProfile must store class name")
require(models.count("studentId: string") >= 4,
        "RawImport/Candidate/Assignment/TutorSession must carry studentId")
require("familyId" not in models and "tenantId" not in models,
        "client domain must remain family-scoped instead of introducing tenant routing")

require("student-xiaoyu-001" in mock_data and "student-xiaomi-002" in mock_data,
        "two children must exist in the regression baseline")
class_names = re.findall(r"className:\s*'([^']+)'", mock_data)
require(len(class_names) >= 2 and len(set(class_names[:2])) == 2,
        "regression children must belong to different classes")

# Legacy Store remains a migration source until Repository/Session replaces it. These checks
# protect the actual isolation behavior without making AppShell routes or schema numbers permanent.
require("getActiveStudentId" in store and "setActiveStudent" in store,
        "current local state must retain an explicit active-child context")
require("assignment.studentId === studentId" in store,
        "Assignment reads must remain isolated by studentId")
require("candidate.studentId === studentId" in store,
        "Candidate reads must remain isolated by studentId")
require("existing.studentId !== studentId" in store,
        "Replacing one child's state must preserve siblings' state")
require("input.studentId !== this.getActiveStudentId()" in store,
        "current raw-import write path must reject another child's import")

require("rawImports: RawHomeworkImport[]" in persistence,
        "Snapshot must persist child-scoped raw imports")
for field in ["settings", "rawImports", "assignments", "candidates", "submissions", "tutorSessions"]:
    require(f"{field}: snapshot.{field}" in migrator,
            f"snapshot migration must preserve multi-child field: {field}")

require("getActiveStudentId" in import_service and "studentId: studentId" in import_service,
        "Text and screenshot imports must bind to the active child")
require("studentId: input.studentId" in ocr,
        "OCR must preserve child context")
require("studentId: input.studentId" in parser,
        "Parser must preserve child context")

# Parent child switching is a persistent family-context selection, not a cycle button. The active
# child must be an explicit reactive state so the identity bar and wide rail re-render immediately.
require("@State private activeStudentId: string = '';" in app_shell and
        "@State private familyStudents: StudentProfile[] = [];" in app_shell,
        "AppShell must keep active child identity in reactive state")
require("StudentSwitcherDialog" in app_shell and "openStudentSwitcher" in app_shell and
        "selectStudent(studentId: string)" in app_shell,
        "Parent child switching must use an explicit selector dialog")
require("DialogAlignment.Bottom" in app_shell and "DialogAlignment.Center" in app_shell,
        "Child selector must adapt Phone bottom modal and wide centered dialog")
require("Text(this.currentStudent().name)" in app_shell and "Text(this.currentStudent().className)" in app_shell,
        "Family context surfaces must read the reactive current child")
require(".onClick(() => this.openStudentSwitcher())" in app_shell,
        "Parent family context controls must open the selector instead of cycling children")
require("this.navPathStack.clear();" in app_shell and "this.parentRoute = ParentRoute.DASHBOARD;" in app_shell,
        "Switching children must clear previous-child detail routes and return to Parent Home")

require("@CustomDialog" in switcher and "@Link activeStudentId: string;" in switcher and
        "@Link students: StudentProfile[];" in switcher,
        "Child selector must react to current family members and active child")
require("this.activeStudentId === student.id" in switcher and "当前孩子" in switcher,
        "Child selector must visibly identify the current child")

require("remoteSummaryStudentId" in assignment_repository and
        "this.remoteSummaryStudentId === activeStudentId" in assignment_repository,
        "Today summary cache must be scoped to the active child")
require("this.queryCache = [];" in assignment_repository and
        "this.remoteSummary = null;" in assignment_repository,
        "Repository refresh must clear previous-child in-memory caches synchronously")

# Parent Home reads the active child through repository/family context and re-renders from the shared
# repository revision. The visible child identity belongs to AppShell's persistent FamilyContextBar.
require("@Prop revision: number = 0;" in parent_home and "private touchRevision(): number" in parent_home,
        "Parent Home must subscribe to shared repository revision instead of duplicating activeStudentId")
require("revision: this.storeRevision" in app_shell and "this.storeRevision++;" in app_shell,
        "child switching must invalidate repository-backed parent home content")
require("@Prop activeStudentId" not in parent_home,
        "Parent Home must not keep a second active-child identity prop")
require("FamilyContextBar" in app_shell and "currentStudent()" in app_shell,
        "Persistent family context surface must own the visible current-child identity")

if errors:
    print("MULTI_CHILD_ISOLATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("MULTI_CHILD_ISOLATION_GATE_PASS")
