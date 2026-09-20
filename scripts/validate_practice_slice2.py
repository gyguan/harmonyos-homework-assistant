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
        "practice paper cards must open the detail flow")
require("开始练习" in detail and "viewModel.start" in detail,
        "practice paper detail must create a server attempt")
require("下一题" in attempt_page and "交卷" in attempt_page and "saveCurrent" in attempt_page,
        "practice attempt page must save answers and support continuous navigation")
require("PracticeSubmitConfirmDialog" in attempt_page and "unansweredCount" in attempt_page,
        "practice submission must explicitly handle unanswered questions")
require("答题回顾" in result_page and "正确答案" in result_page,
        "practice result must expose review after submission")

for route in ["STUDENT_PRACTICE_PAPER", "STUDENT_PRACTICE_ATTEMPT", "STUDENT_PRACTICE_RESULT"]:
    require(route in routes and route in shell, f"practice deep route missing: {route}")

for table in ["practice_paper", "practice_question", "practice_attempt", "practice_answer"]:
    require(f"create table if not exists {table}" in migration,
            f"V9 practice migration missing {table}")

for endpoint in [
    '/students/{studentId}/practice/attempts',
    '/practice/attempts/{attemptId}',
    '/practice/attempts/{attemptId}/answers/{questionId}',
    '/practice/attempts/{attemptId}/submit',
    '/practice/attempts/{attemptId}/result',
]:
    require(endpoint in controller, f"PracticeController missing endpoint {endpoint}")

require('"IN_PROGRESS"' in service and '"SUBMITTED"' in service,
        "PracticeAttemptService must enforce attempt lifecycle")
require("PracticeJudgeEngine" in service and "isCorrect" in judge,
        "practice scoring must use deterministic server JudgeEngine")
require("question.answerSpec" in service and "question.explanation" in service,
        "submitted result must be derived from authoritative server content")
require("answerSpec" not in dtos.split("public record QuestionResponse", 1)[1].split("public record StartRequest", 1)[0],
        "QuestionResponse must not leak answerSpec before submission")
require("explanation" not in dtos.split("public record QuestionResponse", 1)[1].split("public record StartRequest", 1)[0],
        "QuestionResponse must not leak explanation before submission")
require("PRESET_MANIFEST" in bootstrap and "PracticeContentCatalog.Shard" in bootstrap and
        "validator.validateCatalog(catalog)" in bootstrap,
        "server Practice content must come from validated grade/subject shards")
require("mathQuestions(" not in bootstrap and "chineseQuestions(" not in bootstrap and
        "englishQuestions(" not in bootstrap,
        "server Practice bootstrap must not regenerate paper questions in Java")
require("PRACTICE_E2E_PASS" in e2e and "reject answer mutation after practice submission" in e2e,
        "real Practice E2E must cover immutable submitted attempts")
require("reject cross-grade practice attempt" in e2e and "audiencePolicy.requireFreshStartAllowed" in service,
        "Practice fresh-start E2E must reject cross-grade papers")

if errors:
    print("PRACTICE_SLICE2_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PRACTICE_SLICE2_GATE_PASS")
