#!/usr/bin/env python3
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_API = ROOT / "entry/src/main/ets/application/remote/RemoteAssignmentResourceApi.ets"
AUDIO = ROOT / "entry/src/main/ets/application/assignment/AssignmentAudioPlayerService.ets"
SUBMISSION_AUDIO_RECORDER = ROOT / "entry/src/main/ets/application/submission/SubmissionAudioRecorderService.ets"
MODULE_CONFIG = ROOT / "entry/src/main/module.json5"
HOMEWORK_IMPORT_INBOX_STORE = ROOT / "entry/src/main/ets/data/local/HomeworkImportInboxStore.ets"
PARENT_REVIEW_PANE = ROOT / "entry/src/main/ets/features/parent/review/ParentReviewPane.ets"
STUDENT_HOME_PAGE = ROOT / "entry/src/main/ets/features/student/home/StudentHomePage.ets"
HOMEWORK_IMAGE_ENCODER = ROOT / "entry/src/main/ets/infrastructure/ai/HomeworkImageEncoder.ets"
SYSCAP_CONFIG = ROOT / "entry/src/main/syscap.json"
PARENT_PRACTICE_GENERATION = ROOT / "entry/src/main/ets/features/parent/practice/ParentPracticeGenerationPage.ets"
PARENT_PRACTICE_GENERATION_RESULT = ROOT / "entry/src/main/ets/features/parent/practice/ParentPracticeGenerationResultPage.ets"
SHARE_RECEIVE = ROOT / "entry/src/main/ets/application/import/HomeworkShareReceiveService.ets"
PARENT_IMPORT_NAV = ROOT / "entry/src/main/ets/app/navigation/ParentImportNavigator.ets"
APP_SHELL = ROOT / "entry/src/main/ets/pages/AppShell.ets"
APP_ROUTES = ROOT / "entry/src/main/ets/app/navigation/AppRoutes.ets"
VOICE_MATERIAL_API = ROOT / "entry/src/main/ets/application/remote/RemoteVoiceMaterialApi.ets"
VOICE_MATERIAL_PICKER = ROOT / "entry/src/main/ets/application/assignment/VoiceMaterialDirectoryPicker.ets"
SUBMISSION_API = ROOT / "entry/src/main/ets/application/remote/RemoteSubmissionApi.ets"
ASSIGNMENT_ATTENTION = ROOT / "entry/src/main/ets/domain/service/AssignmentAttentionPolicy.ets"
HVIGOR_CONFIG = ROOT / "hvigor/hvigor-config.json5"
VERIFY_HARMONY = ROOT / "scripts/verify_harmony_client.ps1"
ETS_ROOT = ROOT / "entry/src/main/ets"
TOEIC_WEEK_THREE = ROOT / "entry/src/main/ets/toeic/content/ToeicWeekThreeContent.ets"
TOEIC_VALIDATOR = ROOT / "entry/src/main/ets/toeic/content/ToeicContentValidator.ets"
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
    submission_audio_recorder = SUBMISSION_AUDIO_RECORDER.read_text(encoding="utf-8")
    module_config = MODULE_CONFIG.read_text(encoding="utf-8")
    homework_import_inbox_store = HOMEWORK_IMPORT_INBOX_STORE.read_text(encoding="utf-8")
    parent_review_pane = PARENT_REVIEW_PANE.read_text(encoding="utf-8")
    student_home_page = STUDENT_HOME_PAGE.read_text(encoding="utf-8")
    image_encoder = HOMEWORK_IMAGE_ENCODER.read_text(encoding="utf-8")
    syscap = json.loads(SYSCAP_CONFIG.read_text(encoding="utf-8"))
    parent_practice_generation = PARENT_PRACTICE_GENERATION.read_text(encoding="utf-8")
    parent_practice_generation_result = PARENT_PRACTICE_GENERATION_RESULT.read_text(encoding="utf-8")
    share_receive = SHARE_RECEIVE.read_text(encoding="utf-8")
    parent_import_nav = PARENT_IMPORT_NAV.read_text(encoding="utf-8")
    app_shell = APP_SHELL.read_text(encoding="utf-8")
    app_routes = APP_ROUTES.read_text(encoding="utf-8")
    voice_material_api = VOICE_MATERIAL_API.read_text(encoding="utf-8")
    voice_material_picker = VOICE_MATERIAL_PICKER.read_text(encoding="utf-8")
    submission_api = SUBMISSION_API.read_text(encoding="utf-8")
    assignment_attention = ASSIGNMENT_ATTENTION.read_text(encoding="utf-8")
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
    require('"daemon": false' in hvigor_config and
            '"incremental": false' in hvigor_config and '"parallel": false' in hvigor_config,
            "Hvigor must use daemon-free non-incremental non-parallel compilation for es2abc stability")
    require('"maxOldSpaceSize": 8192' in hvigor_config,
            "Hvigor must keep the documented 8GB Node heap for stable compilation")
    require("@('--stop-daemon')" in verify_harmony and
            "Removing stale Harmony build cache" in verify_harmony and
            "'.hvigor'" in verify_harmony and "'entry\\build'" in verify_harmony and
            "'--no-daemon', '--no-parallel', '--stacktrace'" in verify_harmony,
            "Harmony verification must stop stale daemons, purge compiler caches, build serially, and retain diagnostics")

    batch_publish = (ROOT / "entry/src/main/ets/application/import/HomeworkBatchPublishService.ets").read_text(encoding="utf-8")
    inbox_service = (ROOT / "entry/src/main/ets/application/import/HomeworkImportInboxService.ets").read_text(encoding="utf-8")
    state_machine = (ROOT / "entry/src/main/ets/domain/service/AssignmentStateMachine.ets").read_text(encoding="utf-8")
    require("sourceEvidence.batchId === undefined ?" not in batch_publish and
            "private sourceBatchId(candidate: CandidateAssignment)" in batch_publish,
            "batch publish must avoid nested optional-field ternaries in es2abc-sensitive code")
    require("enriched.length === 0 || rawImport.studentId" not in inbox_service,
            "import inbox must keep asynchronous student guards as simple branches")
    require("to === AssignmentStatus.PAUSED ||" not in state_machine and
            "to === AssignmentStatus.READY_TO_SUBMIT ||" not in state_machine,
            "assignment state machine must keep transition codegen flattened")
    require("""if (item.status === AssignmentStatus.NEEDS_REWORK) {
        reworkCount++;
        continue;
      }""" in assignment_attention and
            """item.status !== AssignmentStatus.NEEDS_REWORK &&
        AssignmentDueDate.matches""" not in assignment_attention,
            "assignment attention must not compare NEEDS_REWORK again after continue-based narrowing")

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
    require("media.SeekMode." not in audio,
            "optional Media.Core SeekMode must not leak into the AVPlayer seek path")
    require("当前设备不支持语音播放" in audio,
            "audio capability fallback must provide a user-facing error")
    require("let player = await media.createAVPlayer();" in audio,
            "AVPlayer must use the known-good static MediaKit creation path")
    require("await import('@kit.MediaKit')" not in audio,
            "AVPlayer must not restore the runtime-regressing dynamic MediaKit import")
    require("let descriptor: media.AVFileDescriptor = { fd: source.fd, offset: 0, length: -1 };" in audio,
            "AVPlayer must keep the known-good local file descriptor shape")
    require("player.seek(target, media.SeekMode." not in audio,
            "AVPlayer seek must not require optional Media.Core SeekMode")
    require("player.seek(target);" in audio,
            "AVPlayer seek must have a capability-safe fallback when SeekMode is unavailable")

    require("if (canIUse('SystemCapability.Multimedia.Media.Core'))" in audio,
            "AVPlayer creation must directly guard optional Media.Core before using MediaKit")
    require("if (canIUse('SystemCapability.Multimedia.Media.AVRecorder'))" in submission_audio_recorder and
            "if (canIUse('SystemCapability.Multimedia.Media.Core'))" in submission_audio_recorder,
            "submission recorder must directly guard AVRecorder and optional Media.Core capabilities")
    require("openOutputFile(" in submission_audio_recorder and
            "outputUriFromPath(" in submission_audio_recorder,
            "submission recorder must wrap throwing file open and file-uri operations")
    for operation in ["await recorder.pause();", "await recorder.resume();", "await recorder.stop();"]:
        require(operation in submission_audio_recorder,
                f"submission recorder missing operation: {operation}")
    require("student submission recorder pause failed" in submission_audio_recorder and
            "student submission recorder resume failed" in submission_audio_recorder and
            "student submission recorder stop failed" in submission_audio_recorder,
            "submission recorder pause/resume/stop calls must have explicit exception handling")
    require("ohos.permission.MICROPHONE" in module_config and
            "requestPermissionsFromUser" in submission_audio_recorder and
            "ohos.permission.MICROPHONE" in submission_audio_recorder,
            "submission recording must declare and request MICROPHONE permission")
    for stale_source, stale_name in [
        (homework_import_inbox_store, "HomeworkImportInboxStore"),
        (resource_api, "RemoteAssignmentResourceApi"),
        (parent_review_pane, "ParentReviewPane"),
        (student_home_page, "StudentHomePage"),
    ]:
        for stale_field in ["dueText", "dueAtEpochMs", "dueTimezone"]:
            require(stale_field not in stale_source,
                    f"{stale_name} must not restore removed Assignment field {stale_field}")

    require("encoded = await packer.packToData(pixelMap, packing);" in image_encoder and
            "try {" in image_encoder and
            "catch {" in image_encoder and
            "图片压缩失败，请重新选择后重试" in image_encoder,
            "HomeworkImageEncoder.packToData must have explicit exception handling")
    require("let encoded = await packer.packToData(pixelMap, packing);" not in image_encoder,
            "HomeworkImageEncoder must not restore unhandled packToData assignment")

    development_syscaps = syscap.get("development", {}).get("addedSysCaps", [])
    production_syscaps = syscap.get("production", {}).get("addedSysCaps", [])
    for required_syscap in [avplayer_syscap, media_core_syscap]:
        require(required_syscap in development_syscaps,
                f"syscap.json development.addedSysCaps missing {required_syscap}")
    require(avplayer_syscap in production_syscaps,
            "AVPlayer must remain a required production capability for voice/video playback")
    require("SystemCapability.Multimedia.Media.AVRecorder" in production_syscaps,
            "AVRecorder must remain a required production capability for submission recording")
    require(media_core_syscap not in production_syscaps,
            "Media.Core must remain optional in production")
    require("default" in syscap.get("devices", {}).get("general", []) and
            "tablet" in syscap.get("devices", {}).get("general", []),
            "syscap.json must keep phone/default and tablet development device coverage")

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

    validator = TOEIC_VALIDATOR.read_text(encoding="utf-8")
    require("if (translation===undefined) translation=null;" not in validator and
            "if (translation===undefined) {" in validator,
            "TOEIC translation lookup must narrow undefined without assigning null")
    week_three = TOEIC_WEEK_THREE.read_text(encoding="utf-8")
    require(re.search(r"\[[^\]\n]*\bnull\b[^\]\n]*\]", week_three) is None,
            "week-three TOEIC options must not contain null placeholders")

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
