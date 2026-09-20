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


shared = read("entry/src/main/ets/components/assignment/AssignmentEditForm.ets")
confirmation_components = read(
    "entry/src/main/ets/features/parent/confirmation/ConfirmationCandidateComponents.ets")
confirmation_page = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
review_editor = read("entry/src/main/ets/features/parent/review/ParentAssignmentEditPanel.ets")
review_pane = read("entry/src/main/ets/features/parent/review/ParentReviewPane.ets")
deadline = read("entry/src/main/ets/components/assignment/DeadlinePickerField.ets")
import_service = read("entry/src/main/ets/application/import/HomeworkImportService.ets")
extra_page = read("entry/src/main/ets/features/parent/extra/ParentExtraAssignmentPage.ets")
voice_page = read("entry/src/main/ets/features/parent/voice/ParentVoiceAssignmentPage.ets")

for token in ["作业标题", "老师要求", "截止时间", "预计用时（分钟）", "教材 / 页码"]:
    require(token in shared, f"shared assignment editor missing field: {token}")
require("AssignmentEditForm({" in confirmation_components,
        "create-time confirmation editor must reuse AssignmentEditForm")
require("AssignmentEditForm({" in review_editor,
        "published assignment editor must reuse AssignmentEditForm")
require("bindSheet($$this.showEditSheet" in review_pane and "preferType: SheetType.BOTTOM" in review_pane,
        "published assignment editing must use a bottom sheet")
require("ParentAssignmentEditPanel({" in review_pane and "AssignmentEditorSheet" in review_pane,
        "published edit sheet must host the same published editor wrapper")

require("let today = new Date();" in deadline and "this.selectedDate = today;" in deadline,
        "empty deadline picker must default to today")
require("@State private dueText: string = '今天';" in extra_page,
        "extra assignment creation must default due date to today")
require("@State private dueText: string = '今天';" in voice_page,
        "voice assignment creation must default due date to today")
require("normalizeCandidateDates" in import_service and "candidate.dueText = '今天'" in import_service,
        "imported candidates with no date must default to today")

require("candidateRenderKey" in confirmation_page,
        "confirmation list must use a render key that changes with edited task content")
require("this.candidateRenderKey(item)" in confirmation_page,
        "confirmation ForEach must rebuild the edited card immediately")
for field in ["item.subject", "item.title", "item.instruction", "item.dueText", "item.textbookRef", "item.expectedMinutes"]:
    require(field in confirmation_page, f"confirmation render key missing edited field: {field}")

if errors:
    print("ASSIGNMENT_EDITOR_CONSISTENCY_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ASSIGNMENT_EDITOR_CONSISTENCY_GATE_PASS")
