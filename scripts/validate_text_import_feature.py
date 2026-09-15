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


page = read("entry/src/main/ets/features/parent/import/HomeworkImportPage.ets")
service = read("entry/src/main/ets/application/import/HomeworkImportService.ets")
parser = read("entry/src/main/ets/infrastructure/ai/LocalHomeworkAssignmentParser.ets")

require("TextArea" in page, "parent import page must provide editable teacher-text input")
require("智能整理作业" in page, "parent import page must expose text parsing action")
require("parseTypedText" in page and "HomeworkImportService.instance.parseText" in page,
        "text input must flow through HomeworkImportService")
require(page.count("this.FeedbackBanner();") >= 2 and "if (this.parseMessage.length > 0)" in page,
        "compact candidate result page must keep organizer feedback visible after auto-navigation")
require("async parseText(text: string)" in service,
        "HomeworkImportService must support direct text import")
require("HomeworkImportSourceKind.TEXT" in service and "家长录入文字" in service,
        "direct text import must preserve its source type and label")
require("if (output.candidates.length === 0)" in service,
        "failed parsing must not overwrite existing candidate homework")
require("splitSegments" in parser and "stripListMarker" in parser,
        "local parser must split teacher text into task-level segments")
require("currentSubject" in parser,
        "local parser must support subject inheritance across consecutive tasks")
for marker in ["`${i}.`", "`${i}、`", "`(${i})`", "`（${i}）`"]:
    require(marker in parser, f"local parser must support list marker {marker}")
for subject in ["语文", "数学", "英语"]:
    require(subject in parser, f"local parser must recognize {subject}")
require("sourceEvidence" in parser,
        "each parsed task must retain source evidence")

if errors:
    print("TEXT_IMPORT_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("TEXT_IMPORT_GATE_PASS")
