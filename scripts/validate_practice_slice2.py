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
detail = read("entry/src/main/ets/features/student/practice/PracticePaperDetailPage.ets")
attempt_page = read("entry/src/main/ets/features/student/practice/PracticeAttemptPage.ets")
result_page = read("entry/src/main/ets/features/student/practice/PracticeResultPage.ets")
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
require("下一题" in attempt_page and "交卷" in attempt_page and "saveCurrent" in attempt_page,
        "attempt page must save answers and support navigation")
require("PracticeQuestionVisual" not in attempt_page and "visualSpec" not in attempt_page,
        "attempt page must stay text-only")
require("PracticeSubmitConfirmDialog" in attempt_page and "unansweredCount" in attempt_page,
        "submission must handle unanswered questions")
require("答题回顾" in result_page and "正确答案" in result_page,
        "submitted result must expose review")

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
