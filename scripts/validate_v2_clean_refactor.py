#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

# Temporary migration allowlist. Entries must be removed when the corresponding V2 slice
# switches its default route. New feature files are never added here casually.
LEGACY_FEATURE_STORE_ALLOWLIST = {
    "entry/src/main/ets/features/student/today/StudentTodayPage.ets",
    "entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets",
    "entry/src/main/ets/features/student/profile/StudentProfilePage.ets",
    "entry/src/main/ets/features/parent/import/HomeworkImportPage.ets",
    "entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets",
    "entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets",
}


def fail(message: str) -> None:
    errors.append(message)


feature_root = ROOT / "entry/src/main/ets/features"
for file in feature_root.rglob("*.ets"):
    relative = file.relative_to(ROOT).as_posix()
    text = file.read_text(encoding="utf-8")
    if "HomeworkStore.instance" in text and relative not in LEGACY_FEATURE_STORE_ALLOWLIST:
        fail(f"new/migrated feature must use Repository/ViewModel instead of HomeworkStore.instance: {relative}")

    if re.search(r"(?:<=|>=|<|>)\s*(?:600|840|1080)\b", text):
        fail(f"feature contains private device-style layout breakpoint: {relative}")

    for token in ["isPreview", "isCI", "deviceModel", "deviceType"]:
        if token in text:
            fail(f"feature contains prohibited Preview/CI/device branch {token}: {relative}")

# V2 deep-page state belongs to NavPathStack/NavDestination, never AppShell @State.
app_shell_path = ROOT / "entry/src/main/ets/pages/AppShell.ets"
if app_shell_path.exists():
    app_shell = app_shell_path.read_text(encoding="utf-8")
    state_names = set(re.findall(r"@State\s+private\s+(\w+)\s*:", app_shell))
    suspicious = {
        name for name in state_names
        if "selected" in name.lower() or "returnroute" in name.lower() or name.lower().endswith("assignmentid")
    }
    if suspicious:
        fail(f"AppShell contains feature-specific navigation state: {sorted(suspicious)}")
    for legacy in ["selectedAssignmentId", "studentStudyReturnRoute"]:
        if legacy in app_shell:
            fail(f"AppShell legacy navigation state must be deleted: {legacy}")

# V2 keeps one Assignment aggregate. A parallel ExtraHomework domain is explicitly forbidden.
for root in [ROOT / "entry/src/main/ets", ROOT / "backend/src/main/java"]:
    if not root.exists():
        continue
    for file in root.rglob("*"):
        if not file.is_file() or file.suffix not in {".ets", ".ts", ".java"}:
            continue
        text = file.read_text(encoding="utf-8")
        if "ExtraHomework" in text:
            fail(f"parallel ExtraHomework domain is forbidden; use AssignmentType.EXTRA: {file.relative_to(ROOT)}")

if errors:
    print("V2_CLEAN_REFACTOR_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_CLEAN_REFACTOR_GATE_PASS")
