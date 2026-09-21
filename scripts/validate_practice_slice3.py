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
history_filter = read("entry/src/main/ets/domain/model/PracticeHistoryFilter.ets")
history_filter_dialog = read("entry/src/main/ets/components/practice/PracticeHistoryFilterDialog.ets")
detail_page = read("entry/src/main/ets/features/student/practice/PracticePaperDetailPage.ets")
detail_vm = read("entry/src/main/ets/features/student/practice/PracticePaperDetailViewModel.ets")
pass_policy = read("entry/src/main/ets/domain/service/PracticePassPolicy.ets")
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
require("PracticeAttemptSummary" in history and "item.attemptNo" in history and
        "item.id" in history,
        "Practice history page must present immutable per-attempt records without relying on explanatory copy")
require("DeepPageHeader" in history and "Text('‹')" not in history,
        "Practice history deep page must use the shared DeepPageHeader")
require("selectedSubject" in history and "selectedTime" in history and "selectedPass" in history,
        "Practice history must expose subject, time and pass filters")
require("selectedStatus" not in history and "PracticeHistoryStatusFilter" not in history,
        "Practice history must not keep the redundant completion-status filter")
require("FilterSummaryEntry" in history and "PracticeHistoryFilterDialog" in history,
        "Practice history filters must reuse the shared summary-entry + bottom-sheet pattern")
require("PracticeHistoryTimeFilter" in history_filter and "LAST_7_DAYS" in history_filter and
        "LAST_30_DAYS" in history_filter and "LAST_90_DAYS" in history_filter,
        "Practice history time filter must support all/7/30/90-day ranges")
for token in ["科目", "时间", "通过状态", "重置", "确定"]:
    require(token in history_filter_dialog, f"Practice history filter dialog missing {token}")
require("完成耗时 " in history and "elapsedText(item.elapsedSeconds)" in history,
        "Submitted practice history must label completion elapsed time explicitly")
require("recordStatusLabel(item)" in history and "statusLabel(item)" not in history and "passLabel(item)" not in history,
        "Practice history cards must keep one consolidated status badge")
require("完成耗时 " in detail_page and "recordStatusLabel(item)" in detail_page and
        "statusLabel(item)" not in detail_page and "passLabel(item)" not in detail_page,
        "Paper detail recent attempts must keep one consolidated status badge plus completion duration")
require("PracticePassPolicy" in history_vm and "PracticePassPolicy" in detail_vm,
        "History pass state must reuse the shared PracticePassPolicy")
require("PASS_PERCENT: number = 60" in pass_policy and
        "item.mode !== PracticeAttemptMode.FULL" in pass_policy,
        "Practice history pass display must preserve the shared 60% full-paper policy")
require("'进行中'" in history_vm and "'已通过'" in history_vm and "'未通过'" in history_vm and
        "'专项练习'" in history_vm,
        "Practice history must consolidate record state into in-progress/passed/not-passed/special labels")
require("matchesTime" in history_vm and "matchesPass" in history_vm and "matchesSubject" in history_vm,
        "Practice history filtering must compose subject, time and pass predicates")
require("PracticePassPolicy.matchesAttemptPassFilter(item, pass)" in history_vm,
        "Practice history must delegate pass filtering to the shared policy")
require("static matchesAttemptPassFilter(item: PracticeAttemptSummary, filter: PracticePassFilter)" in pass_policy and
        "item.mode !== PracticeAttemptMode.FULL" in pass_policy,
        "Pass filters must exclude wrong-only attempts from passed/not-passed classifications")
require("PracticeHistoryStatistics" in history_vm and "statistics(" in history_vm,
        "Practice history ViewModel must own lightweight statistics")
require("this.statistics = this.viewModel.statistics(this.attempts)" in history,
        "Practice history statistics must follow the current filtered result set")
require("item.status !== PracticeAttemptStatus.SUBMITTED" in history_vm,
        "Practice history statistics must exclude unsubmitted attempts")
require("totalQuestions += item.maxScore" in history_vm and
        "totalCorrect * 100 / totalQuestions" in history_vm,
        "Practice history correct rate must use weighted completed-question totals")
require("totalElapsedSeconds / completedCount" in history_vm,
        "Practice history average elapsed time must only use completed attempts")
require("基于当前筛选" in history and "完成次数" in history and "平均耗时" in history,
        "Practice history statistics summary must make filtered scope and metrics explicit")
require(history.find("this.StatisticsCard();") < history.find("this.FilterBar();"),
        "Practice history statistics must appear above the filter bar")
require("@Prop paperId: string = '';" in history and "viewModel.list(this.paperId)" in history,
        "Practice history page must support a paper-scoped query without a second page implementation")
require("if (!this.isPaperScoped())" in history and "showSubject: false" in history and "当前套卷" in history,
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
