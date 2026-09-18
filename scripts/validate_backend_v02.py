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
ai_properties = read("backend/src/main/java/com/xiaoban/homework/ai/AiProviderProperties.java")
ai_transport = read("backend/src/main/java/com/xiaoban/homework/ai/OpenAiCompatibleTransport.java")
model_client = read("backend/src/main/java/com/xiaoban/homework/tutor/ConfigurableTutorModelClient.java")
tutor_prompt = read("backend/src/main/java/com/xiaoban/homework/tutor/TutorPromptBuilder.java")
tutor_controller = read("backend/src/main/java/com/xiaoban/homework/tutor/TutorController.java")
organizer_controller = read("backend/src/main/java/com/xiaoban/homework/organizer/HomeworkOrganizerController.java")
organizer_service = read("backend/src/main/java/com/xiaoban/homework/organizer/HomeworkOrganizerService.java")
organizer_model = read("backend/src/main/java/com/xiaoban/homework/organizer/ConfigurableHomeworkOrganizerModelClient.java")
access_log = read("backend/src/main/java/com/xiaoban/homework/common/AccessLogFilter.java")
payload_log = read("backend/src/main/java/com/xiaoban/homework/common/ApiPayloadLogAdvice.java")
http_log_properties = read("backend/src/main/java/com/xiaoban/homework/common/HttpLogProperties.java")
app_yml = read("backend/src/main/resources/application.yml")
local_example = read("backend/config/application-local.example.yml")
gitignore = read(".gitignore")
app_config = read("entry/src/main/ets/common/config/AppConfig.ets")
backend_session = read("entry/src/main/ets/application/remote/BackendSession.ets")
session_storage = read("entry/src/main/ets/infrastructure/persistence/PreferencesBackendSessionStorage.ets")
family_cloud = read("entry/src/main/ets/application/remote/FamilyCloudService.ets")
settings_page = read("entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets")
tutor_remote = read("entry/src/main/ets/application/remote/TutorRemoteApi.ets")
organizer_remote = read("entry/src/main/ets/application/remote/HomeworkOrganizerRemoteApi.ets")
import_service = read("entry/src/main/ets/application/import/HomeworkImportService.ets")
import_page = read("entry/src/main/ets/features/parent/import/HomeworkImportPage.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
submission_cache = read("entry/src/main/ets/application/remote/RemoteSubmissionCache.ets")
parent_evidence = read("entry/src/main/ets/application/submission/ParentSubmissionEvidenceService.ets")
parent_review = read("entry/src/main/ets/features/parent/review/ParentReviewPane.ets")

for table in ["auth_session", "tutor_session", "tutor_message"]:
    require(f"create table {table}" in v3.lower(), f"missing V0.2 table: {table}")
require("AuthSessionRepository" in auth_tokens and "ConcurrentHashMap" not in auth_tokens,
        "auth sessions must persist in PostgreSQL rather than process memory")
require('@DeleteMapping("/{id}")' in student_controller and "countByFamilyId" in student_service,
        "family management must support guarded child deletion")
require("existsByFamilyIdAndStudentId" in student_service,
        "child deletion must protect children that already own homework")

require('@ConfigurationProperties(prefix = "app.ai")' in ai_properties and
        "tutorModel" in ai_properties and "organizerModel" in ai_properties,
        "AI provider configuration must be centralized and provider-neutral")
require("responses" in ai_transport and "chatCompletion" in ai_transport and
        'body.put("store", false)' in ai_transport and '"json_schema"' in ai_transport,
        "AI transport must support responses/chat-completions and structured output without provider storage")
require(ai_transport.count('body.put("stream", false)') >= 2 and
        ".accept(MediaType.APPLICATION_JSON)" in ai_transport,
        "AI transport must explicitly request non-streaming JSON responses for OpenAI-compatible providers")
require("[AI] config" in ai_transport and "[AI] request" in ai_transport and
        "[AI] response error" in ai_transport and "RestClientResponseException" in ai_transport and
        "sanitizeProviderError" in ai_transport and "keyConfigured" in ai_transport,
        "AI transport must emit safe provider diagnostics for config/request/http errors")
require("isLogPayloads()" in ai_transport and "[AI-PAYLOAD] request" in ai_transport and
        "[AI-PAYLOAD] response" in ai_transport and "sanitizePayloadForLog" in ai_transport,
        "AI transport must support opt-in redacted request/response payload diagnostics")
require("instructions" not in " ".join(
        line for line in ai_transport.splitlines() if "log." in line or "log.info" in line or "log.warn" in line),
        "AI diagnostic logs must not log prompt instructions")
require("input" not in " ".join(
        line for line in ai_transport.splitlines() if "log." in line or "log.info" in line or "log.warn" in line),
        "AI diagnostic logs must not log user/model input")
require("AiProviderProperties" in model_client and "OpenAiCompatibleTransport" in model_client,
        "Tutor business must use the generic configurable AI transport")
require("AiProviderProperties" in organizer_model and "OpenAiCompatibleTransport" in organizer_model,
        "Organizer business must use the generic configurable AI transport")
require("不得编造" in organizer_model and "不解答作业" in organizer_model and "JSON" in organizer_model,
        "AI organizer prompt must avoid hallucinating/solving homework and support JSON fallback")
require("normalizeSubject" in organizer_model and 'normalized.contains("语文")' in organizer_model and
        'normalized.contains("数学")' in organizer_model and 'normalized.contains("英语")' in organizer_model and
        'lower.contains("chinese")' in organizer_model and 'lower.contains("math")' in organizer_model and
        'lower.contains("english")' in organizer_model,
        "AI organizer must normalize common provider subject labels before filtering")
require("unsupportedValues" in organizer_model and "safeSubjectForLog" in organizer_model,
        "AI organizer must expose bounded unsupported subject values for diagnosis")
require("subject 字段必须严格只填写语文、数学或英语之一" in organizer_model,
        "AI organizer prompt must explicitly constrain subject to the supported vocabulary")
require("[AI] organizer parsed" in organizer_model and "unsupportedSubject" in organizer_model and
        "blankTitle" in organizer_model,
        "AI organizer must log privacy-safe conversion counts when model output is filtered")
require("converted.sourceCount() > 0 && converted.candidates().isEmpty()" in organizer_model and
        "return Optional.empty();" in organizer_model,
        "AI organizer must fall back instead of returning a misleading empty AI result when all model assignments are rejected")
for phrase in ["不要直接给出", "个人信息", "可信成年人"]:
    require(phrase in tutor_prompt, f"Tutor safety/guidance prompt missing: {phrase}")
require('@PostMapping("/messages")' in tutor_controller,
        "Tutor API must support real persisted conversations")
require("@RequestParam(required = false) Long before" in tutor_controller and
        '@RequestParam(defaultValue = "40") int limit' in tutor_controller,
        "Tutor history API must expose bounded backward pagination")
require("MODEL_CONTEXT_MESSAGES = 20" in read("backend/src/main/java/com/xiaoban/homework/tutor/TutorService.java"),
        "Tutor model context must stay bounded independently from persisted history")

require("optional:file:./config/application-local.yml" in app_yml,
        "backend must automatically load the external local override file")
require("backend/config/application-local.yml" in gitignore,
        "local backend secrets file must be ignored by Git")
require("app:" in local_example and "ai:" in local_example and "api-key:" in local_example and
        "protocol:" in local_example and "base-url:" in local_example,
        "repository must provide a safe local configuration example")
require("app:\n" in app_yml and "  ai:" in app_yml and "AI_PROTOCOL" in app_yml and
        "AI_BASE_URL" in app_yml and "AI_TUTOR_MODEL" in app_yml and "AI_ORGANIZER_MODEL" in app_yml,
        "public configuration must expose provider-neutral AI settings")
require("AI_LOG_PAYLOADS" in app_yml and "log-payloads: false" in local_example and
        "private boolean logPayloads = false;" in ai_properties,
        "AI payload logging must be explicitly opt-in and documented for local troubleshooting")

require('@PostMapping("/organize")' in organizer_controller and "FAMILY_ID" in organizer_controller,
        "homework organizer must expose an authenticated family-scoped API")
require("familyId.equals(student.familyId)" in organizer_service and "ServiceUnavailable" in organizer_service,
        "organizer must enforce child ownership and expose provider outage for app fallback")
require("/homework/organize" in organizer_remote and "BackendHttpClient" in organizer_remote,
        "HarmonyOS organizer must call the authenticated backend API rather than a model provider directly")
require("HomeworkOrganizerRemoteApi.instance.organize" in import_service and
        "HomeworkOrganizerMode.AI" in import_service and "HomeworkOrganizerMode.LOCAL" in import_service and
        "this.pipeline.parse(extracted)" in import_service,
        "import pipeline must prefer cloud AI and preserve local parser fallback")
require("AI 已整理出" in import_page and "本地规则" in import_page,
        "parent import UI must make AI versus local fallback visible")

require("OncePerRequestFilter" in access_log and "request.getMethod()" in access_log and
        "request.getRequestURI()" in access_log and "response.getStatus()" in access_log and
        "request.getRemoteAddr()" in access_log and "System.nanoTime()" in access_log,
        "backend must emit lightweight method/path/status/duration/client access logs")
for forbidden_log_data in ["Authorization", "getInputStream()", "getReader()"]:
    require(forbidden_log_data not in access_log,
            f"access log must not directly capture sensitive/request-body data: {forbidden_log_data}")
for safe_header in ["X-Request-Id", "X-Client-Scene", "X-Client-Request-Key"]:
    require(safe_header in access_log, f"access log missing safe observability header: {safe_header}")
require("request.getHeader(REQUEST_ID_HEADER)" in access_log and
        "request.getHeader(CLIENT_SCENE_HEADER)" in access_log and
        "request.getHeader(CLIENT_REQUEST_KEY_HEADER)" in access_log,
        "access log may read only the declared correlation/scene/request-key headers")
require("[HTTP-REQUEST]" in access_log and "request.getQueryString()" in access_log,
        "HTTP request logs must include request metadata and query parameters")
require("[HTTP-REQUEST-BODY]" in payload_log and "[HTTP-RESPONSE]" in payload_log and
        "jsonMapper.writeValueAsString" in payload_log,
        "API payload advice must log JSON request and response bodies")
require("password|token|api[-_]?key|authorization" in payload_log and
        "Bearer ***" in payload_log and "sk-***" in payload_log,
        "API payload logs must redact credential-like fields")
require('@ConfigurationProperties(prefix = "app.http")' in http_log_properties and
        "private boolean logPayloads = true;" in http_log_properties and
        "HTTP_LOG_PAYLOADS:true" in app_yml and "HTTP_MAX_PAYLOAD_CHARS:20000" in app_yml,
        "HTTP request/response payload logging must be enabled and bounded by configuration")
require("PreferencesBackendSessionStorage" in session_storage and "initialize(storage" in backend_session,
        "HarmonyOS must restore its backend session from app-private storage")
require("AppConfig.BACKEND_BASE_URL" in backend_session and "http://10.37.255.92:8080" in app_config,
        "HarmonyOS default cloud server must be centralized in AppConfig")
require("FamilyCloudService" in settings_page and "StudentRemoteApi" in family_cloud,
        "parent settings must manage cloud-backed family members")
require("TutorRemoteApi" in study and "/tutor/messages" in tutor_remote,
        "student workspace must use the real backend Tutor API")
require("RemoteSubmissionCache" in parent_evidence and "RemoteSubmissionCache" in submission_cache and
        "RemoteSubmissionApi.instance.latest" in parent_evidence and
        "ParentSubmissionEvidenceService" in parent_review and "CloudSubmissionPhotoStrip" in parent_review,
        "V2 Parent Review must fetch only the latest cross-device submission through the evidence boundary")

ets_root = ROOT / "entry" / "src" / "main" / "ets"
if ets_root.exists():
    for file in ets_root.rglob("*.ets"):
        text = file.read_text(encoding="utf-8")
        if "OPENAI_API_KEY" in text or "AI_API_KEY" in text or "api.openai.com" in text:
            errors.append(f"model credentials/provider endpoint leaked into app code: {file.relative_to(ROOT).as_posix()}")

if errors:
    print("BACKEND_V02_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("BACKEND_V02_GATE_PASS")
