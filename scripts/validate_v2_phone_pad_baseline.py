#!/usr/bin/env python3
from pathlib import Path
import re

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


theme = read("entry/src/main/ets/common/theme/AppTheme.ets")
layout_policy = read("entry/src/main/ets/common/responsive/LayoutPolicy.ets")
responsive = read("entry/src/main/ets/common/responsive/WindowSizeClass.ets")
home = read("entry/src/main/ets/features/student/home/StudentHomePage.ets")
assignments = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets")
filter_dialog = read("entry/src/main/ets/features/student/assignments/AssignmentFilterDialog.ets")
detail = read("entry/src/main/ets/features/student/assignments/StudentAssignmentDetailPage.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
study_route = read("entry/src/main/ets/features/student/study/StudyWorkspaceRoutePage.ets")
app_shell = read("entry/src/main/ets/pages/AppShell.ets")
spec = read("docs/product/v2-phone-pad-baseline-standard.md")

for token in [
    "HOME_READABLE_MAX_WIDTH",
    "ASSIGNMENT_LIST_READABLE_MAX_WIDTH",
    "ASSIGNMENT_DETAIL_READABLE_MAX_WIDTH",
    "STUDY_READABLE_MAX_WIDTH",
    "FILTER_DIALOG_MAX_WIDTH",
    "STUDY_PRIMARY_MIN_WIDTH",
    "STUDY_TUTOR_MIN_WIDTH",
]:
    require(token in theme, f"AppTheme missing Phone/Pad baseline token: {token}")

for token in [
    "export class LayoutRequirement",
    "export class LayoutPolicy",
    "assignmentMasterDetailRequirement",
    "studyTutorRequirement",
    "requiredWidth",
    "canSplit",
]:
    require(token in layout_policy, f"LayoutPolicy missing required capability: {token}")

require("LayoutPolicy" in responsive and "assignmentMasterDetailRequirement" in responsive,
        "responsive content capability must delegate to LayoutPolicy")
require("AppTheme.HOME_READABLE_MAX_WIDTH" in home,
        "Student Home must keep a readable single-column fallback")
require("alignItems(HorizontalAlign.Center)" in home,
        "Student Home must center its fallback/wide content surfaces")
require("AppTheme.ASSIGNMENT_LIST_READABLE_MAX_WIDTH" in assignments,
        "Assignment List must keep the shared readable-width fallback token")
require("AppTheme.FILTER_DIALOG_MAX_WIDTH" in filter_dialog,
        "Assignment filter dialog must be width-capped on wide containers")
require("AppTheme.ASSIGNMENT_DETAIL_READABLE_MAX_WIDTH" in detail,
        "Assignment Detail must use the shared readable-width token")
require("AppTheme.STUDY_READABLE_MAX_WIDTH" in study and "AppTheme.STUDY_TITLE_SIZE" in study,
        "Study Workspace must keep shared readable-width and title tokens")

for text, path in [
    (study, "StudyWorkspacePage.ets"),
    (study_route, "StudyWorkspaceRoutePage.ets"),
]:
    require("WindowSizeClass." not in text,
            f"migrated Study surface must not branch on WindowSizeClass enum values: {path}")
    require("@Prop sizeClass" not in text and "this.sizeClass" not in text,
            f"migrated Study surface must not branch on sizeClass: {path}")

study_destination = app_shell.split("StudyWorkspaceRoutePage({", 1)
require(len(study_destination) == 2,
        "AppShell must still route to StudyWorkspaceRoutePage")
if len(study_destination) == 2:
    study_call = study_destination[1].split("});", 1)[0]
    require("sizeClass:" not in study_call,
            "AppShell must not pass a shell size class into the migrated Study feature")

feature_texts = [home, assignments, filter_dialog, detail, study, study_route]
magic_breakpoint = re.compile(r"(?:<=|>=|<|>)\s*(?:600|840|1080)\b")
for text in feature_texts:
    require(magic_breakpoint.search(text) is None,
            "migrated V2 student surfaces must not introduce private device-style breakpoints")
    for token in ["isPhone", "isTablet", "isPadDevice", "deviceType", "deviceModel"]:
        require(token not in text,
                f"migrated V2 student surfaces must not branch on device identity: {token}")

require("LayoutPolicy" in spec and "基础适配不能延期" in spec,
        "Phone/Pad baseline spec must require LayoutPolicy and mandatory baseline adaptation")
require("完整 Pad 增强" in spec,
        "Phone/Pad baseline spec must distinguish baseline from richer Pad composition work")

if errors:
    print("V2_PHONE_PAD_BASELINE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("V2_PHONE_PAD_BASELINE_PASS")
