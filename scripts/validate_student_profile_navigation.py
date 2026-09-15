#!/usr/bin/env python3
from pathlib import Path

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


shell = read("entry/src/main/ets/pages/AppShell.ets")
profile = read("entry/src/main/ets/features/student/profile/StudentProfilePage.ets")

require("PROFILE = 'PROFILE'" in shell, "student navigation must define a PROFILE route")
require("StudentProfilePage" in shell, "AppShell must render StudentProfilePage")
require("this.studentRoute === StudentRoute.PROFILE" in shell,
        "student profile route must have an active navigation state")
require(shell.count("() => this.studentRoute = StudentRoute.PROFILE") >= 2,
        "both phone bottom navigation and pad side navigation must open student profile")
require("'我的', false, () => {}" not in shell,
        "student 我的 must never regress to an empty navigation action")

for token in ["getStudent()", "grade", "className", "semester", "textbookSummary"]:
    require(token in profile, f"student profile must show current student field: {token}")
for token in ["getSettings()", "tutorGuidanceFirst", "directAnswerAllowed", "AI 辅导规则"]:
    require(token in profile, f"student profile must show existing tutor rule: {token}")

require("setActiveStudent" not in profile and "getStudents()" not in profile,
        "student profile must not expose sibling switching")
require("BackendSession" not in profile and "FamilyCloudService" not in profile,
        "student profile must not expose family/cloud administration")
require("由家长" in profile,
        "student profile must explain that profile/settings changes belong to the parent space")

if errors:
    print("STUDENT_PROFILE_NAVIGATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("STUDENT_PROFILE_NAVIGATION_GATE_PASS")
