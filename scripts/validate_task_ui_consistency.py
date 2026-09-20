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

# 1. Assignment list deadlines use one concrete date/time format.
require("static displayText(item: Assignment): string" in due and
        "return `${year}-${month}-${day} ${hour}:${minute}`" in due,
        "deadline display helper must use concrete YYYY-MM-DD HH:mm format")
require("AssignmentDueDate.displayText(this.assignment)" in list_item and
        "Text(this.deadlineText())" in list_item,
        "assignment list item must use the shared concrete deadline formatter")
require("Text(this.assignment.dueText)" not in list_item,
        "assignment list item must not show raw relative due text")

# 2. Parent home/progress share the exact same four metrics with different scopes.
for token in ["全部任务", "待完成", "待验收", "已完成"]:
    require(token in metrics, f"shared assignment metric component missing: {token}")
require("AssignmentMetricSummary({" in home and "this.todayAssignments().length" in home,
        "parent home metrics must use shared component scoped to today")
require("AssignmentMetricSummary({" in progress and "private allAssignments(): Assignment[]" in progress,
        "parent progress metrics must use shared component scoped to all assignments")
require("interactive: true" in progress and "onSelect: (key: AssignmentMetricKey)" in progress,
        "parent progress metrics must remain clickable status filters")
require("Text(`${this.viewModel.student().name}" not in progress,
        "parent progress title must not duplicate the global student context")

# 3/4. Parent and student use one date+subject query model; no relative-date/type presets.
for page, name in [(progress, "parent progress"), (student, "student assignments")]:
    require("label: '日期'" in page and "label: '科目'" in page,
            f"{name} must expose date and subject query entries")
    require("label: '类型'" not in page and "label: '截止'" not in page,
            f"{name} must not expose old type/due preset query entries")
    require("active: !this.isSelectedDayToday()" in page and "active: this.subjectCode !== 'ALL'" in page,
            f"{name} query state must bind to selected date and subject")
require("@Link selectedDayEpochMs: number" in query_dialog and "DatePicker({" in query_dialog and
        "@Link subjectCode: string" in query_dialog,
        "shared task query dialog must use selectable date plus subject")
for removed in ["private TypeOption", "private DateOption", "今天", "明天", "本周", "全部日期"]:
    require(removed not in query_dialog, f"shared task query retains removed preset: {removed}")

# 5. Popup/sheet action convention: right-top only exit actions; primary/destructive actions at bottom.
require(query_dialog.index("Text('关闭')") < query_dialog.index("DatePicker({") <
        query_dialog.index("Button('查询'"),
        "task query dialog must keep close top-right and query action at bottom")
require(deadline_dialog.index("Text('关闭')") < deadline_dialog.index("DatePicker({") <
        deadline_dialog.index("Button('确定'"),
        "deadline dialog must keep close top-right and confirm action at bottom")
require("Text('关闭')" in student_switcher,
        "student switcher must keep a top-right close action")
require("Text('关闭')" in photo_preview,
        "photo preview must keep a top-right close action")
require(parent_edit.index("Text('关闭')") < parent_edit.index("AssignmentEditForm({") <
        parent_edit.index("Button(this.saving ? '保存中…' : '保存修改'"),
        "parent edit sheet must keep close in header and save in the fixed bottom action area")
require("Text('关闭')" in confirmation_components and "confirmDiscard" in confirmation_components,
        "candidate edit sheet must use close as the only header exit and protect dirty edits")
require(confirmation_components.index("AssignmentEditForm({") <
        confirmation_components.index("Button('删除'") <
        confirmation_components.index("Button('完成'"),
        "candidate editor business actions must stay in its bottom action area")

if errors:
    print("TASK_UI_CONSISTENCY_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("TASK_UI_CONSISTENCY_GATE_PASS")
