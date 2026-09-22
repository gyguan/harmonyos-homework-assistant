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


controller = read("backend/src/main/java/com/xiaoban/homework/admin/AdminPageController.java")
index = read("backend/src/main/resources/static/admin/index.html")
css = read("backend/src/main/resources/static/admin/css/admin.css")
api = read("backend/src/main/resources/static/admin/js/api.js")
app = read("backend/src/main/resources/static/admin/js/app.js")
voice = read("backend/src/main/resources/static/admin/js/voice-material.js")

require('@GetMapping({"/admin", "/admin/"})' in controller and 'forward:/admin/index.html' in controller,
        "admin root must deterministically forward to the static admin shell")
require('webkitdirectory' in index and 'id="folder-input"' in index,
        "admin import must support browser folder selection")
require('id="student-select"' in index and 'id="subject-chips"' in index and
        'id="default-minutes"' in index,
        "admin import must expose student, subject and expected-minute defaults")
require('作业管理' in index and '系统' in index and '待扩展' in index,
        "admin shell must keep future navigation placeholders without implementing extra scope")
require('sessionStorage' in api and 'localStorage' not in api,
        "admin auth token must remain session-scoped instead of persistent localStorage")
for endpoint in [
    "/api/v1/auth/login",
    "/api/v1/students",
    "/voice-material-batches",
    "/voice-material-packages/",
]:
    require(endpoint in api, f"admin import must reuse existing API boundary: {endpoint}")
require("webkitRelativePath" in voice and "parseVoiceMaterialPackages" in voice,
        "browser directory import must group files using relative paths")
require("audioCount === 0" in voice and "audioCount > 1" in voice and "imageCount === 0" in voice,
        "admin preview must enforce 1 audio + at least 1 image before upload")
require("completeVoiceMaterialBatch" in app and "registerVoiceMaterialPackage" in app and
        "uploadVoiceMaterialFile" in app,
        "admin upload must execute the existing batch/package/file/complete workflow")
require("registrationFailures" in app and "failures === 0" in app,
        "partial failures must be surfaced and failed selections retained for retry")
require("AdminVoiceMaterialService" not in controller + app + api,
        "admin import must not introduce a second voice-material business service")
require("#1456b8" in css and "#fff" in css,
        "admin shell must keep the low-saturation white/deep-blue visual baseline")

if errors:
    print("ADMIN_VOICE_IMPORT_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ADMIN_VOICE_IMPORT_GATE_PASS")
