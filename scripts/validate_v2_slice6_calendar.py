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


page = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets")
view_model = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsViewModel.ets")
workflow = read(".github/workflows/static-gate.yml")
calendar_file = ROOT / "entry/src/main/ets/features/student/assignments/AssignmentCalendarPanel.ets"

# Calendar UI was intentionally retired: Assignment is now one list surface with quick filters.
require(not calendar_file.exists(),
        "retired Assignment calendar component must stay deleted")
for token in ["AssignmentCalendarPanel", "calendarMode", "calendarMonthEpochMs",
              "ViewModeToggle", "PadExtraAssignmentsPane", "showCalendar()", "showList()"]:
    require(token not in page, f"retired Assignment calendar behavior must not return: {token}")
require("private QuickFilterBar()" in page and "label: '今天'" in page and
        "label: '全部'" in page and "label: '语文'" in page and
        "label: '数学'" in page and "label: '英语'" in page,
        "Assignment list must expose common date and subject filters directly")
require("AssignmentFilterDialog" in page and "更多筛选：" in page,
        "low-frequency date/subject choices must remain available through More filters")

# Structured selected-day query semantics remain useful for quick/custom filters.
require("assignmentsOnDay" in view_model and "queryOnDay" in view_model,
        "Assignment list filters must retain selected-day query semantics")
require("item.dueAtEpochMs <= 0" in view_model and
        "AssignmentDateRange.startOfDay(item.dueAtEpochMs)" in view_model,
        "selected-day filtering must continue to use structured dueAt")
require("dueText" not in view_model and "dueDateKey" not in view_model,
        "Assignment filtering must never infer dates from legacy display strings")
require("AssignmentFilterFactory" in view_model and "AssignmentDateRange" in view_model,
        "Assignment filters must reuse shared date/query services")

require("Validate V2 Slice 6 calendar" in workflow and "validate_v2_slice6_calendar.py" in workflow,
        "CI must continue guarding the intentional calendar retirement")

if errors:
    print("V2_SLICE6_CALENDAR_RETIREMENT_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_SLICE6_CALENDAR_RETIREMENT_GATE_PASS")
