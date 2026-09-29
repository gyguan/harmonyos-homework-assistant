#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)

submission = read("entry/src/main/ets/application/submission/HomeworkSubmissionService.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
attention = read("entry/src/main/ets/domain/service/AssignmentAttentionPolicy.ets")
due_date = read("entry/src/main/ets/domain/service/AssignmentDueDate.ets")
student_vm = read("entry/src/main/ets/features/student/home/StudentHomeViewModel.ets")
student_home = read("entry/src/main/ets/features/student/home/StudentHomePage.ets")
parent_home = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
student_assignments = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets")
parent_progress = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")
app_shell = read("entry/src/main/ets/pages/AppShell.ets")
result_vm = read("entry/src/main/ets/features/student/practice/PracticeResultViewModel.ets")
result_page = read("entry/src/main/ets/features/student/practice/PracticeResultPage.ets")
module_config = read("entry/src/main/module.json5")

require("@kit.ImageKit" in submission and "async preflight(" in submission and "getImageInfo(0)" in submission and
        "fileIo.statSync(source.fd)" in submission and "seenUris" in submission,
        "submission flow must check readability, file size, dimensions and duplicate selections")
require(study.find("HomeworkSubmissionService.instance.preflight") <
        study.find("HomeworkSubmissionService.instance.submit"),
        "photo preflight must execute before submission")
require("class AssignmentAttentionPolicy" in attention and "AssignmentAttentionPolicy.student" in student_vm and
        "AssignmentDueDate.matches" in attention and "DueDateFilterKey.OVERDUE" in attention,
        "attention must reuse the canonical due-date policy for overdue detection")
require("if (item.dueAtEpochMs > 0) return item.dueAtEpochMs <= nowEpochMs;" in due_date,
        "canonical overdue detection must honor precise dueAt time, not only calendar day")
require("AttentionBanner" in student_home and "AttentionBanner" in parent_home,
        "attention must stay embedded in existing home pages")
require("AssignmentAttentionKind" in attention and "studentResult" in attention and "parentResult" in attention and
        "static filter(" in attention and "static label(" in attention,
        "attention policy must expose one shared navigation/filter contract")
require("onOpenAttention" in student_home and "onOpenAttention" in parent_home and
        "accessibilityRole(AccessibilityRoleType.BUTTON)" in student_home and
        "accessibilityRole(AccessibilityRoleType.BUTTON)" in parent_home,
        "attention banners must be actionable without adding a new page")
require("openStudentAttention" in app_shell and "openParentAttention" in app_shell and
        "studentAttentionKind" in app_shell and "parentAttentionKind" in app_shell,
        "AppShell must carry attention context into existing assignment root pages")
require("attentionKind: AssignmentAttentionKind" in student_assignments and
        "AttentionFilterBanner" in student_assignments and
        "AssignmentAttentionPolicy.filter" in student_assignments and
        "onAttentionFilterCleared" in student_assignments,
        "student reminder navigation must open the existing assignment list with a visible default filter")
require("attentionKind: AssignmentAttentionKind" in parent_progress and
        "AttentionFilterBanner" in parent_progress and
        "AssignmentAttentionPolicy.filter" in parent_progress and
        "onAttentionFilterCleared" in parent_progress,
        "parent reminder navigation must open student assignments with a visible default filter")
require("questionCount: 5" in result_vm and "PracticePublishPurpose.REINFORCEMENT" in result_vm and
        "retryWrongAttempt(attemptId, 5)" in result_vm and "let studentId = attempt.studentId" in result_vm and
        "reinforcementGenerationId" in result_vm and "reinforcementPaperId" in result_vm,
        "reinforcement must be bounded, student-bound and recover publish/start retries")
require("'再巩固'" in result_page and "再挑战 ${this.result.wrongCount} 道错题" not in result_page,
        "result page must expose one simple reinforcement action without over-promising fallback count")
practice_paper_repository = read("backend/src/main/java/com/xiaoban/homework/practice/PracticePaperRepository.java")
attempt_service = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeAttemptService.java")
require("AI_REINFORCEMENT" in practice_paper_repository and "source_type <> 'AI_REINFORCEMENT'" in practice_paper_repository,
        "reinforcement papers must stay out of the normal practice catalog")
require("sourceAttemptId" in attempt_service and
        "findFirstByFamilyIdAndStudentIdAndPaperIdAndPaperVersionAndSourceAttemptIdAndStatusOrderByStartedAtDesc" in attempt_service,
        "reinforcement start must recover an existing in-progress attempt after lost responses")
require("PUBLISH_AGENT_REMINDER" not in module_config,
        "issue 370 must not introduce privileged reminder permissions")

if errors:
    print("ISSUE370_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE370_GATE_PASS")
