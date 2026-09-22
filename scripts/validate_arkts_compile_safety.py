#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_API = ROOT / "entry/src/main/ets/application/remote/RemoteAssignmentResourceApi.ets"
AUDIO = ROOT / "entry/src/main/ets/application/assignment/AssignmentAudioPlayerService.ets"
NATIVE_RUNTIME = ROOT / "entry/src/main/ets/infrastructure/capture/NativeHomeworkCaptureRuntime.ets"
CAPTURE_DIAGNOSTIC = ROOT / "entry/src/main/ets/features/parent/import/HomeworkCaptureDiagnosticPage.ets"
CAPTURE_PAGE = ROOT / "entry/src/main/ets/features/parent/import/HomeworkCapturePage.ets"
SHARE_RECEIVE = ROOT / "entry/src/main/ets/application/import/HomeworkShareReceiveService.ets"
PARENT_IMPORT_NAV = ROOT / "entry/src/main/ets/app/navigation/ParentImportNavigator.ets"
APP_SHELL = ROOT / "entry/src/main/ets/pages/AppShell.ets"
APP_ROUTES = ROOT / "entry/src/main/ets/app/navigation/AppRoutes.ets"
VOICE_MATERIAL_API = ROOT / "entry/src/main/ets/application/remote/RemoteVoiceMaterialApi.ets"
VOICE_MATERIAL_PICKER = ROOT / "entry/src/main/ets/application/assignment/VoiceMaterialDirectoryPicker.ets"

errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def main() -> int:
    resource_api = RESOURCE_API.read_text(encoding="utf-8")
    audio = AUDIO.read_text(encoding="utf-8")
    native_runtime = NATIVE_RUNTIME.read_text(encoding="utf-8")
    capture_diagnostic = CAPTURE_DIAGNOSTIC.read_text(encoding="utf-8")
    capture_page = CAPTURE_PAGE.read_text(encoding="utf-8")
    share_receive = SHARE_RECEIVE.read_text(encoding="utf-8")
    parent_import_nav = PARENT_IMPORT_NAV.read_text(encoding="utf-8")
    app_shell = APP_SHELL.read_text(encoding="utf-8")
    app_routes = APP_ROUTES.read_text(encoding="utf-8")
    voice_material_api = VOICE_MATERIAL_API.read_text(encoding="utf-8")
    voice_material_picker = VOICE_MATERIAL_PICKER.read_text(encoding="utf-8")

    legacy_unsafe = [
        "let writer = await fileIo.open(multipartPath",
        "totalBytes += await fileIo.write(writer.fd",
        "let reader = await fileIo.open(multipartPath",
        "let readLength = await fileIo.read(reader.fd",
        "total += await fileIo.write(fd, header)",
        "let source = await fileIo.open(uri",
        "let readLength = await fileIo.read(source.fd",
        "let written = await fileIo.write(fd, chunk",
        "total += await fileIo.write(fd, '\\r\\n')",
    ]
    for pattern in legacy_unsafe:
        require(pattern not in resource_api,
                f"RemoteAssignmentResourceApi still contains unhandled multipart file IO: {pattern}")
    for helper in ["openFile(", "writeText(", "readBuffer(", "writeBuffer("]:
        require(helper in resource_api, f"missing handled file IO helper: {helper}")

    voice_material_unsafe = [
        "let response = await client.request(",
        "let writer = await fileIo.open(",
        "totalBytes += await fileIo.write(",
        "let source = await fileIo.open(",
        "let readLength = await fileIo.read(",
        "let written = await fileIo.write(",
        "let reader = await fileIo.open(",
    ]
    for pattern in voice_material_unsafe:
        require(pattern not in voice_material_api,
                f"RemoteVoiceMaterialApi still contains unhandled throwing call: {pattern}")
    for helper in ["requestUpload(", "openFile(", "writeText(", "readBuffer(", "writeBuffer("]:
        require(helper in voice_material_api,
                f"RemoteVoiceMaterialApi missing handled helper: {helper}")

    require("deviceInfo.apiAvailable('26.0.0')" in voice_material_picker,
            "voice material folder selection must use apiAvailable for API 26 compatibility")
    require("SystemCapability.FileManagement.UserFileService.FolderSelection" in voice_material_picker,
            "voice material folder selection must guard the FolderSelection SysCap")
    require("allowsMulFolderSelection" not in voice_material_picker,
            "voice material picker must not use multi-folder selection because Phone does not support it")
    require("options.maxSelectNumber = 1" in voice_material_picker and
            "DocumentSelectMode.FOLDER" in voice_material_picker,
            "voice material picker must use phone-compatible single-folder selection")
    require("deviceInfo.sdkApiVersion >= 26" not in voice_material_picker,
            "raw sdkApiVersion comparison must not replace ArkTS apiAvailable compatibility protection")

    require("class ParentVoiceMaterialRouteParam" in app_routes,
            "voice material navigation must declare an explicit route param type")
    require("AppRoute.PARENT_VOICE_MATERIAL, {}" not in app_shell,
            "AppShell must not use an untyped object literal for voice material navigation")
    require("new ParentVoiceMaterialRouteParam()" in app_shell,
            "AppShell must use the typed voice material route param")

    syscap = "SystemCapability.Multimedia.Media.AVPlayer"
    require(audio.count(f"canIUse('{syscap}')") >= 2,
            "AVPlayer create/seek paths must be guarded by canIUse")
    require(f"if (canIUse('{syscap}'))" in audio,
            "AVPlayer calls must live inside a positive canIUse branch for ArkTS SysCap analysis")
    require("当前设备不支持语音播放" in audio,
            "audio capability fallback must provide a user-facing error")

    require("libhomeworkcapture.so" in native_runtime,
            "native capture library must be isolated behind NativeHomeworkCaptureRuntime")
    require("libhomeworkcapture.so" not in capture_diagnostic,
            "HomeworkCaptureDiagnosticPage must not import the native library directly")
    require("throw error;" not in share_receive,
            "share receive flow must only throw explicit Error values")
    require("this.openCapture(stack)" not in parent_import_nav,
            "static ParentImportNavigator methods must not dispatch through this")
    for source, name in [
        (capture_page, "HomeworkCapturePage"),
        (capture_diagnostic, "HomeworkCaptureDiagnosticPage"),
    ]:
        require("floatView" not in source and "FLOAT_VIEW" not in source,
                f"{name} must not depend on restricted floating-window APIs")
    for method in ["finishShareImportReady", "finishShareImportEmpty", "cancelShareImport"]:
        require(f"private {method}(): void" in app_shell,
                f"AppShell missing typed share-import callback: {method}")

    if errors:
        print("ARKTS_COMPILE_SAFETY_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("ARKTS_COMPILE_SAFETY_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
