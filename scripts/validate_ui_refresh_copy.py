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


parent_progress = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")
student_assignments = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets")
student_home = read("entry/src/main/ets/features/student/home/StudentHomePage.ets")
parent_import = read("entry/src/main/ets/features/parent/import/HomeworkImportPage.ets")
parent_confirmation = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
voice_create = read("entry/src/main/ets/features/parent/voice/ParentVoiceAssignmentPage.ets")
study_route = read("entry/src/main/ets/features/student/study/StudyWorkspaceRoutePage.ets")
deadline = read("entry/src/main/ets/components/assignment/DeadlinePickerField.ets")
review = read("entry/src/main/ets/features/parent/review/ParentReviewPane.ets")
person_entry = read("entry/src/main/ets/pages/PersonEntryPage.ets")
assignment_detail = read("entry/src/main/ets/features/student/assignments/AssignmentDetailPane.ets")
practice_home = read("entry/src/main/ets/features/student/practice/PracticeHomePage.ets")
practice_detail = read("entry/src/main/ets/features/student/practice/PracticePaperDetailPage.ets")
practice_history = read("entry/src/main/ets/features/student/practice/PracticeHistoryPage.ets")
study_workspace = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
review_page = read("entry/src/main/ets/features/parent/review/ParentReviewPage.ets")
extra_create = read("entry/src/main/ets/features/parent/extra/ParentExtraAssignmentPage.ets")
capture_home = read("entry/src/main/ets/features/parent/import/HomeworkCaptureHomePage.ets")
capture_page = read("entry/src/main/ets/features/parent/import/HomeworkCapturePage.ets")
share_status = read("entry/src/main/ets/features/parent/import/HomeworkShareImportStatusPage.ets")
settings = read("entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets")
import_route = read("entry/src/main/ets/features/parent/import/HomeworkImportRoutePage.ets")
import_inbox = read("entry/src/main/ets/features/parent/import/HomeworkImportInboxPage.ets")
submit_confirm = read("entry/src/main/ets/components/practice/PracticeSubmitConfirmDialog.ets")
source_profile = read("entry/src/main/ets/features/parent/import/HomeworkSourceProfilePage.ets")
parent_progress = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")

require("@Prop @Watch('onRevisionChanged') revision: number = 0" in parent_progress and
        "private onRevisionChanged(): void" in parent_progress and
        "this.rebuildView();" in parent_progress and
        "private currentVisibleAssignments(): Assignment[]" in parent_progress,
        "parent progress must rebuild its shared query snapshot when revision changes")
require("this.assignmentRenderKey(item)" in parent_progress,
        "parent progress rows must use content-aware assignment keys")

require("snapshotRevision" in student_assignments and "currentVisibleAssignments" in student_assignments,
        "student assignment groups must invalidate cached snapshots when revision changes")
for method in [
    "currentNeedHandlingAssignments",
    "currentNotStartedAssignments",
    "currentSubmittedAssignments",
    "currentCompletedAssignments",
]:
    require(method in student_assignments, f"student assignments missing revision-aware group: {method}")
require("this.assignmentRenderKey(item)" in student_assignments,
        "student assignment rows must use content-aware assignment keys")

require("onStoreChanged: () => void" in student_home and "this.onStoreChanged();" in student_home,
        "student home must invalidate shared UI state after a direct action")
require("TodayScopeNote" not in student_home,
        "student home must not reference the removed TodayScopeNote builder")
require("this.assignmentRenderKey(item)" in student_home,
        "student home task rows must use content-aware assignment keys")

require("CandidatePane" not in parent_import and "继续确认" not in parent_import and
        "this.onOpenConfirmation()" in parent_import,
        "import page must use one direct confirmation step after organization")

for source, token, message in [
    (parent_confirmation, "发布采用整批原子提交", "publish page must not expose atomic-submit implementation details"),
    (voice_create, "学生端会按图片文件名排序", "voice create page must not expose student-side sorting implementation"),
    (study_route, "不建立第二套任务流程", "study page must not expose architecture implementation copy"),
    (student_assignments, "共用 Assignment", "student assignment UI must not expose domain-model terminology"),
    (deadline, "日期和时间均使用北京时间", "deadline picker should not show redundant timezone implementation copy"),
    (student_home, "首页只显示今天要做的任务", "student home should not carry persistent navigation guidance"),
]:
    require(token not in source, message)

for success_assignment in [
    "this.operationNotice = '任务信息已更新'",
    "this.operationNotice = '已通过验收'",
    "this.operationNotice = '已退回订正'",
]:
    require(success_assignment not in review,
            f"parent review should express successful actions through state change instead of persistent copy: {success_assignment}")


# Keep routine pages concise: controls and state should explain themselves. Risk, privacy,
# failure recovery and irreversible-action copy remain explicit.
removed_copy = [
    (person_entry, "进入后身份固定，孩子只看到自己的作业。", "person entry duplicates role behavior"),
    (person_entry, "选择后进入对应空间。家长可以管理多个孩子", "person entry footer repeats visible role choices"),
    (student_assignments, "可选择其他日期或科目后重新查询。", "assignment empty state should not restate visible filters"),
    (student_assignments, "家长布置的课外任务会出现在这里。", "extra-task empty state should be self-explanatory"),
    (assignment_detail, "详情会在这里显示，不需要离开作业列表。", "master-detail layout should not explain itself"),
    (practice_home, "默认按当前学生的", "practice home should not narrate current filter defaults"),
    (practice_home, "教材同步紧跟二年级上学期核心能力", "practice footer should not repeat catalog semantics"),
    (practice_home, "可以切换科目、题库类型或通过状态继续浏览", "practice empty state should not restate visible filters"),
    (practice_detail, "内容来源：", "student practice detail should not expose catalog implementation metadata"),
    (practice_history, "每次开始练习都会创建独立实例", "practice history should show records rather than architecture copy"),
    (practice_history, "可以切换状态或科目继续查看。", "practice history empty state should not restate filters"),
    (study_workspace, "先说说你已经做到哪一步", "tutor suggestions already communicate how to ask"),
    (study_workspace, "文字提问或拍题", "input controls already expose text and capture affordances"),
    (review_page, "查看任务、调整计划，提交后可在这里验收", "review header should not repeat page functions"),
    (review, "提交证据、实际用时和家长验收都会在这里显示。", "review empty state should not explain the pane"),
    (review, "当前状态无需家长验收。", "assignment status already communicates review eligibility"),
    (review, "这项作业已通过验收。", "completed status already communicates review outcome"),
    (extra_create, "安排阅读、运动或实践任务", "extra-task form fields already express the task type"),
    (parent_confirmation, "可以手工新增一项，或返回导入页重新整理老师原文。", "confirmation empty state should stay concise"),
    (parent_import, "继续编辑后可直接发布", "pending-candidate action label already explains the next step"),
    (capture_home, "从老师群聊中提取今日作业", "capture title and source card already express the purpose"),
    (capture_home, "抓取结束后，仍需家长确认后才能导入作业。", "capture workflow should not repeat confirmation copy"),
    (capture_page, "进群手工上滑，小伴自动识别、整理并交给你确认", "capture execution page already has explicit usage steps"),
    (share_status, "分享内容只有在全部读取和整理成功后才会写入导入批次", "share status should not expose transaction implementation"),
    (settings, "管理家庭成员、小伴规则和数据同步。", "settings sections already express their responsibilities"),
    (voice_create, "上传语音和配套图片", "voice assignment form already exposes its media inputs"),
    (import_route, "粘贴文字、选择截图或从系统分享导入", "manual import actions already expose supported sources"),
    (import_inbox, "保留每次导入来源、原始消息和候选作业", "inbox cards already expose traceable import state"),
    (import_inbox, "从文字或截图整理一次老师作业后", "inbox empty state should stay concise"),
]
for source, token, message in removed_copy:
    require(token not in source, f"redundant UI copy regressed: {message}")

for source, token, message in [
    (capture_home, "不读取微信数据库", "capture home must retain the privacy boundary"),
    (capture_home, "不自动点击或滚动微信", "capture home must retain the non-automation boundary"),
    (capture_page, "隐私边界", "capture execution must retain explicit privacy guidance"),
    (submit_confirm, "未答题会按错误计入结果", "practice submit must retain consequence copy"),
    (source_profile, "无法匹配的聊天消息会进入人工确认，不会猜测", "source setup must retain ambiguity handling"),
    (settings, "删除家庭成员属于高风险操作", "destructive family action must retain risk copy"),
    (parent_progress, "删除后无法恢复", "bulk assignment deletion must retain irreversible-action copy"),
    (review, "删除后无法恢复", "single assignment deletion must retain irreversible-action copy"),
    (voice_create, "单个文件不超过 20MB", "voice upload must retain file-size constraints"),
]:
    require(token in source, f"critical UI copy missing: {message}")

if errors:
    print("UI_REFRESH_COPY_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("UI_REFRESH_COPY_GATE_PASS")
