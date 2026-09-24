#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_API = ROOT / "entry/src/main/ets/application/remote/RemoteAssignmentResourceApi.ets"
AUDIO = ROOT / "entry/src/main/ets/application/assignment/AssignmentAudioPlayerService.ets"
SHARE_RECEIVE = ROOT / "entry/src/main/ets/application/import/HomeworkShareReceiveService.ets"
PARENT_IMPORT_NAV = ROOT / "entry/src/main/ets/app/navigation/ParentImportNavigator.ets"
APP_SHELL = ROOT / "entry/src/main/ets/pages/AppShell.ets"
APP_ROUTES = ROOT / "entry/src/main/ets/app/navigation/AppRoutes.ets"
VOICE_MATERIAL_API = ROOT / "entry/src/main/ets/application/remote/RemoteVoiceMaterialApi.ets"
VOICE_MATERIAL_PICKER = ROOT / "entry/src/main/ets/application/assignment/VoiceMaterialDirectoryPicker.ets"
ACTION_CONTROLS = ROOT / "entry/src/main/ets/components/action/ActionControls.ets"
ETS_ROOT = ROOT / "entry/src/main/ets"
QUALIFIED_MODEL_SYMBOLS = [
    "AssignmentStatus",
    "AssignmentType",
    "AssignmentContentType",
    "AssignmentBacking",
    "AssignmentResourceType",
    "Subject",
    "SubmissionType",
    "HomeworkImportSourceKind",
]

errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def imports_symbol(source: str, symbol: str) -> bool:
    if re.search(rf"\b(?:enum|class|interface|type)\s+{re.escape(symbol)}\b", source):
        return True
    for match in re.finditer(r"import\s*\{([^}]*)\}\s*from", source, flags=re.S):
        names = [part.strip().split(" as ")[0].strip() for part in match.group(1).split(",")]
        if symbol in names:
            return True
    return False


def validate_qualified_model_imports() -> None:
    for file in ETS_ROOT.rglob("*.ets"):
        source = file.read_text(encoding="utf-8")
        for symbol in QUALIFIED_MODEL_SYMBOLS:
            if re.search(rf"\b{re.escape(symbol)}\s*\.", source) and not imports_symbol(source, symbol):
                relative = file.relative_to(ROOT)
                errors.append(
                    f"{relative} uses {symbol}. but does not import or declare {symbol}")


def main() -> int:
    resource_api = RESOURCE_API.read_text(encoding="utf-8")
    audio = AUDIO.read_text(encoding="utf-8")
    share_receive = SHARE_RECEIVE.read_text(encoding="utf-8")
    parent_import_nav = PARENT_IMPORT_NAV.read_text(encoding="utf-8")
    app_shell = APP_SHELL.read_text(encoding="utf-8")
    app_routes = APP_ROUTES.read_text(encoding="utf-8")
    voice_material_api = VOICE_MATERIAL_API.read_text(encoding="utf-8")
    voice_material_picker = VOICE_MATERIAL_PICKER.read_text(encoding="utf-8")
    action_controls = ACTION_CONTROLS.read_text(encoding="utf-8")

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

    require("class ParentVoiceCreateRouteParam" in app_routes,
            "voice assignment creation navigation must declare an explicit route param type")
    require("AppRoute.PARENT_VOICE_CREATE, {}" not in app_shell,
            "AppShell must not use an untyped object literal for voice assignment creation")
    require("new ParentVoiceCreateRouteParam()" in app_shell,
            "AppShell must use the typed voice assignment creation route param")
    require("PARENT_VOICE_MATERIAL" not in app_routes and "PARENT_VOICE_MATERIAL" not in app_shell,
            "legacy standalone voice-material navigation must not reappear")

    require("onAction: () => void = () => {};" in action_controls,
            "shared action controls must use onAction instead of the ArkUI-reserved onClick property")
    require("onClick: () => void = () => {};" not in action_controls,
            "custom ActionButton/TextAction must not shadow CustomComponent.onClick")
    require("@Prop size:" not in action_controls,
            "custom ActionButton must not shadow CustomComponent.size")
    require("@Prop actionSize: ActionButtonSize" in action_controls,
            "ActionButton must expose ArkUI-safe actionSize instead of size")
    for file in ETS_ROOT.rglob("*.ets"):
        source = file.read_text(encoding="utf-8")
        relative = file.relative_to(ROOT)
        require(
            re.search(r"^\s*onClick\s*:\s*\([^\n]*\)\s*=>\s*void\s*=", source, flags=re.M) is None,
            f"{relative} declares a custom onClick callback that can collide with ArkUI CommonAttribute")
        if file != ACTION_CONTROLS:
            require(
                "onAction: () =>" not in source,
                f"{relative} uses an implicitly typed shared action callback; declare (): void explicitly")
            require(
                re.search(r"onAction:\s*\(\):\s*void\s*=>\s*this\.[A-Za-z0-9_]+\s*=", source) is None,
                f"{relative} returns an assignment value from a void onAction callback; use a block body")

    syscap = "SystemCapability.Multimedia.Media.AVPlayer"
    require(audio.count(f"canIUse('{syscap}')") >= 2,
            "AVPlayer create/seek paths must be guarded by canIUse")
    require(f"if (canIUse('{syscap}'))" in audio,
            "AVPlayer calls must live inside a positive canIUse branch for ArkTS SysCap analysis")
    require("当前设备不支持语音播放" in audio,
            "audio capability fallback must provide a user-facing error")

    require("throw error;" not in share_receive,
            "share receive flow must only throw explicit Error values")
    require("this.openCapture(stack)" not in parent_import_nav,
            "static ParentImportNavigator methods must not dispatch through this")
    for method in ["finishShareImportReady", "finishShareImportEmpty", "cancelShareImport"]:
        require(f"private {method}(): void" in app_shell,
                f"AppShell missing typed share-import callback: {method}")

    for retired_capture_path in [
        "entry/src/main/ets/features/parent/import/HomeworkCapturePage.ets",
        "entry/src/main/ets/features/parent/import/HomeworkCaptureHomePage.ets",
        "entry/src/main/ets/features/parent/import/HomeworkCaptureDiagnosticPage.ets",
        "entry/src/main/ets/features/parent/import/HomeworkSourceProfilePage.ets",
    ]:
        require(not (ROOT / retired_capture_path).exists(),
                f"retired screen-capture source must stay removed: {retired_capture_path}")

    validate_qualified_model_imports()

    if errors:
        print("ARKTS_COMPILE_SAFETY_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("ARKTS_COMPILE_SAFETY_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
