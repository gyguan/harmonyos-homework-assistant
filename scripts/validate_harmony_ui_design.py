#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def read_optional(path: str) -> str:
    file = ROOT / path
    return file.read_text(encoding="utf-8") if file.exists() else ""


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def between(text: str, start: str, end: str) -> str:
    if start not in text:
        return ""
    tail = text.split(start, 1)[1]
    return tail.split(end, 1)[0] if end in tail else tail


theme_path = "entry/src/main/ets/common/theme/AppTheme.ets"
theme = read_optional(theme_path)
require(len(theme) > 0, f"missing required file: {theme_path}")

# Keep only durable design-system contracts here. Page-specific composition belongs to the
# V2 UI spec and DevEco acceptance, not to string assertions against V1 builders.
for token in [
    "SURFACE_SUBTLE",
    "SURFACE_EMPHASIS",
    "PRIMARY_SOFT",
    "PRIMARY_FAINT",
    "DIVIDER",
    "PAGE_PADDING",
    "SECTION_GAP",
    "CARD_RADIUS",
    "CONTROL_RADIUS",
    "MIN_TOUCH_TARGET",
    "BUTTON_HEIGHT",
    "PAGE_TITLE_SIZE",
    "SECTION_TITLE_SIZE",
]:
    require(f"static readonly {token}" in theme, f"AppTheme missing durable design token: {token}")

app_shell = read_optional("entry/src/main/ets/pages/AppShell.ets")
primary_nav = read_optional("entry/src/main/ets/components/navigation/PrimaryNavItem.ets")
if app_shell:
    require("Text(active ? '●' : '○')" not in app_shell,
            "navigation must not regress to text-dot icons")

    # Route content and primary-nav visuals must subscribe to the same route state. Do not pass the
    # selected flag through ordinary @Builder value parameters: the page may switch while the visual
    # node keeps its old value. A child @Component with @Prop selected gives ArkUI an explicit state
    # dependency and keeps Phone and wide navigation consistent.
    require("private BottomItem(" not in app_shell and "private SideItem(" not in app_shell,
            "primary navigation selection must not use ordinary @Builder boolean parameters")
    require("BottomPrimaryNavItem" in app_shell and "SidePrimaryNavItem" in app_shell,
            "AppShell must use reactive primary navigation components")
    for expression in [
        "selected: this.studentRoute === StudentRoute.HOME",
        "selected: this.studentRoute === StudentRoute.ASSIGNMENTS",
        "selected: this.studentRoute === StudentRoute.PROFILE",
        "selected: this.parentRoute === ParentRoute.DASHBOARD",
        "selected: this.parentRoute === ParentRoute.PROGRESS",
        "selected: this.parentRoute === ParentRoute.SETTINGS",
    ]:
        require(expression in app_shell,
                f"primary navigation must bind selection directly to route state: {expression}")

require(len(primary_nav) > 0, "missing reactive primary navigation component")
if primary_nav:
    require(primary_nav.count("@Prop selected: boolean = false;") >= 2,
            "Phone and side primary navigation items must receive selected as reactive @Prop")
    require("backgroundColor(this.selected ? AppTheme.PRIMARY_SOFT : Color.Transparent)" in primary_nav,
            "primary navigation must expose a visible selected surface")
    require("fontColor([this.selected ? AppTheme.PRIMARY : AppTheme.TERTIARY_TEXT])" in primary_nav and
            "fontColor(this.selected ? AppTheme.PRIMARY : AppTheme.SUBTEXT)" in primary_nav,
            "primary navigation must keep selected icon/text foreground feedback")
    require("accessibilityText(this.selected ? `${this.label}，当前页面` : this.label)" in primary_nav,
            "primary navigation must expose current-page state to accessibility")

legacy_visual_literals = [
    "#F7F8FA",
    "#F4F6F9",
    "#F1F3F5",
    "#EEF9F3",
    "#FFF8E7",
    "#C9D1DD",
    "#6D8DFF",
]

ui_roots = [
    ROOT / "entry/src/main/ets/pages",
    ROOT / "entry/src/main/ets/features",
    ROOT / "entry/src/main/ets/components",
]
for ui_root in ui_roots:
    if not ui_root.exists():
        continue
    for file in ui_root.rglob("*.ets"):
        text = file.read_text(encoding="utf-8")
        relative = file.relative_to(ROOT).as_posix()
        for literal in legacy_visual_literals:
            require(literal not in text, f"legacy hardcoded visual color {literal} remains in {relative}")

        # Production UI must not introduce Preview/CI/device-only branches to make a layout pass.
        prohibited_branch = re.compile(r"\b(?:isPreview|isCI|deviceModel|deviceType)\b")
        require(prohibited_branch.search(text) is None,
                f"UI must not contain Preview/CI/device-specific production branching: {relative}")

# Shared master-detail rows are persistent selections on wide layouts. A faint fill alone is too easy
# to miss, so selected rows must combine a selected surface with a primary border.
assignment_list_item = read_optional("entry/src/main/ets/components/assignment/AssignmentListItem.ets")
if assignment_list_item:
    require("accessibilityRole(AccessibilityRoleType.BUTTON)" in assignment_list_item,
            "AssignmentListItem must expose button accessibility semantics while it exists")
    require("backgroundColor(this.selected ? AppTheme.PRIMARY_FAINT : AppTheme.SURFACE)" in assignment_list_item,
            "AssignmentListItem selected state must keep a selected surface")
    require("width: this.selected ? 1 : 0" in assignment_list_item and
            "color: this.selected ? AppTheme.PRIMARY : Color.Transparent" in assignment_list_item,
            "AssignmentListItem selected state must add a primary border as a second visual cue")

# Audit representative persistent selectors across the current V2 surfaces. The invariant is not that
# every control must look identical; it is that a persistent selection uses more than text/icon color.
student_assignments = read_optional("entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets")
view_mode = between(student_assignments, "private ViewModeButton(", "private ViewModeToggle()")
require("backgroundColor(active ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)" in view_mode,
        "Student Assignment list/calendar selector must have an active surface")

filter_dialog = read_optional("entry/src/main/ets/components/assignment/AssignmentFilterDialog.ets")
for state_expr, label in [
    ("this.typeFilter === value ? AppTheme.PRIMARY_SOFT", "assignment type"),
    ("this.dateFilter === value ? AppTheme.PRIMARY_SOFT", "assignment due date"),
    ("this.subjectCode === value ? AppTheme.PRIMARY_SOFT", "assignment subject"),
]:
    require(state_expr in filter_dialog,
            f"shared filter dialog {label} selection must have an active surface")

parent_progress = read_optional("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")
status_chip = between(parent_progress, "private FilterChip(", "private StatusFilterBar()")
require("backgroundColor(active ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE)" in status_chip and
        "border({ width: 1, color: active ? AppTheme.PRIMARY : AppTheme.BORDER })" in status_chip,
        "Parent Progress status selector must combine active surface and border")

extra_assignment = read_optional("entry/src/main/ets/features/parent/extra/ParentExtraAssignmentPage.ets")
category_option = between(extra_assignment, "private CategoryOption(", "private CategorySection()")
require("backgroundColor(this.category === value ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)" in category_option,
        "Extra assignment category selection must have an active surface")

confirmation = read_optional("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
subject_chip = between(confirmation, "private SubjectChip(", "private TimeChip(")
time_chip = between(confirmation, "private TimeChip(", "private CandidateCard(")
candidate_card = between(confirmation, "private CandidateCard(", "private CandidateEditor(")
require("backgroundColor(item.subject === subject ? AppTheme.PRIMARY_SOFT" in subject_chip,
        "Confirmation subject selection must have an active surface")
require("backgroundColor(item.expectedMinutes === minutes ? AppTheme.PRIMARY_SOFT" in time_chip,
        "Confirmation duration selection must have an active surface")
require("backgroundColor(this.editingCandidateId === item.id ? AppTheme.PRIMARY_FAINT" in candidate_card and
        "color: this.editingCandidateId === item.id ? AppTheme.PRIMARY : Color.Transparent" in candidate_card,
        "Confirmation selected candidate must combine active surface and border")

calendar = read_optional("entry/src/main/ets/features/student/assignments/AssignmentCalendarPanel.ets")
day_cell = between(calendar, "private DayCell(", "private WeekdayHeader()")
require("backgroundColor(this.isSelected(dayEpochMs) ? AppTheme.PRIMARY" in day_cell and
        "this.isSelected(dayEpochMs) ? AppTheme.TEXT_ON_PRIMARY" in day_cell,
        "Calendar selected day must use a filled selected state with contrasting text")

settings = read_optional("entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets")
require("Toggle({ type: ToggleType.Switch, isOn: enabled })" in settings,
        "Parent settings boolean rules must keep native switch state feedback")

if errors:
    print("HARMONY_UI_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("HARMONY_UI_GATE_PASS")
