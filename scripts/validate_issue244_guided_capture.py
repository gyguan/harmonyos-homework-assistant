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


models = read("entry/src/main/ets/domain/model/CaptureModels.ets")
runtime_port = read("entry/src/main/ets/domain/port/HomeworkCaptureRuntime.ets")
recognizer_port = read("entry/src/main/ets/domain/port/HomeworkCaptureFrameRecognizer.ets")
persistence = read("entry/src/main/ets/infrastructure/persistence/PreferencesHomeworkCaptureSessionPersistence.ets")
store = read("entry/src/main/ets/data/local/HomeworkCaptureSessionStore.ets")
runtime = read("entry/src/main/ets/infrastructure/capture/NativeHomeworkCaptureRuntime.ets")
recognizer = read("entry/src/main/ets/infrastructure/capture/CoreVisionHomeworkCaptureFrameRecognizer.ets")
service = read("entry/src/main/ets/application/capture/HomeworkCaptureSessionService.ets")
page = read("entry/src/main/ets/features/parent/import/HomeworkCapturePage.ets")
float_page = read("entry/src/main/ets/pages/HomeworkCaptureFloatView.ets")
route_page = read("entry/src/main/ets/features/parent/import/HomeworkImportRoutePage.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
entry = read("entry/src/main/ets/entryability/EntryAbility.ets")
fixture = read("entry/src/main/ets/experimental/homeworkcapture/Issue244CaptureSessionFixture.ets")
spike = read("entry/src/main/ets/experimental/homeworkcapture/HomeworkCaptureSpikePage.ets")
import_models = read("entry/src/main/ets/domain/model/ImportModels.ets")
inbox_service = read("entry/src/main/ets/application/import/HomeworkImportInboxService.ets")
batch_detail = read("entry/src/main/ets/features/parent/import/HomeworkImportBatchDetailPage.ets")

for status in [
    "CREATED", "WAITING_PERMISSION", "CAPTURING", "STOPPING",
    "COMPLETED", "CANCELLED", "FAILED"
]:
    require(status in models, f"CaptureSession status missing: {status}")

for field in [
    "startedAtEpochMs", "stoppedAtEpochMs", "status", "frameCount",
    "acceptedFrameCount", "sourceProfileId", "stopReason", "importBatchId",
    "lastFrameSequence", "runtimeErrorCode", "runtimeTimestamp"
]:
    require(field in models, f"CaptureSession field missing: {field}")

require("interface HomeworkCaptureRuntime" in runtime_port,
        "native capture must stay behind a runtime port")
require("interface HomeworkCaptureFrameRecognizer" in recognizer_port,
        "frame OCR must stay behind a recognizer port")
require("homework_capture_sessions_v1" in persistence,
        "CaptureSession persistence must be isolated")
require("ArrayBuffer" not in persistence,
        "raw RGBA frame bytes must never be persisted")
require("PROCESS_RESTARTED" in store and "recoverInterruptedSession" in store,
        "interrupted sessions must recover to a terminal state")
require("已有采集会话正在运行" in store and "activeSessionId" in store,
        "store must enforce a single active CaptureSession")

require("nativeCapture.startCapture()" in runtime and "nativeCapture.stopCapture()" in runtime,
        "formal runtime must adapt the #241 native bridge")
require("nativeCapture.getLatestFrame()" in runtime,
        "formal runtime must expose latest sampled frame")
require("textRecognition.recognizeText" in recognizer,
        "formal frame recognizer must use Core Vision OCR")

require("CaptureSessionStatus.WAITING_PERMISSION" in service,
        "session must enter WAITING_PERMISSION before capture")
require("if (!frame || frame.sequence <= session.lastFrameSequence)" in service,
        "capture must require a real new frame before processing")
require(service.index("session.status = CaptureSessionStatus.CAPTURING") >
        service.index("let frame = runtime.getLatestFrame()"),
        "CAPTURING must only be entered after a real frame exists")
require("START_REJECTED" in service and "CaptureSessionStatus.CANCELLED" in service,
        "rejected start/permission path must return to recoverable terminal state")
require("SYSTEM_STOPPED" in models and "finishRuntimeEnded" in service,
        "system-driven capture stop must converge to a terminal session")
require("!stats.isCapturing" in service,
        "capture state must observe runtime-driven stop/cancel signals")
require("已有作业采集正在进行" in service,
        "duplicate start must be rejected")
require("FRAME_DIFF_THRESHOLD" in service and "SIGNATURE_SAMPLES" in service,
        "deterministic Frame Diff sampling must exist")
require("isMeaningfulChange" in service and "frameSignature" in service,
        "unchanged frames must be filtered")
require(service.index("recognize(frame)") > service.index("isMeaningfulChange"),
        "OCR must run only after Frame Diff accepts a changed frame")
require("HomeworkOrganizerRemoteApi" not in service and "runSmart" not in service,
        "#244 capture loop must not call AI/LLM per frame")
require("runtime.stopCapture()" in service,
        "manual/cancel/destroy paths must release capture runtime")
require("sampleInFlight" in service and
        "if (this.sampleInFlight !== null) await this.sampleInFlight" in service,
        "stop/cancel must serialize against in-flight OCR sampling")
require("isTerminal(latest.status)" in service,
        "late OCR completion must not revive a terminal CaptureSession")
require("runtime.clearLatestFrame()" in service,
        "formal termination must clear the retained raw RGBA frame")
require("capturedAtEpochMs: Date.now()" in service and "runtimeTimestamp: frame.timestamp" in service,
        "native media timestamp must not be misused as wall-clock epoch")
require("handleAbilityDestroy" in service and "ABILITY_DESTROYED" in service,
        "UIAbility abnormal destruction must safely terminate the session")

require("capture-batch-" in service and
        "HomeworkImportInboxService.instance.getBatch(batchId)" in service,
        "CaptureSession to ImportBatch creation must be idempotent")
require("captureSessionId: session.id" in service,
        "ImportBatch must trace back to its CaptureSession")
require("ImportBatchStatus.RECEIVED" in service,
        "#244 evidence batch must remain RECEIVED until downstream semantics")
require("captureSessionId?: string" in import_models,
        "ImportBatch model must expose captureSessionId")
require("batch.status === ImportBatchStatus.RECEIVED" in inbox_service,
        "Import Inbox must preserve RECEIVED capture batches")
require("采集会话：" in batch_detail,
        "ImportBatch detail must expose CaptureSession trace")

require("抓取今日作业" in route_page and "onOpenCapture" in route_page,
        "parent import page must expose the formal capture entry")
require("PARENT_CAPTURE" in routes and "HomeworkCapturePage" in shell,
        "formal capture must use its own navigation route")
require(shell.count("HomeworkCaptureSessionService.instance.getActiveSession() !== null") >= 2,
        "active capture must block parent child-context switching")
require(("不自动点击" in page or "不会自动点击" in page) and
        ("不自动滚动" in page or "不会自动点击或滚动" in page) and
        "Accessibility" in page,
        "formal capture UI must state click/scroll/accessibility non-automation boundaries")
require("手工向上滑" in page,
        "formal UX must require user-driven chat scrolling")
require("setInterval" in float_page and "sampleLatestFrame" in float_page,
        "FloatView must continuously sample the formal session")
require("HomeworkCaptureSessionService.instance.stopByUser" in float_page,
        "FloatView must allow user-controlled stop")
require("CaptureSessionStatus.COMPLETED" in float_page and
        "CaptureSessionStatus.FAILED" in float_page,
        "FloatView must reflect runtime-driven terminal states")
require("nativeCapture.stopCapture()" in float_page,
        "#241 diagnostic fallback must remain available")

require("HomeworkCaptureSessionBootstrap" in entry and
        "PreferencesHomeworkCaptureSessionPersistence" in entry,
        "EntryAbility must restore CaptureSession history")
require("handleAbilityDestroy" in entry,
        "EntryAbility destruction must invoke capture cleanup")

require("this.frame(1, 12)" in fixture and
        "this.frame(2, 88)" in fixture and
        "this.frame(3, 88)" in fixture,
        "#244 fixture must include one unchanged sampled frame")
require("completed.acceptedFrameCount === 2" in fixture,
        "#244 fixture must prove 3 sampled frames reduce to 2 accepted frames")
require("messages.length === 2" in fixture,
        "#244 fixture must generate two OCR evidence messages")
require("batch.captureSessionId === completed.id" in fixture,
        "#244 fixture must verify Session/Batch traceability")
require("运行 #244 离线流程自测" in spike,
        "diagnostic page must expose independent #244 fixture acceptance")

if errors:
    print("ISSUE_244_GUIDED_CAPTURE_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_244_GUIDED_CAPTURE_GATE_PASS")
