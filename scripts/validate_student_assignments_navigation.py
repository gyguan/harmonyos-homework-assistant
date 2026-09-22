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
filter_dialog = read("entry/src/main/ets/components/assignment/AssignmentFilterDialog.ets")
selection_controls = read("entry/src/main/ets/components/selection/SelectionControls.ets")
detail = read("entry/src/main/ets/features/student/assignments/StudentAssignmentDetailPage.ets")
detail_pane = read("entry/src/main/ets/features/student/assignments/AssignmentDetailPane.ets")
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

# Navigation: root tabs remain in Shell; Phone assignment detail/study stay true deep destinations.
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
require("AssignmentAction.START" in study and "StudyWorkspaceViewModel" in study_route and
        "this.viewModel.performAction(this.assignmentId, action)" in study,
        "Study Workspace must preserve explicit start/continue semantics through the ViewModel command path")
require("AssignmentAction.START" not in study_route and "activateAssignment" not in study_route,
        "study route boundary must never auto-start timing on page entry")
require("HomeworkStore.instance.startAssignment" not in shell,
        "AppShell must not execute assignment business commands")
require("onOpenStudy: (assignmentId: string) => this.openStudy(assignmentId)" in shell,
        "embedded Pad assignment detail must keep the existing Study navigation action")

# Slice 2 list/filter behavior plus Pad master-detail composition.
require("HomeworkStore.instance" not in page and "HomeworkStore.instance" not in detail and
        "HomeworkStore.instance" not in detail_pane and "HomeworkStore.instance" not in view_model,
        "V2 assignment list/detail/view-model must not access HomeworkStore directly")
require("WindowSizeClass." not in page and "@Prop sizeClass" not in page and "this.sizeClass" not in page,
        "V2 assignment list must use LayoutPolicy rather than window-class branching")
require("@State private selectedAssignmentId" in page and "AssignmentDetailPane" in page,
        "Assignment Feature must own local Pad master-detail selection and reusable detail pane")
require("LayoutPolicy.assignmentMasterDetailRequirement()" in page and "private AssignmentMasterDetail()" in page,
        "Assignment master-detail must be enabled by shared content capability")
require("selected: this.isSelected(item.id)" in page and "showChevron: !this.canUseMasterDetail()" in page,
        "Pad list items must expose local selection instead of Phone chevron navigation")
require("AssignmentDetailPane" in detail and "DeepPageHeader" in detail,
        "Phone detail must reuse the same AssignmentDetailPane under deep-page chrome")
require("AppTheme.ASSIGNMENT_LIST_READABLE_MAX_WIDTH" in page and
        "AppTheme.ASSIGNMENT_DETAIL_READABLE_MAX_WIDTH" in detail,
        "list/detail must keep shared readable-width fallback constraints")
require("private AssignmentListPage()" in page and ".align(Alignment.TopStart)" in page and
        ".justifyContent(FlexAlign.Start)" in detail and ".height('100%')" in detail,
        "Phone list/detail fallback must stay top-anchored")
require("components/assignment/AssignmentFilterDialog" in page,
        "student assignment page must use the shared assignment filter dialog")
require("components/selection/SelectionControls" in page,
        "student assignment page must use shared reactive selection controls")

for token in ["'ALL'", "'CHINESE'", "'MATH'", "'ENGLISH'", "'OTHER'"]:
    require(token in page or token in filter_dialog, f"missing subject filter option: {token}")

for token in ["StudentAssignmentsViewModel", "DefaultAssignmentRepository.instance", "@State private visibleTotal",
              "private applyItems(items: Assignment[]): void", "this.visibleTotal = items.length",
              "AssignmentFilterDialog", "CustomDialogController", "alignment: DialogAlignment.Bottom",
              "this.filterDialogController.open()", "FilterSummaryEntry({", "label: '日期'", "label: '科目'",
              "allDates: $draftAllDates", "selectedDayEpochMs: $draftSelectedDayEpochMs",
              "AssignmentDateFilter.ALL", "queryOnDay"]:
    require(token in page or token in view_model, f"assignment result page missing required date+subject behavior: {token}")
require("@Prop active: boolean = false;" in selection_controls and
        "export struct FilterSummaryEntry" in selection_controls,
        "assignment filter summary must keep active state in a reactive shared component")
for expression in [
    "active: !this.allDates && !this.isSelectedDayToday()",
    "active: this.subjectCode !== 'ALL'",
]:
    require(expression in page, f"assignment query summary must bind directly to page state: {expression}")
for token in ["@CustomDialog", "@Link allDates", "@Link selectedDayEpochMs", "@Link subjectCode",
              "DateModeOption('全部日期', true)", "DateModeOption('指定日期', false)",
              "DatePicker({", "private SubjectOption", "Button('重置'", "Button('查询'",
              "this.onQuery(this.allDates, this.selectedDayEpochMs, this.subjectCode)"]:
    require(token in filter_dialog, f"assignment query dialog missing required behavior: {token}")
for removed in ["private TypeOption", "private DateOption", "今天", "明天", "本周"]:
    require(removed not in filter_dialog,
            f"shared assignment query must not retain preset type/relative-date option: {removed}")

for legacy in ["showFilterPage", "FilterPage()", "bindSheet", "FilterOverlay", "FilterPanel"]:
    require(legacy not in page, f"legacy filter implementation must not return: {legacy}")

for getter in ["currentTodoAssignments", "currentHistoryAssignments"]:
    require(f"ForEach(this.{getter}()" in page,
            f"simplified assignment group must render from revision-aware data: {getter}")
    require(f"this.{getter}().length" in page,
            f"simplified assignment group count must be revision-aware: {getter}")
for source_getter in [
    "currentNeedHandlingAssignments",
    "currentNotStartedAssignments",
    "currentSubmittedAssignments",
    "currentCompletedAssignments",
]:
    require(f"this.{source_getter}()" in page,
            f"combined assignment groups must retain revision-aware source: {source_getter}")
require("@State private historyExpanded: boolean = false;" in page and
        "Text(`已提交 / 已完成 · ${this.currentHistoryAssignments().length}`)" in page,
        "submitted and completed assignments must remain collapsed behind one history row")
require("snapshotRevision" in page and "currentVisibleAssignments" in page,
        "assignment list must invalidate cached groups when repository revision changes")

require("SingleColumnWorkspace" in study and "SplitWorkspace" in study and "Button('问小伴'" in study,
        "Study must keep Phone standalone Tutor flow and add Pad Study+Tutor split composition")
require("LayoutPolicy.studyTutorRequirement()" in study and "this.TutorPane();" in study,
        "Study Pad split must use shared content capability and the existing Tutor pane")

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
require("queryOnDay(subjectCode: string, dayEpochMs: number" in view_model and "this.repository.query" in view_model,
        "ViewModel must delegate selected-day queries to Repository")
for param in ["String type", "String subjectCode", "Long from", "Long to", "String status", "Boolean undated"]:
    require(param in controller, f"backend assignment query missing parameter: {param}")
require("listSpecification" in service and "statusFilter" in service and "compareForList" in service and
        "undatedOnly" in service and "repository.findAll(listSpecification" in service,
        "backend must push combined filtering to the database while preserving stable legacy ordering")

if errors:
    print("STUDENT_ASSIGNMENTS_NAVIGATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("STUDENT_ASSIGNMENTS_NAVIGATION_GATE_PASS")
