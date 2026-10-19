#!/usr/bin/env python3
"""Guard explicit ArkTS types in organizer remote APIs while HAP CI is unavailable."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]
directory = root / "entry/src/main/ets/application/remote"
organizer = (directory / "HomeworkOrganizerRemoteApi.ets").read_text(encoding="utf-8")
feedback = (directory / "HomeworkOrganizerFeedbackRemoteApi.ets").read_text(encoding="utf-8")
teacher = (directory / "HomeworkStudentTeacherRemoteApi.ets").read_text(encoding="utf-8")

checks = {
    "Map oldest key must not use IteratorResult.value with any/unknown type": (
        ".keys().next().value" not in organizer
        and "for (let oldestKey of this.originalById.keys())" in organizer
    ),
    "Experience active request must be explicitly typed": (
        "interface HomeworkExperienceActiveRequest" in feedback
        and "let payload: HomeworkExperienceActiveRequest = { active: active };" in feedback
        and "http.RequestMethod.PUT, payload)" in feedback
    ),
    "Teacher registration request must be explicitly typed": (
        "interface HomeworkTeacherRegistrationRequest" in teacher
        and "let payload: HomeworkTeacherRegistrationRequest = {" in teacher
        and "http.RequestMethod.POST, payload)" in teacher
    ),
}
failures = [message for message, ok in checks.items() if not ok]
if failures:
    print("ORGANIZER_ARKTS_TYPES_FAIL")
    for message in failures:
        print(f"- {message}")
    raise SystemExit(1)
print("ORGANIZER_ARKTS_TYPES_PASS")
