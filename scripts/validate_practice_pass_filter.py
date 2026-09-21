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
policy = read("entry/src/main/ets/domain/service/PracticePassPolicy.ets")
dialog = read("entry/src/main/ets/components/practice/PracticeFilterDialog.ets")
home = read("entry/src/main/ets/features/student/practice/PracticeHomePage.ets")
view_model = read("entry/src/main/ets/features/student/practice/PracticeHomeViewModel.ets")

for token in [
    "export enum PracticePassFilter",
    "PASSED = 'PASSED'",
    "NOT_PASSED = 'NOT_PASSED'",
    "static passFilterLabel(filter: PracticePassFilter)",
]:
    require(token in models, f"practice pass filter model missing: {token}")

require("static readonly PASS_PERCENT: number = 60;" in policy,
        "practice pass threshold must remain centralized at 60 percent")
require("item.status !== PracticeAttemptStatus.SUBMITTED" in policy and
        "item.mode !== PracticeAttemptMode.FULL" in policy,
        "only submitted full-paper attempts may pass the whole paper")
require("item.score * 100 >= item.maxScore * PracticePassPolicy.PASS_PERCENT" in policy,
        "practice pass policy must compare normalized score against the shared threshold")
require("paper.id, paper.version" in policy and "item.paperId, item.paperVersion" in policy,
        "pass state must bind to immutable paper id + version")

for token in [
    "@Link selectedPassFilter: PracticePassFilter",
    "Text('通过状态')",
    "PassOption(PracticePassFilter.ALL)",
    "PassOption(PracticePassFilter.PASSED)",
    "PassOption(PracticePassFilter.NOT_PASSED)",
    "PracticeTaxonomy.passFilterLabel(filter)",
]:
    require(token in dialog, f"practice filter dialog missing pass-status behavior: {token}")

for token in [
    "@State private selectedPassFilter: PracticePassFilter = PracticePassFilter.ALL",
    "label: '通过状态'",
    "active: this.selectedPassFilter !== PracticePassFilter.ALL",
    "@Prop passed: boolean = false",
    "Text('已通过')",
    "passed: this.viewModel.isPaperPassed(paper, this.passedPaperKeys)",
    "filterByPass(",
]:
    require(token in home or token in view_model, f"practice home missing pass filter/tag behavior: {token}")

require("listAttempts(this.familyContext.getActiveStudentId(), '')" in view_model,
        "pass status must use the active student's own practice history")
require("PracticePassPolicy.passedPaperKeys(attempts)" in view_model and
        "PracticePassPolicy.isPaperPassed(paper, passedPaperKeys)" in view_model,
        "filter and tag must share PracticePassPolicy")

require(".layoutWeight(1)" in home and
        ".textOverflow({ overflow: TextOverflow.Ellipsis })" in home and
        ".constraintSize({ minWidth: 64 })" in home and
        ".textAlign(TextAlign.End)" in home,
        "practice paper-list header must preserve count visibility on narrow Phone layouts")

if errors:
    print("PRACTICE_PASS_FILTER_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("PRACTICE_PASS_FILTER_GATE_PASS")
