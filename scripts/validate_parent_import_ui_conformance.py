#!/usr/bin/env python3
from pathlib import Path

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


inbox = read("entry/src/main/ets/features/parent/import/HomeworkImportInboxPage.ets")
batch = read("entry/src/main/ets/features/parent/import/HomeworkImportBatchDetailPage.ets")
import_route = read("entry/src/main/ets/features/parent/import/HomeworkImportRoutePage.ets")
import_page = read("entry/src/main/ets/features/parent/import/HomeworkImportPage.ets")
import_vm = read("entry/src/main/ets/features/parent/import/HomeworkImportViewModel.ets")
import_service = read("entry/src/main/ets/application/import/HomeworkImportService.ets")
entry = read("entry/src/main/ets/entryability/EntryAbility.ets")
dashboard = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")

# Current deep pages must remain top anchored and hide the system scrollbar.
for name, source in [
    ("import inbox", inbox),
    ("batch detail", batch),
]:
    require(".align(Alignment.TopStart)" in source,
            f"{name} page-level Scroll must be explicitly top anchored")
    require(".scrollBar(BarState.Off)" in source,
            f"{name} page-level Scroll must hide the system scrollbar")

# Manual import and inbox are the supported parent import surfaces after screen-capture retirement.
require(".alignItems(HorizontalAlign.Center)" in import_route and
        "AppTheme.CONTENT_STANDARD_MAX_WIDTH" in import_page,
        "manual import route must center the embedded readable content column on Pad")

require("Button(this.parseBusy ? '识别中…' : '拍照识别'" in import_page and
        "Button(this.parseBusy ? '识别中…' : '相册识别'" in import_page,
        "manual homework must expose compact camera and gallery OCR actions")
require("private ActionFooter()" in import_page and
        import_page.find("this.ActionFooter();") > import_page.find(".scrollBar(BarState.Off);"),
        "manual homework primary action must remain fixed outside scrolling content")
require(".height(200)" in import_page and "整理并继续" in import_page,
        "manual homework content editor must stay compact and preserve one primary continuation action")
require("private SubjectSelector()" in import_page and
        "label: Subject.CHINESE" in import_page and "label: Subject.MATH" in import_page and
        "label: Subject.ENGLISH" in import_page and "label: Subject.OTHER" in import_page,
        "manual homework must expose a compact subject selector before organization")
require("@State private subjectChosen: boolean = false" in import_page and
        "请先选择作业科目" in import_page and
        ".enabled(!this.parseBusy && this.subjectChosen && this.textDraft.trim().length > 0)" in import_page,
        "manual homework must require an explicit subject before organization")
require("this.viewModel.parseText(text, this.selectedSubject, this.sourceImageRef, this.sourceImageLabel)" in import_page,
        "manual homework must pass the parent-selected subject into organization")
require("captureImageText()" in import_vm and
        "HomeworkImportService.instance.captureImageText()" in import_vm,
        "manual homework ViewModel must expose camera OCR through the import service")
require("cameraPicker.pick(" in import_service and
        "cameraPicker.PickerMediaType.PHOTO" in import_service and
        "CameraPosition.CAMERA_POSITION_BACK" in import_service,
        "manual homework camera OCR must use the system camera picker")
require("recognizeImageText" in import_service and
        "this.pipeline.extract(rawImport)" in import_service,
        "camera and gallery OCR must reuse the existing text extraction pipeline")
require("HomeworkImportService.instance.configure(" in entry and
        "this.context, new CoreVisionHomeworkTextExtractor()" in entry,
        "manual homework camera OCR must receive UIAbility context during bootstrap")
require("输入文字、拍照或相册识别" in dashboard,
        "parent home must make photo recognition discoverable from the homework action")

require("FilterSummaryEntry" in inbox and "label: '来源'" in inbox and
        "label: '状态'" in inbox and "label: '时间'" in inbox,
        "Import Inbox must reuse the standard filter summary interaction")
require("AppTheme.CONTENT_STANDARD_MAX_WIDTH" in inbox and
        "AppTheme.CARD_RADIUS_COMPACT" in inbox and "AppTheme.BORDER" in inbox,
        "Import Inbox cards must stay aligned with current Phone/Pad visual tokens")

require(inbox.count(".alignItems(HorizontalAlign.Center)") >= 1 and
        ".constraintSize({ maxWidth: AppTheme.CONTENT_STANDARD_MAX_WIDTH })" in inbox,
        "Import Inbox page shell must center the readable column on wide layouts")
require(batch.count(".alignItems(HorizontalAlign.Center)") >= 1 and
        ".constraintSize({ maxWidth: AppTheme.CONTENT_STANDARD_MAX_WIDTH })" in batch,
        "Import batch detail page shell must center the readable column on wide layouts")
require("backAccessibilityText: '返回作业收件箱'" in batch,
        "Import batch detail return semantics must match the current inbox title")
require(batch.count("AppTheme.CARD_RADIUS_COMPACT") >= 4 and
        batch.count(".border({ width: 1, color: AppTheme.BORDER })") >= 4,
        "Import batch detail cards must reuse current parent card radius and border tokens")

for retired in [
    "HomeworkCapturePage",
    "HomeworkCaptureHomePage",
    "HomeworkCaptureDiagnosticPage",
    "HomeworkSourceProfilePage",
]:
    require(retired not in import_route + inbox + batch,
            f"retired screen-capture surface must not return to current import navigation: {retired}")

if errors:
    print("PARENT_IMPORT_UI_CONFORMANCE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("PARENT_IMPORT_UI_CONFORMANCE_PASS")
