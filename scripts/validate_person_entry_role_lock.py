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

require("PersonEntryPage" in index and "AppRole.NONE" in index,
        "Index must show a person entry page before creating AppShell")
require("enterParent" in index and "AppRole.PARENT" in index,
        "entry page must provide an explicit parent persona")
require("enterStudent(studentId: string)" in index and "setActiveStudent(studentId)" in index,
        "student persona selection must bind the selected child before entering")
require("AppShell({" in index and "role: this.selectedRole" in index,
        "AppShell role must be supplied by the root entry gate")

require("HomeworkStore.instance.getStudents()" in entry_page,
        "person entry page must render the current family children")
require("家长" in entry_page and "孩子" in entry_page and "谁在使用" in entry_page,
        "person entry page must clearly expose parent and child choices")
require("onSelectStudent(student.id)" in entry_page,
        "each child choice must enter with its own studentId")

require("@Prop role: AppRole" in app_shell,
        "AppShell role must be read-only input from the entry page")
require("@State private role" not in app_shell,
        "AppShell must not keep a mutable role state")
require("切换家长" not in app_shell and "切换学生" not in app_shell,
        "in-app parent/student role switching must be removed")
require("if (this.role !== AppRole.PARENT)" in app_shell,
        "child context switching must be guarded to parent role only")
require("private switchStudent()" in app_shell and "HomeworkStore.instance.setActiveStudent" in app_shell,
        "parent shell must retain explicit child context switching")
require("private FamilyContextBar()" in app_shell and "this.role === AppRole.PARENT" in app_shell,
        "phone parent shell must show family context without exposing role switching")
require("this.role === AppRole.PARENT" in app_shell and "this.switchStudent()" in app_shell,
        "child switching actions must remain inside parent-only UI branches")
require("onClick(() => this.switchStudent())" in app_shell,
        "parent child switch control must remain actionable")

if errors:
    print("PERSON_ENTRY_ROLE_LOCK_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PERSON_ENTRY_ROLE_LOCK_GATE_PASS")
