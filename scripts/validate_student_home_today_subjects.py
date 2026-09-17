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

# The Student Home is a Today surface. Its data boundary must be structured dueAt,
# never dueText inference, and undated/future/history work belongs to Assignments filters.
for token in [
    "todayActionableAssignments()",
    "todaySubjectGroups()",
    "private static isToday(item: Assignment)",
    "item.dueAtEpochMs <= 0",
    "due.getFullYear() === now.getFullYear()",
    "due.getMonth() === now.getMonth()",
    "due.getDate() === now.getDate()",
]:
    require(token in view_model, f"Student Home ViewModel missing today-only contract: {token}")
require("dueText" not in view_model,
        "Student Home must not infer Today from legacy dueText")
require("nextAssignment(): Assignment | null" in view_model and
        "let items = this.todayActionableAssignments();" in view_model,
        "Student Home focus assignment must come only from today's actionable tasks")

# Subject-first information architecture and accordion behavior.
for token in [
    "StudentHomeSubjectGroup",
    "StudentSubjectTaskGroupCard",
    "@State private expandedSubjectKey: string = '';",
    "toggleSubject(key: string)",
    "expanded: this.expandedSubjectKey === group.key",
    "今天要做",
    "按学科完成，一次专注一个学科",
    "首页只显示今天要做的任务",
    "其他日期和未定时间作业请到「作业」页筛选",
]:
    require(token in page, f"Student Home missing subject-first Today UX: {token}")
require("@Prop expanded: boolean = false;" in page,
        "Subject group expanded state must be a reactive component prop")
require("this.expandedSubjectKey = this.expandedSubjectKey === key ? '' : key;" in page,
        "Subject groups must support collapse and single-subject focus")

# The old all-assignment hero/remaining-list structure must not return.
for legacy in ["NextAssignmentHero", "RemainingAssignments", "今天还要做"]:
    require(legacy not in page,
            f"Student Home must not reintroduce the old all-assignment structure: {legacy}")

require("Validate student home Today subject groups" in workflow and
        "python scripts/validate_student_home_today_subjects.py" in workflow,
        "CI must run the Student Home Today subject-group gate")

if errors:
    print("STUDENT_HOME_TODAY_SUBJECTS_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("STUDENT_HOME_TODAY_SUBJECTS_GATE_PASS")
