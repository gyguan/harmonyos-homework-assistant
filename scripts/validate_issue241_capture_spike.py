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
ocr = read("entry/src/main/ets/experimental/homeworkcapture/HomeworkCaptureOcrService.ets")
spike = read("entry/src/main/ets/experimental/homeworkcapture/HomeworkCaptureSpikePage.ets")
float_page = read("entry/src/main/ets/pages/HomeworkCaptureFloatView.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
import_route = read("entry/src/main/ets/features/parent/import/HomeworkImportRoutePage.ets")
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
    require(api in cpp, f"native spike missing AVScreenCapture API: {api}")

require("OH_AVBuffer_GetAddr" in cpp and "OH_NativeBuffer_GetConfig" in cpp,
        "native bridge must read the RGBA buffer and its stride metadata")
require(re.search(r"=\\s*OH_NativeBuffer_GetConfig\\s*\\(", cpp) is None,
        "OH_NativeBuffer_GetConfig returns void and must not be treated as a status code")
require("SAMPLE_EVERY_CALLBACKS" in cpp,
        "native bridge must sample video callbacks instead of retaining every frame")
require("fwrite(" not in cpp and "std::ofstream" not in cpp,
        "issue #241 must not persist captured chat frames to disk")
require("OH_MIC" not in cpp and "ohos.permission.MICROPHONE" not in module,
        "issue #241 must not capture microphone audio")

require('"ohos.permission.FLOAT_VIEW"' in module,
        "FloatView user-grant permission must be declared")
require('"reason": "$string:float_view_permission_reason"' in module and
        '"usedScene"' in module and '"when": "inuse"' in module,
        "FloatView permission must include reason and in-use scene")
require('"pages/HomeworkCaptureFloatView"' in pages,
        "FloatView content page must be registered")
require("libhomeworkcapture.so" in entry_pkg and "externalNativeOptions" in build,
        "native bridge must be wired into the entry module")

require("@kit.CoreVisionKit" in ocr and "textRecognition.recognizeText" in ocr,
        "spike must run Core Vision OCR directly on the captured frame")
require("image.PixelMapFormat.RGBA_8888" in ocr,
        "captured RGBA bytes must be reconstructed as RGBA_8888 PixelMap")
require("result.blocks" in ocr and "cornerPoints" in ocr,
        "OCR evidence must retain line coordinates, not only plain text")
require("nativeCapture.stopCapture()" in float_page,
        "FloatView must allow the user to stop capture while still in WeChat")
require("PARENT_CAPTURE_SPIKE" in routes and "HomeworkCaptureSpikePage" in spike,
        "issue #241 must remain reachable through an isolated experimental route")
require("#241" in import_route and "onOpenCaptureSpike" in import_route,
        "homework import page must expose an explicit experimental entry")
require("不读取微信数据库" in spike and "不自动点击或滚动微信" in spike,
        "experimental UI must keep the product/privacy boundary explicit")
require("CandidateAssignment" not in spike and "AssignmentRepository" not in spike,
        "feasibility spike must not create or mutate assignment business data")

if errors:
    print("ISSUE_241_CAPTURE_SPIKE_STATIC_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ISSUE_241_CAPTURE_SPIKE_STATIC_PASS")
