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


page = read("entry/src/main/ets/features/student/home/StudentHomePage.ets")
view_model = read("entry/src/main/ets/features/student/home/StudentHomeViewModel.ets")
workflow = read(".github/workflows/static-gate.yml")

# Student Home remains a strict Today surface backed by structured dueAt data.
for token in [
    "todayActionableAssignments()",
    "private static isToday(item: Assignment)",
    "item.dueAtEpochMs <= 0",
    "AssignmentDueDate.businessDayStart(item.dueAtEpochMs)",
    "AssignmentDueDate.businessDayStart(Date.now())",
    "private static insertByPriority",
]:
    require(token in view_model, f"Student Home ViewModel missing today-only contract: {token}")
require("dueText" not in view_model,
        "Student Home must not infer Today from legacy dueText")

# Grade-two Today UX is a direct, priority-ordered task list with one action per card.
for token in [
    "StudentTodayTaskCard",
    "private TaskList(items: Assignment[])",
    "private TodayTasks()",
    "今天要做",
    "this.viewModel.todayActionableAssignments()",
    "AssignmentAction.START",
    "this.viewModel.performAction(assignmentId, AssignmentAction.START)",
    "@State private actionAssignmentId",
    "onStoreChanged: () => void",
]:
    require(token in page, f"Student Home missing simplified Today UX: {token}")

for removed in [
    "StudentHomeMetricCard",
    "StudentSubjectTaskGroupCard",
    "expandedSubjectKey",
    "TodayOverview",
    "todaySubjectGroups",
]:
    require(removed not in page,
            f"Student Home must not restore summary or subject-accordion friction: {removed}")

require("先做这项" in page and "接下来" in page and
        "LayoutPolicy.homeFocusSummaryRequirement()" in page,
        "Pad Student Home must keep a distinct focus + next-tasks composition")
require("Validate student home Today task list" in workflow and
        "python scripts/validate_student_home_today_subjects.py" in workflow,
        "CI must run the simplified Student Home Today gate")

if errors:
    print("STUDENT_HOME_TODAY_TASKS_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("STUDENT_HOME_TODAY_TASKS_GATE_PASS")
