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

    direct_size_class_import = re.search(r"import\s*\{[^}]*\bWindowSizeClass\b[^}]*\}", text) is not None
    direct_size_class_branch = re.search(r"\bWindowSizeClass\.(?:COMPACT|MEDIUM|EXPANDED)\b", text) is not None
    if direct_size_class_import or direct_size_class_branch:
        fail(f"feature must not branch on WindowSizeClass; use LayoutPolicy with actual available width: {relative}")

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
    for legacy in [
        "selectedAssignmentId",
        "studentStudyReturnRoute",
        "ParentRoute.CONFIRMATION",
        "CONFIRMATION = 'CONFIRMATION'",
        "contentSizeClass",
        "resolveContent(",
    ]:
        if legacy in app_shell:
            fail(f"AppShell legacy navigation/layout state must be deleted: {legacy}")
    if "AppRoute.PARENT_IMPORT_CONFIRMATION" not in app_shell:
        fail("parent import confirmation must use AppRoute.PARENT_IMPORT_CONFIRMATION")
    if "openParentImportConfirmation" not in app_shell or "NavDestination()" not in app_shell:
        fail("parent import confirmation must use NavDestination instead of AppShell parent route state")

settings_path = ROOT / "entry/src/main/ets/features/parent/settings/BackendConnectionPage.ets"
if settings_path.exists():
    settings = settings_path.read_text(encoding="utf-8")
    if "LayoutPolicy.settingsInlineFieldsRequirement()" not in settings or "availableWidthVp" not in settings:
        fail("parent settings form must use LayoutPolicy and actual available width")
    if "WindowSizeClass" in settings or "sizeClass" in settings:
        fail("parent settings must not keep WindowSizeClass compatibility layout state")

study_route_path = ROOT / "entry/src/main/ets/features/student/study/StudyWorkspaceRoutePage.ets"
if study_route_path.exists():
    study_route = study_route_path.read_text(encoding="utf-8")
    if "AssignmentType.EXTRA" not in study_route or "课外任务" not in study_route:
        fail("study workspace must surface EXTRA assignment context")
    if "StudyWorkspacePage" not in study_route or "AssignmentAction.START" not in study_route:
        fail("EXTRA context must reuse the standard study execution chain")

student_home_path = ROOT / "entry/src/main/ets/features/student/home/StudentHomePage.ets"
if student_home_path.exists():
    student_home = student_home_path.read_text(encoding="utf-8")
    if "HOME_PAD_PRIMARY_ACTION_MAX_WIDTH" not in student_home or "canUsePadComposition()" not in student_home:
        fail("Pad student-home primary action must use capability-based width density")
    if ".width(this.canUsePadComposition() ? AppTheme.HOME_PAD_PRIMARY_ACTION_MAX_WIDTH : '100%')" not in student_home:
        fail("Pad primary action width must be constrained without changing Phone full-width behavior")

responsive_path = ROOT / "entry/src/main/ets/common/responsive/WindowSizeClass.ets"
if responsive_path.exists():
    responsive = responsive_path.read_text(encoding="utf-8")
    for legacy_helper in ["resolveContent", "canUseTwoPane", "twoPaneRequiredWidthVp"]:
        if legacy_helper in responsive:
            fail(f"legacy responsive helper must be removed after Slice 6: {legacy_helper}")

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
