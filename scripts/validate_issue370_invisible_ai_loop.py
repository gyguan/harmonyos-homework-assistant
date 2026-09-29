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
student_vm = read("entry/src/main/ets/features/student/home/StudentHomeViewModel.ets")
student_home = read("entry/src/main/ets/features/student/home/StudentHomePage.ets")
parent_home = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
result_vm = read("entry/src/main/ets/features/student/practice/PracticeResultViewModel.ets")
result_page = read("entry/src/main/ets/features/student/practice/PracticeResultPage.ets")
module_config = read("entry/src/main/module.json5")

require("@kit.ImageKit" in submission and "async preflight(" in submission and "getImageInfo(0)" in submission,
        "submission flow must keep local photo preflight")
require(study.find("HomeworkSubmissionService.instance.preflight") <
        study.find("HomeworkSubmissionService.instance.submit"),
        "photo preflight must execute before submission")
require("class AssignmentAttentionPolicy" in attention and "AssignmentAttentionPolicy.student" in student_vm,
        "student attention must stay a small policy over existing assignments")
require("AttentionBanner" in student_home and "AttentionBanner" in parent_home,
        "attention must stay embedded in existing home pages")
require("questionCount: 5" in result_vm and "PracticePublishScope.CURRENT" in result_vm and
        "retryWrongAttempt(attemptId)" in result_vm,
        "five-question reinforcement must generate for current student and retain wrong-only fallback")
require("'再练 5 题'" in result_page and "再挑战 ${this.result.wrongCount} 道错题" not in result_page,
        "result page must expose one simple reinforcement action")
require("PUBLISH_AGENT_REMINDER" not in module_config,
        "issue 370 must not introduce privileged reminder permissions")

if errors:
    print("ISSUE370_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE370_GATE_PASS")
