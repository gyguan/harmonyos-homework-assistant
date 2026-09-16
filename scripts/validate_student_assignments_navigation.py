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
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
view_model = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsViewModel.ets")
filter_model = read("entry/src/main/ets/domain/model/AssignmentFilter.ets")
query = read("entry/src/main/ets/domain/service/AssignmentQuery.ets")
repository_port = read("entry/src/main/ets/domain/port/AssignmentRepository.ets")
repository_impl = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
remote_api = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
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
require("if (this.isDetailFlow())" in shell and "this.BottomNavShell();" in shell and
        "else if (this.sizeClass === WindowSizeClass.EXPANDED)" in shell,
        "detail flows must bypass expanded SideNavigation and render as full-screen content")

require("HomeworkStore.instance" not in page and "HomeworkStore.instance" not in detail and
        "HomeworkStore.instance" not in view_model,
        "V2 assignment list/detail/view-model must not access HomeworkStore directly")
require("WindowSizeClass" not in page and "PhoneLayout" not in page and "PadLayout" not in page,
        "V2 assignment list must not branch on device/window classes")
require("selectedAssignmentId" not in page and "DetailPane" not in page,
        "V2 assignment list must not retain embedded master-detail state")
require("constraintSize({ maxWidth: 760 })" in page,
        "V2 list should control readable width without device-specific split logic")
require("constraintSize({ maxWidth: 720 })" in detail and "align(Alignment.TopStart)" in detail,
        "V2 detail must keep a readable width and explicit top-anchored reading flow")

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
        "private applyItems(items: Assignment[]): void" in page and "this.visibleTotal = items.length" in page,
        "query confirmation must replace observable result state")
require("@State private showFilterPage" in page and "private FilterPage()" in page,
        "filters must use a normal full-page interaction instead of popup/overlay implementations")
require("bindSheet" not in page and "FilterOverlay" not in page and "FilterPanel" not in page,
        "legacy popup filter implementations must not return")
require("Button(label, { type: ButtonType.Normal })" in page and "private TypeOption" in page and
        "private DateOption" in page and "private SubjectOption" in page,
        "filter choices must be real button controls with direct state updates")
require("private async applyFilters(): Promise<void>" in page and "await this.viewModel.query" in page and
        "Button(this.querying ? '查询中…' : '查询'" in page,
        "query confirmation must execute an asynchronous repository query")
require("Button('重置'" in page and "resetDraftFilters" in page,
        "filter page must provide reset without immediately mutating the applied query")
require("FilterEntry('类型'" in page and "FilterEntry('截止'" in page and "FilterEntry('科目'" in page,
        "assignment page must expose compact result-page filter entry points")

require("PadWorkspace" not in study and "SingleColumnWorkspace" in study,
        "study flow must not keep the legacy Pad two-column task+tutor composition")
require("tutorPanelOpen" in study and "Button('问小伴'" in study,
        "Tutor must open as a separate single-column study state until Pad enhancement is rebuilt")

require("export interface AssignmentFilter" in filter_model and "statuses: AssignmentStatus[]" in filter_model and
        "undatedOnly: boolean" in filter_model and "UNDATED = 'UNDATED'" in filter_model,
        "AssignmentFilter must explicitly represent undated work")
require("dueAtEpochMs" in query and "dueText" not in query and "filter.undatedOnly" in query,
        "V2 date filtering must use structured dueAt/undated state and never infer dueText")
require("query(filter: AssignmentFilter): Promise<Assignment[]>" in repository_port,
        "Repository contract must expose filtered query")
require("HomeworkRemoteApi.instance.listFiltered" in repository_impl and "RemoteAssignmentMapper.toLocal" in repository_impl,
        "online filtered queries must call the backend and map remote results")
require("!BackendSession.instance.isConnected()" in repository_impl and "this.listCached(filter)" in repository_impl,
        "offline filtered queries may fall back to local cache")
require("async listFiltered(studentId: string, filter: AssignmentFilter)" in remote_api and
        "type=${encodeURIComponent(filter.assignmentType)}" in remote_api and
        "subjectCode=${encodeURIComponent(filter.subjectCode)}" in remote_api and
        "undated=true" in remote_api,
        "remote API must send the combined filter as query parameters")
require("async query(typeFilter: AssignmentTypeFilter" in view_model and "this.repository.query" in view_model,
        "ViewModel must delegate confirmed filters to Repository.query")

for param in ["String type", "String subjectCode", "Long from", "Long to", "String status", "Boolean undated"]:
    require(param in controller, f"backend assignment query missing parameter: {param}")
require("matchesListFilter" in service and "statusFilter" in service and "compareForList" in service,
        "backend must implement combined filters and stable ordering")
require("undatedOnly" in service and "assignment.dueAt != null" in service,
        "backend must explicitly support undated assignment queries")

if errors:
    print("STUDENT_ASSIGNMENTS_NAVIGATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("STUDENT_ASSIGNMENTS_NAVIGATION_GATE_PASS")
