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

controller = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialController.java")
query_service = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceTaskQueryService.java")
dtos = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialDtos.java")
material_service = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialService.java")
index = read("backend/src/main/resources/static/admin/index.html")
css = read("backend/src/main/resources/static/admin/css/admin.css")
api = read("backend/src/main/resources/static/admin/js/api.js")
app = read("backend/src/main/resources/static/admin/js/app.js")
voice = read("backend/src/main/resources/static/admin/js/voice-material.js")
admin_controller = read("backend/src/main/java/com/xiaoban/homework/admin/AdminPageController.java")

# Web shell and primary entry.
require('@GetMapping({"/admin", "/admin/"})' in admin_controller and
        'forward:/admin/index.html' in admin_controller,
        "admin root must deterministically forward to the static admin shell")
require('id="nav-voice-tasks"' in index and '<span>语音任务</span>' in index,
        "admin shell must expose the voice-task navigation entry")
require('voice-task-stats' not in index and 'voice-stat-created' not in index,
        "voice task management page must not regress to statistic cards")

# Search + server-side pagination.
for element_id in [
    'task-search-form', 'student-select', 'status-filter', 'subject-filter',
    'keyword-filter', 'created-from', 'created-to', 'task-table-body',
    'page-size', 'pagination'
]:
    require(f'id="{element_id}"' in index, f"missing voice task query UI: {element_id}")
require('@GetMapping("/voice-task-items")' in controller and
        '@GetMapping("/voice-task-items/{packageId}")' in controller,
        "voice task list and detail query endpoints must exist")
require("NamedParameterJdbcTemplate" in query_service and
        "limit :limit offset :offset" in query_service and
        "totalElements" in dtos and "totalPages" in dtos,
        "voice task query must use server-side pagination")
require("searchVoiceTasks(currentFilters())" in app and
        "getVoiceTaskDetail(packageId)" in app,
        "Web task list must use paged query and detail APIs")
require("/api/v1/voice-task-items" in api,
        "admin API client must expose voice task query endpoints")
require("listVoiceMaterialPackages(" not in app,
        "Web task search must not fetch the full legacy material package list")

# Result list + detail drawer.
require('id="detail-drawer"' in index and 'id="detail-content"' in index and
        'data-open-detail' in app,
        "query result rows must open a task detail drawer")
require("素材文件" in app and "关联记录" in app and
        "createTaskFromDetail" in app,
        "detail drawer must show source materials/history and support task creation")

# Import entry, import workspace, import result list.
for element_id in [
    'open-import', 'import-drawer', 'folder-input', 'folder-picker',
    'import-table-body', 'start-import', 'import-progress-stage',
    'import-result-stage', 'import-result-body'
]:
    require(f'id="{element_id}"' in index, f"missing voice folder import UI: {element_id}")
require("webkitdirectory" in index and "dragover" in app and
        "webkitGetAsEntry" in app and "collectDroppedDirectory" in app,
        "voice folder import must support directory selection and drag/drop")
require("parseVoiceMaterialPackages" in app and
        "audioCount === 0" in voice and "audioCount > 1" in voice and
        "imageCount === 0" in voice,
        "import preview must validate 1 audio + at least 1 image")
require("uploadSelectedPackages" in app and "completeVoiceMaterialBatch" in app and
        "showImportResults" in app and "renderImportResults" in app,
        "folder import must end in a per-directory result list")
require("audioCount" in dtos and "imageCount" in dtos and
        "PackageResult" in material_service,
        "batch completion results must include material counts for the import result table")

# Existing service boundaries and media preview remain reused.
for endpoint in [
    "/api/v1/auth/login",
    "/voice-material-batches",
    "/voice-material-packages/",
    "/api/v1/media-assets/"
]:
    require(endpoint in api, f"admin must reuse existing API boundary: {endpoint}")
require("AdminVoiceMaterialService" not in controller + app + api,
        "admin refactor must not introduce a duplicate voice-material business service")
require("#1456b8" in css and "#fff" in css and ".data-table" in css and ".drawer-panel" in css,
        "admin shell must keep the white/deep-blue Web management visual baseline")

if errors:
    print("ADMIN_VOICE_IMPORT_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("ADMIN_VOICE_IMPORT_GATE_PASS")
