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
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")

require("Button('全屏查看'" in pane and "this.onFullscreenRequest()" in pane,
        "voice pane must request fullscreen from the workspace")
require("onMediaStateChanged" in pane and "onFullscreenControlsReady" in pane,
        "voice pane must expose media state and controls while retaining its player")
require("AssignmentAudioPlayerService" in pane,
        "voice pane must remain the single audio player owner")
require("bindContentCover" not in pane and "bindContentCover" not in study,
        "voice fullscreen must not use bindContentCover on the current compiler baseline")
require("$this" not in pane and "$this" not in study,
        "voice fullscreen must not contain invalid $this syntax")
require("CustomDialogController" not in pane,
        "voice pane fullscreen must not use CustomDialogController")
require("@State private voiceFullscreenOpen: boolean = false" in study,
        "study workspace must own fullscreen visibility")
require("Stack({ alignContent: Alignment.TopStart })" in study and
        "this.VoiceFullscreenOverlay()" in study,
        "study workspace must render fullscreen as a root Stack overlay")
require("this.voiceFullscreenOpen = false" in study and
        ".onClick(() => this.closeVoiceFullscreen())" in study,
        "fullscreen close must be a normal parent state update")
require("this.voiceToggleAudio()" in study and "this.voiceSeek(value)" in study,
        "fullscreen audio must control the still-mounted pane player")
require("this.voicePreviousImage()" in study and "this.voiceNextImage()" in study and
        "this.voiceSelectImage(index)" in study,
        "fullscreen image controls must delegate to the still-mounted pane")

if errors:
    print("VOICE_WORKSPACE_FULLSCREEN_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("VOICE_WORKSPACE_FULLSCREEN_GATE_PASS")
