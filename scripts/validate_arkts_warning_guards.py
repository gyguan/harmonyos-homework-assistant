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


http_client = read("entry/src/main/ets/application/remote/BackendHttpClient.ets")
submission_api = read("entry/src/main/ets/application/remote/RemoteSubmissionApi.ets")
homework_api = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
capture = read("entry/src/main/ets/application/tutor/TutorQuestionCaptureService.ets")
assignment_controller = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentController.java")

require("await client.request" in http_client and "catch {" in http_client,
        "BackendHttpClient request must remain explicitly exception guarded")
require("后端请求失败，请检查网络或后端地址" in http_client,
        "BackendHttpClient must expose a stable network failure message")

require("canIUse('SystemCapability.MiscServices.Upload')" in submission_api,
        "request.uploadFile must be guarded by SystemCapability.MiscServices.Upload")
require("request.uploadFile" in submission_api,
        "submission upload implementation must remain present")

require("http.RequestMethod.PUT" in homework_api,
        "HarmonyOS assignment updates must use PUT for compatibleSdk 6.0.0(20)")
require("http.RequestMethod.PATCH" not in homework_api,
        "HarmonyOS client must not use PATCH because RequestMethod.PATCH requires SDK 26")
require("@PutMapping(\"/assignments/{id}\")" in assignment_controller,
        "backend must expose the PUT-compatible assignment update endpoint")
require("@PatchMapping(\"/assignments/{id}\")" in assignment_controller,
        "backend must keep the legacy PATCH assignment update endpoint")

require("fileIo.openSync" in capture and "fileIo.closeSync" in capture,
        "Tutor question capture must still create the CameraPicker cache target")
require(capture.count("catch {") >= 3,
        "Tutor question capture must explicitly guard file open, file close and CameraPicker failures")
require("return { captured: false, imageUri: '', recognizedText: '' }" in capture,
        "Tutor capture failure guards must retain the non-crashing fallback result")

if errors:
    print("ARKTS_WARNING_GUARDS_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("ARKTS_WARNING_GUARDS_PASS")
