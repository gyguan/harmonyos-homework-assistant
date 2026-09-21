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


capture_home = read("entry/src/main/ets/features/parent/import/HomeworkCaptureHomePage.ets")
capture = read("entry/src/main/ets/features/parent/import/HomeworkCapturePage.ets")
profile = read("entry/src/main/ets/features/parent/import/HomeworkSourceProfilePage.ets")
inbox = read("entry/src/main/ets/features/parent/import/HomeworkImportInboxPage.ets")
batch = read("entry/src/main/ets/features/parent/import/HomeworkImportBatchDetailPage.ets")
import_route = read("entry/src/main/ets/features/parent/import/HomeworkImportRoutePage.ets")
import_page = read("entry/src/main/ets/features/parent/import/HomeworkImportPage.ets")
diagnostic = read("entry/src/main/ets/features/parent/import/HomeworkCaptureDiagnosticPage.ets")

# Deep pages must not depend on default vertical alignment.
for name, source in [
    ("capture home", capture_home),
    ("capture", capture),
    ("source profile", profile),
    ("import inbox", inbox),
    ("batch detail", batch),
    ("capture diagnostic", diagnostic),
]:
    require(".align(Alignment.TopStart)" in source,
            f"{name} page-level Scroll must be explicitly top anchored")
    require(".scrollBar(BarState.Off)" in source,
            f"{name} page-level Scroll must hide the system scrollbar")

# Accessibility return semantics must match the new independent capture information architecture.
require("backAccessibilityText: '返回抓取老师作业'" in capture,
        "formal capture page must return semantically to the capture home")
require("backAccessibilityText: '返回上一页'" in profile,
        "SourceProfile is reachable from multiple capture surfaces and must use neutral back semantics")
require("backAccessibilityText: '返回上一页'" in inbox,
        "Import Inbox is shared by manual import and capture and must use neutral back semantics")
require("返回导入老师作业" not in capture and "返回导入老师作业" not in inbox,
        "legacy coupled import return copy must not reappear")

# Phone/Pad readable-width rules.
require("AppTheme.PROFILE_READABLE_MAX_WIDTH" in profile,
        "SourceProfile must use its dedicated Pad readable-width token")
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

# Formal capture UI is a business surface; engineering counters stay in the diagnostic page.
for engineering_copy in ["视频回调", "OCR失败", "最近序号"]:
    require(engineering_copy not in capture,
            f"formal capture page must not expose engineering diagnostic counter: {engineering_copy}")
require("已采集 " in capture and "个有效画面" in capture,
        "formal capture page should expose a user-facing capture progress summary")

# SourceProfile does not edit the student; do not tell users it does.
require("请先设置班级、学生和微信群信息" not in capture_home and
        "请先设置班级、微信群和老师信息" in capture_home,
        "capture home setup copy must match actual SourceProfile capabilities")

# Capture diagnostics are a formal support surface, not the old feasibility spike.
require("title: '屏幕采集诊断'" in diagnostic and "高级诊断信息" in diagnostic,
        "capture diagnostic must use the formal, user-facing information hierarchy")
for legacy in ["#241", "真机 Gate", "测试 Fixture", "开始真机采集实验", "读取最近一帧并执行 OCR"]:
    require(legacy not in diagnostic,
            f"capture diagnostic must not expose legacy spike content: {legacy}")

if errors:
    print("PARENT_IMPORT_UI_CONFORMANCE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("PARENT_IMPORT_UI_CONFORMANCE_PASS")
