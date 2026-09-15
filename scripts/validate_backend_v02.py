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


v3 = read("backend/src/main/resources/db/migration/V3__auth_tutor_schema.sql")
auth_tokens = read("backend/src/main/java/com/xiaoban/homework/auth/AuthTokenService.java")
student_controller = read("backend/src/main/java/com/xiaoban/homework/student/StudentController.java")
student_service = read("backend/src/main/java/com/xiaoban/homework/student/StudentService.java")
model_client = read("backend/src/main/java/com/xiaoban/homework/tutor/OpenAiTutorModelClient.java")
tutor_prompt = read("backend/src/main/java/com/xiaoban/homework/tutor/TutorPromptBuilder.java")
tutor_controller = read("backend/src/main/java/com/xiaoban/homework/tutor/TutorController.java")
app_yml = read("backend/src/main/resources/application.yml")
backend_session = read("entry/src/main/ets/application/remote/BackendSession.ets")
session_storage = read("entry/src/main/ets/infrastructure/persistence/PreferencesBackendSessionStorage.ets")
family_cloud = read("entry/src/main/ets/application/remote/FamilyCloudService.ets")
settings_page = read("entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets")
tutor_remote = read("entry/src/main/ets/application/remote/TutorRemoteApi.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
submission_cache = read("entry/src/main/ets/application/remote/RemoteSubmissionCache.ets")
progress = read("entry/src/main/ets/features/parent/progress/ParentProgressPage.ets")

for table in ["auth_session", "tutor_session", "tutor_message"]:
    require(f"create table {table}" in v3.lower(), f"missing V0.2 table: {table}")
require("AuthSessionRepository" in auth_tokens and "ConcurrentHashMap" not in auth_tokens,
        "auth sessions must persist in PostgreSQL rather than process memory")
require('@DeleteMapping("/{id}")' in student_controller and "countByFamilyId" in student_service,
        "family management must support guarded child deletion")
require("existsByFamilyIdAndStudentId" in student_service,
        "child deletion must protect children that already own homework")
require('uri("/v1/responses")' in model_client and 'body.put("store", false)' in model_client,
        "Tutor provider must use the Responses API without provider-side conversation storage")
require("OPENAI_API_KEY" in app_yml and "gpt-5.6-luna" in app_yml,
        "Tutor model must be server-configurable and keep credentials off the app")
for phrase in ["不要直接给出", "个人信息", "可信成年人"]:
    require(phrase in tutor_prompt, f"Tutor safety/guidance prompt missing: {phrase}")
require('@PostMapping("/messages")' in tutor_controller,
        "Tutor API must support real persisted conversations")
require("PreferencesBackendSessionStorage" in session_storage and "initialize(storage" in backend_session,
        "HarmonyOS must restore its backend session from app-private storage")
require("FamilyCloudService" in settings_page and "StudentRemoteApi" in family_cloud,
        "parent settings must manage cloud-backed family members")
require("TutorRemoteApi" in study and "/tutor/messages" in tutor_remote,
        "student workspace must use the real backend Tutor API")
require("RemoteSubmissionCache" in progress and "RemoteSubmissionCache" in submission_cache,
        "parent progress must expose cross-device cloud submission metadata")

ets_root = ROOT / "entry" / "src" / "main" / "ets"
if ets_root.exists():
    for file in ets_root.rglob("*.ets"):
        text = file.read_text(encoding="utf-8")
        if "OPENAI_API_KEY" in text or "api.openai.com" in text:
            errors.append(f"OpenAI credentials/provider endpoint leaked into app code: {file.relative_to(ROOT).as_posix()}")

if errors:
    print("BACKEND_V02_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("BACKEND_V02_GATE_PASS")
