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

route = read("entry/src/main/ets/features/student/study/StudyWorkspaceRoutePage.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
pane = read("entry/src/main/ets/components/assignment/VoiceAssignmentPane.ets")

require("assignment.contentType !== AssignmentContentType.AUDIO_IMAGE" in route,
        "voice assignments must hide the duplicated extracurricular context banner")
require("contentType !== AssignmentContentType.AUDIO_IMAGE" in study,
        "voice assignments must hide the duplicated generic ResourcePane")
require("Text('情景图片')" not in pane and "Text('情景对话语音')" not in pane,
        "voice media pane must not repeat section titles")
require(".height(286)" in pane,
        "voice media pane must give the main image more visual space")
require("ForEach(this.imageUris" in pane and "this.selectImage(index)" in pane,
        "voice media pane must provide direct thumbnail image switching")
require("Slider({" in pane and "this.player.seek(value)" in pane,
        "voice media pane must retain audio progress seeking")
require("this.toggleAudio()" in pane and "this.pauseAudio()" in pane,
        "voice media pane must retain play/pause controls")

if errors:
    print("VOICE_WORKSPACE_MEDIA_FOCUS_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("VOICE_WORKSPACE_MEDIA_FOCUS_GATE_PASS")
