#!/usr/bin/env python3
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def read(path: str) -> str:
    file = ROOT / path
    if not file.exists():
        errors.append(f"missing required UI file: {path}")
        return ""
    return file.read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


theme = read("entry/src/main/ets/common/theme/AppTheme.ets")
app_shell = read("entry/src/main/ets/pages/AppShell.ets")

required_theme_tokens = [
    "SURFACE_SUBTLE",
    "SURFACE_EMPHASIS",
    "DIVIDER",
    "PAGE_PADDING",
    "PAGE_PADDING_WIDE",
    "SECTION_GAP",
    "CARD_RADIUS",
    "CONTROL_RADIUS",
    "BUTTON_HEIGHT",
    "PAGE_TITLE_SIZE",
    "SECTION_TITLE_SIZE",
]
for token in required_theme_tokens:
    require(f"static readonly {token}" in theme, f"AppTheme missing design token: {token}")

require("SymbolGlyph" in app_shell, "navigation must use HarmonyOS SymbolGlyph instead of text dots")
for symbol in [
    "sys.symbol.house",
    "sys.symbol.plus_square",
    "sys.symbol.checkmark_circle",
    "sys.symbol.checkmark_square",
    "sys.symbol.gearshape",
]:
    require(symbol in app_shell, f"AppShell missing verified system navigation symbol: {symbol}")

require("BottomNavShell" in app_shell and "SideNavShell" in app_shell,
        "AppShell must keep separate bottom/side navigation shells")
require("if (this.sizeClass === WindowSizeClass.EXPANDED)" in app_shell,
        "side navigation must remain limited to EXPANDED windows")
require("Text(active ? '●' : '○')" not in app_shell,
        "navigation must not regress to text-dot icons")

visible_ui_files = [
    "entry/src/main/ets/pages/PersonEntryPage.ets",
    "entry/src/main/ets/pages/AppShell.ets",
    "entry/src/main/ets/components/assignment/AssignmentCard.ets",
    "entry/src/main/ets/components/state/PageStateView.ets",
    "entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets",
    "entry/src/main/ets/features/parent/import/HomeworkImportPage.ets",
    "entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets",
    "entry/src/main/ets/features/parent/progress/ParentProgressPage.ets",
    "entry/src/main/ets/features/student/today/StudentTodayPage.ets",
    "entry/src/main/ets/features/student/study/StudyWorkspacePage.ets",
]

old_visual_literals = [
    "#F7F8FA",
    "#F4F6F9",
    "#F1F3F5",
    "#EEF9F3",
    "#FFF8E7",
    "#C9D1DD",
    "#6D8DFF",
]

for path in visible_ui_files:
    text = read(path)
    require("AppTheme" in text, f"visible UI must use shared AppTheme: {path}")
    for literal in old_visual_literals:
        require(literal not in text, f"legacy hardcoded visual color {literal} remains in {path}")

page_files = [
    "entry/src/main/ets/pages/PersonEntryPage.ets",
    "entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets",
    "entry/src/main/ets/features/parent/import/HomeworkImportPage.ets",
    "entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets",
    "entry/src/main/ets/features/parent/progress/ParentProgressPage.ets",
    "entry/src/main/ets/features/student/today/StudentTodayPage.ets",
    "entry/src/main/ets/features/student/study/StudyWorkspacePage.ets",
]
for path in page_files:
    text = read(path)
    require("AppTheme.PAGE_PADDING" in text,
            f"page must use shared page-edge spacing instead of a local magic number: {path}")

for path in [
    "entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets",
    "entry/src/main/ets/features/parent/import/HomeworkImportPage.ets",
    "entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets",
    "entry/src/main/ets/features/student/today/StudentTodayPage.ets",
    "entry/src/main/ets/features/student/study/StudyWorkspacePage.ets",
]:
    text = read(path)
    require("ButtonType.Normal" in text,
            f"primary interaction page must use rounded-rectangle ButtonType.Normal controls: {path}")
    require("AppTheme.CONTROL_RADIUS" in text,
            f"primary interaction page must use shared control radius: {path}")

require("sys.symbol.exclamationmark_triangle" not in read("entry/src/main/ets/features/student/today/StudentTodayPage.ets"),
        "unverified warning symbol must not be used")
require("sys.symbol.bubble_left" not in read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets"),
        "unverified tutor symbol must not be used")

if errors:
    print("HARMONY_UI_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("HARMONY_UI_GATE_PASS")
