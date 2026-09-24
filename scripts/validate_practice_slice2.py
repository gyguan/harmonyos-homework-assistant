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


theme = read("entry/src/main/ets/common/theme/AppTheme.ets")
models = read("entry/src/main/ets/domain/model/practice/PracticeModels.ets")
repo = read("entry/src/main/ets/domain/port/PracticeRepository.ets")
remote = read("entry/src/main/ets/application/remote/PracticeRemoteApi.ets")
home = read("entry/src/main/ets/features/student/practice/PracticeHomePage.ets")
detail = read("entry/src/main/ets/features/student/practice/PracticePaperDetailPage.ets")
detail_vm = read("entry/src/main/ets/features/student/practice/PracticePaperDetailViewModel.ets")
attempt_page = read("entry/src/main/ets/features/student/practice/PracticeAttemptPage.ets")
result_page = read("entry/src/main/ets/features/student/practice/PracticeResultPage.ets")
result_vm = read("entry/src/main/ets/features/student/practice/PracticeResultViewModel.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
migration = read("backend/src/main/resources/db/migration/V9__practice_core.sql")
track_migration = read("backend/src/main/resources/db/migration/V14__practice_paper_track.sql")
controller = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeController.java")
service = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeAttemptService.java")
judge = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeJudgeEngine.java")
dtos = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeDtos.java")
bootstrap = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeContentBootstrap.java")
e2e = read("backend/scripts/practice_e2e.py")

for token in ["PracticeAttempt", "PracticeAnswer", "PracticeResult", "PracticeAttemptStatus"]:
    require(token in models, f"Practice Slice 2 domain missing {token}")

for method in ["startAttempt", "getAttempt", "saveAnswer", "submitAttempt", "getResult"]:
    require(method in repo, f"PracticeRepository missing execution method {method}")
    require(method in remote, f"PracticeRemoteApi missing execution method {method}")

require("onOpenPaper" in home and "onOpen: () => this.onOpenPaper" in home,
        "practice paper cards must open detail")
require("开始练习" in detail and "viewModel.start" in detail,
        "paper detail must create server attempt")
require("DeepPageHeader" in detail and "Text('‹')" not in detail,
        "Practice paper detail must use the shared DeepPageHeader")
require("我的练习记录" in detail and "recentAttempts" in detail and "查看全部" in detail,
        "Practice paper detail must expose recent per-paper history")
require("onOpenAttempt" in detail and "onOpenResult" in detail and "onOpenHistory" in detail,
        "Practice paper detail history cards must reuse existing attempt/result/history navigation")
require("listAttempts(paperId: string)" in detail_vm and
        "repository.listAttempts(this.familyContext.getActiveStudentId(), paperId)" in detail_vm,
        "Practice paper detail must query history through the existing paperId repository contract")
require("attempts.slice(0, 3)" in detail_vm,
        "Practice paper detail must limit the embedded history to the latest three attempts")
require("下一题" in attempt_page and "交卷" in attempt_page and "saveCurrent" in attempt_page,
        "attempt page must save answers and support navigation")
require("DeepPageHeader" in attempt_page and "Text('‹')" not in attempt_page,
        "Practice attempt deep page must use the shared DeepPageHeader")
require("availableWidthVp" in attempt_page and "ResponsiveContext.areaLengthToVp" in attempt_page,
        "Practice attempt must derive readability from actual available container width")
require("contentScale()" in attempt_page and "AppTheme.PRACTICE_ATTEMPT_MAX_SCALE" in attempt_page,
        "Practice attempt must use bounded continuous scaling for wide-container readability")
require("AppTheme.CONTENT_STANDARD_MAX_WIDTH" in attempt_page,
        "Practice attempt content must use the shared standard readable-width token")
require(".fontSize(this.scaled(AppTheme.QUESTION_TEXT_SIZE))" in attempt_page and
        ".lineHeight(this.scaled(AppTheme.QUESTION_TEXT_LINE_HEIGHT))" in attempt_page and
        ".height(this.scaled(50))" in attempt_page,
        "Practice attempt must scale semantic question typography and answer controls together")
require("CONTENT_STANDARD_MAX_WIDTH" in theme and
        "PRACTICE_ATTEMPT_SCALE_REFERENCE_WIDTH" in theme and
        "PRACTICE_ATTEMPT_MAX_SCALE" in theme and
        "QUESTION_TEXT_SIZE" in theme and
        "QUESTION_TEXT_LINE_HEIGHT" in theme,
        "AppTheme must own Practice attempt readability and question typography tokens")
require("private CurrentQuestionAnswer()" in attempt_page,
        "choice rendering must derive directly from reactive currentIndex state")
require("this.attempt.questions[this.currentIndex].options" in attempt_page,
        "choice rendering must bind option data directly to currentIndex")
require("private QuestionAnswer(question: PracticeQuestion)" not in attempt_page,
        "parameterized question Builder can retain stale question snapshots")
require("private OptionButton(option: PracticeQuestionOption)" not in attempt_page,
        "parameterized option Builder can retain stale option snapshots")
require("${this.currentIndex}:${option.key}:${option.label}" in attempt_page,
        "choice option identity must include current question state and option content")
require("PracticeQuestionVisual" not in attempt_page and "visualSpec" not in attempt_page,
        "attempt page must stay text-only")
require("PracticeSubmitConfirmDialog" in attempt_page and "unansweredCount" in attempt_page,
        "submission must handle unanswered questions")
require("答题回顾" in result_page and "正确答案" in result_page,
        "submitted result must expose review")
require("DeepPageHeader" in result_page and "Text('完成')" not in result_page,
        "Practice result must use the shared back header instead of a Done action")
require("subtitle: this.headerSubtitle()" in result_page and "paperTitle" in result_page,
        "Practice result header must identify the paper and attempt")
require("paperTitle(result: PracticeResult)" in result_vm and "item.paperTitle" in result_vm,
        "Practice result must resolve the paper title without changing backend result DTOs")
require("replacePracticeAttemptWithResult" in shell and
        "onSubmitted: (attemptId: string) => this.replacePracticeAttemptWithResult(attemptId)" in shell,
        "Submitting practice must replace the completed attempt route with the result route")

for route in ["STUDENT_PRACTICE_PAPER", "STUDENT_PRACTICE_ATTEMPT", "STUDENT_PRACTICE_RESULT"]:
    require(route in routes and route in shell, f"practice deep route missing: {route}")

for table in ["practice_paper", "practice_question", "practice_attempt", "practice_answer"]:
    require(f"create table if not exists {table}" in migration,
            f"V9 migration missing {table}")
require("add column if not exists track" in track_migration,
        "V14 must persist practice paper track")

for endpoint in [
    '/students/{studentId}/practice/attempts',
    '/practice/attempts/{attemptId}',
    '/practice/attempts/{attemptId}/answers/{questionId}',
    '/practice/attempts/{attemptId}/submit',
    '/practice/attempts/{attemptId}/result',
]:
    require(endpoint in controller, f"PracticeController missing endpoint {endpoint}")

require('"IN_PROGRESS"' in service and '"SUBMITTED"' in service,
        "PracticeAttemptService must enforce lifecycle")
require("PracticeJudgeEngine" in service and "isCorrect" in judge,
        "scoring must use deterministic JudgeEngine")
question_dto = dtos.split("public record QuestionResponse", 1)[1].split("public record StartRequest", 1)[0]
require("answerSpec" not in question_dto and "explanation" not in question_dto,
        "QuestionResponse must not leak answers before submission")
require("visualSpec" not in question_dto,
        "QuestionResponse must not carry retired visual data")
require("String track" in dtos.split("public record PaperResponse", 1)[1].split("public record QuestionResponse", 1)[0],
        "PaperResponse must expose catalog type")
require("archiveRetiredPresets" in bootstrap and 'paper.status = "ARCHIVED"' in bootstrap,
        "bootstrap must archive old presets while preserving history")
require("shard.track().equals(paper.track())" in bootstrap,
        "bootstrap must enforce shard/Paper track consistency")
require("PRACTICE_E2E_PASS" in e2e and "retired practice paper must be unavailable" in e2e,
        "real E2E must verify old catalog retirement")
require("TEXTBOOK_SYNC" in e2e and "EXTRACURRICULAR" in e2e,
        "real E2E must verify both catalog types")
require("reject answer mutation after practice submission" in e2e,
        "real E2E must cover immutable submitted attempts")

if errors:
    print("PRACTICE_SLICE2_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PRACTICE_SLICE2_GATE_PASS")
