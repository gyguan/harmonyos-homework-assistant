#!/usr/bin/env python3
from pathlib import Path
import re
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


cpp = read("entry/src/main/cpp/homework_capture_napi.cpp")
cmake = read("entry/src/main/cpp/CMakeLists.txt")
module = read("entry/src/main/module.json5")
pages = read("entry/src/main/resources/base/profile/main_pages.json")
ocr = read("entry/src/main/ets/infrastructure/capture/HomeworkCaptureOcrService.ets")
diagnostic = read("entry/src/main/ets/features/parent/import/HomeworkCaptureDiagnosticPage.ets")
native_runtime = read("entry/src/main/ets/infrastructure/capture/NativeHomeworkCaptureRuntime.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
capture_home = read("entry/src/main/ets/features/parent/import/HomeworkCaptureHomePage.ets")
capture_page = read("entry/src/main/ets/features/parent/import/HomeworkCapturePage.ets")
entry_pkg = read("entry/oh-package.json5")
build = read("entry/build-profile.json5")

for library in [
    "libnative_avscreen_capture.so",
    "libnative_buffer.so",
    "libnative_media_core.so",
    "libnative_display_manager.so",
    "libace_napi.z.so",
]:
    require(library in cmake, f"native capture CMake must link {library}")

for api in [
    "OH_AVScreenCapture_Create",
    "OH_AVScreenCapture_Init",
    "OH_AVScreenCapture_SetDataCallback",
    "OH_AVScreenCapture_StartScreenCapture",
    "OH_AVScreenCapture_StopScreenCapture",
    "OH_AVScreenCapture_Release",
    "OH_VIDEO_SOURCE_SURFACE_RGBA",
]:
    require(api in cpp, f"native diagnostic missing AVScreenCapture API: {api}")

require("OH_AVBuffer_GetAddr" in cpp and "OH_NativeBuffer_GetConfig" in cpp,
        "native bridge must read the RGBA buffer and its stride metadata")
require(re.search(r"=\s*OH_NativeBuffer_GetConfig\s*\(", cpp) is None,
        "OH_NativeBuffer_GetConfig returns void and must not be treated as a status code")
require("SAMPLE_EVERY_CALLBACKS" in cpp,
        "native bridge must sample video callbacks instead of retaining every frame")
require("fwrite(" not in cpp and "std::ofstream" not in cpp,
        "issue #241 must not persist captured chat frames to disk")
require("OH_MIC" not in cpp and "ohos.permission.MICROPHONE" not in module,
        "issue #241 must not capture microphone audio")

require('"ohos.permission.FLOAT_VIEW"' not in module and
        '"ohos.permission.SYSTEM_FLOAT_WINDOW"' not in module,
        "capture must not depend on restricted floating-window permissions")
require('"pages/HomeworkCaptureFloatView"' not in pages,
        "obsolete cross-app floating capture page must stay unregistered")
require("libhomeworkcapture.so" in entry_pkg and "externalNativeOptions" in build,
        "native bridge must be wired into the entry module")

require("@kit.CoreVisionKit" in ocr and "textRecognition.recognizeText" in ocr,
        "spike must run Core Vision OCR directly on the captured frame")
require("image.PixelMapFormat.RGBA_8888" in ocr,
        "captured RGBA bytes must be reconstructed as RGBA_8888 PixelMap")
require("result.blocks" in ocr and "cornerPoints" in ocr,
        "OCR evidence must retain line coordinates, not only plain text")
require("libhomeworkcapture.so" in native_runtime and
        "NativeHomeworkCaptureRuntime" in native_runtime,
        "native capture library must be isolated behind NativeHomeworkCaptureRuntime")
require("this.captureRuntime.stopCapture()" in diagnostic,
        "diagnostic page must allow capture to stop after the user returns to the app")
require("this.viewModel.finishByUser()" in capture_page and "返回小伴" in capture_page,
        "formal capture must finish from the app after the user returns from the target chat")
require("PARENT_CAPTURE_DIAGNOSTIC" in routes and "HomeworkCaptureDiagnosticPage" in diagnostic,
        "capture diagnostics must remain reachable through a dedicated formal route")
require("屏幕采集诊断" in capture_home and "onOpenDiagnostics" in capture_home,
        "capture home must expose the formal diagnostic entry under usage guidance")
require("不读取微信数据库" in diagnostic and "不自动点击或滚动微信" in diagnostic,
        "diagnostic UI must keep the product/privacy boundary explicit")
require("CandidateAssignment" not in diagnostic and "AssignmentRepository" not in diagnostic,
        "diagnostic page must not create or mutate assignment business data")
require("测试 Fixture" not in diagnostic and "#241" not in diagnostic and "真机 Gate" not in diagnostic,
        "formal diagnostic UI must not expose feasibility-spike language or fixture content")
for text in ["屏幕采集", "文字识别", "高级诊断信息", "开始诊断"]:
    require(text in diagnostic, f"diagnostic UI missing user-facing capability: {text}")
for detail in ["callbacks=", "sequence=", "OCR 全文", "OCR 行坐标"]:
    require(detail in diagnostic, f"advanced diagnostic evidence must remain available: {detail}")

if errors:
    print("ISSUE_241_CAPTURE_SPIKE_STATIC_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_241_CAPTURE_SPIKE_STATIC_PASS")
