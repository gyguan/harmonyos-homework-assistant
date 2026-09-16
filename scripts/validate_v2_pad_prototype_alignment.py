#!/usr/bin/env python3
from pathlib import Path

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


theme = read("entry/src/main/ets/common/theme/AppTheme.ets")
policy = read("entry/src/main/ets/common/responsive/LayoutPolicy.ets")
home = read("entry/src/main/ets/features/student/home/StudentHomePage.ets")
assignments = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets")
detail_pane = read("entry/src/main/ets/features/student/assignments/AssignmentDetailPane.ets")
detail_page = read("entry/src/main/ets/features/student/assignments/StudentAssignmentDetailPage.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
prototype = read("docs/product/ui-page-spec-v2.md")
alignment_spec = read("docs/product/v2-pad-prototype-alignment.md")

for token in [
    "HOME_PAD_CONTENT_MAX_WIDTH",
    "ASSIGNMENT_MASTER_DETAIL_MAX_WIDTH",
    "STUDY_SPLIT_MAX_WIDTH",
    "HOME_PRIMARY_MIN_WIDTH",
    "HOME_SECONDARY_MIN_WIDTH",
    "SPLIT_PRIMARY_MIN_WIDTH",
    "SPLIT_SECONDARY_MIN_WIDTH",
    "STUDY_PRIMARY_MIN_WIDTH",
    "STUDY_TUTOR_MIN_WIDTH",
]:
    require(token in theme, f"missing Pad composition token: {token}")

for token in [
    "homeFocusSummaryRequirement",
    "assignmentMasterDetailRequirement",
    "studyTutorRequirement",
    "canSplit",
]:
    require(token in policy, f"LayoutPolicy missing Pad prototype capability: {token}")

# Home: wide composition must be materially different from Phone single column.
for token in [
    "@State private availableWidthVp",
    "LayoutPolicy.homeFocusSummaryRequirement()",
    "private PhoneHome()",
    "private PadHome()",
    "AppTheme.HOME_PRIMARY_MIN_WIDTH",
    "AppTheme.HOME_SECONDARY_MIN_WIDTH",
    "this.AttentionBanner();",
    "this.RemainingAssignments();",
    ".onAreaChange",
]:
    require(token in home, f"Student Home missing Pad prototype behavior: {token}")
require("WindowSizeClass" not in home and "sizeClass" not in home,
        "Student Home must use container capability, not size-class branching")

# Assignment: Phone navigation and Pad master-detail share one detail pane.
for token in [
    "@State private selectedAssignmentId",
    "LayoutPolicy.assignmentMasterDetailRequirement()",
    "private AssignmentMasterDetail()",
    "AssignmentDetailPane",
    "selected: this.isSelected(item.id)",
    "showChevron: !this.canUseMasterDetail()",
    "onOpenStudy: (assignmentId: string)",
    ".onAreaChange",
]:
    require(token in assignments, f"Assignment master-detail missing behavior: {token}")
require("selectedAssignmentId" not in shell,
        "Pad assignment selection must stay inside Assignment Feature, not AppShell")
require("AssignmentDetailPane" in detail_page and "DeepPageHeader" in detail_page,
        "Phone detail page must reuse AssignmentDetailPane under standard deep-page chrome")
require("DefaultAssignmentRepository.instance" in detail_pane,
        "AssignmentDetailPane must use the same Assignment repository/cache as Phone detail")
require("onOpenStudy: (assignmentId: string) => this.openStudy(assignmentId)" in shell,
        "AppShell must wire the embedded Pad detail primary action to the existing Study destination")

# Study: Phone stays single-column; Pad shows Study + Tutor simultaneously.
for token in [
    "@State private availableWidthVp",
    "LayoutPolicy.studyTutorRequirement()",
    "private SingleColumnWorkspace()",
    "private SplitWorkspace()",
    "private PhoneWorkspacePage()",
    "private PadWorkspacePage()",
    "this.StudyContent(false);",
    "this.TutorPane();",
    "AppTheme.STUDY_PRIMARY_MIN_WIDTH",
    "AppTheme.STUDY_TUTOR_MIN_WIDTH",
    ".onAreaChange",
]:
    require(token in study, f"Study/Tutor Pad composition missing behavior: {token}")
require("WindowSizeClass" not in study and "@Prop sizeClass" not in study and "this.sizeClass" not in study,
        "Study Workspace must not regress to size-class/device branching")
require("Button('问小伴'" in study,
        "Phone Study flow must retain the standalone Tutor entry")

require("Pad 不是放大的 Phone" in prototype,
        "V2 UI prototype must retain the Pad-not-enlarged-Phone principle")
for token in ["Student Home", "Assignment List + Detail", "Study Workspace + Tutor", "LayoutPolicy"]:
    require(token in alignment_spec, f"Pad prototype alignment spec missing: {token}")

if errors:
    print("V2_PAD_PROTOTYPE_ALIGNMENT_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("V2_PAD_PROTOTYPE_ALIGNMENT_PASS")
