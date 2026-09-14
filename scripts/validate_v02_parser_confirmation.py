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
confirmation = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
cases = read("docs/development/v0.2-parser-confirmation-cases.md")

require("splitTaskBodies" in parser, "parser must split multiple tasks inside one subject segment")
require("isNonHomeworkNotice" in parser, "parser must filter non-homework notices")
require("learningLocation" in parser, "parser must extract lesson/page/unit context")
for word in ["背诵", "听读", "口算", "订正", "默写", "预习", "复习"]:
    require(word in parser, f"parser missing common homework action: {word}")
for word in ["带书", "缴费", "穿校服", "家长会"]:
    require(word in parser, f"parser missing notice filter keyword: {word}")
for due in ["周五", "星期五", "月\\d{1,2}"]:
    require(due in parser, f"parser missing due-date support marker: {due}")

require("updateCandidate(candidate" in store, "HomeworkStore must support full candidate updates")
require("addCandidate(candidate" in store, "HomeworkStore must support manually adding a candidate")

for capability in ["updateSubject", "updateTitle", "updateDueText", "updateTextbookRef", "addCandidate", "SubjectChip"]:
    require(capability in confirmation, f"confirmation page missing capability: {capability}")
require("手工新增一项" in confirmation, "confirmation page must expose manual candidate creation")
require(cases.count("### CASE-") >= 20, "V0.2 regression catalog must contain at least 20 cases")

if errors:
    print("V02_PARSER_CONFIRMATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V02_PARSER_CONFIRMATION_GATE_PASS")
