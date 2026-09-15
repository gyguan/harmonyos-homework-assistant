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
due_date = read("entry/src/main/ets/domain/service/AssignmentDueDate.ets")
list_item = read("entry/src/main/ets/components/assignment/AssignmentListItem.ets")

require("ASSIGNMENTS = 'ASSIGNMENTS'" in shell, "student route must include ASSIGNMENTS")
require("StudentAssignmentsPage" in shell, "AppShell must render StudentAssignmentsPage")
require("() => this.studentRoute = StudentRoute.ASSIGNMENTS" in shell,
        "student homework navigation must open assignments list instead of empty study workspace")
require("studentStudyReturnRoute" in shell,
        "study detail must remember whether it was opened from Today or Assignments")

require("我的作业" in page and "需要处理" in page and "待开始" in page,
        "student assignments page must organize active and not-started homework")
require("已提交" in page and "已完成" in page,
        "student assignments page must keep submitted/completed homework visible")
require("this.onOpenStudy(item.id)" in page,
        "student assignments page must open the selected task by id")
require("private openAssignment(item: Assignment)" in page,
        "student assignments page must centralize phone/pad task opening behavior")
require("this.sizeClass === WindowSizeClass.COMPACT" in page,
        "phone task selection must use the COMPACT layout path")
require("selectedAssignmentId" in page and "private DetailPane()" in page and "private PadLayout()" in page,
        "pad assignments page must provide list-detail behavior instead of stretching the phone list")
require("AssignmentListItem" in page and "onOpen: () => this.openAssignment(item)" in page,
        "assignment rows must be fully tappable native-style list items")
require("export struct AssignmentListItem" in list_item,
        "shared native assignment list item must exist")

require("@State private subjectFilter: string = 'ALL'" in page and "filteredAssignments()" in page,
        "student assignments page must keep an explicit subject filter state")
require("SubjectTab('ALL', '全部')" in page and "SubjectTab(Subject.CHINESE, '语文')" in page and
        "SubjectTab(Subject.MATH, '数学')" in page and "SubjectTab(Subject.ENGLISH, '英语')" in page,
        "student assignments page must expose all/chinese/math/english filters")
require("this.subjectCount(key)" in page and "this.filteredAssignments()" in page,
        "student subject filters must show counts and drive the status sections")

require("@State private dateFilter: DueDateFilterKey = DueDateFilterKey.ALL" in page,
        "student assignments page must keep an explicit due-date filter state")
for token in ["DueDateFilterKey.ALL", "DueDateFilterKey.TODAY", "DueDateFilterKey.TOMORROW",
              "DueDateFilterKey.THIS_WEEK", "DueDateFilterKey.OVERDUE"]:
    require(token in page, f"student assignments page missing date filter: {token}")
require("AssignmentDueDate.matches(item, this.dateFilter)" in page and "matchesSubject(item, this.subjectFilter)" in page,
        "student assignments must combine subject and due-date filters")
require("this.dateCount(key)" in page and "private DateTab(" in page and "private FilterPanel()" in page,
        "student due-date filters must show counts in a dedicated lightweight filter row")
require("for (let item of this.filteredAssignments())" in page,
        "student status grouping must run after subject and date filtering")

require("export enum DueDateFilterKey" in due_date and "export class AssignmentDueDate" in due_date,
        "a shared assignment due-date normalizer must back both homework lists")
for phrase in ["今天", "明天", "后天", "周日", "星期天", "月"]:
    require(phrase in due_date, f"due-date normalizer missing supported expression: {phrase}")
require("AssignmentStatus.COMPLETED" in due_date and "AssignmentStatus.SUBMITTED" in due_date and
        "AssignmentStatus.OVERDUE" in due_date,
        "overdue filtering must respect completed/submitted/overdue assignment states")
require("dueDay >= today && dueDay <= AssignmentDueDate.endOfWeek(today)" in due_date,
        "this-week filtering must use the local week boundary")
require("this." not in due_date,
        "AssignmentDueDate static utility must not use standalone this; ArkTS requires explicit class references")

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
