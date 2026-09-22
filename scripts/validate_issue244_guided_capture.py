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
capture_home = read("entry/src/main/ets/features/parent/import/HomeworkCaptureHomePage.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")
entry = read("entry/src/main/ets/entryability/EntryAbility.ets")
fixture = read("entry/src/test/fixtures/Issue244CaptureSessionFixture.ets")
diagnostic = read("entry/src/main/ets/features/parent/import/HomeworkCaptureDiagnosticPage.ets")
import_models = read("entry/src/main/ets/domain/model/ImportModels.ets")
inbox_service = read("entry/src/main/ets/application/import/HomeworkImportInboxService.ets")
batch_detail = read("entry/src/main/ets/features/parent/import/HomeworkImportBatchDetailPage.ets")
workflow = read("entry/src/main/ets/application/capture/HomeworkCaptureWorkflowService.ets")
cpp = read("entry/src/main/cpp/homework_capture_napi.cpp")
module = read("entry/src/main/module.json5")
pages = read("entry/src/main/resources/base/profile/main_pages.json")

for status in [
    "CREATED", "WAITING_PERMISSION", "CAPTURING", "STOPPING",
    "COMPLETED", "CANCELLED", "FAILED"
]:
    require(status in models, f"CaptureSession status missing: {status}")

for field in [
    "startedAtEpochMs", "stoppedAtEpochMs", "status", "frameCount",
    "acceptedFrameCount", "ocrFailureCount", "sourceProfileId", "stopReason", "importBatchId",
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
require("nativeCapture.getLatestFrame()" in runtime and "nativeCapture.getPendingFrame()" in runtime,
        "formal runtime must expose latest and pending sampled frames")
require("MAX_PENDING_FRAMES" in cpp and "MAX_PENDING_BYTES" in cpp and
        "GetPendingFrame" in cpp,
        "cross-app capture must retain a bounded in-memory changed-frame queue")
require("textRecognition.recognizeText" in recognizer,
        "formal frame recognizer must use Core Vision OCR")

require("CaptureSessionStatus.WAITING_PERMISSION" in service,
        "session must enter WAITING_PERMISSION before capture")
require("if (!frame || frame.sequence <= session.lastFrameSequence)" in service,
        "capture must require a real new frame before processing")
require("let frame = runtime.getPendingFrame()" in service and
        service.index("session.status = CaptureSessionStatus.CAPTURING") >
        service.index("let frame = runtime.getPendingFrame()"),
        "CAPTURING must only be entered after a real pending frame exists")
require("START_REJECTED" in service and "CaptureSessionStatus.CANCELLED" in service,
        "rejected start/permission path must return to recoverable terminal state")
require("FIRST_FRAME_TIMEOUT_MS" in service and "FIRST_FRAME_TIMEOUT" in models,
        "capture waiting for authorization/first frame must have an explicit timeout")
require("session.ocrFailureCount++" in service,
        "single-frame OCR failures must be observable without aborting the session")
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

require("抓取老师作业" in capture_home and "onStartCapture" in capture_home,
        "dedicated capture home must expose the formal capture entry")
require("HomeworkCaptureDiagnosticPage" in diagnostic and "屏幕采集诊断" in diagnostic,
        "guided capture must retain the formal screen-capture diagnostic surface")
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
require('"ohos.permission.FLOAT_VIEW"' not in module and
        '"ohos.permission.SYSTEM_FLOAT_WINDOW"' not in module,
        "guided capture must not request restricted floating-window permissions")
require('"pages/HomeworkCaptureFloatView"' not in pages,
        "guided capture must not register a cross-app floating UI")
require("floatView" not in page and "FLOAT_VIEW" not in page,
        "formal capture page must not invoke FloatView APIs")
require("系统录屏通知" in page and "备用：" in page and
        "this.viewModel.finishByUser()" in page and "this.capture.stopByUser()" in workflow,
        "system notification must be the primary stop path with an in-app fallback")
require("pendingFrameCount" in service and "runtime.getPendingFrame()" in service,
        "system-driven stop must drain bounded pending frames before finalization")
require("floatView" not in diagnostic and "FLOAT_VIEW" not in diagnostic and
        "this.captureRuntime.stopCapture()" in diagnostic,
        "diagnostic capture must also avoid floating-window permissions and stop in-app")

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

if errors:
    print("ISSUE_244_GUIDED_CAPTURE_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_244_GUIDED_CAPTURE_GATE_PASS")
