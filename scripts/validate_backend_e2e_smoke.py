#!/usr/bin/env python3
from pathlib import Path
import py_compile

ROOT = Path(__file__).resolve().parents[1]
SMOKE = ROOT / "backend/scripts/e2e_smoke.py"
HEALTH = ROOT / "backend/src/main/java/com/xiaoban/homework/common/HealthController.java"
README = ROOT / "backend/README.md"
GITIGNORE = ROOT / ".gitignore"
errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


if not SMOKE.exists():
    errors.append("missing backend/scripts/e2e_smoke.py")
    smoke = ""
else:
    smoke = SMOKE.read_text(encoding="utf-8")
    try:
        py_compile.compile(str(SMOKE), doraise=True)
    except py_compile.PyCompileError as exc:
        errors.append(f"backend e2e smoke must compile: {exc}")

health = HEALTH.read_text(encoding="utf-8") if HEALTH.exists() else ""
readme = README.read_text(encoding="utf-8") if README.exists() else ""
gitignore = GITIGNORE.read_text(encoding="utf-8") if GITIGNORE.exists() else ""

for token in [
    "/api/v1/health",
    "/api/v1/auth/login",
    "/api/v1/auth/session",
    "/api/v1/students",
    "/assignments",
    "/submissions",
    "/tutor/messages",
    "(409,)",
    "(401,)",
    "multipart/form-data",
    "--session-only",
    "--expect-tutor-available",
    "--expect-tutor-unavailable",
    "BACKEND_E2E_SMOKE_PASS",
    "BACKEND_SESSION_RESUME_PASS",
]:
    require(token in smoke, f"backend e2e smoke missing contract marker: {token}")

require("ApplicationAvailability" in health and "ReadinessState.ACCEPTING_TRAFFIC" in health,
        "health endpoint must wait for Spring application readiness before E2E starts")
require("HttpStatus.SERVICE_UNAVAILABLE" in health,
        "health endpoint must reject startup probes until bootstrap runners finish")
require("backend/.e2e-session.json" in gitignore, "local e2e bearer token file must be ignored")
require("真实 Backend E2E Smoke" in readme, "backend README must document real E2E smoke")
require("--session-only" in readme, "backend README must document post-restart session validation")
require("--expect-tutor-available" in readme and "--expect-tutor-unavailable" in readme,
        "backend README must document Tutor real/fallback verification")

if errors:
    print("BACKEND_E2E_SMOKE_GATE_FAIL")
    for item in errors:
        print(f"- {item}")
    raise SystemExit(1)

print("BACKEND_E2E_SMOKE_GATE_PASS")
