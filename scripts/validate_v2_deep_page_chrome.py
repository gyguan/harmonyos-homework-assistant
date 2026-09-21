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


theme = read("entry/src/main/ets/common/theme/AppTheme.ets")
header = read("entry/src/main/ets/components/navigation/DeepPageHeader.ets")
detail = read("entry/src/main/ets/features/student/assignments/StudentAssignmentDetailPage.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
parent_import_route = read("entry/src/main/ets/features/parent/import/HomeworkImportRoutePage.ets")
practice_attempt = read("entry/src/main/ets/features/student/practice/PracticeAttemptPage.ets")
spec = read("docs/product/v2-deep-page-chrome-standard.md")
agents = read("AGENTS.md")

for token in [
    "DEEP_PAGE_TOP_PADDING",
    "DEEP_PAGE_BOTTOM_PADDING",
    "DEEP_PAGE_HEADER_HEIGHT",
    "DEEP_PAGE_HEADER_GAP",
    "DEEP_PAGE_HEADER_TITLE_SIZE",
    "DEEP_PAGE_HEADER_META_SIZE",
    "DEEP_PAGE_BACK_GLYPH_SIZE",
    "DEEP_PAGE_CONTENT_GAP",
]:
    require(token in theme, f"AppTheme missing shared deep-page token: {token}")

require("export struct DeepPageHeader" in header, "shared DeepPageHeader component is required")
require("SymbolGlyph($r('sys.symbol.chevron_left'))" in header,
        "shared header must use the HarmonyOS chevron-left Symbol")
require("Text('‹')" not in header,
        "shared header must not fall back to a text-character back glyph")
require("MIN_TOUCH_TARGET" in header and "accessibilityText" in header,
        "shared header back control must keep touch target and accessibility semantics")
require("backgroundColor(AppTheme.SURFACE_EMPHASIS)" in header and "borderRadius" in header,
        "shared header back control must keep the system-style subtle circular surface")

for path, text in [
    ("StudentAssignmentDetailPage.ets", detail),
    ("StudyWorkspacePage.ets", study),
    ("HomeworkImportRoutePage.ets", parent_import_route),
    ("PracticeAttemptPage.ets", practice_attempt),
]:
    require("DeepPageHeader" in text, f"migrated deep page must reuse DeepPageHeader: {path}")
    require("AppTheme.DEEP_PAGE_TOP_PADDING" in text,
            f"migrated deep page must use the shared top spacing token: {path}")
    require("Text('‹')" not in text,
            f"migrated deep page must not implement a private back glyph: {path}")

require("backAccessibilityText: '返回家长首页'" in parent_import_route and "embeddedInDeepPage: true" in parent_import_route,
        "parent import deep page must expose shared back chrome without duplicating the import page heading")
require("private WorkspaceHeader()" not in study,
        "StudyWorkspace must not reintroduce its legacy private WorkspaceHeader")
require("top: 0" in study,
        "StudyWorkspace content should not add a second top padding below shared chrome")

study_content = ""
if "private StudyContent" in study and "private TutorPane" in study:
    study_content = study.split("private StudyContent", 1)[1].split("private TutorPane", 1)[0]
require(".align(Alignment.TopStart)" in study_content,
        "StudyWorkspace page-level Scroll must be explicitly top anchored")
require(".scrollBar(BarState.Off)" in study_content,
        "StudyWorkspace page-level Scroll must keep scrolling but hide the system scrollbar")
require(".justifyContent(FlexAlign.Start)" in study_content and ".alignItems(HorizontalAlign.Start)" in study_content,
        "StudyWorkspace content column must be explicitly anchored to the top/start")

require("docs/product/v2-deep-page-chrome-standard.md" in agents and "DeepPageHeader" in agents,
        "Agent guide must require the shared deep-page chrome standard for future V2 refactors")
require("深层页面必须复用 `DeepPageHeader`" in spec,
        "deep-page chrome spec must explicitly require DeepPageHeader reuse")
require("sys.symbol.chevron_left" in spec and "圆形浅色" in spec,
        "deep-page chrome spec must lock the system-style back control")
require("页面级纵向 `Scroll`" in spec and "scrollBar(BarState.Off)" in spec,
        "deep-page chrome spec must require top-anchored scrolling with hidden system scrollbars")

if errors:
    print("V2_DEEP_PAGE_CHROME_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("V2_DEEP_PAGE_CHROME_GATE_PASS")
