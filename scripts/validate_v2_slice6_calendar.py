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
panel = read("entry/src/main/ets/features/student/assignments/AssignmentCalendarPanel.ets")
view_model = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsViewModel.ets")
due_date = read("entry/src/main/ets/domain/service/AssignmentDueDate.ets")
workflow = read(".github/workflows/static-gate.yml")

require("AssignmentCalendarPanel" in page and "calendarMode" in page,
        "Student Assignments must expose a calendar view without creating a second feature page")
require("ViewModeButton('列表'" in page and "ViewModeButton('日历'" in page,
        "Student Assignments must offer an explicit list/calendar switch")
require("AssignmentDateFilter.CUSTOM" in page and "assignmentsOnDay" in page,
        "calendar day selection must reuse Assignment filtering semantics")
require("$selectedCalendarDayEpochMs" in page and "$calendarMonthEpochMs" in page,
        "calendar selection/month state must stay page-local and flow through component links")
require("LayoutPolicy.canSplit" in page and "assignmentMasterDetailRequirement" in page,
        "calendar must preserve capability-based Pad composition")
require("WindowSizeClass." not in page and "=== WindowSizeClass" not in page,
        "Student Assignments must not choose its business composition from device size classes")

require("export struct AssignmentCalendarPanel" in panel,
        "Slice 6 must provide a reusable Assignment calendar panel")
require("for (let row = 0; row < 6; row++)" in panel and "column < 7" in panel,
        "month calendar must render a stable six-week by seven-day grid")
require("AssignmentType.SCHOOL" in panel and "AssignmentType.EXTRA" in panel,
        "calendar must visibly distinguish school and extracurricular Assignment types")
require("AssignmentStatus.COMPLETED" in panel,
        "calendar must expose completed-state markers")
require("AssignmentDueDate.dayStart(item)" in panel,
        "calendar markers must use the shared stable Assignment due-day resolver")

require("calendarAssignments" in view_model and "assignmentsOnDay" in view_model,
        "StudentAssignmentsViewModel must own calendar/day query semantics")
require("AssignmentDueDate.dayStart(item)" in view_model,
        "calendar query must use the shared stable Assignment due-day resolver")
require("CalendarRepository" not in view_model and "CalendarService" not in view_model,
        "calendar view must not introduce a parallel Calendar domain/repository")

require("static dayStart(item: Assignment" in due_date,
        "AssignmentDueDate must expose one stable resolver for list and calendar consumers")
require("if (item.dueAtEpochMs > 0)" in due_date and "item.dueDateKey" in due_date,
        "stable due-day resolver must prefer structured dueAt and preserve frozen dueDateKey fallback")

require("Validate V2 Slice 6 calendar" in workflow and "validate_v2_slice6_calendar.py" in workflow,
        "CI must run the Slice 6 calendar gate")

if errors:
    print("V2_SLICE6_CALENDAR_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_SLICE6_CALENDAR_GATE_PASS")
