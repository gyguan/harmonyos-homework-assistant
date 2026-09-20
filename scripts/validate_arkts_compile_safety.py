#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VISUAL = ROOT / "entry/src/main/ets/components/practice/PracticeQuestionVisual.ets"
ATTEMPT = ROOT / "entry/src/main/ets/features/student/practice/PracticeAttemptPage.ets"
RESOURCE_API = ROOT / "entry/src/main/ets/application/remote/RemoteAssignmentResourceApi.ets"
AUDIO = ROOT / "entry/src/main/ets/application/assignment/AssignmentAudioPlayerService.ets"

errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def main() -> int:
    visual = VISUAL.read_text(encoding="utf-8")
    attempt = ATTEMPT.read_text(encoding="utf-8")
    resource_api = RESOURCE_API.read_text(encoding="utf-8")
    audio = AUDIO.read_text(encoding="utf-8")

    require("@Prop accessibilityLabel: string = '';" in visual,
            "PracticeQuestionVisual must use a non-ArkUI-reserved Prop name")
    require("@Prop accessibilityText" not in visual,
            "PracticeQuestionVisual must not shadow CustomComponent.accessibilityText")
    require(".accessibilityText(this.accessibilityLabel.length > 0 ?" in visual,
            "Practice visual must still expose ArkUI accessibility text")
    require("accessibilityLabel: this.currentQuestion()!.visualSpec.accessibilityText" in attempt,
            "PracticeAttemptPage must pass visual accessibility text through accessibilityLabel")

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

    syscap = "SystemCapability.Multimedia.Media.AVPlayer"
    require(audio.count(f"canIUse('{syscap}')") >= 2,
            "AVPlayer create/seek paths must be guarded by canIUse")
    require("当前设备不支持语音播放" in audio,
            "audio capability fallback must provide a user-facing error")

    if errors:
        print("ARKTS_COMPILE_SAFETY_FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("ARKTS_COMPILE_SAFETY_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
