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

detail = read("entry/src/main/ets/features/student/assignments/AssignmentDetailPane.ets")
page = read("entry/src/main/ets/features/student/assignments/StudentAssignmentDetailPage.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")

require("StudyWorkspacePage" in detail and
        "assignmentId: this.assignmentId" in detail and
        "revision: this.revision" in detail and
        "onStoreChanged: () => this.onStoreChanged()" in detail,
        "Assignment Detail must embed the execution workspace instead of navigating to a second page")
require("AssignmentDetailPane" in page and "DeepPageHeader" in page and
        "onStoreChanged: () => void" in page,
        "Phone Assignment Detail must keep deep-page chrome around the unified workspace")
require("private StudyContent(showPrimaryAction: boolean)" in study and
        "this.StudyContent(false);" in study and "this.WorkspaceActionBar();" in study,
        "unified workspace must render detail content and execution actions in one surface")
for token in ["老师要求", "教材 / 页码", "Button('问小伴'", "TutorPane"]:
    require(token not in study, f"unified workspace must not show removed student UI: {token}")
require("this.assignment()!.instruction.length > 0" in study,
        "teacher instruction must remain visible on the unified page")
require("this.assignment()!.resourceLabels.length > 0" in study and "老师附件" in study,
        "teacher attachments may remain when actual resources exist")
require("AssignmentCountdownCard" in study and
        "this.assignment()!.status === AssignmentStatus.IN_PROGRESS" in study and
        "this.assignment()!.status === AssignmentStatus.PAUSED" in study,
        "countdown must appear in the same page after START/RESUME")
require("STUDENT_STUDY" not in routes and "AppRoute.STUDENT_STUDY" not in shell and
        "StudyWorkspaceRoutePage" not in shell,
        "separate Student Study navigation destination must be retired")
require("HomeworkStore.instance" not in detail and "HomeworkStore.instance" not in study,
        "unified detail/workspace must stay behind repository/application boundaries")

if errors:
    print("V2_ASSIGNMENT_DETAIL_CONTENT_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_ASSIGNMENT_DETAIL_CONTENT_PASS")
