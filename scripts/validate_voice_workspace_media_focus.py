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
parent = read("entry/src/main/ets/features/parent/voice/ParentVoiceAssignmentPage.ets")
media_picker = read("entry/src/main/ets/application/assignment/VoiceAssignmentMediaService.ets")
remote_resource = read("entry/src/main/ets/application/remote/RemoteAssignmentResourceApi.ets")
backend_resource = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentResourceService.java")

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
require("Swiper()" in pane and ".onChange((index: number) => { void this.showImage(index); })" in pane,
        "voice media pane must support direct touch swipe paging")
require("let merged = this.imageUris.slice()" in parent and
        "existing: Set<string>" in parent and
        "＋ 继续添加图片" in parent,
        "parent voice assignment must append and deduplicate image selections")
require("MAX_VOICE_IMAGES_PER_PICK" in media_picker and
        "maxSelectNumber: MAX_VOICE_IMAGES_PER_PICK" in media_picker,
        "nine images must remain only a per-picker selection limit")
require("imageUris.length > 9" not in remote_resource and
        "MAX_IMAGES" not in backend_resource,
        "voice assignment publishing must not impose a total nine-image limit")
require("images.sort(" in pane and "compareImageResources" in pane and
        "originalName.toLowerCase()" in pane,
        "student voice images must use natural filename ordering")
require("loadImage(index: number)" in pane and "prefetchNextImage" in pane and
        "void this.prefetchNextImage(0)" in pane,
        "student voice images must load on demand and prefetch the next image")
require("pendingDownloads" in remote_resource,
        "resource downloads must deduplicate concurrent prefetch and foreground requests")
require("void this.loadAudio(audio)" in pane and "正在加载语音…" in pane,
        "voice audio must load independently after the first image becomes visible")
require("void this.load(this.lifecycleVersion)" in pane and
        "void this.load();" not in pane and
        "lifecycleVersion" in pane,
        "voice media reloads must preserve lifecycle guards")


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
