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

store = read("entry/src/main/ets/data/HomeworkStore.ets")
repository = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
remote = read("entry/src/main/ets/application/remote/RemoteModels.ets")

require("contentType: source.contentType === AssignmentContentType.AUDIO_IMAGE" in store,
        "HomeworkStore.cloneAssignment must retain AUDIO_IMAGE")
require("contentType: base.contentType === AssignmentContentType.AUDIO_IMAGE" in repository,
        "editable Assignment merge must retain AUDIO_IMAGE")
require("assignment()!.contentType === AssignmentContentType.AUDIO_IMAGE" in study,
        "StudyWorkspace must render voice media from Assignment.contentType")
require("contentType: remote.contentType === AssignmentContentType.AUDIO_IMAGE" in remote,
        "remote Assignment mapping must hydrate AUDIO_IMAGE")
require("contentType: AssignmentContentType.NORMAL" in store,
        "local normal Assignment creation must set NORMAL explicitly")

if errors:
    print("VOICE_ASSIGNMENT_CONTENT_TYPE_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("VOICE_ASSIGNMENT_CONTENT_TYPE_GATE_PASS")
