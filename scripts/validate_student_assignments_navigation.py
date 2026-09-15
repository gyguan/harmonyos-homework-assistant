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


shell = read("entry/src/main/ets/pages/AppShell.ets")
page = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets")
today = read("entry/src/main/ets/features/student/today/StudentTodayPage.ets")

require("ASSIGNMENTS = 'ASSIGNMENTS'" in shell, "student route must include ASSIGNMENTS")
require("StudentAssignmentsPage" in shell, "AppShell must render StudentAssignmentsPage")
require("() => this.studentRoute = StudentRoute.ASSIGNMENTS" in shell,
        "student homework navigation must open assignments list instead of empty study workspace")
require("studentStudyReturnRoute" in shell,
        "study detail must remember whether it was opened from Today or Assignments")
require("我的作业" in page and "需要处理" in page and "待开始" in page,
        "student assignments page must organize active and not-started homework")
require("已提交 · 待家长验收" in page and "已完成" in page,
        "student assignments page must keep submitted/completed homework visible")
require("this.onOpenStudy(item.id)" in page,
        "student assignments page must open the selected task by id")
require("@State private subjectFilter: string = 'ALL'" in page and "filteredAssignments()" in page,
        "student assignments page must keep an explicit subject filter state")
require("SubjectFilterChip('ALL', '全部')" in page and "SubjectFilterChip(Subject.CHINESE, '语文')" in page and
        "SubjectFilterChip(Subject.MATH, '数学')" in page and "SubjectFilterChip(Subject.ENGLISH, '英语')" in page,
        "student assignments page must expose all/chinese/math/english filters")
require("subjectCount(key)" in page and "this.filteredAssignments()" in page,
        "student subject filters must show counts and drive the status sections")
require("for (let item of this.filteredAssignments())" in page,
        "student status grouping must run after subject filtering")
require("HomeworkStore.instance.getAssignments()" in today,
        "Today must include overdue assignments instead of filtering them out")
require("overdueAssignments" in today and "逾期" in today,
        "Today must explicitly surface overdue homework")
require("AssignmentStatus.OVERDUE" in today and "AssignmentStatus.NOT_STARTED" in today,
        "Today recommendation must account for overdue and not-started work")
over_pos = today.find("AssignmentStatus.OVERDUE")
not_started_pos = today.find("AssignmentStatus.NOT_STARTED", over_pos)
require(over_pos >= 0 and not_started_pos > over_pos,
        "overdue work must rank ahead of ordinary not-started work in recommendation order")

if errors:
    print("STUDENT_ASSIGNMENTS_NAVIGATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("STUDENT_ASSIGNMENTS_NAVIGATION_GATE_PASS")
