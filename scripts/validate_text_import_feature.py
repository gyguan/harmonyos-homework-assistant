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
view_model = read("entry/src/main/ets/features/parent/import/HomeworkImportViewModel.ets")
service = read("entry/src/main/ets/application/import/HomeworkImportService.ets")
draft_port = read("entry/src/main/ets/domain/port/HomeworkImportDraftRepository.ets")
draft_repo = read("entry/src/main/ets/data/repository/DefaultHomeworkImportDraftRepository.ets")
draft_local = read("entry/src/main/ets/data/local/HomeworkImportLocalDataSource.ets")
parser = read("entry/src/main/ets/infrastructure/ai/LocalHomeworkAssignmentParser.ets")
publisher = read("entry/src/main/ets/application/import/HomeworkBatchPublishService.ets")

# One parent-facing assignment input: pasted teacher copy, direct parent instructions and
# screenshot OCR all converge before organization.
require("TextArea" in page and "作业内容" in page,
        "parent assignment create page must expose one editable assignment-content input")
require("整理作业" in page and "private async organize()" in page,
        "parent assignment create page must expose one organize action")
require("this.viewModel.parseText(text, this.sourceImageRef)" in page,
        "all editable assignment text must flow through the import ViewModel")
require("this.viewModel.selectImageText()" in page and
        "已识别截图文字，可以修改后再整理" in page,
        "screenshot must only fill editable text before organization")
require("selectImageAndParse()" not in page and "parseTypedText" not in page and
        "textEntryOpen" not in page,
        "unified create page must not retain separate screenshot/text sub-flows")
require("HomeworkStore" not in page,
        "assignment create page must not access HomeworkStore directly")
require("private afterOrganized(candidateCount: number)" in page and
        "this.onOpenConfirmation()" in page,
        "successful organization must navigate directly to the single confirmation page")
require("CandidatePane" not in page and "继续确认" not in page,
        "assignment create flow must not retain a redundant intermediate confirmation step")
require("AppTheme.IMPORT_READABLE_MAX_WIDTH" in page and
        ".alignItems(HorizontalAlign.Center)" in page,
        "assignment create page must keep one centered readable content column")
require("this.FeedbackBanner();" in page and "if (this.parseMessage.length > 0)" in page,
        "organizer feedback must remain visible in the assignment create flow")
require("HomeworkConfirmationPage" not in page,
        "assignment create page must navigate to confirmation rather than duplicate confirmation UI")

require("HomeworkImportService.instance.parseText(text, imageRef)" in view_model and
        "HomeworkImportService.instance.selectImageText()" in view_model,
        "import ViewModel must delegate unified text and screenshot OCR actions")
require("HomeworkImportDraftRepository" in service and "DefaultHomeworkImportDraftRepository" in service,
        "HomeworkImportService must persist drafts through the draft repository boundary")
require("HomeworkStore" not in service,
        "HomeworkImportService must not access HomeworkStore directly")
require("async parseText(text: string, imageRef: string = '')" in service,
        "HomeworkImportService must support one text entry with optional screenshot evidence")
require("HomeworkImportSourceKind.TEXT" in service and "家长录入文字" in service and
        "相册作业截图" in service,
        "unified assignment input must preserve its actual source evidence")
require("async selectImageText()" in service and "this.pipeline.extract(rawImport)" in service,
        "screenshot action must stop after OCR/extraction until the user chooses to organize")
require("fallbackCandidate" in service and
        "output.candidates.length > 0" in service,
        "non-empty free text must fall back to one confirmable candidate instead of dead-ending")
require("fallbackSubject" in service and "Subject.SPORTS" in service and
        "Subject.READING" in service,
        "free-text fallback must preserve common extracurricular category semantics")

# Unified publishing must keep the single Assignment aggregate while retaining SCHOOL vs EXTRA.
require("this.assignmentType(candidate.subject)" in publisher and
        "return AssignmentType.EXTRA" in publisher and
        "return AssignmentType.SCHOOL" in publisher,
        "unified create flow must preserve school versus extracurricular AssignmentType")

require("getRawImport" in draft_port and "getCandidates" in draft_port and
        "replaceRawImport" in draft_port and "replaceCandidates" in draft_port,
        "draft repository port must own import draft reads and writes")
require("HomeworkStore" not in draft_repo and "HomeworkImportLocalDataSource" in draft_repo,
        "draft repository must depend on HomeworkImportLocalDataSource instead of HomeworkStore")
require("HomeworkStore.instance" in draft_local,
        "legacy import local adapter must isolate the remaining HomeworkStore access")

require("splitSegments" in parser and "stripListMarker" in parser,
        "local parser must split teacher text into task-level segments")
require("currentSubject" in parser,
        "local parser must support subject inheritance across consecutive school tasks")
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
