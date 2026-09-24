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
    "CARD_SURFACE",
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
    "PARENT_DEEP_READABLE_MAX_WIDTH",
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

centered_badge = read_optional("entry/src/main/ets/components/family/CenteredTextBadge.ets")
require("export struct CenteredTextBadge" in centered_badge and
        "Stack() {" in centered_badge and ".alignContent(Alignment.Center)" in centered_badge,
        "shared text badges must use real container centering instead of top padding")
for safe_prop in ["badgeText", "badgeWidth", "badgeHeight", "badgeFontSize", "badgeRadius",
                  "badgeBold", "badgeForeground", "badgeBackground"]:
    require(f"@Prop {safe_prop}:" in centered_badge,
            f"CenteredTextBadge missing ArkUI-safe prop name: {safe_prop}")
for badge_path in [
    "entry/src/main/ets/pages/PersonEntryPage.ets",
    "entry/src/main/ets/pages/AppShell.ets",
    "entry/src/main/ets/components/family/StudentSwitcherDialog.ets",
    "entry/src/main/ets/components/family/IdentitySwitcherDialog.ets",
    "entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets",
    "entry/src/main/ets/features/student/profile/StudentProfilePage.ets",
    "entry/src/main/ets/features/student/home/StudentHomePage.ets",
]:
    badge_user = read_optional(badge_path)
    require("CenteredTextBadge" in badge_user,
            f"text/avatar badges must reuse centered badge component: {badge_path}")

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

        # ArkUI custom components inherit CommonAttribute.enabled(value). A custom @Prop named
        # enabled collides with that method and fails CompileArkTS even though Python gates pass.
        for forbidden_prop in ["enabled", "width", "height", "background"]:
            require(f"@Prop {forbidden_prop}:" not in text,
                    f"custom component prop must not shadow ArkUI CommonAttribute.{forbidden_prop}: {relative}")

# Ordinary cards use one shared white surface. Persistent selection is expressed by border/control state,
# not by changing the entire card fill.
assignment_list_item = read_optional("entry/src/main/ets/components/assignment/AssignmentListItem.ets")
if assignment_list_item:
    require("accessibilityRole(AccessibilityRoleType.BUTTON)" in assignment_list_item,
            "AssignmentListItem must expose button accessibility semantics while it exists")
    require("backgroundColor(AppTheme.CARD_SURFACE)" in assignment_list_item,
            "AssignmentListItem must keep the shared card surface regardless of selection")
    require("width: this.selected ? 1 : 0" in assignment_list_item and
            "color: this.selected ? AppTheme.PRIMARY : Color.Transparent" in assignment_list_item,
            "AssignmentListItem selected state must add a primary border as a second visual cue")
    require("@Prop selectionMode: boolean = false;" in assignment_list_item and
            "private LeadingIndicator()" in assignment_list_item and
            "if (this.selectionMode)" in assignment_list_item,
            "AssignmentListItem must support an in-card selection control without expanding row width")
    require("TextOverflow.Ellipsis" in assignment_list_item and
            "this.assignment.subject} · ${this.deadlineText()} · ${this.timingText()}" in assignment_list_item,
            "AssignmentListItem compact metadata must truncate instead of overlapping neighboring content")
    require("Row({ space: 8 })" in assignment_list_item and
            ".lineHeight(22)" in assignment_list_item and
            ".lineHeight(18)" in assignment_list_item and
            ".constraintSize({ minHeight: 78 })" in assignment_list_item,
            "AssignmentListItem must reserve stable vertical space for title/status and metadata rows")

# Persistent selectors whose visual state changes at runtime must use reactive child-component props,
# not ordinary @Builder boolean snapshots. Keep both the binding mechanism and visible feedback guarded.
selection_controls = read_optional("entry/src/main/ets/components/selection/SelectionControls.ets")
require(len(selection_controls) > 0, "missing shared reactive selection controls")
if selection_controls:
    require("export struct SegmentedSelectionButton" in selection_controls and
            "export struct StatusSelectionChip" in selection_controls and
            "export struct FilterSummaryEntry" in selection_controls and
            "export struct ChoiceSelectionChip" in selection_controls,
            "shared reactive selection controls are incomplete")
    require(selection_controls.count("@Prop selected: boolean = false;") >= 3,
            "persistent selection controls must receive selected as reactive @Prop")
    require("@Prop active: boolean = false;" in selection_controls,
            "filter summary active state must be a reactive @Prop")
    require("backgroundColor(this.selected ? AppTheme.PRIMARY_SOFT" in selection_controls,
            "reactive selection controls must expose a visible selected surface")
    require("border({ width: 1, color: this.selected ? AppTheme.PRIMARY : AppTheme.BORDER })" in selection_controls,
            "status selection must combine selected surface and border")

parent_dashboard = read_optional("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
identity_switcher = read_optional("entry/src/main/ets/components/family/IdentitySwitcherDialog.ets")
student_switcher = read_optional("entry/src/main/ets/components/family/StudentSwitcherDialog.ets")
app_shell = read_optional("entry/src/main/ets/pages/AppShell.ets")
student_home = read_optional("entry/src/main/ets/features/student/home/StudentHomePage.ets")
voice_assignment = read_optional("entry/src/main/ets/features/parent/voice/ParentVoiceAssignmentPage.ets")
parent_extra_assignment = read_optional("entry/src/main/ets/features/parent/extra/ParentExtraAssignmentPage.ets")
parent_review_page = read_optional("entry/src/main/ets/features/parent/review/ParentReviewPage.ets")
homework_import_route = read_optional("entry/src/main/ets/features/parent/import/HomeworkImportRoutePage.ets")
homework_import = read_optional("entry/src/main/ets/features/parent/import/HomeworkImportPage.ets")
homework_confirmation = read_optional("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
parent_settings = read_optional("entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets")
for card_path, card_source in [
    ("ParentDashboardPage", parent_dashboard),
    ("IdentitySwitcherDialog", identity_switcher),
    ("StudentSwitcherDialog", student_switcher),
    ("AppShell", app_shell),
    ("StudentHomePage", student_home),
    ("ParentVoiceAssignmentPage", voice_assignment),
    ("HomeworkImportPage", homework_import),
]:
    require("AppTheme.CARD_SURFACE" in card_source,
            f"{card_path} must use the shared ordinary card surface")
require("backgroundColor(AppTheme.PRIMARY_FAINT)" not in parent_dashboard,
        "Parent dashboard action cards must not use a different fill for 布置作业")
require("backgroundColor(this.parentActive ? AppTheme.PRIMARY_FAINT" not in identity_switcher and
        "AppTheme.PRIMARY_FAINT : AppTheme.SURFACE" not in identity_switcher,
        "Identity switcher cards must keep one surface and use border/checkmark for selection")
require("backgroundColor(this.activeStudentId === student.id ? AppTheme.PRIMARY_FAINT" not in student_switcher,
        "Student switcher cards must keep one surface and use border/checkmark for selection")
require(".backgroundColor(AppTheme.CARD_SURFACE)" in app_shell and
        ".backgroundColor(AppTheme.PRIMARY_FAINT)" not in app_shell,
        "AppShell identity switch card must use the shared ordinary card surface")
require("private PendingReview()" in homework_import and
        ".backgroundColor(AppTheme.CARD_SURFACE)" in homework_import and
        "backgroundColor(AppTheme.PRIMARY_FAINT)" not in between(homework_import, "private PendingReview()", "private RecognitionActions()"),
        "Homework import pending-review card must use the shared ordinary card surface")

for deep_page_name, deep_page_source in [
    ("ParentExtraAssignmentPage", parent_extra_assignment),
    ("ParentVoiceAssignmentPage", voice_assignment),
    ("ParentReviewPage", parent_review_page),
    ("HomeworkImportRoutePage", homework_import_route),
    ("HomeworkConfirmationPage", homework_confirmation),
]:
    require("AppTheme.PARENT_DEEP_READABLE_MAX_WIDTH" in deep_page_source,
            f"{deep_page_name} must use the shared parent deep-page readable width")

require("left: this.embeddedInDeepPage ? 0 : AppTheme.PHONE_PAGE_PADDING" in homework_import and
        "right: this.embeddedInDeepPage ? 0 : AppTheme.PHONE_PAGE_PADDING" in homework_import,
        "embedded HomeworkImportPage must not add a second horizontal page padding")
require("AppTheme.PHONE_PAGE_PADDING" not in homework_confirmation and
        "left: AppTheme.PAGE_PADDING" in homework_confirmation and
        "right: AppTheme.PAGE_PADDING" in homework_confirmation,
        "Homework confirmation must align to the shared parent deep-page horizontal padding")

for collapsed_state in [
    "@State private familyExpanded: boolean = false;",
    "@State private parentAccessExpanded: boolean = false;",
    "@State private tutorRulesExpanded: boolean = false;",
    "@State private dataSyncExpanded: boolean = false;",
]:
    require(collapsed_state in parent_settings,
            f"Parent My sections must default to collapsed: {collapsed_state}")
for toggle_expression in [
    "this.familyExpanded = !this.familyExpanded",
    "this.parentAccessExpanded = !this.parentAccessExpanded",
    "this.tutorRulesExpanded = !this.tutorRulesExpanded",
    "this.dataSyncExpanded = !this.dataSyncExpanded",
]:
    require(toggle_expression in parent_settings,
            f"Parent My section must be expandable by its header: {toggle_expression}")
require("cloudPanelOpen" not in parent_settings,
        "Parent My data/sync must not keep a second nested collapse state")
require("AppTheme.PROFILE_READABLE_MAX_WIDTH" in parent_settings,
        "Parent and student My pages must share the same readable width")
require("private SectionTitle(" not in parent_settings and
        "private FamilySettingsSection()" in parent_settings and
        "private DataSyncSettingsSection()" in parent_settings,
        "Parent My must use the same card-and-collapsible-section composition as Student My")

student_assignments = read_optional("entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets")
require("private ViewModeButton(" not in student_assignments and "private FilterEntry(" not in student_assignments,
        "Student Assignments must not keep runtime selection in ordinary @Builder boolean parameters")
require("SegmentedSelectionButton" in student_assignments and "private QuickFilterBar()" in student_assignments,
        "Student Assignments must use shared reactive quick-filter controls")
for expression in [
    "selected: !this.allDates && this.isSelectedDayToday()",
    "selected: this.allDates",
    "selected: this.subjectCode === 'ALL'",
    "selected: this.subjectCode === 'CHINESE'",
    "selected: this.subjectCode === 'MATH'",
    "selected: this.subjectCode === 'ENGLISH'",
]:
    require(expression in student_assignments,
            f"Student Assignments must bind quick-filter selection directly to page state: {expression}")
require("calendarMode" not in student_assignments and "AssignmentCalendarPanel" not in student_assignments,
        "Student Assignments must stay list-only after calendar retirement")

filter_dialog = read_optional("entry/src/main/ets/components/assignment/AssignmentFilterDialog.ets")
for state_expr, label in [
    ("this.allDates === allDates ? AppTheme.PRIMARY_SOFT", "assignment date mode"),
    ("DatePicker({", "assignment date"),
    ("this.subjectCode === value ? AppTheme.PRIMARY_SOFT", "assignment subject"),
]:
    require(state_expr in filter_dialog,
            f"shared filter dialog {label} selection must have an active surface")

parent_progress = read_optional("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")
require("private FilterChip(" not in parent_progress and "private FilterEntry(" not in parent_progress,
        "Parent Progress must not keep runtime selection in ordinary @Builder boolean parameters")
require("FilterSummaryEntry" in parent_progress,
        "Parent Progress must reuse shared reactive filter summary controls")
require("StatusSelectionChip" not in parent_progress and "AssignmentMetricSummary" not in parent_progress and
        "AssignmentMetricKey" not in parent_progress,
        "Parent Progress must stay list-first without summary metric selection")
for expression in [
    "active: !this.allDates && !this.isSelectedDayToday()",
    "active: this.subjectCode !== 'ALL'",
]:
    require(expression in parent_progress,
            f"Parent Progress must bind selection directly to page state: {expression}")
require("Text('作业进度')" not in parent_progress and
        "Text(this.bulkMode ? '取消' : '删除')" in parent_progress,
        "Parent Progress must avoid duplicate root title and keep delete/cancel action explicit")

deadline_picker = read_optional("entry/src/main/ets/components/assignment/DeadlinePickerField.ets")
require("DatePicker({" in deadline_picker and "TimePicker({" in deadline_picker,
        "shared deadline input must use native ArkUI date and time pickers")
require("AssignmentDueDate.resolveDueAtEpochMs" in deadline_picker,
        "shared deadline picker must understand existing AI/free-text due values before editing")

extra_assignment = read_optional("entry/src/main/ets/features/parent/extra/ParentExtraAssignmentPage.ets")
category_option = between(extra_assignment, "private CategoryOption(", "private CategorySection()")
require("backgroundColor(this.category === value ? AppTheme.PRIMARY_SOFT : AppTheme.SURFACE_SUBTLE)" in category_option,
        "Extra assignment category selection must have an active surface")
require("DeadlinePickerField" in extra_assignment and "placeholder: 'YYYY-MM-DD'" not in extra_assignment,
        "Extra assignment deadline must use the shared native picker instead of a manual date field")

confirmation = read_optional("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
confirmation_components = read_optional(
    "entry/src/main/ets/features/parent/confirmation/ConfirmationCandidateComponents.ets")
assignment_edit_form = read_optional(
    "entry/src/main/ets/components/assignment/AssignmentEditForm.ets")
require("private SubjectChip(" not in confirmation and "private TimeChip(" not in confirmation and
        "private CandidateCard(" not in confirmation and "private CandidateEditor(" not in confirmation,
        "Confirmation persistent selection must not depend on ordinary @Builder object snapshots")
require("ConfirmationCandidateCard" in confirmation and "ConfirmationCandidateEditor" in confirmation,
        "Confirmation page must render reactive Candidate child components")
require("AssignmentEditForm" in confirmation_components and
        "DeadlinePickerField" in assignment_edit_form and
        "TextInput({ text: this.item.dueText })" not in confirmation_components,
        "Confirmation deadline edit must reuse the shared assignment form and native deadline picker")
require("this.showEditorSheet && this.editingCandidateId === item.id" in confirmation,
        "Confirmation selected Candidate must reflect both the active editor id and bottom-sheet visibility")
require(".bindSheet($$this.showEditorSheet" in confirmation and
        ".bindSheet($this.showEditorSheet" not in confirmation and
        "private CandidateEditorSheet()" in confirmation,
        "Confirmation editing must use a reactive bottom sheet")
require(confirmation_components.count("@Prop item: CandidateAssignment;") >= 2 and
        "@Prop selected: boolean = false;" in confirmation_components,
        "Confirmation Candidate components must receive current item/selection through reactive props")
require("backgroundColor(AppTheme.CARD_SURFACE)" in confirmation_components and
        "color: this.selected ? AppTheme.PRIMARY : Color.Transparent" in confirmation_components,
        "Confirmation Candidate must keep the shared card surface and express selection with border")
for expression in [
    "selected: this.subject === Subject.CHINESE",
    "selected: this.subject === Subject.MATH",
    "selected: this.subject === Subject.ENGLISH",
]:
    require(expression in assignment_edit_form,
            f"Shared assignment editor subject state must bind directly to current prop: {expression}")
for expression in [
    "selected: this.item.expectedMinutes === 10",
    "selected: this.item.expectedMinutes === 15",
    "selected: this.item.expectedMinutes === 20",
    "selected: this.item.expectedMinutes === 30",
    "selected: this.item.expectedMinutes === 45",
]:
    require(expression in confirmation_components,
            f"Confirmation duration state must bind directly to current Candidate prop: {expression}")
require("backgroundColor(this.selected ? AppTheme.PRIMARY_SOFT" in selection_controls and
        "color: this.selected ? AppTheme.PRIMARY : Color.Transparent" in selection_controls,
        "shared choice selection must combine active surface and border")

calendar_path = ROOT / "entry/src/main/ets/features/student/assignments/AssignmentCalendarPanel.ets"
require(not calendar_path.exists(),
        "retired Assignment calendar UI must stay deleted")

# Settings use the same reactive child-component rule as navigation and status selectors. The native
# Toggle still owns the visual switch feedback, while isEnabled avoids ArkUI CommonAttribute.enabled.
settings = read_optional("entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets")
student_profile = read_optional("entry/src/main/ets/features/student/profile/StudentProfilePage.ets")
require("private TutorRule(" not in settings,
        "Parent settings must not pass Tutor switch state through an ordinary @Builder boolean")
require("SettingsToggleRow" in settings and "export struct SettingsToggleRow" in selection_controls,
        "Parent settings must use the shared reactive switch row")
require("@Prop isEnabled: boolean = false;" in selection_controls and
        "Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })" in selection_controls,
        "shared settings switch must bind native Toggle isOn to reactive @Prop isEnabled")
for expression in [
    "isEnabled: this.tutorGuidanceFirst()",
    "isEnabled: this.directAnswerAllowed()",
    "onToggle: (enabled: boolean) => this.updateTutorSettings(enabled, this.directAnswerAllowed())",
    "onToggle: (enabled: boolean) => this.updateTutorSettings(this.tutorGuidanceFirst(), enabled)",
]:
    require(expression in settings, f"Parent settings must bind Tutor rule directly to current state: {expression}")
require("private RuleRow(" not in student_profile and "ReadonlySettingStateRow" in student_profile,
        "Student profile Tutor rule display must use the reactive shared read-only state row")
for expression in [
    "isEnabled: this.settings().tutorGuidanceFirst",
    "isEnabled: this.settings().directAnswerAllowed",
]:
    require(expression in student_profile,
            f"Student profile must bind displayed Tutor rule directly to current settings: {expression}")

if errors:
    print("HARMONY_UI_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("HARMONY_UI_GATE_PASS")
