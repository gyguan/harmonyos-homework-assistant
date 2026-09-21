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


page = read("entry/src/main/ets/features/parent/import/HomeworkCaptureHomePage.ets")
view_model = read("entry/src/main/ets/features/parent/import/HomeworkCaptureHomeViewModel.ets")
theme = read("entry/src/main/ets/common/theme/AppTheme.ets")

for text in [
    "从老师群聊中抓取今日作业",
    "当前来源",
    "班级",
    "学生",
    "微信群",
    "老师",
    "抓取时间范围",
    "开始抓取",
    "班级采集设置",
    "抓取记录",
    "使用说明",
]:
    require(text in page, f"capture home prototype content missing: {text}")

require(page.count("Button(") == 1,
        "capture home must keep exactly one primary Button")
require("if (this.hasSourceProfile())" in page and "尚未配置来源" in page,
        "capture home must have explicit configured/unconfigured source states")
require("studentName()" in page and "studentName(): string" in view_model,
        "source card must surface the active student")
require("showGuide" in page and "屏幕采集技术诊断" in page,
        "technical diagnostics must be nested under the usage guide")
require("onOpenDiagnostics()" in page,
        "technical diagnostics must remain reachable")
require("不读取微信数据库" in page and "不自动点击或滚动微信" in page and
        "Accessibility" in page,
        "capture privacy/non-automation boundary must remain explicit")
require("CAPTURE_HOME_READABLE_MAX_WIDTH" in page and
        "static readonly CAPTURE_HOME_READABLE_MAX_WIDTH" in theme,
        "capture home must use a dedicated readable-width ceiling on Pad")
require("WindowSizeClass" not in page and "deviceType" not in page,
        "capture home must not branch on device identity")

if errors:
    print("ISSUE_271_CAPTURE_HOME_LAYOUT_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("ISSUE_271_CAPTURE_HOME_LAYOUT_PASS")
