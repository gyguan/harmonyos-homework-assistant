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
legacy = ROOT / "entry/src/main/ets/components/assignment/VoiceAssignmentFullscreenDialog.ets"

require("private previousImage()" in pane and "private nextImage()" in pane,
        "normal voice workspace must retain previous/next image navigation")
require("Button('←'" in pane and "Button('→'" in pane,
        "voice workspace must use visually centered arrow buttons")
require("Button('全屏查看'" in pane,
        "voice workspace must expose a prominent fullscreen entry")
require("@State private fullscreenOpen: boolean = false" in pane,
        "fullscreen visibility must be state-driven")
require("this.fullscreenOpen = true" in pane and "this.fullscreenOpen = false" in pane,
        "fullscreen open/close must directly update local state")
require(".bindContentCover($$this.fullscreenOpen, this.FullscreenMediaView())" in pane,
        "fullscreen must use a state-driven full modal instead of CustomDialogController")
require("CustomDialogController" not in pane and "VoiceAssignmentFullscreenDialog" not in pane,
        "voice fullscreen must not depend on the legacy CustomDialog path")
require("Button('关闭'" in pane and ".onClick(() => this.closeFullscreen())" in pane,
        "fullscreen close button must directly close the local state-driven modal")
require("Button(this.playing ? 'Ⅱ' : '▶'" in pane and
        ".onClick(() => { void this.toggleAudio(); })" in pane,
        "fullscreen play/pause must call the same pane player directly")
require("this.player.seek(value)" in pane,
        "fullscreen progress slider must seek on the same player")
require("ForEach(this.imageUris" in pane,
        "fullscreen media view must keep thumbnail switching")
require(not legacy.exists(),
        "legacy VoiceAssignmentFullscreenDialog must be removed after state-modal migration")

if errors:
    print("VOICE_WORKSPACE_FULLSCREEN_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("VOICE_WORKSPACE_FULLSCREEN_GATE_PASS")
