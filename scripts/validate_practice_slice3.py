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


models = read("entry/src/main/ets/domain/model/practice/PracticeModels.ets")
repo = read("entry/src/main/ets/domain/port/PracticeRepository.ets")
remote = read("entry/src/main/ets/application/remote/PracticeRemoteApi.ets")
home = read("entry/src/main/ets/features/student/practice/PracticeHomePage.ets")
history = read("entry/src/main/ets/features/student/practice/PracticeHistoryPage.ets")
history_vm = read("entry/src/main/ets/features/student/practice/PracticeHistoryViewModel.ets")
attempt_page = read("entry/src/main/ets/features/student/practice/PracticeAttemptPage.ets")
result_page = read("entry/src/main/ets/features/student/practice/PracticeResultPage.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
migration = read("backend/src/main/resources/db/migration/V10__practice_history_repeat.sql")
attempt_entity = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeAttemptEntity.java")
attempt_service = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeAttemptService.java")
controller = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeController.java")
student_service = read("backend/src/main/java/com/xiaoban/homework/student/StudentService.java")
e2e = read("backend/scripts/practice_e2e.py")

for token in ["PracticeAttemptSummary", "PracticePreviousAnswer", "sourceAttemptId", "previousAnswers"]:
    require(token in models, f"Practice Slice 3 model missing {token}")

for method in ["listAttempts", "repeatAttempt"]:
    require(method in repo, f"PracticeRepository missing {method}")
    require(method in remote, f"PracticeRemoteApi missing {method}")

require("练习记录" in home and "onOpenHistory" in home,
        "Practice home must expose a compact history entry")
require("每次开始练习都会创建独立实例" in history and "PracticeAttemptSummary" in history,
        "Practice history page must present immutable per-attempt records")
require("DeepPageHeader" in history and "Text('‹')" not in history,
        "Practice history deep page must use the shared DeepPageHeader")
require("selectedStatus" in history and "selectedSubject" in history,
        "Practice history must expose simple status and subject filters")
require("耗时 " in history and "elapsedText(item.elapsedSeconds)" in history,
        "Submitted practice history must label elapsed time explicitly")
require("PracticeHistoryStatistics" in history_vm and "statistics(" in history_vm,
        "Practice history ViewModel must own lightweight statistics")
require("item.status !== PracticeAttemptStatus.SUBMITTED" in history_vm,
        "Practice history statistics must exclude unsubmitted attempts")
require("totalQuestions += item.maxScore" in history_vm and
        "totalCorrect * 100 / totalQuestions" in history_vm,
        "Practice history correct rate must use weighted completed-question totals")
require("totalElapsedSeconds / completedCount" in history_vm,
        "Practice history average elapsed time must only use completed attempts")
require("showStatistics" in history_vm and "IN_PROGRESS" in history_vm,
        "Practice history must hide statistics for the in-progress-only filter")
require("@Prop paperId: string = '';" in history and "viewModel.list(this.paperId)" in history,
        "Practice history page must support a paper-scoped query without a second page implementation")
require("if (!this.isPaperScoped())" in history and "当前套卷" in history,
        "Paper-scoped practice history must hide the redundant subject filter and identify its scope")
history_route = routes.split("export class PracticeHistoryRouteParam", 1)[1].split("export class PracticePaperRouteParam", 1)[0]
require("paperId: string;" in history_route and "constructor(paperId: string = '')" in history_route,
        "PracticeHistoryRouteParam must carry an optional paperId scope")
require("new PracticeHistoryRouteParam(paperId)" in shell and
        "paperId: (param as PracticeHistoryRouteParam).paperId" in shell,
        "Practice history navigation must preserve the optional paperId scope")
require("onOpenHistory: (paperId: string) => this.openPracticeHistory(paperId)" in shell,
        "Practice paper detail must route View All to the scoped history page")
require("showPreviousAnswer: boolean = false" in attempt_page,
        "repeat practice must hide previous answers by default")
require("显示上次作答" in attempt_page and "previousAnswerFor" in attempt_page,
        "repeat practice must allow explicit previous-answer display")
require("再练一遍" in result_page and "viewModel.repeat" in result_page,
        "submitted result must support creating a new repeat attempt")
require("STUDENT_PRACTICE_HISTORY" in routes and "STUDENT_PRACTICE_HISTORY" in shell,
        "Practice history must be a deep route, not inline state in the home page")
require("onRepeatStarted" in result_page and "onRepeatStarted" in shell,
        "repeat result flow must navigate to the new attempt instance")
require("replacePracticeResultWithAttempt" in shell and
        "onRepeatStarted: (attemptId: string) => this.replacePracticeResultWithAttempt(attemptId)" in shell,
        "repeat and wrong-only flows must replace the old result route instead of stacking it")
require("onBack: () => this.navPathStack.pop()" in shell,
        "Practice result back action must preserve the caller navigation context")

# ArkTS declarations/routes must stay explicitly typed.
require("listAttempts(studentId: string, paperId: string = '')" not in repo,
        "PracticeRepository interface methods must not use parameter initializers")
require("PracticeHistoryRouteParam" in routes and "new PracticeHistoryRouteParam(paperId)" in shell,
        "Practice history route must use an explicitly declared parameter class")
require("STUDENT_PRACTICE_HISTORY, {})" not in shell,
        "Practice navigation must not pass untyped object literals")

require("source_attempt_id" in migration and "sourceAttemptId" in attempt_entity,
        "practice attempt lineage must be persisted")
require('/students/{studentId}/practice/attempts' in controller and
        '/practice/attempts/{attemptId}/repeat' in controller,
        "PracticeController must expose history and repeat endpoints")
require("source.questionIdsJson" in attempt_service and "source.paperVersion" in attempt_service,
        "repeat must preserve the exact source paper version and frozen question set")
require("previousAnswers(attempt)" in attempt_service,
        "repeat attempt response must expose prior student answers separately")
require("practiceAttempts.existsByFamilyIdAndStudentId" in student_service,
        "student deletion must protect persisted practice history")

for phrase in [
    "list practice history by paper",
    "repeat submitted practice attempt",
    "repeat did not preserve sourceAttemptId lineage",
    "repeating practice must never mutate the source result",
    "student deletion rejects persisted practice history",
]:
    require(phrase in e2e, f"Practice E2E missing Slice 3 coverage: {phrase}")

if errors:
    print("PRACTICE_SLICE3_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PRACTICE_SLICE3_GATE_PASS")
