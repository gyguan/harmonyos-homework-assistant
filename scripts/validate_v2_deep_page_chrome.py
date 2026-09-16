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
require("Text('‹')" in header, "the shared header must own the single back glyph implementation")
require("MIN_TOUCH_TARGET" in header and "accessibilityText" in header,
        "shared header back control must keep touch target and accessibility semantics")

for path, text in [
    ("StudentAssignmentDetailPage.ets", detail),
    ("StudyWorkspacePage.ets", study),
]:
    require("DeepPageHeader" in text, f"migrated deep page must reuse DeepPageHeader: {path}")
    require("AppTheme.DEEP_PAGE_TOP_PADDING" in text,
            f"migrated deep page must use the shared top spacing token: {path}")
    require("AppTheme.DEEP_PAGE_BOTTOM_PADDING" in text,
            f"migrated deep page must use the shared bottom spacing token: {path}")
    require("Text('‹')" not in text,
            f"migrated deep page must not implement a private back glyph: {path}")

require("private WorkspaceHeader()" not in study,
        "StudyWorkspace must not reintroduce its legacy private WorkspaceHeader")
require("top: 0" in study,
        "StudyWorkspace content should not add a second top padding below shared chrome")
require("docs/product/v2-deep-page-chrome-standard.md" in agents and "DeepPageHeader" in agents,
        "Agent guide must require the shared deep-page chrome standard for future V2 refactors")
require("深层页面必须复用 `DeepPageHeader`" in spec,
        "deep-page chrome spec must explicitly require DeepPageHeader reuse")

if errors:
    print("V2_DEEP_PAGE_CHROME_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("V2_DEEP_PAGE_CHROME_GATE_PASS")
