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

require(".accessibilityText('拍照添加作业图片')" in import_page and
        ".accessibilityText('从相册添加作业图片')" in import_page and
        "void this.recognizePhoto();" in import_page and "void this.recognizeGallery();" in import_page,
        "manual homework must expose accessible camera and gallery actions sharing the image/OCR flow")
require("private ActionFooter()" in import_page and
        import_page.find("this.ActionFooter();") > import_page.find(".scrollBar(BarState.Off);"),
        "manual homework primary action must remain fixed outside scrolling content")
require(".height(160)" in import_page and "整理并继续" in import_page and
        ".constraintSize({ minHeight: AppTheme.BUTTON_HEIGHT })" in import_page,
        "manual homework content editor must stay compact and the primary action must allow large text")

# The content is primary; subject override and old imports are secondary, contextual controls.
composition = import_page[import_page.find("  build() {"):]
require(composition.find("this.AssignmentInput();") < composition.find("this.SubjectOptions();") <
        composition.find("this.PendingReview();") < composition.find("this.ImportRecordsEntry();"),
        "manual homework must place content before optional subject, pending review and import records")
require("@State private subjectOptionsOpen: boolean = false" in import_page and
        "if (this.subjectOptionsOpen) {\n        this.SubjectSelector();" in import_page,
        "manual subject overrides must default to collapsed optional settings")
require("this.RecognitionActions();" in import_page and
        import_page.find("this.RecognitionActions();") < import_page.find("TextArea({"),
        "image actions must be discoverable before the editable text input")
require("private ImageInput()" in import_page and
        "if (this.sourceImageRef.length > 0) {" in import_page and
        "ImageModeSelector" not in import_page and
        "Flex({ wrap: FlexWrap.Wrap })" in import_page,
        "image controls must be contextual without permanent parsing tabs; subject options must wrap")
require("下一步核对作业，确认后再发布" in import_page,
        "manual homework primary action must clarify that publishing follows parent confirmation")
require("private SubjectSelector()" in import_page and
        "label: Subject.CHINESE" in import_page and "label: Subject.MATH" in import_page and
        "label: Subject.ENGLISH" in import_page and "label: Subject.OTHER" in import_page,
        "manual homework must expose a compact subject selector before organization")
require("@State private selectedSubject: Subject | null = null" in import_page and
        "label: '自动识别'" in import_page and
        ".enabled(this.canOrganize())" in import_page and "请先选择作业科目" not in import_page,
        "manual homework must allow automatic subject inference before organization")
require("HomeworkImageRecognitionMode.AI_IMAGE" in import_page and
        "HomeworkImageRecognitionMode.OCR" in import_page and
        "识别图片文字" in import_page and "重新用图片解析" in import_page and
        "this.viewModel.parseImage(" in import_page and "this.viewModel.recognizeSelectedImageText(" in import_page,
        "manual homework must default to image AI parsing and retain explicit same-image OCR rollback")
input_section = import_page.split("private AssignmentInput()", 1)[-1].split("private ActionFooter()", 1)[0]
require("this.ImageInput();" in input_section and "TextArea({" in input_section and
        "} else {" not in input_section and
        "this.viewModel.parseImage(this.sourceImageRef, this.selectedSubject, this.sourceImageLabel, text)" in import_page,
        "image and text must coexist and supplemental text must reach image organization")
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
require("backAccessibilityText: '返回导入记录'" in batch,
        "Import batch detail return semantics must match the current records title")
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
