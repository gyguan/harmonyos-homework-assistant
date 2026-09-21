#!/usr/bin/env python3
from pathlib import Path
import re
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


theme = read("entry/src/main/ets/common/theme/AppTheme.ets")
layout_policy = read("entry/src/main/ets/common/responsive/LayoutPolicy.ets")
repo = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
home = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
home_vm = read("entry/src/main/ets/features/parent/dashboard/ParentHomeViewModel.ets")
progress = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")
progress_vm = read("entry/src/main/ets/features/parent/progress/ParentProgressViewModel.ets")
student_assignments = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets")
shared_filter = read("entry/src/main/ets/components/assignment/AssignmentFilterDialog.ets")
selection_controls = read("entry/src/main/ets/components/selection/SelectionControls.ets")
review_page = read("entry/src/main/ets/features/parent/review/ParentReviewPage.ets")
review_pane = read("entry/src/main/ets/features/parent/review/ParentReviewPane.ets")
review_vm = read("entry/src/main/ets/features/parent/review/ParentReviewViewModel.ets")
review_editor = read("entry/src/main/ets/features/parent/review/ParentAssignmentEditPanel.ets")
shared_editor = read("entry/src/main/ets/components/assignment/AssignmentEditForm.ets")
confirmation_editor = read("entry/src/main/ets/features/parent/confirmation/ConfirmationCandidateComponents.ets")
remote_api = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
assignment_controller = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentController.java")
assignment_service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
evidence = read("entry/src/main/ets/application/submission/ParentSubmissionEvidenceService.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
app_shell = read("entry/src/main/ets/pages/AppShell.ets")
batch_publish = read("entry/src/main/ets/application/import/HomeworkBatchPublishService.ets")
homework_store = read("entry/src/main/ets/data/HomeworkStore.ets")
due_date = read("entry/src/main/ets/domain/service/AssignmentDueDate.ets")
issue_spec = read("docs/product/ui-page-spec-v2.md")

for token in [
    "PARENT_HOME_READABLE_MAX_WIDTH",
    "PARENT_HOME_PAD_CONTENT_MAX_WIDTH",
    "PARENT_PROGRESS_READABLE_MAX_WIDTH",
    "PARENT_PROGRESS_REVIEW_MAX_WIDTH",
    "PARENT_REVIEW_READABLE_MAX_WIDTH",
    "PARENT_HOME_PRIMARY_MIN_WIDTH",
    "PARENT_HOME_SECONDARY_MIN_WIDTH",
    "PARENT_PROGRESS_LIST_MIN_WIDTH",
    "PARENT_REVIEW_MIN_WIDTH",
]:
    require(token in theme, f"AppTheme missing Slice 4 parent layout token: {token}")

for token in ["parentHomeRequirement", "parentProgressReviewRequirement", "canSplit"]:
    require(token in layout_policy, f"LayoutPolicy missing Slice 4 capability: {token}")

for text, path in [
    (home, "ParentDashboardPage.ets"),
    (home_vm, "ParentHomeViewModel.ets"),
    (progress, "ParentProgressPage.ets"),
    (progress_vm, "ParentProgressViewModel.ets"),
    (review_page, "ParentReviewPage.ets"),
    (review_pane, "ParentReviewPane.ets"),
    (review_vm, "ParentReviewViewModel.ets"),
]:
    require("HomeworkStore.instance" not in text,
            f"migrated Slice 4 parent surface must not access HomeworkStore directly: {path}")

for text, path in [
    (home, "ParentDashboardPage.ets"),
    (progress, "ParentProgressPage.ets"),
    (review_page, "ParentReviewPage.ets"),
    (review_pane, "ParentReviewPane.ets"),
]:
    require("WindowSizeClass" not in text and "@Prop sizeClass" not in text and "this.sizeClass" not in text,
            f"Slice 4 business layout must not branch on WindowSizeClass: {path}")
    require("private PhoneLayout()" not in text and "private PadLayout()" not in text,
            f"Slice 4 must not reintroduce fixed PhoneLayout/PadLayout branches: {path}")
    require(re.search(r"(?:<=|>=|<|>)\s*(?:600|840|1080)\b", text) is None,
            f"Slice 4 must not use private device breakpoints: {path}")

require("LayoutPolicy.parentHomeRequirement()" in home and "availableWidthVp" in home,
        "Parent Home must choose wide composition from actual container width + LayoutPolicy")
require("AppTheme.PARENT_HOME_READABLE_MAX_WIDTH" in home and "AppTheme.PARENT_HOME_PAD_CONTENT_MAX_WIDTH" in home,
        "Parent Home must keep readable fallback and capped Pad composition")
for phrase in ["需要我处理", "最近提交", "导入老师作业", "查看全部"]:
    require(phrase in home, f"Parent Home missing required P01 content: {phrase}")
require("AssignmentStatus.OVERDUE" in home_vm and "AssignmentStatus.NEEDS_REWORK" in home_vm and
        "AssignmentStatus.SUBMITTED" in home_vm,
        "Parent Home attention must cover overdue, rework and submitted assignments")

require("private openRecentActivity(item: Assignment)" in home and
        "this.onOpenReview(item.id)" in home.split("private openRecentActivity(item: Assignment)", 1)[1].split("@Builder", 1)[0],
        "Parent Home recent activity must open the selected assignment detail directly")
recent_activity = home.split("private RecentActivity()", 1)
require(len(recent_activity) == 2, "Parent Home must keep a RecentActivity section")
if len(recent_activity) == 2:
    recent_block = recent_activity[1].split("private QuickActions()", 1)[0]
    require("Text('查看全部')" in recent_block and "this.onOpenProgress()" in recent_block,
            "Parent Home Recent Activity must keep an explicit View All action to Progress")
    require("openRecentActivity(item)" in recent_block and "openAttention(item)" not in recent_block,
            "Parent Home recent items must not reuse attention routing")
attention_section = home.split("private AttentionSection()", 1)
require(len(attention_section) == 2, "Parent Home must keep an AttentionSection")
if len(attention_section) == 2:
    attention_block = attention_section[1].split("private RecentActivity()", 1)[0]
    require("openAttention(item)" in attention_block,
            "Parent Home attention items must preserve state-aware routing")

require("LayoutPolicy.parentProgressReviewRequirement()" in progress and "availableWidthVp" in progress,
        "Parent Progress must choose review split from actual container width + LayoutPolicy")
require("AppTheme.PARENT_PROGRESS_READABLE_MAX_WIDTH" in progress and
        "AppTheme.PARENT_PROGRESS_REVIEW_MAX_WIDTH" in progress,
        "Parent Progress must keep readable fallback and capped list-review split")
require("components/assignment/AssignmentFilterDialog" in progress and
        "components/assignment/AssignmentFilterDialog" in student_assignments,
        "Parent Progress and Student Assignments must reuse the same shared assignment filter dialog")
require("components/selection/SelectionControls" in progress and
        "components/selection/SelectionControls" in student_assignments,
        "Parent Progress and Student Assignments must reuse shared reactive selection controls")
for token in ["FilterSummaryEntry({", "label: '日期'", "label: '科目'",
              "CustomDialogController", "alignment: DialogAlignment.Bottom", "StatusSummary",
              "AssignmentMetricSummary", "AssignmentMetricKey"]:
    require(token in progress, f"Parent Progress must align common query/metric interaction: {token}")
require("StatusSelectionChip" not in progress and "StatusFilterBar" not in progress,
        "Parent Progress status selection must remain in metric cards without duplicate chips")
for phrase in ["全部任务", "待完成", "待验收", "已完成"]:
    require(phrase in progress or phrase in read("entry/src/main/ets/components/assignment/AssignmentMetricSummary.ets"),
            f"Parent Progress missing unified metric: {phrase}")
for token in ["DatePicker({", "@Link selectedDayEpochMs", "@Link subjectCode", "Button('查询'"]:
    require(token in shared_filter, f"shared task query missing date+subject behavior: {token}")
for removed in ["private TypeOption", "private DateOption", "今天", "明天", "本周"]:
    require(removed not in shared_filter,
            f"Parent/Student task query must not retain preset type/relative-date option: {removed}")
require("AssignmentTypeFilter" in progress_vm and "AssignmentFilterFactory.create(typeFilter" in progress_vm,
        "Parent Progress query must preserve the Assignment type dimension through the shared filter factory")
require("ParentReviewPane({" in progress and "selectedAssignmentId" in progress,
        "wide Parent Progress must reuse ParentReviewPane instead of a duplicate detail model")
require("this.onOpenReview(item.id)" in progress,
        "narrow Parent Progress must navigate to independent Parent Review")

require("DeepPageHeader" in review_page and "ParentReviewPane" in review_page,
        "Parent Review page must use shared deep-page chrome and reusable review pane")
require("AppTheme.PARENT_REVIEW_READABLE_MAX_WIDTH" in review_page,
        "Parent Review page must keep a readable width cap")
require("ParentSubmissionEvidenceService" in review_pane and "CloudSubmissionPhotoStrip" in review_pane,
        "Parent Review must show authoritative/local submission evidence through the submission boundary")
require("AssignmentStatus.SUBMITTED" in review_pane and "退回订正" in review_pane and "通过" in review_pane,
        "Parent Review must expose review actions only around submitted work")
require("this.viewModel.approve" in review_pane and "this.viewModel.returnForRework" in review_pane,
        "Parent Review UI must delegate decisions to ParentReviewViewModel")
require("ParentAssignmentEditPanel" in review_pane and "编辑任务" in review_pane and
        "this.viewModel.updateDetails(updated)" in review_pane,
        "Parent task detail must expose editable task definition before submission")
require("AssignmentEditForm" in review_editor and "保存修改" in review_editor and
        "不会修改作业状态和计时" in review_editor,
        "Parent assignment editor must reuse the shared assignment form and explain status isolation")
require("AssignmentEditForm" in confirmation_editor,
        "confirmation editing must reuse the same shared assignment form as published assignment editing")
require("DeadlinePickerField" in shared_editor and "预计用时（分钟）" in shared_editor and
        "教材 / 页码" in shared_editor and "作业标题" in shared_editor,
        "shared assignment editor must own the common title/deadline/duration/textbook fields")
require("bindSheet($$this.showEditSheet" in review_pane and "AssignmentEditorSheet" in review_pane,
        "published assignment editing must open in a bottom sheet rather than inline")
require("AssignmentStatus.SUBMITTED" in review_pane and "AssignmentStatus.COMPLETED" in review_pane and
        "private canEdit(item: Assignment)" in review_pane,
        "submitted/completed assignments must lock task-definition editing")
require("let persisted = item.remoteVersion > 0 || item.candidateId.length > 0" not in review_pane and
        "return item.status !== AssignmentStatus.SUBMITTED && item.status !== AssignmentStatus.COMPLETED" in review_pane,
        "all unfinished assignments, including NOT_STARTED, must expose parent editing")
require("current.backing === AssignmentBacking.LOCAL_SEED" in repo and
        "ensureRemoteCurrent" in repo and "this.applyAuthoritative(localDraft)" in repo,
        "parent edit must use explicit Assignment backing and hydrate remote work centrally")
require("remoteVersion > 0 || current.candidateId.length > 0" not in repo,
        "parent edit must not infer remote identity from sync metadata")
require("async updateDetails(assignment: Assignment" in remote_api and
        "'parent.assignment.edit'" in remote_api and "/details" in remote_api,
        "HarmonyOS parent edit must use the narrow assignment details API")
require('@PutMapping("/assignments/{id}/details")' in assignment_controller and
        "service.updateDetails" in assignment_controller,
        "backend must expose owned assignment details editing")
require("public AssignmentDtos.Response updateDetails" in assignment_service and
        '"SUBMITTED".equals(e.status)' in assignment_service and '"COMPLETED".equals(e.status)' in assignment_service,
        "backend must preserve status boundaries when editing task details")
require("RemoteSubmissionApi.instance.latest" in evidence and "HomeworkSubmissionService.instance.listCached" in evidence,
        "Parent evidence service must fetch only the latest remote evidence with local fallback")

require("PARENT_REVIEW = 'parent/review'" in routes,
        "Parent Review must have a formal Navigation route")
require("openParentReview" in app_shell and "AppRoute.PARENT_REVIEW" in app_shell and "ParentReviewPage({" in app_shell,
        "AppShell must route Parent Review through NavPathStack/NavDestination")

require("DefaultAssignmentRepository.instance.applyAuthoritativeBatch(mapped)" in batch_publish,
        "Batch publish must update the authoritative assignment cache before returning to Parent Home")

today_summary = homework_store.split("getTodaySummary(): TodaySummary", 1)
require(len(today_summary) == 2, "HomeworkStore must expose TodaySummary")
if len(today_summary) == 2:
    today_block = today_summary[1].split("getDashboardSummary()", 1)[0]
    require("AssignmentDueDate.businessDayStart(Date.now())" in today_block and
            "AssignmentDueDate.dayStart(assignment)" in today_block,
            "HomeworkStore TodaySummary must use the shared Asia/Shanghai business-day semantics")
    require("due.getFullYear() === now.getFullYear()" not in today_block and
            "new Date(assignment.dueAtEpochMs)" not in today_block,
            "HomeworkStore TodaySummary must not fall back to the device-local calendar date")
require("AssignmentDueDate.businessDayStart(Date.now())" in home and
        "AssignmentDueDate.dayStart(item)" in home,
        "Parent Dashboard TodayOverview must share the same business-day semantics as TodaySummary")
require("SHANGHAI_OFFSET_HOURS: number = 8" in due_date,
        "assignment business-day semantics must remain anchored to Asia/Shanghai")
require("candidateAnchor(candidate.id)" in batch_publish,
        "relative teacher deadlines must remain anchored to the Candidate/import creation time")
require("private finishParentImportPublished(): void" in app_shell and
        "this.navPathStack.clear();" in app_shell.split("private finishParentImportPublished(): void", 1)[1].split("private openParentExtraCreate", 1)[0] and
        "this.notifyUiChanged();" in app_shell.split("private finishParentImportPublished(): void", 1)[1].split("private openParentExtraCreate", 1)[0],
        "Parent import completion must invalidate the dashboard after clearing the deep navigation stack")
require("onPublished: () => this.finishParentImportPublished()" in app_shell,
        "Homework confirmation must use the post-navigation dashboard refresh boundary")
require("backAccessibilityText: '返回上一页'" in review_page and "backAccessibilityText: '返回进度'" not in review_page,
        "Parent assignment detail back semantics must remain neutral across Home and Progress callers")
parent_progress_call = app_shell.split("ParentProgressPage({", 1)
require(len(parent_progress_call) == 2, "AppShell must render ParentProgressPage")
if len(parent_progress_call) == 2:
    call = parent_progress_call[1].split("});", 1)[0]
    require("sizeClass:" not in call,
            "AppShell must not pass shell WindowSizeClass into migrated Parent Progress")
parent_home_call = app_shell.split("ParentDashboardPage({", 1)
require(len(parent_home_call) == 2, "AppShell must render migrated Parent Home")
if len(parent_home_call) == 2:
    call = parent_home_call[1].split("});", 1)[0]
    require("sizeClass:" not in call,
            "AppShell must not pass shell WindowSizeClass into migrated Parent Home")

require("this.queryCache = AssignmentQuery.filter(mapped, filter)" in repo,
        "Repository remote query results must still apply the complete filter for multi-status parent views")

for phrase in ["今天是否正常？哪里需要我处理？", "作业列表 | 提交证据 / 验收详情", "[通过]", "[退回订正]"]:
    require(phrase in issue_spec, f"V2 UI spec missing Slice 4 contract phrase: {phrase}")

if errors:
    print("V2_SLICE4_PARENT_SURFACES_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_SLICE4_PARENT_SURFACES_GATE_PASS")
