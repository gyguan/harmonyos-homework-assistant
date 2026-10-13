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
    "CONTENT_WIDE_MAX_WIDTH",
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

# Home: Phone and Pad intentionally share one readable single-column task stream.
# Pad-specific density comes from shared width/padding tokens, not a forced two-pane split.
for token in [
    "@State private availableWidthVp",
    "private HomeContent()",
    "AppTheme.CONTENT_STANDARD_MAX_WIDTH",
    "LayoutPolicy.pagePaddingForWidth(this.availableWidthVp)",
    "private PendingTasks()",
    "private SubjectTaskSection(group: StudentHomeSubjectGroup)",
    "StudentPendingTaskCard",
    ".onAreaChange",
]:
    require(token in home, f"Student Home missing shared Phone/Pad single-column behavior: {token}")
for removed in ["private PhoneHome()", "private PadHome()", "先做这项", "接下来",
                "AppTheme.HOME_PRIMARY_MIN_WIDTH", "AppTheme.HOME_SECONDARY_MIN_WIDTH"]:
    require(removed not in home, f"Student Home must not keep obsolete Pad split behavior: {removed}")
require("WindowSizeClass." not in home and "@Prop sizeClass" not in home and "this.sizeClass" not in home,
        "Student Home must use container capability, not size-class branching")

# Assignment: Phone navigation and Pad master-detail share one detail pane.
for token in [
    "@State private selectedAssignmentId",
    "LayoutPolicy.assignmentMasterDetailRequirement()",
    "private AssignmentMasterDetail()",
    "AssignmentDetailPane",
    "selected: this.isSelected(item.id)",
    "showChevron: !this.canUseMasterDetail()",
    "onStoreChanged: () => void",
    ".onAreaChange",
]:
    require(token in assignments, f"Assignment master-detail missing behavior: {token}")
require("selectedAssignmentId" not in shell,
        "Pad assignment selection must stay inside Assignment Feature, not AppShell")
require("AssignmentDetailPane" in detail_page and "DeepPageHeader" in detail_page,
        "Phone detail page must reuse AssignmentDetailPane under standard deep-page chrome")
require("StudyWorkspacePage" in detail_pane and "onStoreChanged: () => void" in detail_pane,
        "AssignmentDetailPane must embed the unified workspace and publish repository changes")
require("openStudy(" not in shell and "STUDENT_STUDY" not in shell and
        "StudyWorkspaceRoutePage" not in shell,
        "AppShell must not route from Assignment Detail to a second Study page")

# Unified workspace stays inside the Phone detail page or Pad master-detail pane.
for token in [
    "private UnifiedWorkspace()",
    "this.StudyContent(false);",
    "this.WorkspaceActionBar();",
    "AssignmentCountdownCard",
    "Button('暂停一下'",
]:
    require(token in study, f"unified assignment workspace missing behavior: {token}")
require("Button('问小伴'" not in study and "TutorPane" not in study and
        "教材 / 页码" not in study,
        "unified assignment workspace must remove Tutor and textbook/page UI")

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
