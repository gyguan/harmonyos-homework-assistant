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

# Home shows only today's unfinished work. Every assignment has one structured completion date.
for token in [
    "todayPendingAssignments(studentId: string = '')",
    "item.studentId === studentId",
    "private static isToday(item: Assignment)",
    "item.taskDate === AssignmentTaskDate.today()",
    "private static isUnfinished(status: AssignmentStatus)",
    "status !== AssignmentStatus.SUBMITTED",
    "status !== AssignmentStatus.COMPLETED",
    "private static insertByPriority",
]:
    require(token in view_model, f"Student Home ViewModel missing pending-work contract: {token}")
require("dueText" not in view_model and "dueAtEpochMs" not in view_model,
        "Student Home must use required taskDate instead of legacy deadline fields")

# Tasks are grouped by subject but remain direct, one-action cards (no accordion/drill-down).
for token in [
    "StudentPendingTaskCard",
    "interface StudentHomeSubjectGroup",
    "private buildSubjectGroups(items: Assignment[])",
    "private SubjectTaskSection(group: StudentHomeSubjectGroup)",
    "private PendingTasks()",
    "今日待完成",
    "this.viewModel.todayPendingAssignments(this.studentId)",
    "@State private pendingTaskItems: Assignment[]",
    "@State private subjectGroups: StudentHomeSubjectGroup[]",
    "ForEach(this.subjectGroups",
    "ForEach(group.items",
    "Subject.CHINESE",
    "Subject.MATH",
    "Subject.ENGLISH",
    "taskRenderEpoch",
    "AssignmentAction.START",
    "this.viewModel.performAction(assignmentId, AssignmentAction.START)",
]:
    require(token in page, f"Student Home missing subject-grouped pending UX: {token}")

for removed in [
    "StudentHomeMetricCard",
    "StudentSubjectTaskGroupCard",
    "expandedSubjectKey",
    "TodayOverview",
    "todaySubjectGroups",
    "private PadHome()",
    "private PhoneHome()",
    "先做这项",
    "接下来",
    "homeFocusSummaryRequirement()",
]:
    require(removed not in page,
            f"Student Home must not restore old summary/accordion/two-column behavior: {removed}")

require("Text(this.assignment.subject)" not in page and
        "AssignmentType.EXTRA" not in page and
        "${this.assignment.expectedMinutes} 分钟" in page,
        "subject grouping must avoid repeating subject/type metadata inside every task card")
require("Button(this.actionLabel()" in page and
        ".alignItems(VerticalAlign.Center)" in page,
        "Student Home task actions must share the main task row and stay vertically centered")
require("private HomeContent()" in page and
        "AppTheme.CONTENT_STANDARD_MAX_WIDTH" in page and
        "this.HomeContent();" in page,
        "Phone and Pad Student Home must share one single-column content composition")
require("${item.subjectCode}|${item.subject}|" in page,
        "Student Home render keys must refresh when authoritative subject data changes")

require("Validate student home today subject groups" in workflow and
        "python scripts/validate_student_home_today_subjects.py" in workflow,
        "CI must run the Student Home today/subject-group gate")

if errors:
    print("STUDENT_HOME_TODAY_SUBJECTS_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("STUDENT_HOME_TODAY_SUBJECTS_GATE_PASS")
