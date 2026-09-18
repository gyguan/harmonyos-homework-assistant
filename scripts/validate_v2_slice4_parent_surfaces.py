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
evidence = read("entry/src/main/ets/application/submission/ParentSubmissionEvidenceService.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
app_shell = read("entry/src/main/ets/pages/AppShell.ets")
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
for phrase in ["需要我处理", "最近提交", "导入老师作业", "作业进度"]:
    require(phrase in home, f"Parent Home missing required P01 content: {phrase}")
require("AssignmentStatus.OVERDUE" in home_vm and "AssignmentStatus.NEEDS_REWORK" in home_vm and
        "AssignmentStatus.SUBMITTED" in home_vm,
        "Parent Home attention must cover overdue, rework and submitted assignments")

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
for token in ["FilterSummaryEntry({", "label: '类型'", "label: '截止'", "label: '科目'",
              "CustomDialogController", "alignment: DialogAlignment.Bottom", "StatusMetricCard", "StatusSummary"]:
    require(token in progress, f"Parent Progress must align common filter interaction with Student Assignments: {token}")
require("StatusSelectionChip" not in progress and "StatusFilterBar" not in progress,
        "Parent Progress status cards must own status filtering without duplicate status chips")
require("this.StatusMetricCard('全部'" in progress and
        "this.StatusMetricCard('需关注'" in progress and
        "this.StatusMetricCard('待验收'" in progress and
        "this.StatusMetricCard('已完成'" in progress,
        "Parent Progress must expose all four clickable status summary cards")
require(".onClick(() => this.chooseStatus(filter))" in progress,
        "Parent Progress summary cards must filter the assignment list directly")
require("@Prop active: boolean = false;" in selection_controls and
        "@Prop selected: boolean = false;" in selection_controls,
        "shared selection controls must expose reactive active/selected props")
for phrase in ["全部日期", "今天", "明天", "本周", "未定", "全部科目", "语文", "数学", "英语", "其他",
               "全部状态", "需关注", "待验收", "已完成"]:
    require(phrase in progress or phrase in shared_filter,
            f"Parent Progress missing required filter/summary content: {phrase}")
require("AssignmentTypeFilter" in progress_vm and "assignmentType: typeFilter" in progress_vm,
        "Parent Progress query must support the same Assignment type dimension as Student Assignments")
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
require("RemoteSubmissionApi.instance.latest" in evidence and "HomeworkSubmissionService.instance.listCached" in evidence,
        "Parent evidence service must fetch only the latest remote evidence with local fallback")

require("PARENT_REVIEW = 'parent/review'" in routes,
        "Parent Review must have a formal Navigation route")
require("openParentReview" in app_shell and "AppRoute.PARENT_REVIEW" in app_shell and "ParentReviewPage({" in app_shell,
        "AppShell must route Parent Review through NavPathStack/NavDestination")
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
