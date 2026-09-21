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

capture_models = read("entry/src/main/ets/domain/model/CaptureModels.ets")
chat_models = read("entry/src/main/ets/domain/model/ChatReconstructionModels.ets")
recognizer = read("entry/src/main/ets/infrastructure/capture/CoreVisionHomeworkCaptureFrameRecognizer.ets")
capture_store = read("entry/src/main/ets/data/local/HomeworkCaptureSessionStore.ets")
parser = read("entry/src/main/ets/application/capture/DeterministicChatRegionParser.ets")
reconstructor = read("entry/src/main/ets/application/capture/DeterministicChatReconstructor.ets")
service = read("entry/src/main/ets/application/capture/HomeworkChatReconstructionService.ets")
capture_service = read("entry/src/main/ets/application/capture/HomeworkCaptureSessionService.ets")
import_models = read("entry/src/main/ets/domain/model/ImportModels.ets")
inbox_store = read("entry/src/main/ets/data/local/HomeworkImportInboxStore.ets")
inbox_service = read("entry/src/main/ets/application/import/HomeworkImportInboxService.ets")
fixture = read("entry/src/test/fixtures/Issue245ChatReconstructionFixture.ets")
detail = read("entry/src/main/ets/features/parent/import/HomeworkImportBatchDetailPage.ets")

for field in ["value", "left", "top", "right", "bottom"]:
    require(field in capture_models, f"OCR line geometry field missing: {field}")
require("lines?: CaptureOcrLineEvidence[]" in capture_models,
        "CaptureFrameEvidence lines must stay backward compatible")
require("cornerPoints" in recognizer and "lines: lines" in recognizer,
        "Core Vision recognizer must persist line geometry")
require("source.lines !== undefined" in capture_store,
        "old capture snapshots without OCR lines must restore safely")
require("fallbackLines" in parser and "GEOMETRY_MISSING" in parser,
        "legacy OCR text must degrade through fallback parsing")

for field in [
    "groupTitle", "messages", "timeBoundaryReached",
    "earliestDetectedMinuteOfDay", "earliestDetectedTime", "warnings"
]:
    require(field in chat_models, f"ChatReconstructionResult field missing: {field}")

require("parseInlineMessage" in parser and "looksLikeSender" in parser,
        "parser must support inline and geometry-assisted message blocks")
require("parseTime" in parser and "approxEpoch" in parser,
        "explicit chat time recognition missing")
require("imageHash" in parser and "[图片:" in parser,
        "image placeholder/hash recognition missing")

require("bestOverlap" in reconstructor and "mergeFrame" in reconstructor,
        "cross-frame overlap reconstruction missing")
require("length === 1 && !this.strongIdentity" in reconstructor,
        "single weak match must not deduplicate ambiguous untimed text")
require("strongIdentity" in reconstructor and "baseMatch" in reconstructor,
        "strong/weak deterministic identity separation missing")
require("sourceFrameEvidenceIds" in reconstructor,
        "deduplicated messages must retain all source frame evidence")
require("relativePosition" in reconstructor and "imageHash" in reconstructor,
        "persisted fingerprint must consider relative position and image hash")
require("detectedMinuteOfDay" in reconstructor and "sender" in reconstructor,
        "fingerprint/order must consider time and sender")
require("HomeworkOrganizerRemoteApi" not in reconstructor and
        "HomeworkOrganizerRemoteApi" not in parser and
        "runSmart" not in reconstructor,
        "#245 reconstruction must not call AI/LLM")
require("CandidateAssignment" not in reconstructor and "CandidateAssignment" not in parser,
        "#245 must not create candidate assignments")

require("sourceFrameEvidenceIds?: string[]" in import_models,
        "ImportedMessage evidence must expose source frame refs")
require("sourceFrameEvidenceIds" in inbox_store,
        "Import Inbox store must preserve source frame refs")
for field in ["reconstructed?: boolean", "groupTitle?: string",
              "timeBoundaryReached?: boolean", "earliestDetectedTime?: string",
              "reconstructionWarnings?: string[]"]:
    require(field in import_models, f"ImportBatch reconstruction metadata missing: {field}")
require("reconstructionWarnings" in inbox_service,
        "Import Inbox service must retain reconstruction metadata")

require("reconstructCaptureSession" in service,
        "capture reconstruction service missing")
require("tryReconstructCaptureSession" in service and
        "CHAT_RECONSTRUCTION_EXCEPTION" in service,
        "capture shutdown must survive reconstruction failure")
require("candidateCount: 0" in service,
        "#245 service must not create candidates")
require("HomeworkChatReconstructionService" not in capture_service,
        "CaptureSessionService must stop at evidence/batch creation; reconstruction belongs to workflow")
require("tryReconstructCaptureSession" in read("entry/src/main/ets/application/capture/HomeworkCaptureWorkflowService.ets"),
        "profile-aware workflow must own deterministic reconstruction")

for item in [
    "this.frame(1, ['17:46 家长甲 收到', '17:50 李老师 C'])",
    "this.frame(2, ['17:45 王老师 B', '17:46 家长甲 收到'])",
    "this.frame(3, ['17:42 王老师 A', '17:45 王老师 B'])",
    "this.frame(4, ['14:58 王老师 D', '17:42 王老师 A'])",
    "this.frame(5, ['17:42 王老师 A', '17:45 王老师 B'])"
]:
    require(item in fixture, "five-frame 50% overlap fixture is incomplete")
require("repeatedEvidenceCount === 3" in fixture,
        "same message repeated in 3 frames must collapse to one with 3 evidence refs")
require("15 * 60" in fixture and "14:58" in fixture and
        "timeBoundaryReached" in fixture,
        "15:00 time-boundary fixture missing")
require("sameTextDifferentSender" in fixture and "sameTextDifferentTime" in fixture,
        "same text / different sender or time regression cases missing")
require("missingTimeOverlap" in fixture,
        "missing-time structural overlap regression case missing")
require("imageMessage" in fixture and "img_001" in fixture,
        "image-message/hash regression case missing")
require("ocrFailure" in fixture and "OCR_EXCEPTION" in fixture,
        "single-frame OCR failure tolerance case missing")

require("群标题：" in detail and "最早识别时间：" in detail and "来源画面：" in detail,
        "batch detail must expose reconstruction and provenance evidence")

if errors:
    print("ISSUE_245_CHAT_RECONSTRUCTION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_245_CHAT_RECONSTRUCTION_GATE_PASS")
