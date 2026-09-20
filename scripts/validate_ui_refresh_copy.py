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

require("snapshotRevision" in parent_progress and "currentVisibleAssignments" in parent_progress,
        "parent progress must invalidate cached list snapshots when revision changes")
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

require("effectiveExpandedSubjectKey" in student_home,
        "student home must recover when the expanded subject disappears after an action")
require("this.assignmentRenderKey(item)" in student_home,
        "student home task rows must use content-aware assignment keys")

require("shouldShowCandidatesStep" in parent_import and
        "this.showCandidatesStep && this.candidates().length > 0" in parent_import,
        "import page must leave candidate step when no candidates remain")

for source, token, message in [
    (parent_confirmation, "发布采用整批原子提交", "publish page must not expose atomic-submit implementation details"),
    (voice_create, "学生端会按图片文件名排序", "voice create page must not expose student-side sorting implementation"),
    (study_route, "不建立第二套任务流程", "study page must not expose architecture implementation copy"),
    (student_assignments, "共用 Assignment", "student assignment UI must not expose domain-model terminology"),
    (deadline, "日期和时间均使用北京时间", "deadline picker should not show redundant timezone implementation copy"),
    (student_home, "首页只显示今天要做的任务", "student home should not carry persistent navigation guidance"),
]:
    require(token not in source, message)

for success_copy in ["任务信息已更新", "已通过验收", "已退回订正"]:
    require(success_copy not in review,
            f"parent review should express successful actions through state change instead of persistent copy: {success_copy}")

if errors:
    print("UI_REFRESH_COPY_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("UI_REFRESH_COPY_GATE_PASS")
