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

require("TextArea" in page, "parent import page must provide editable teacher-text input")
require("让小伴整理" in page and "parseTypedText" in page,
        "parent import page must expose text parsing action")
require("HomeworkImportViewModel" in page and "this.viewModel.parseText(text)" in page,
        "text input must flow through the import ViewModel")
require("this.viewModel.selectImageAndParse()" in page,
        "screenshot import must continue through the import ViewModel")
require("HomeworkStore" not in page,
        "V2 import page must not access HomeworkStore directly")
require("private afterOrganized(candidateCount: number)" in page and
        "this.onOpenConfirmation()" in page,
        "successful organization must navigate directly to the single confirmation page")
require("CandidatePane" not in page and "继续确认" not in page,
        "import flow must not retain a redundant intermediate confirmation step")
require("LayoutPolicy.importOrganizeRequirement()" in page and "private canUseSplit()" in page and
        "this.availableWidthVp" in page,
        "import composition must use actual container width and LayoutPolicy")
require("WindowSizeClass.COMPACT" not in page and "WindowSizeClass.EXPANDED" not in page,
        "import page must not choose business composition from size-class breakpoints")
require("this.FeedbackBanner();" in page and "if (this.parseMessage.length > 0)" in page,
        "organizer feedback must remain visible in the import flow")
require("HomeworkConfirmationPage" not in page,
        "import page must navigate to confirmation rather than duplicate confirmation UI")

require("HomeworkImportService.instance.parseText(text)" in view_model and
        "HomeworkImportService.instance.selectImageAndParse()" in view_model,
        "import ViewModel must delegate parsing to HomeworkImportService")
require("HomeworkImportDraftRepository" in service and "DefaultHomeworkImportDraftRepository" in service,
        "HomeworkImportService must persist drafts through the draft repository boundary")
require("HomeworkStore" not in service,
        "HomeworkImportService must not access HomeworkStore directly")
require("async parseText(text: string)" in service,
        "HomeworkImportService must support direct text import")
require("HomeworkImportSourceKind.TEXT" in service and "家长录入文字" in service,
        "direct text import must preserve its source type and label")
require("if (output.candidates.length === 0)" in service,
        "failed parsing must not overwrite existing candidate homework")
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
