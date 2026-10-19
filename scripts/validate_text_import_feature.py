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
inbox_service = read("entry/src/main/ets/application/import/HomeworkImportInboxService.ets")
confirmation_candidate = read("entry/src/main/ets/features/parent/confirmation/ConfirmationCandidateComponents.ets")

# One parent-facing assignment input: pasted teacher copy, direct parent instructions and
# screenshot OCR all converge before organization.
require("TextArea" in page and "作业内容" in page,
        "parent assignment create page must expose one editable assignment-content input")
require("整理并继续" in page and "private async organize()" in page,
        "parent assignment create page must expose one organize action")
require("this.viewModel.parseText(text, this.selectedSubject, '', '', this.boundTeacherName)" in page,
        "all typed homework must flow through the import ViewModel with subject and selected teacher")
require("private SubjectSelector()" in page and "@State private selectedSubject: Subject | null = null" in page and
        "label: '自动识别'" in page and "this.selectSubject(null)" in page and
        "请先选择作业科目" not in page and ".enabled(this.canOrganize())" in page,
        "assignment creation must default to automatic subject inference without a required subject gate")
require("HomeworkImageRecognitionMode.OCR" not in page and
        "this.viewModel.parseImage(" in page and
        "void this.recognizePhoto();" in page and "void this.recognizeGallery();" in page,
        "parent-facing image parsing must use direct AI image flow without retired OCR fallback buttons")
require("this.sourceImageRef, this.selectedSubject, this.sourceImageLabel, '', this.boundTeacherName" in page and
        "text: text.trim()" in service and "补充文字：" in service and
        "HomeworkImportService.instance.parseImage(imageRef, subject, sourceLabel, text, teacherName)" in view_model,
        "parent's exclusive image mode must use verified teacher and the service must preserve explicit supplemental text from supported callers")
selected_image = page.split("private applySelectedImage(", 1)[-1].split("private selectInputMode(", 1)[0]
require("this.textDraft = '';" in selected_image and
        "this.inputMode = HomeworkAssignmentInputMode.IMAGE;" in selected_image and
        "this.sourceImageRef = imageRef;" in selected_image,
        "selecting an image must activate the image-only mode and clear stale typed text")
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
require("AppTheme.CONTENT_STANDARD_MAX_WIDTH" in page and
        ".alignItems(HorizontalAlign.Center)" in page,
        "assignment create page must keep one centered readable content column")
require("this.FeedbackBanner();" in page and "if (this.parseMessage.length > 0)" in page,
        "organizer feedback must remain visible in the assignment create flow")
require("HomeworkConfirmationPage" not in page,
        "assignment create page must navigate to confirmation rather than duplicate confirmation UI")

require("HomeworkImportService.instance.parseText(text, subject, imageRef, imageSourceLabel, teacherName)" in view_model and
        "HomeworkImportService.instance.selectImage()" in view_model and
        "HomeworkImportService.instance.captureImage()" in view_model and
        "HomeworkImportService.instance.parseImage(imageRef, subject, sourceLabel, text, teacherName)" in view_model,
        "import ViewModel must delegate text/image parsing with teacher source binding and device image selection")
require("HomeworkImportDraftRepository" in service and "DefaultHomeworkImportDraftRepository" in service,
        "HomeworkImportService must persist drafts through the draft repository boundary")
require("HomeworkStore" not in service,
        "HomeworkImportService must not access HomeworkStore directly")
require("async parseText(text: string, subject: Subject | null = null, imageRef: string = ''" in service and
        "imageSourceLabel: string = ''" in service,
        "HomeworkImportService must support optional subject override plus image evidence")
require("HomeworkImportSourceKind.TEXT" in service and "家长录入文字" in service and
        "相册作业截图" in service,
        "unified assignment input must preserve its actual source evidence")
require("async selectImageText()" in service and "async captureImageText()" in service and
        "recognizeImageText" in service and "this.pipeline.extract(rawImport)" in service,
        "image OCR actions must stop after extraction until the user chooses to organize")
require("fallbackCandidate" in service and
        "output.organizerMode === HomeworkOrganizerMode.LOCAL" in service,
        "only local parser empty results may fall back to one confirmable candidate")
require("candidates.length === 0 && output.organizerMode === HomeworkOrganizerMode.LOCAL" in service,
        "an authoritative AI zero-task result must not be converted into a fake assignment")
require("private applySelectedSubject(candidates: CandidateAssignment[], subject: Subject | null)" in service and
        "if (subject === null) return candidates;" in service and
        "candidates = this.applySelectedSubject(output.candidates, subject)" in service and
        "subject: subject" in service and "fallbackSubject" not in service,
        "automatic inference must preserve multi-subject output and explicit subject overrides must remain authoritative")

# Unified publishing must keep the single Assignment aggregate while retaining SCHOOL vs EXTRA.
require("this.assignmentType(candidate.subject)" in publisher and
        "return AssignmentType.EXTRA" in publisher and
        "return AssignmentType.SCHOOL" in publisher,
        "unified create flow must preserve school versus extracurricular AssignmentType")

require("private sourceEvidenceText(candidate: CandidateAssignment): string" in publisher and
        "candidate.sourceEvidence.rawText" in publisher and
        "sourceExcerpt: this.sourceEvidenceText(candidate)" in publisher,
        "published AI homework must preserve deterministic raw source text for duplicate review")

for field in ["sameTaskGroup", "duplicateAssignmentId", "duplicateAssignmentTitle",
              "duplicateConfidence", "duplicateReason"]:
    require(f"{field}: candidate.{field}" in service,
            f"subject override must preserve AI duplicate metadata: {field}")
    require(inbox_service.count(f"{field}: candidate.{field}") >= 2,
            f"import inbox enrichment and normalization must preserve AI duplicate metadata: {field}")

require("ConfirmationCandidateEditor" in confirmation_candidate and
        "反馈 AI 整理问题" in confirmation_candidate and
        "HomeworkOrganizerFeedbackRemoteApi.instance" in confirmation_candidate,
        "confirmation must allow parents to provide persisted AI organizer corrections")

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
