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
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
page = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets")
filter_dialog = read("entry/src/main/ets/features/student/assignments/AssignmentFilterDialog.ets")
detail = read("entry/src/main/ets/features/student/assignments/StudentAssignmentDetailPage.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
study_route = read("entry/src/main/ets/features/student/study/StudyWorkspaceRoutePage.ets")
view_model = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsViewModel.ets")
filter_model = read("entry/src/main/ets/domain/model/AssignmentFilter.ets")
query = read("entry/src/main/ets/domain/service/AssignmentQuery.ets")
repository_port = read("entry/src/main/ets/domain/port/AssignmentRepository.ets")
repository_impl = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
remote_api = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
controller = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentController.java")
service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")

# Navigation: root tabs remain in Shell; assignment detail/study are true deep destinations.
require("ASSIGNMENTS = 'ASSIGNMENTS'" in shell and "ASSIGNMENT_DETAIL = 'ASSIGNMENT_DETAIL'" not in shell and
        "STUDY = 'STUDY'" not in shell,
        "student root routes must contain only top-level surfaces")
require("STUDENT_ASSIGNMENT_DETAIL" in routes and "STUDENT_STUDY" in routes and "AssignmentRouteParam" in routes,
        "typed assignment deep routes must exist")
require(".navDestination(this.AppNavDestination)" in shell and "NavDestination()" in shell,
        "AppShell must register NavDestination builder")
require("pushPathByName" in shell and "AppRoute.STUDENT_ASSIGNMENT_DETAIL" in shell and
        "AppRoute.STUDENT_STUDY" in shell,
        "detail/study must push onto NavPathStack")
require("selectedAssignmentId" not in shell and "studentStudyReturnRoute" not in shell,
        "AppShell must not retain selected-id or manual return-route state")
require("this.navPathStack.size() > 0" in shell and "this.navPathStack.pop()" in shell,
        "system back must pop the Navigation stack")
require("StudentAssignmentsPage" in shell and "StudentAssignmentDetailPage" in shell and
        "StudyWorkspaceRoutePage" in shell,
        "AppShell must wire list plus deep-page destination components")
require("AssignmentAction.START" in study_route and "StudyWorkspaceViewModel" in study_route,
        "study route boundary must preserve start/continue semantics through the ViewModel command path")
require("HomeworkStore.instance.startAssignment" not in shell,
        "AppShell must not execute assignment business commands")

# Slice 2 list/filter behavior remains protected while navigation changes.
require("HomeworkStore.instance" not in page and "HomeworkStore.instance" not in detail and
        "HomeworkStore.instance" not in view_model,
        "V2 assignment list/detail/view-model must not access HomeworkStore directly")
require("WindowSizeClass" not in page and "PhoneLayout" not in page and "PadLayout" not in page,
        "V2 assignment list must not branch on device/window classes")
require("selectedAssignmentId" not in page and "DetailPane" not in page,
        "assignment list must not retain embedded detail selection")
require("AppTheme.ASSIGNMENT_LIST_READABLE_MAX_WIDTH" in page and
        "AppTheme.ASSIGNMENT_DETAIL_READABLE_MAX_WIDTH" in detail,
        "list/detail must keep shared readable-width constraints")
require("private AssignmentListPage()" in page and ".align(Alignment.TopStart)" in page and
        ".align(Alignment.TopStart)" in detail,
        "list/detail must stay top-anchored")

for token in ["AssignmentTypeFilter.ALL", "AssignmentTypeFilter.SCHOOL", "AssignmentTypeFilter.EXTRA"]:
    require(token in page or token in filter_dialog, f"missing type filter option: {token}")
for token in ["AssignmentDateFilter.ALL", "AssignmentDateFilter.TODAY", "AssignmentDateFilter.TOMORROW",
              "AssignmentDateFilter.THIS_WEEK", "AssignmentDateFilter.UNDATED"]:
    require(token in page or token in filter_dialog, f"missing date filter option: {token}")
for token in ["'ALL'", "'CHINESE'", "'MATH'", "'ENGLISH'", "'OTHER'"]:
    require(token in page or token in filter_dialog, f"missing subject filter option: {token}")

for token in ["StudentAssignmentsViewModel", "DefaultAssignmentRepository.instance", "@State private visibleTotal",
              "private applyItems(items: Assignment[]): void", "this.visibleTotal = items.length",
              "AssignmentFilterDialog", "CustomDialogController", "alignment: DialogAlignment.Bottom",
              "this.filterDialogController.open()", "FilterEntry('类型'", "FilterEntry('截止'", "FilterEntry('科目'"]:
    require(token in page, f"assignment result page missing required V2 behavior: {token}")
for token in ["@CustomDialog", "@Link typeFilter", "@Link dateFilter", "@Link subjectCode",
              "private TypeOption", "private DateOption", "private SubjectOption", "Button('重置'", "Button('查询'",
              "this.onQuery(this.typeFilter, this.dateFilter, this.subjectCode)"]:
    require(token in filter_dialog, f"assignment filter dialog missing required behavior: {token}")
for legacy in ["showFilterPage", "FilterPage()", "bindSheet", "FilterOverlay", "FilterPanel"]:
    require(legacy not in page, f"legacy filter implementation must not return: {legacy}")

for state_array in ["needHandlingAssignments", "notStartedAssignments", "submittedAssignments", "completedAssignments"]:
    require(f"ForEach(this.{state_array}" in page,
            f"assignment group must render directly from observable state: {state_array}")
    require(f"Text(`${{this.{state_array}.length}}`)" in page,
            f"assignment group count must be reactive: {state_array}")
require("PadWorkspace" not in study and "SingleColumnWorkspace" in study and "Button('问小伴'" in study,
        "study workspace must keep the validated single-column Tutor flow")

# Query contract remains shared by local cache and backend.
require("export interface AssignmentFilter" in filter_model and "statuses: AssignmentStatus[]" in filter_model and
        "undatedOnly: boolean" in filter_model and "UNDATED = 'UNDATED'" in filter_model,
        "AssignmentFilter must explicitly represent undated work")
require("dueAtEpochMs" in query and "dueText" not in query and "filter.undatedOnly" in query,
        "date filtering must use structured dueAt semantics")
require("query(filter: AssignmentFilter): Promise<Assignment[]>" in repository_port,
        "Repository must expose filtered query")
require("HomeworkRemoteApi.instance.listFiltered" in repository_impl and "RemoteAssignmentMapper.toLocal" in repository_impl,
        "online queries must use backend filtering")
require("!BackendSession.instance.isConnected()" in repository_impl and "this.listCached(filter)" in repository_impl,
        "offline query must fall back to cache")
require("async listFiltered(studentId: string, filter: AssignmentFilter)" in remote_api and
        "type=${encodeURIComponent(filter.assignmentType)}" in remote_api and
        "subjectCode=${encodeURIComponent(filter.subjectCode)}" in remote_api and "undated=true" in remote_api,
        "remote API must transmit combined filters")
require("async query(typeFilter: AssignmentTypeFilter" in view_model and "this.repository.query" in view_model,
        "ViewModel must delegate confirmed filters to Repository")
for param in ["String type", "String subjectCode", "Long from", "Long to", "String status", "Boolean undated"]:
    require(param in controller, f"backend assignment query missing parameter: {param}")
require("matchesListFilter" in service and "statusFilter" in service and "compareForList" in service and
        "undatedOnly" in service,
        "backend must keep combined filtering and stable ordering")

if errors:
    print("STUDENT_ASSIGNMENTS_NAVIGATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("STUDENT_ASSIGNMENTS_NAVIGATION_GATE_PASS")
