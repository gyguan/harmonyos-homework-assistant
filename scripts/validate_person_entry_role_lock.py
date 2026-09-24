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
student_switcher = read("entry/src/main/ets/components/family/StudentSwitcherDialog.ets")
identity_switcher = read("entry/src/main/ets/components/family/IdentitySwitcherDialog.ets")
identity_context = read("entry/src/main/ets/components/family/IdentityContextBar.ets")
parent_access = read("entry/src/main/ets/components/family/ParentAccessDialog.ets")
settings = read("entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets")

require("PersonEntryPage" in index and "AppRole.NONE" in index,
        "Index must keep the initial person entry page")
require("enterParent" in index and "enterStudent(studentId: string)" in index,
        "root entry must own parent/student persona changes")
require("this.familyContext.setActiveStudent(studentId)" in index,
        "student identity selection must bind active student through FamilyContextRepository")
require("AppShell({" in index and "role: this.selectedRole" in index,
        "AppShell role must remain a root-owned read-only prop")
require("onSwitchParent: () => this.requestParentAccess()" in index and
        "onSwitchStudent: (studentId: string) => this.enterStudent(studentId)" in index,
        "AppShell identity changes must delegate role ownership back to Index")
require("HomeworkSyncService" not in index and
        "DefaultAssignmentRepository.instance.requestSync()" in index,
        "root identity switch must keep repository background sync")

require("HomeworkStore" not in entry_page and "FamilyContextRepository" in entry_page and
        "this.familyContext.getStudents()" in entry_page,
        "person entry page must continue using FamilyContextRepository")
require("家长" in entry_page and "孩子" in entry_page and "谁在使用" in entry_page,
        "initial entry page must still expose parent and child choices")
require("onSelectStudent(student.id)" in entry_page,
        "initial student selection must preserve the selected child id")
require("onSelectParent: () => this.requestParentAccess()" in index and
        "private requestParentAccess(): void" in index and
        "private confirmParentAccess(): void" in index,
        "all parent role entry must use the root-owned parent access gate")
require("@CustomDialog" in parent_access and "请输入设备家长码" in parent_access,
        "parent access must use an explicit local verification dialog")
require("updateParentAccessCode" in settings and "设备家长码" in settings and
        "家长码只保存在当前设备" in settings,
        "parent settings must allow enabling, changing and disabling the device access code")

require("@Prop @Watch('onRoleChanged') role: AppRole" in app_shell and
        "@State private role" not in app_shell and
        "private onRoleChanged(): void" in app_shell,
        "AppShell must observe root-owned role changes without owning mutable role state")
require("IdentitySwitcherDialog" in app_shell and "@CustomDialog" in identity_switcher,
        "AppShell must expose a reusable in-app identity switcher")
require("private openIdentitySwitcher()" in app_shell and
        "private switchToParent()" in app_shell and
        "private switchToStudent(studentId: string)" in app_shell,
        "AppShell must provide explicit identity switch actions")
require("private resetPersonaNavigation()" in app_shell and
        "this.navPathStack.clear()" in app_shell and
        "this.studentRoute = StudentRoute.HOME" in app_shell and
        "this.parentRoute = ParentRoute.DASHBOARD" in app_shell,
        "identity changes must clear role-specific navigation state")
switch_parent = app_shell.split("private switchToParent(): void {", 1)[1].split(
    "private switchToStudent(studentId: string): void {", 1)[0]
require("this.resetPersonaNavigation()" not in switch_parent and
        "this.onSwitchParent();" in switch_parent and
        "this.resetPersonaNavigation();" in app_shell.split("private onRoleChanged(): void {", 1)[1].split(
            "private openIdentitySwitcher()", 1)[0],
        "parent navigation must reset only after parent access succeeds and role actually changes")
switch_student = app_shell.split("private switchToStudent(studentId: string): void {", 1)[1].split(
    "private openStudentSwitcher()", 1)[0]
require("this.familyContext.setActiveStudent(studentId)" not in switch_student and
        "this.onSwitchStudent(studentId)" in switch_student,
        "AppShell identity switch must delegate student context ownership to Index")
require("IdentityContextBar({" in app_shell and
        "onSwitchIdentity: () => this.openIdentitySwitcher()" in app_shell and
        "@Component" in identity_context and "export struct IdentityContextBar" in identity_context,
        "Phone identity context presentation must stay in the shared family component")
require("onSwitchIdentity: () => this.openIdentitySwitcher()" in app_shell and
        ".onClick(() => this.openIdentitySwitcher())" in app_shell,
        "Phone and wide shells must both expose identity switching")
require("@State private identityParentActive: boolean" in app_shell and
        "parentActive: $identityParentActive" in app_shell and
        "this.identityParentActive = this.role === AppRole.PARENT" in app_shell and
        "students: $familyStudents" in app_shell and
        "activeStudentId: $activeStudentId" in app_shell,
        "identity switcher must bind role and student context reactively")

require("private openStudentSwitcher()" in app_shell and
        "private selectStudent(studentId: string)" in app_shell and
        "StudentSwitcherDialog" in app_shell and "@CustomDialog" in student_switcher,
        "parent child-context switching must remain independently available")
require("if (this.role !== AppRole.PARENT" in app_shell,
        "parent child-context switching must remain parent-only")
require("选择家长或学生" in identity_switcher and
        "onSelectParent" in identity_switcher and
        "onSelectStudent" in identity_switcher,
        "identity dialog must combine role and person selection in one surface")
require("CenteredTextBadge" in identity_switcher and "badgeText: '家'" in identity_switcher,
        "identity dialog must reuse shared centered identity badges")
require("@Link parentActive: boolean" in identity_switcher and
        identity_switcher.count("!this.parentActive && this.activeStudentId === student.id") >= 4,
        "student current-state marker must be guarded by non-parent identity")

if errors:
    print("PERSON_ENTRY_ROLE_LOCK_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PERSON_ENTRY_ROLE_LOCK_GATE_PASS")
