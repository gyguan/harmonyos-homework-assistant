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
layer = read("entry/src/main/ets/features/student/study/VoiceFullscreenLayer.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")

require("Button('全屏查看'" in pane and "this.onFullscreenRequest()" in pane,
        "voice pane must request fullscreen from the workspace")
require("onMediaStateChanged" in pane and "onFullscreenControlsReady" in pane,
        "voice pane must expose media state and controls while retaining its player")
require("AssignmentAudioPlayerService" in pane,
        "voice pane must remain the single audio player owner")
require("bindContentCover" not in pane and "bindContentCover" not in study and
        "bindContentCover" not in layer,
        "voice fullscreen must not use bindContentCover on the current compiler baseline")
require("$this" not in pane and "$this" not in study and "$this" not in layer,
        "voice fullscreen must not contain invalid $this syntax")
require("CustomDialogController" not in pane and "CustomDialogController" not in layer,
        "voice fullscreen must not use CustomDialogController")

# 全屏层是窗口级图层，挂在 AppShell 根 Stack；页面内 Stack overlay 盖不住侧栏/标题栏，禁止回退。
require("VoiceFullscreenLayer()" in shell and "VoiceFullscreenHub" in shell,
        "AppShell must mount the window-level VoiceFullscreenLayer at its root Stack")
require("VoiceFullscreenOverlay" not in study and "voiceFullscreenOpen" not in study,
        "study workspace must not keep a page-local fullscreen overlay")
require("VoiceFullscreenHub.instance.open(this.voiceMedia)" in study and
        "VoiceFullscreenHub.instance.update(media)" in study and
        "VoiceFullscreenHub.instance.close()" in study,
        "study workspace must bridge fullscreen open/update/close through the hub")
require("VoiceFullscreenHub.instance.toggleAudio = () => this.voiceToggleAudio()" in study and
        "VoiceFullscreenHub.instance.seek = (value: number) => this.voiceSeek(value)" in study,
        "hub controls must delegate to the still-mounted pane player")
require("VoiceFullscreenHub.instance.resetControls()" in study,
        "study workspace must reset hub controls when unmounted")
require("VoiceFullscreenHub.instance.requestCloseIfOpen()" in shell,
        "system back must exit fullscreen before popping routes")

# 全屏期间隐藏系统栏，退出时恢复。
require("setWindowSystemBarEnable([])" in layer and "setWindowSystemBarEnable(['status', 'navigation'])" in layer,
        "fullscreen layer must toggle immersive system bars")
require("AppStorage.setOrCreate<number>(VoiceFullscreenHub.REVISION_KEY, this.revision)" in layer,
        "hub must publish revision changes into AppStorage for the layer")
require("Swiper()" in layer and ".onChange((index: number)" in layer,
        "fullscreen assignment images must support touch swipe paging")
require(".onClick(() => VoiceFullscreenHub.instance.close())" in layer,
        "fullscreen close button must go through the hub")

if errors:
    print("VOICE_WORKSPACE_FULLSCREEN_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("VOICE_WORKSPACE_FULLSCREEN_GATE_PASS")
