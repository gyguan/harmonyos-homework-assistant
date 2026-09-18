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

pane = read("entry/src/main/ets/components/assignment/VoiceAssignmentPane.ets")
fullscreen = read("entry/src/main/ets/components/assignment/VoiceAssignmentFullscreenDialog.ets")

require("private previousImage()" in pane and "private nextImage()" in pane,
        "normal voice workspace must retain previous/next image navigation")
require("accessibilityText('上一张情景图片')" in pane and
        "accessibilityText('下一张情景图片')" in pane,
        "normal voice workspace must expose both image navigation buttons")
require("Text('全屏')" in pane and "this.fullscreenController.open()" in pane,
        "voice workspace must expose a fullscreen entry")
require("VoiceAssignmentFullscreenDialog" in pane and
        "AssignmentAudioPlayerService" not in fullscreen,
        "fullscreen view must reuse the pane player instead of creating a second AVPlayer service")
for state in ["imageUris: $imageUris", "imageIndex: $imageIndex", "playing: $playing",
              "currentTimeMs: $currentTimeMs", "durationMs: $durationMs"]:
    require(state in pane, f"fullscreen must share media state through @Link: {state}")
require("onToggleAudio" in fullscreen and "onSeek" in fullscreen,
        "fullscreen must delegate play/pause and seek to the existing player")
require("controller.close()" in fullscreen,
        "fullscreen media view must provide an explicit exit")
require("accessibilityText('上一张情景图片')" in fullscreen and
        "accessibilityText('下一张情景图片')" in fullscreen,
        "fullscreen media view must support previous/next image navigation")
require("ForEach(this.imageUris" in fullscreen,
        "fullscreen media view must keep thumbnail switching")
require("Slider({" in fullscreen and "this.onSeek(value)" in fullscreen,
        "fullscreen media view must keep the audio progress slider")

if errors:
    print("VOICE_WORKSPACE_FULLSCREEN_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("VOICE_WORKSPACE_FULLSCREEN_GATE_PASS")
