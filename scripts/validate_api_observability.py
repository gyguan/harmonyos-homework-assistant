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


client = read("entry/src/main/ets/application/remote/BackendHttpClient.ets")
access = read("backend/src/main/java/com/xiaoban/homework/common/AccessLogFilter.java")
payload = read("backend/src/main/java/com/xiaoban/homework/common/ApiPayloadLogAdvice.java")
http_config = read("backend/src/main/java/com/xiaoban/homework/common/HttpLogProperties.java")
assignment = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
tutor = read("entry/src/main/ets/application/remote/TutorRemoteApi.ets")
organizer = read("entry/src/main/ets/application/remote/HomeworkOrganizerRemoteApi.ets")
students = read("entry/src/main/ets/application/remote/StudentRemoteApi.ets")
auth = read("entry/src/main/ets/application/remote/BackendAuthService.ets")
submission = read("entry/src/main/ets/application/remote/RemoteSubmissionApi.ets")
e2e = read("backend/scripts/api_observability_e2e.py")

for token in ["X-Request-Id", "X-Client-Scene", "X-Client-Request-Key", "requestFor(", "traceHeaders("]:
    require(token in client, f"BackendHttpClient missing observability primitive: {token}")
require("encodeURIComponent(`" in client and "method}|" in client,
        "request fingerprint must include HTTP method and exact client path/query")
require("Authorization" not in client.split("traceHeaders", 1)[1].split("async request(", 1)[0],
        "trace headers must never include credentials")

for token in ["REQUEST_ID_HEADER", "CLIENT_SCENE_HEADER", "CLIENT_REQUEST_KEY_HEADER",
              "response.setHeader(REQUEST_ID_HEADER", "[HTTP] requestId={}", "[HTTP-DUPLICATE]",
              "DUPLICATE_WINDOW_MS = 1500L"]:
    require(token in access, f"backend access logging missing observability behavior: {token}")
for forbidden in ["getInputStream()", "getReader()", 'getHeader("Authorization")']:
    require(forbidden not in access, f"access logging must not directly capture sensitive data: {forbidden}")
require("[HTTP-REQUEST]" in access and "getQueryString()" in access,
        "access logging must expose query parameters for request diagnosis")
require("[HTTP-REQUEST-BODY]" in payload and "[HTTP-RESPONSE]" in payload,
        "API observability must include request and response payload logs")
require("sanitizeAndTruncate" in payload and "password|token|api[-_]?key|authorization" in payload,
        "payload logs must redact credential-like fields before output")
require("private boolean logPayloads = true;" in http_config and
        "private int maxPayloadChars = 20000;" in http_config,
        "HTTP payload logging must be enabled by default with a bounded payload size")

for scene in [
    "assignment.sync.snapshot", "assignment.query", "assignment.get", "assignment.create", "assignment.batchPublish",
    "assignment.action", "assignment.sync.dirty", "parent.assignment.edit", "parent.review",
]:
    require(scene in assignment, f"assignment API scene missing: {scene}")
for scene in ["tutor.history.latest", "tutor.history.more", "tutor.ask"]:
    require(scene in tutor, f"Tutor API scene missing: {scene}")
require("homework.organize" in organizer, "homework organizer scene missing")
for scene in ["family.students.list", "family.student.save", "family.student.delete"]:
    require(scene in students, f"family API scene missing: {scene}")
for scene in ["auth.login", "auth.session", "auth.logout"]:
    require(scene in auth, f"auth API scene missing: {scene}")
for scene in ["parent.review.evidence", "submission.upload", "submission.photo.download"]:
    require(scene in submission, f"submission API scene missing: {scene}")
require("traceHeaders(path, http.RequestMethod.POST, 'submission.upload')" in submission and
        "traceHeaders(path, http.RequestMethod.GET, 'submission.photo.download')" in submission,
        "direct multipart/photo HTTP calls must participate in correlation tracing")

require("X-Client-Request-Key" in e2e and "X-Request-Id" in e2e and
        "API_OBSERVABILITY_E2E_PASS" in e2e,
        "real E2E must verify request correlation headers")

if errors:
    print("API_OBSERVABILITY_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("API_OBSERVABILITY_GATE_PASS")
