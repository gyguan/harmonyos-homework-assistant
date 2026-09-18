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


index = read("entry/src/main/ets/pages/Index.ets")
entry_page = read("entry/src/main/ets/pages/PersonEntryPage.ets")
app_shell = read("entry/src/main/ets/pages/AppShell.ets")
switcher = read("entry/src/main/ets/components/family/StudentSwitcherDialog.ets")

require("PersonEntryPage" in index and "AppRole.NONE" in index,
        "Index must show a person entry page before creating AppShell")
require("enterParent" in index and "AppRole.PARENT" in index,
        "entry page must provide an explicit parent persona")
require("enterStudent(studentId: string)" in index and "this.familyContext.setActiveStudent(studentId)" in index,
        "student persona selection must bind the selected child through FamilyContextRepository before entering")
require("AppShell({" in index and "role: this.selectedRole" in index,
        "AppShell role must be supplied by the root entry gate")
require("HomeworkSyncService" not in index and "DefaultAssignmentRepository.instance.requestSync()" in index,
        "root entry must use AssignmentRepository background sync instead of legacy HomeworkSyncService")

require("HomeworkStore" not in entry_page and "FamilyContextRepository" in entry_page and
        "this.familyContext.getStudents()" in entry_page,
        "person entry page must render family children through FamilyContextRepository")
require("家长" in entry_page and "孩子" in entry_page and "谁在使用" in entry_page,
        "person entry page must clearly expose parent and child choices")
require("onSelectStudent(student.id)" in entry_page,
        "each child choice must enter with its own studentId")
require("CenteredTextBadge" in entry_page and "text: '家'" in entry_page,
        "parent entry badge must reuse the shared real-centering component")

require("@Prop role: AppRole" in app_shell,
        "AppShell role must be read-only input from the entry page")
require("@State private role" not in app_shell,
        "AppShell must not keep a mutable role state")
require("切换家长" not in app_shell and "切换学生" not in app_shell,
        "in-app parent/student role switching must be removed")
require("if (this.role !== AppRole.PARENT" in app_shell,
        "child context switching must be guarded to parent role only")
require("private openStudentSwitcher()" in app_shell and "private selectStudent(studentId: string)" in app_shell and
        "this.familyContext.setActiveStudent(studentId)" in app_shell,
        "parent shell must retain explicit child context switching through FamilyContextRepository")
require("private FamilyContextBar()" in app_shell and "this.role === AppRole.PARENT" in app_shell,
        "phone parent shell must show family context without exposing role switching")
require("StudentSwitcherDialog" in app_shell and "@CustomDialog" in switcher,
        "child switching must use an explicit selector instead of cycling to the next child")
require(app_shell.count(".onClick(() => this.openStudentSwitcher())") >= 2,
        "phone and wide parent child switch controls must remain actionable")
require("activeStudentId: $activeStudentId" in app_shell and "students: $familyStudents" in app_shell,
        "child selector must bind to the reactive family context")

if errors:
    print("PERSON_ENTRY_ROLE_LOCK_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PERSON_ENTRY_ROLE_LOCK_GATE_PASS")
