#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_API = ROOT / "entry/src/main/ets/application/remote/RemoteAssignmentResourceApi.ets"
AUDIO = ROOT / "entry/src/main/ets/application/assignment/AssignmentAudioPlayerService.ets"
PARENT_PRACTICE_GENERATION = ROOT / "entry/src/main/ets/features/parent/practice/ParentPracticeGenerationPage.ets"
PARENT_PRACTICE_GENERATION_RESULT = ROOT / "entry/src/main/ets/features/parent/practice/ParentPracticeGenerationResultPage.ets"
SHARE_RECEIVE = ROOT / "entry/src/main/ets/application/import/HomeworkShareReceiveService.ets"
PARENT_IMPORT_NAV = ROOT / "entry/src/main/ets/app/navigation/ParentImportNavigator.ets"
APP_SHELL = ROOT / "entry/src/main/ets/pages/AppShell.ets"
APP_ROUTES = ROOT / "entry/src/main/ets/app/navigation/AppRoutes.ets"
VOICE_MATERIAL_API = ROOT / "entry/src/main/ets/application/remote/RemoteVoiceMaterialApi.ets"
VOICE_MATERIAL_PICKER = ROOT / "entry/src/main/ets/application/assignment/VoiceMaterialDirectoryPicker.ets"
SUBMISSION_API = ROOT / "entry/src/main/ets/application/remote/RemoteSubmissionApi.ets"
HVIGOR_CONFIG = ROOT / "hvigor/hvigor-config.json5"
VERIFY_HARMONY = ROOT / "scripts/verify_harmony_client.ps1"
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
    parent_practice_generation = PARENT_PRACTICE_GENERATION.read_text(encoding="utf-8")
    parent_practice_generation_result = PARENT_PRACTICE_GENERATION_RESULT.read_text(encoding="utf-8")
    share_receive = SHARE_RECEIVE.read_text(encoding="utf-8")
    parent_import_nav = PARENT_IMPORT_NAV.read_text(encoding="utf-8")
    app_shell = APP_SHELL.read_text(encoding="utf-8")
    app_routes = APP_ROUTES.read_text(encoding="utf-8")
    voice_material_api = VOICE_MATERIAL_API.read_text(encoding="utf-8")
    voice_material_picker = VOICE_MATERIAL_PICKER.read_text(encoding="utf-8")
    submission_api = SUBMISSION_API.read_text(encoding="utf-8")
    hvigor_config = HVIGOR_CONFIG.read_text(encoding="utf-8")
    verify_harmony = VERIFY_HARMONY.read_text(encoding="utf-8")

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

    require(".split('?')[0].split('#')[0]" not in submission_api,
            "RemoteSubmissionApi must avoid chained split/index expressions that can destabilize es2abc")
    require("endsWith('.png')" not in submission_api and "lastIndexOf('.')" in submission_api and
            "substring(dotIndex + 1)" in submission_api,
            "submission media extension parsing must keep the compiler-safe index/substring form")
    require('"incremental": false' in hvigor_config and '"parallel": false' in hvigor_config,
            "Hvigor must use non-incremental non-parallel compilation for es2abc stability")
    require('"maxOldSpaceSize": 8192' in hvigor_config and '"exposeGC": true' in hvigor_config,
            "Hvigor daemon must keep a bounded 8GB heap and expose explicit GC")
    require("@('--stop-daemon')" in verify_harmony and
            "Removing stale Harmony build cache" in verify_harmony and
            "'.hvigor'" in verify_harmony and "'entry\\\\build'" in verify_harmony and
            "'--no-daemon', '--no-parallel', '--stacktrace'" in verify_harmony,
            "Harmony verification must stop stale daemons, purge compiler caches, build serially, and retain diagnostics")

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

    media_core_syscap = "SystemCapability.Multimedia.Media.Core"
    avplayer_syscap = "SystemCapability.Multimedia.Media.AVPlayer"
    require(audio.count(f"if (canIUse('{avplayer_syscap}'))") >= 2,
            "AVPlayer create/seek paths must be directly guarded by AVPlayer canIUse")
    require(f"if (canIUse('{media_core_syscap}'))" in audio,
            "SeekMode access must be directly guarded by Media.Core canIUse")
    require("当前设备不支持语音播放" in audio,
            "audio capability fallback must provide a user-facing error")
    require("let player = await media.createAVPlayer();" in audio,
            "AVPlayer must use the known-good static MediaKit creation path")
    require("await import('@kit.MediaKit')" not in audio,
            "AVPlayer must not restore the runtime-regressing dynamic MediaKit import")
    require("let descriptor: media.AVFileDescriptor = { fd: source.fd, offset: 0, length: -1 };" in audio,
            "AVPlayer must keep the known-good local file descriptor shape")
    require("player.seek(target, media.SeekMode.SEEK_PREV_SYNC);" in audio,
            "AVPlayer seek must keep the known-good synchronized seek mode")
    require("player.seek(target);" in audio,
            "AVPlayer seek must have a capability-safe fallback when SeekMode is unavailable")

    setup_builder_sections = re.findall(
        r"(?ms)^\s*@Builder\s*\n\s*private .*?(?=^\s*@Builder|^\s*build\(\))",
        parent_practice_generation)
    require(len(setup_builder_sections) >= 3,
            "ParentPracticeGenerationPage setup builder sections could not be identified")
    setup_builder_source = "\n".join(setup_builder_sections)
    require(re.search(r"(?m)^\s+let\s+", setup_builder_source) is None,
            "ParentPracticeGenerationPage @Builder bodies must not contain local let declarations")
    require("Button('AI生成练习'" in parent_practice_generation,
            "practice generation setup page must expose the generate action")
    require("PracticeGenerationResult" not in parent_practice_generation,
            "practice generation setup page must not own generated result state")
    require("this.BottomActionBar();" in parent_practice_generation,
            "practice generation setup page must keep its primary action in a dedicated footer")

    result_builder_sections = re.findall(
        r"(?ms)^\s*@Builder\s*\n\s*private .*?(?=^\s*@Builder|^\s*build\(\))",
        parent_practice_generation_result)
    require(len(result_builder_sections) >= 5,
            "ParentPracticeGenerationResultPage builder sections could not be identified")
    result_builder_source = "\n".join(result_builder_sections)
    require(re.search(r"(?m)^\s+let\s+", result_builder_source) is None,
            "ParentPracticeGenerationResultPage @Builder bodies must not contain local let declarations")
    require("LoadingProgress()" in parent_practice_generation_result,
            "practice generation result page must show explicit loading feedback")
    require("this.BottomActionBar();" in parent_practice_generation_result,
            "practice generation result page must keep preview actions in a dedicated footer")
    require("PARENT_PRACTICE_GENERATION_RESULT" in app_routes,
            "practice generation result must have an explicit app route")
    require("ParentPracticeGenerationResultPage" in app_shell,
            "AppShell must register the dedicated practice generation result page")

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
