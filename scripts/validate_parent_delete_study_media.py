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


port = read("entry/src/main/ets/domain/port/AssignmentRepository.ets")
repo = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
remote = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
progress = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")
progress_vm = read("entry/src/main/ets/features/parent/progress/ParentProgressViewModel.ets")
review = read("entry/src/main/ets/features/parent/review/ParentReviewPane.ets")
review_vm = read("entry/src/main/ets/features/parent/review/ParentReviewViewModel.ets")
review_page = read("entry/src/main/ets/features/parent/review/ParentReviewPage.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
backend = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
e2e = read("backend/scripts/e2e_smoke.py")
import_page = read("entry/src/main/ets/features/parent/import/HomeworkImportPage.ets")
confirmation = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
voice = read("entry/src/main/ets/components/assignment/VoiceAssignmentPane.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
submission = read("entry/src/main/ets/application/submission/HomeworkSubmissionService.ets")
module = read("entry/src/main/module.json5")
workflow = read(".github/workflows/static-gate.yml")

# Parent deletion: every unfinished task can be deleted, with batch management from Progress.
require("deleteAssignments(assignmentIds: string[]): Promise<number>" in port,
        "assignment repository must expose batch deletion")
require("current.status === AssignmentStatus.COMPLETED" in repo and "已完成作业不能删除" in repo,
        "client repository must reject completed assignment deletion")
require("HomeworkRemoteApi.instance.delete(assignmentId)" in repo and "removeCachedAssignments" in repo,
        "assignment deletion must remove authoritative remote work and local cache")
require('"COMPLETED".equals(assignment.status)' in backend and "已完成作业不能删除" in backend,
        "backend must reject completed assignment deletion")
require("delete unfinished assignment" in e2e and "completed assignment delete rejection" in e2e,
        "real backend E2E must cover unfinished deletion and completed-delete rejection")
for token in [
    "@State private bulkMode",
    "@State private selectedDeleteIds",
    "private selectAllDeletable()",
    "private async deleteSelectedAssignments(): Promise<void>",
    "this.viewModel.deleteAssignments(ids)",
    "全选当前",
    "确认删除",
    ".bindSheet($$this.showDeleteSheet",
]:
    require(token in progress, f"parent progress missing bulk delete behavior: {token}")
require("deleteAssignments(assignmentIds: string[])" in progress_vm,
        "parent progress ViewModel must delegate batch deletion")
require("删除作业" in review and "this.viewModel.deleteAssignment(item.id)" in review,
        "parent detail must allow single unfinished assignment deletion")
require("deleteAssignment(assignmentId: string)" in review_vm,
        "parent review ViewModel must delegate deletion")
require("onDeleted" in review_page and "onDeleted" in review and "this.navPathStack.pop()" in shell,
        "phone parent review must return after assignment deletion")

# Import -> confirmation: only one explicit confirmation remains.
require("this.onOpenConfirmation()" in import_page and "private afterOrganized(candidateCount: number)" in import_page,
        "organized homework must navigate directly to final confirmation")
require("CandidatePane" not in import_page and "继续确认" not in import_page,
        "redundant intermediate confirmation layer must be removed")
require("确认并发布" in confirmation and "ConfirmationCandidateCard" in confirmation,
        "final confirmation page must retain review/edit/publish behavior")

# Voice/image assignment workspace must support touch paging inline and fullscreen.
require("Swiper()" in voice and ".onChange((index: number) => { void this.showImage(index); })" in voice,
        "inline assignment images must support swipe paging")
require("Swiper()" in study and "this.voiceSelectImage(index)" in study,
        "fullscreen assignment images must support swipe paging")

# Homework submission supports both gallery and system camera without persistent CAMERA permission.
require("photoAccessHelper.PhotoViewPicker" in submission,
        "homework submission must retain gallery picker")
require("cameraPicker.pick" in submission and "cameraPicker.PickerMediaType.PHOTO" in submission,
        "homework submission must support camera picker")
require("captureSubmissionPhoto" in study and "从图库选择" in study and "拍照" in study,
        "student workspace must expose gallery and camera actions")
require("appendSubmissionPhotos" in study and "next.length >= 6" in study,
        "gallery and camera photos must share the six-photo cap")
require("ohos.permission.CAMERA" not in module,
        "system camera picker must not introduce persistent CAMERA permission")

# Compiler safety for the recently fragile ArkTS binding pattern.
for text, path in [
    (progress, "ParentProgressPage.ets"),
    (review, "ParentReviewPane.ets"),
    (study, "StudyWorkspacePage.ets"),
    (voice, "VoiceAssignmentPane.ets"),
]:
    require("$this" not in text.replace("$$this", ""),
            f"invalid single-dollar this binding found in {path}")

require("Validate parent delete and study media enhancements" in workflow and
        "python scripts/validate_parent_delete_study_media.py" in workflow,
        "CI must run this feature regression gate")

if errors:
    print("PARENT_DELETE_STUDY_MEDIA_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PARENT_DELETE_STUDY_MEDIA_GATE_PASS")
