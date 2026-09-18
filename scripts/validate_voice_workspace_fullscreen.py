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
require("Button('←'" in pane and "Button('→'" in pane,
        "normal voice workspace must use visually centered arrow buttons")
require("Button('全屏查看'" in pane and "this.fullscreenController.open()" in pane,
        "voice workspace must expose a prominent fullscreen entry")
require("VoiceAssignmentFullscreenDialog" in pane and
        "AssignmentAudioPlayerService" not in fullscreen,
        "fullscreen view must reuse the pane player instead of creating a second AVPlayer service")
for state in ["imageUris: $imageUris", "imageIndex: $imageIndex", "playing: $playing",
              "currentTimeMs: $currentTimeMs", "durationMs: $durationMs"]:
    require(state in pane, f"fullscreen must share media state through @Link: {state}")
require("fullscreenPlaybackEnabled" not in pane and "fullscreenPrepared" not in pane,
        "fullscreen must not keep duplicated playback readiness state")
require("onClose: () => this.closeFullscreen()" in pane and
        "this.fullscreenController.close()" in pane,
        "fullscreen close must be owned by the parent controller")
require("Button('关闭'" in fullscreen and ".onClick(() => this.onClose())" in fullscreen,
        "fullscreen must use an explicit button that delegates close to the parent")
require("Button(this.playing ? 'Ⅱ' : '▶'" in fullscreen and
        ".onClick(() => this.onToggleAudio())" in fullscreen,
        "fullscreen play/pause must delegate directly to the existing player")
require("playbackEnabled" not in fullscreen and "prepared" not in fullscreen,
        "fullscreen controls must not be blocked by copied readiness links")
require("Button('←'" in fullscreen and "Button('→'" in fullscreen and
        ".alignItems(VerticalAlign.Center)" in fullscreen,
        "fullscreen image arrows must be visually centered")
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
