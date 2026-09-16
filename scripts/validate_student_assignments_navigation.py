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
detail = read("entry/src/main/ets/features/student/assignments/StudentAssignmentDetailPage.ets")
view_model = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsViewModel.ets")
filter_model = read("entry/src/main/ets/domain/model/AssignmentFilter.ets")
query = read("entry/src/main/ets/domain/service/AssignmentQuery.ets")
repository_port = read("entry/src/main/ets/domain/port/AssignmentRepository.ets")
repository_impl = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
controller = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentController.java")
service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")

require("ASSIGNMENTS = 'ASSIGNMENTS'" in shell and "ASSIGNMENT_DETAIL = 'ASSIGNMENT_DETAIL'" in shell,
        "student routes must include list and standalone assignment detail")
require("StudentAssignmentsPage" in shell and "StudentAssignmentDetailPage" in shell,
        "AppShell must render V2 assignment list and detail pages")
require("onOpenDetail" in shell and "openAssignmentDetail" in shell,
        "assignment list must navigate to standalone detail by assignment id")
require("studentStudyReturnRoute = StudentRoute.ASSIGNMENT_DETAIL" in shell,
        "study opened from assignment detail must return to that detail")

require("HomeworkStore.instance" not in page and "HomeworkStore.instance" not in detail and
        "HomeworkStore.instance" not in view_model,
        "V2 assignment list/detail/view-model must not access HomeworkStore directly")
require("WindowSizeClass" not in page and "PhoneLayout" not in page and "PadLayout" not in page,
        "V2 assignment list must not branch on device/window classes")
require("selectedAssignmentId" not in page and "DetailPane" not in page,
        "V2 assignment list must not retain embedded master-detail state")
require("constraintSize({ maxWidth: 760 })" in page,
        "V2 list should control readable width without device-specific split logic")
require("constraintSize({ maxWidth: 720 })" in detail and "alignItems(VerticalAlign.Top)" in detail,
        "V2 detail must keep a readable width and top-anchored reading flow")

for token in ["AssignmentTypeFilter.ALL", "AssignmentTypeFilter.SCHOOL", "AssignmentTypeFilter.EXTRA"]:
    require(token in page, f"assignment list missing type filter: {token}")
for token in ["AssignmentDateFilter.ALL", "AssignmentDateFilter.TODAY", "AssignmentDateFilter.TOMORROW",
              "AssignmentDateFilter.THIS_WEEK", "AssignmentDateFilter.UNDATED"]:
    require(token in page, f"assignment list missing date filter: {token}")
for subject in ["'ALL'", "'CHINESE'", "'MATH'", "'ENGLISH'", "'OTHER'"]:
    require(subject in page, f"assignment list missing subject filter: {subject}")

require("StudentAssignmentsViewModel" in page and "DefaultAssignmentRepository.instance" in page,
        "assignment list must query through ViewModel + Repository")
require("@State private visibleTotal" in page and "@State private needHandlingAssignments" in page and
        "private rebuildResults(): void" in page and "this.visibleTotal = items.length" in page,
        "filter changes must explicitly replace observable result state instead of relying on implicit method re-evaluation")
require("this.rebuildResults();" in page and "selectType" in page and "selectDate" in page and "selectSubject" in page,
        "every filter selection must rebuild visible assignment results")
require("typeCount(typeFilter" in view_model and "subjectCount(subjectCode" in view_model and
        "dateCount(dateFilter" in view_model,
        "filter counts must be stable per dimension rather than depend on other active chips")
require("筛选作业" in page and "筛选结果" in page and "重置" in page,
        "assignment filters must have grouped visual hierarchy and a visible result summary")

require("export interface AssignmentFilter" in filter_model and "statuses: AssignmentStatus[]" in filter_model and
        "undatedOnly: boolean" in filter_model and "UNDATED = 'UNDATED'" in filter_model,
        "AssignmentFilter must explicitly represent undated work")
require("dueAtEpochMs" in query and "dueText" not in query and "filter.undatedOnly" in query,
        "V2 date filtering must use structured dueAt/undated state and never infer dueText")
require("AssignmentQuery.filter" in repository_impl and "filter?: AssignmentFilter" in repository_port,
        "Repository boundary must own local AssignmentFilter execution")
require("getCached(assignmentId: string)" in repository_port and "getCached(assignmentId: string)" in repository_impl,
        "standalone detail must load through Repository instead of Store")

for param in ["String type", "String subjectCode", "Long from", "Long to", "String status", "Boolean undated"]:
    require(param in controller, f"backend assignment query missing parameter: {param}")
require("matchesListFilter" in service and "statusFilter" in service and "compareForList" in service,
        "backend must implement combined filters and stable ordering")
require("undatedOnly" in service and "assignment.dueAt != null" in service,
        "backend must explicitly support undated assignment queries")
require("未定日期筛选不能同时指定日期范围" in service,
        "backend must reject ambiguous undated + date-range queries")

if errors:
    print("STUDENT_ASSIGNMENTS_NAVIGATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("STUDENT_ASSIGNMENTS_NAVIGATION_GATE_PASS")
