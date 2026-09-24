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


inbox = read("entry/src/main/ets/features/parent/import/HomeworkImportInboxPage.ets")
batch = read("entry/src/main/ets/features/parent/import/HomeworkImportBatchDetailPage.ets")
import_route = read("entry/src/main/ets/features/parent/import/HomeworkImportRoutePage.ets")
import_page = read("entry/src/main/ets/features/parent/import/HomeworkImportPage.ets")

# Current deep pages must remain top anchored and hide the system scrollbar.
for name, source in [
    ("import inbox", inbox),
    ("batch detail", batch),
]:
    require(".align(Alignment.TopStart)" in source,
            f"{name} page-level Scroll must be explicitly top anchored")
    require(".scrollBar(BarState.Off)" in source,
            f"{name} page-level Scroll must hide the system scrollbar")

# Manual import and inbox are the supported parent import surfaces after screen-capture retirement.
require(".alignItems(HorizontalAlign.Center)" in import_route and
        "AppTheme.IMPORT_READABLE_MAX_WIDTH" in import_page,
        "manual import route must center the embedded readable content column on Pad")

require("FilterSummaryEntry" in inbox and "label: '来源'" in inbox and
        "label: '状态'" in inbox and "label: '时间'" in inbox,
        "Import Inbox must reuse the standard filter summary interaction")
require("AppTheme.IMPORT_READABLE_MAX_WIDTH" in inbox and
        "AppTheme.PHONE_CARD_RADIUS" in inbox and "AppTheme.BORDER" in inbox,
        "Import Inbox cards must stay aligned with current Phone/Pad visual tokens")

require(inbox.count(".alignItems(HorizontalAlign.Center)") >= 1 and
        ".constraintSize({ maxWidth: AppTheme.IMPORT_READABLE_MAX_WIDTH })" in inbox,
        "Import Inbox page shell must center the readable column on wide layouts")
require(batch.count(".alignItems(HorizontalAlign.Center)") >= 1 and
        ".constraintSize({ maxWidth: AppTheme.IMPORT_READABLE_MAX_WIDTH })" in batch,
        "Import batch detail page shell must center the readable column on wide layouts")
require("backAccessibilityText: '返回作业收件箱'" in batch,
        "Import batch detail return semantics must match the current inbox title")
require(batch.count("AppTheme.PHONE_CARD_RADIUS") >= 4 and
        batch.count(".border({ width: 1, color: AppTheme.BORDER })") >= 4,
        "Import batch detail cards must reuse current parent card radius and border tokens")

for retired in [
    "HomeworkCapturePage",
    "HomeworkCaptureHomePage",
    "HomeworkCaptureDiagnosticPage",
    "HomeworkSourceProfilePage",
]:
    require(retired not in import_route + inbox + batch,
            f"retired screen-capture surface must not return to current import navigation: {retired}")

if errors:
    print("PARENT_IMPORT_UI_CONFORMANCE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("PARENT_IMPORT_UI_CONFORMANCE_PASS")
