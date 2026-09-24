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


due = read("entry/src/main/ets/domain/service/AssignmentDueDate.ets")
list_item = read("entry/src/main/ets/components/assignment/AssignmentListItem.ets")
metrics = read("entry/src/main/ets/components/assignment/AssignmentMetricSummary.ets")
home = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
progress = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")
student = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets")
query_dialog = read("entry/src/main/ets/components/assignment/AssignmentFilterDialog.ets")
deadline_dialog = read("entry/src/main/ets/components/assignment/DeadlinePickerField.ets")
student_switcher = read("entry/src/main/ets/components/family/StudentSwitcherDialog.ets")
photo_preview = read("entry/src/main/ets/components/submission/PhotoPreviewDialog.ets")
confirmation = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
confirmation_components = read(
    "entry/src/main/ets/features/parent/confirmation/ConfirmationCandidateComponents.ets")
parent_edit = read("entry/src/main/ets/features/parent/review/ParentAssignmentEditPanel.ets")
sheet_header = read("entry/src/main/ets/components/navigation/EditSheetHeader.ets")

# 1. Assignment list deadlines use one concrete date/time format.
require("static displayText(item: Assignment): string" in due and
        "return `${year}-${month}-${day} ${hour}:${minute}`" in due,
        "deadline display helper must use concrete YYYY-MM-DD HH:mm format")
require("AssignmentDueDate.displayText(this.assignment)" in list_item and
        "this.deadlineText()" in list_item,
        "assignment list item must use the shared concrete deadline formatter even inside compact metadata")
require("Text(this.assignment.dueText)" not in list_item,
        "assignment list item must not show raw relative due text")

# 2. Parent Home and Progress stay compact: navigation already names the surface.
require("AssignmentMetricSummary({" not in home and "今天的学习" not in home and "需要我处理" not in home,
        "parent home must stay action-only without progress metrics or attention sections")
for phrase in ["布置作业", "语音作业", "作业收件箱"]:
    require(phrase in home, f"parent home missing required primary action: {phrase}")
require("Text('家长操作')" not in home and "private PageIntro()" not in home,
        "parent home must not repeat a page title already expressed by primary navigation")
require("AssignmentMetricSummary" not in progress and "StatusSummary" not in progress and
        "AssignmentMetricKey" not in progress,
        "parent progress must not restore summary metric cards or metric-driven status filtering")
require("@State private scopedAssignments: Assignment[] = []" in progress and
        "this.applyItems(this.scopedAssignments)" in progress,
        "parent progress list must render directly from the active date/subject scope")
require("Text('作业进度')" not in progress and
        "label: this.bulkMode ? '取消' : '删除'" in progress and "TextAction({" in progress,
        "parent progress must remove its duplicate page title and expose shared delete/cancel in one stable location")
require("可以调整日期或科目。" in progress,
        "parent progress empty state must match the remaining filter dimensions")

# 3/4. Parent and student share one date+subject query model, while each surface may
# expose the common choices differently.
require("label: '日期'" in progress and "label: '科目'" in progress and
        "active: !this.allDates && !this.isSelectedDayToday()" in progress and
        "active: this.subjectCode !== 'ALL'" in progress,
        "parent progress must keep reactive date and subject query entries")
require("Text('日期')" in student and "Text('科目')" in student and
        "private QuickFilterBar()" in student and
        "selected: !this.allDates && this.isSelectedDayToday()" in student and
        "selected: this.allDates" in student and
        "selected: this.subjectCode === 'CHINESE'" in student and
        "selected: this.subjectCode === 'MATH'" in student and
        "selected: this.subjectCode === 'ENGLISH'" in student,
        "student assignments must expose common date and subject filters directly")
for page, name in [(progress, "parent progress"), (student, "student assignments")]:
    require("label: '类型'" not in page and "label: '截止'" not in page,
            f"{name} must not expose old type/due preset query entries")
    require("allDates: $draftAllDates" in page and "AssignmentDateFilter.ALL" in page,
            f"{name} must support a real all-date query instead of UI-only selection")
require("calendarMode" not in student and "AssignmentCalendarPanel" not in student,
        "student assignments must remain list-only after calendar retirement")
require("@Link allDates: boolean" in query_dialog and
        "DateModeOption('全部日期', true)" in query_dialog and
        "DateModeOption('指定日期', false)" in query_dialog and
        "@Link selectedDayEpochMs: number" in query_dialog and "DatePicker({" in query_dialog and
        "@Link subjectCode: string" in query_dialog,
        "shared task query dialog must support all dates or one selected date plus subject")
for removed in ["private TypeOption", "private DateOption", "今天", "明天", "本周"]:
    require(removed not in query_dialog, f"shared task query retains removed preset: {removed}")

# 5. Popup/sheet action convention: right-top only exit actions; primary/destructive actions at bottom.
require(query_dialog.index("label: '关闭'") < query_dialog.index("DatePicker({") <
        query_dialog.index("label: '查询'"),
        "task query dialog must keep shared close top-right and query action at bottom")
require(deadline_dialog.index("label: '关闭'") < deadline_dialog.index("DatePicker({") <
        deadline_dialog.index("label: '确定'"),
        "deadline dialog must keep shared close top-right and confirm action at bottom")
require("TextAction({" in student_switcher and "label: '关闭'" in student_switcher,
        "student switcher must keep a shared top-right close action")
require("TextAction({" in photo_preview and "label: '关闭'" in photo_preview,
        "photo preview must keep a shared top-right close action")
parent_actions = parent_edit.split("private BottomActions()", 1)[1].split("build()", 1)[0]
require("EditSheetHeader({" in parent_edit and "TextAction({" in sheet_header and "label: '关闭'" in sheet_header and
        "ActionButton({" in parent_actions and "label: this.saving ? '保存中…' : '保存修改'" in parent_actions,
        "parent edit sheet must reuse the shared close-only header and fixed shared save area")
require("EditSheetHeader({" in confirmation_components and "TextAction({" in sheet_header and
        "label: '关闭'" in sheet_header and "confirmDiscard" in confirmation_components,
        "candidate edit sheet must reuse the shared close-only header and protect dirty edits")
candidate_actions = confirmation_components.split("private BottomActions()", 1)[1].split("build()", 1)[0]
require("ActionButton({" in candidate_actions and "label: '删除'" in candidate_actions and
        "label: '保存'" in candidate_actions,
        "candidate editor business actions must stay in its bottom action area through shared actions")

if errors:
    print("TASK_UI_CONSISTENCY_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("TASK_UI_CONSISTENCY_GATE_PASS")
