#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def read(path: str) -> str:
    file = ROOT / path
    if not file.exists():
        errors.append(f"missing file: {path}")
        return ""
    return file.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


parser = read("entry/src/main/ets/infrastructure/ai/LocalHomeworkAssignmentParser.ets")
task_date = read("entry/src/main/ets/domain/service/AssignmentTaskDate.ets")
confirmation = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
confirmation_components = read(
    "entry/src/main/ets/features/parent/confirmation/ConfirmationCandidateComponents.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
confirmation_vm = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationViewModel.ets")
cases = read("docs/development/v0.2-parser-confirmation-cases.md")

require("splitTaskBodies" in parser, "parser must split multiple tasks inside one subject segment")
require("isNonHomeworkNotice" in parser, "parser must filter non-homework notices")
require("learningLocation" in parser, "parser must extract lesson/page/unit context")
for word in ["背诵", "听读", "口算", "订正", "默写", "预习", "复习"]:
    require(word in parser, f"parser missing common homework action: {word}")
for word in ["带书", "缴费", "穿校服", "家长会"]:
    require(word in parser, f"parser missing notice filter keyword: {word}")
require("AssignmentTaskDate.resolve" in parser,
        "parser must delegate task-date normalization to the shared AssignmentTaskDate service")
for marker in ["resolveWeekday", "下周|下星期|本周|本星期|这周|这星期|周|星期",
               "(\\d{1,2})月(\\d{1,2})"]:
    require(marker in task_date, f"task-date parser missing support marker: {marker}")

require("updateCandidate(candidate" in store, "HomeworkStore must support full candidate updates")
require("addCandidate(candidate" in store, "HomeworkStore must support manually adding a candidate")

for capability in ["saveCandidate", "addCandidate", "ConfirmationCandidateEditor", "CandidateEditorSheet"]:
    require(capability in confirmation, f"confirmation page missing capability: {capability}")
for capability in ["subjectDraft", "titleDraft", "taskDateDraft", "textbookRefDraft",
                   "buildCandidate", "saveAndClose", "confirmDiscard"]:
    require(capability in confirmation_components,
            f"confirmation editor missing staged-edit capability: {capability}")
require("ChoiceSelectionChip" in confirmation_components,
        "confirmation editor must expose reactive subject/duration choices")
require("手工新增一项" in confirmation, "confirmation page must expose manual candidate creation")
require("createManualCandidateDraft" in confirmation_vm and
        "addCandidate(candidate: CandidateAssignment): boolean" in confirmation_vm and
        "@State private manualCandidateDraft: CandidateAssignment | null = null;" in confirmation,
        "manual candidate creation must remain transient until explicit Save")
require(cases.count("### CASE-") >= 20, "V0.2 regression catalog must contain at least 20 cases")

if errors:
    print("V02_PARSER_CONFIRMATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V02_PARSER_CONFIRMATION_GATE_PASS")
