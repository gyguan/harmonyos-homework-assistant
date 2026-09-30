#!/usr/bin/env python3
from pathlib import Path
import re
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

access = read("backend/src/main/java/com/xiaoban/homework/common/AccessLogFilter.java")
handler = read("backend/src/main/java/com/xiaoban/homework/common/ApiExceptionHandler.java")
config = read("backend/src/main/resources/application.yml")
assignment = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
review = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentReviewService.java")
submission = read("backend/src/main/java/com/xiaoban/homework/submission/SubmissionService.java")
generation = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeGenerationService.java")
attempt = read("backend/src/main/java/com/xiaoban/homework/practice/PracticeAttemptService.java")
tutor = read("backend/src/main/java/com/xiaoban/homework/tutor/TutorService.java")
voice = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialService.java")
voice_assignment = read("backend/src/main/java/com/xiaoban/homework/voicematerial/VoiceMaterialAssignmentService.java")
auth = read("backend/src/main/java/com/xiaoban/homework/auth/AuthService.java")
standard = read("docs/architecture/backend-logging-standard.md")
agents = read("AGENTS.md")

require('MDC.put("requestId", requestId)' in access and
        'MDC.put("scene", scene)' in access and
        'MDC.remove("requestId")' in access and
        'MDC.remove("scene")' in access,
        "HTTP trace context must be scoped through MDC")
require("%X{requestId}" in config and "%X{scene}" in config,
        "console log pattern must expose MDC requestId and scene")
require("api service_unavailable" in handler and "api unexpected_error" in handler and
        "@ExceptionHandler(Exception.class)" in handler,
        "API exception handler must log degraded and unexpected failures")
require("assignment created" in assignment and
        "assignment state_changed" in assignment and
        "assignment auto_paused" in assignment and
        "assignment deleted" in assignment,
        "Assignment lifecycle logs are required")
require("assignment_review completed" in review,
        "assignment review completion log is required")
require("submission created" in submission,
        "submission completion log is required")
require("practice_generation started" in generation and
        "practice_generation ready" in generation and
        "practice_generation failed" in generation and
        "practice_generation published" in generation,
        "Practice generation lifecycle logs are required")
require("practice_attempt started" in attempt and
        "practice_attempt submitted" in attempt,
        "Practice attempt lifecycle logs are required")
require("tutor ask_success" in tutor and
        "tutor ask_unavailable" in tutor and
        "tutor ask_failed" in tutor,
        "Tutor business outcome logs are required")
require("voice_material batch_created" in voice and
        "voice_material package_registered" in voice and
        "voice_material batch_completed" in voice,
        "voice material aggregate logs are required")
require("voice_material manual_create_start" in voice_assignment and
        "voice_material manual_create_success" in voice_assignment,
        "manual voice assignment logs are required")
require("auth login_success" in auth and "auth login_failed" in auth,
        "privacy-safe auth event logs are required")
require("后端日志规范" in standard and "敏感信息" in standard and
        "validate_backend_logging.py" in standard,
        "backend logging standard must document privacy and validation rules")
require("backend-logging-standard.md" in agents,
        "AGENTS.md must point backend changes to the logging standard")

forbidden = [
    "request.password(",
    "passwordHash",
    "request.text(",
    "assistant.content",
    ".reviewNote",
    ".instruction",
    ".sourceExcerpt",
    ".generatedJson",
    ".originalName",
]
java_root = ROOT / "backend/src/main/java"
log_call = re.compile(r"log\.(?:info|warn|error|debug)\((.*?)\);", re.DOTALL)
for file in java_root.rglob("*.java"):
    content = file.read_text(encoding="utf-8")
    if "System.out.print" in content or "System.err.print" in content:
        errors.append(f"direct stdout/stderr logging is forbidden: {file.relative_to(ROOT)}")
    for match in log_call.finditer(content):
        block = match.group(1)
        for token in forbidden:
            if token in block:
                errors.append(
                    f"sensitive/raw business content in log call: {file.relative_to(ROOT)} token={token}"
                )

if errors:
    print("BACKEND_LOGGING_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("BACKEND_LOGGING_GATE_PASS")
