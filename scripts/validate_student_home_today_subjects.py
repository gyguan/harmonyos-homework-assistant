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

# Home is an unfinished-work surface across dates. Submitted/completed work belongs in 作业/history.
for token in [
    "pendingAssignments(studentId: string = '')",
    "item.studentId === studentId",
    "private static isUnfinished(status: AssignmentStatus)",
    "status !== AssignmentStatus.SUBMITTED",
    "status !== AssignmentStatus.COMPLETED",
    "private static insertByPriority",
]:
    require(token in view_model, f"Student Home ViewModel missing pending-work contract: {token}")
for removed in ["todayActionableAssignments", "private static isToday", "AssignmentDueDate.businessDayStart"]:
    require(removed not in view_model,
            f"Student Home must not restrict the home list to Today: {removed}")

# Tasks are grouped by subject but remain direct, one-action cards (no accordion/drill-down).
for token in [
    "StudentPendingTaskCard",
    "interface StudentHomeSubjectGroup",
    "private buildSubjectGroups(items: Assignment[])",
    "private SubjectTaskSection(group: StudentHomeSubjectGroup)",
    "private PendingTasks()",
    "待完成作业",
    "this.viewModel.pendingAssignments(this.studentId)",
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

require("Validate student home pending subject groups" in workflow and
        "python scripts/validate_student_home_today_subjects.py" in workflow,
        "CI must run the Student Home pending/subject-group gate")

if errors:
    print("STUDENT_HOME_PENDING_SUBJECTS_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("STUDENT_HOME_PENDING_SUBJECTS_GATE_PASS")
