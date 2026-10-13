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


service = read("entry/src/main/ets/application/tutor/TutorQuestionCaptureService.ets")
panel = read("entry/src/main/ets/components/tutor/TutorQuestionCapturePanel.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
tutor_api = read("entry/src/main/ets/application/remote/TutorRemoteApi.ets")
module = read("entry/src/main/module.json5")
ocr = read("entry/src/main/ets/infrastructure/ai/CoreVisionHomeworkTextExtractor.ets")

require("cameraPicker.pick" in service and "PickerMediaType.PHOTO" in service,
        "tutor question capture must use the system CameraPicker photo flow")
require("saveUri" in service and "context.cacheDir" in service,
        "camera result must be written into app cache instead of automatically polluting Gallery")
require("fileIo.openSync" in service and "fileIo.closeSync" in service and service.count("catch") >= 4,
        "camera cache file, CameraPicker and OCR URI attempts must remain explicitly exception guarded")
require("return { captured: false, imageUri: '', recognizedText: '' }" in service,
        "capture failures must return the non-crashing empty result")
require("CoreVisionHomeworkTextExtractor" in service,
        "captured question must reuse local CoreVision OCR")
require("recognizedText" in service and "candidates.push(saveUri)" in service and
        "result.resultUri !== saveUri" in service and "resourceUri: uri" in service,
        "camera OCR must prefer the app-cache saveUri and fall back to the Picker result URI")
require("Button(this.capturing ? '识别中…' : '拍题'" in panel and "只在本机识别" in panel,
        "Tutor composer must expose compact camera capture and clearly explain local-only image recognition")
require("onRecognized" in panel and "this.onRecognized(result.recognizedText)" in panel,
        "recognized question text must be handed back to the editable Tutor draft")
require("本机文字识别暂不可用" in panel and "照片读取失败" in panel and
        "无法打开系统相机" in panel,
        "Tutor capture failures must distinguish OCR, camera and image-read problems")
require("TutorQuestionCapturePanel" not in study and "TutorRemoteApi" not in study and
        "问小伴" not in study,
        "assignment workspace must not expose Tutor question capture after the focused UI simplification")
require("只在本机识别" in panel and ".padding(12)" not in panel,
        "Tutor capture component must remain a compact reusable input accessory")

require("imageUri" not in tutor_api and "photo" not in tutor_api.lower(),
        "Tutor remote API must remain text-only and must not upload the question image")
require("ohos.permission.CAMERA" not in module,
        "system CameraPicker flow must not add a persistent CAMERA permission")
require("textRecognition.recognizeText" in ocr,
        "local OCR adapter must remain the actual recognition implementation")

if errors:
    print("TUTOR_QUESTION_CAPTURE_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("TUTOR_QUESTION_CAPTURE_GATE_PASS")
