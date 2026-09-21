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


dashboard = read("entry/src/main/ets/features/parent/dashboard/ParentDashboardPage.ets")
import_home = read("entry/src/main/ets/features/parent/import/HomeworkImportRoutePage.ets")
capture_home = read("entry/src/main/ets/features/parent/import/HomeworkCaptureHomePage.ets")
capture_home_vm = read("entry/src/main/ets/features/parent/import/HomeworkCaptureHomeViewModel.ets")
routes = read("entry/src/main/ets/app/navigation/AppRoutes.ets")
navigator = read("entry/src/main/ets/app/navigation/ParentImportNavigator.ets")
shell = read("entry/src/main/ets/pages/AppShell.ets")

require("手工导入作业" in dashboard and "抓取老师作业" in dashboard,
        "parent dashboard must expose manual import and capture as independent entries")
require("onOpenImport" in dashboard and "onOpenCapture" in dashboard,
        "dashboard entries must have independent callbacks")

require("title: '手工导入作业'" in import_home and "HomeworkImportPage" in import_home,
        "manual import page must remain dedicated to manual input")
for forbidden in ["抓取今日作业", "班级采集设置", "屏幕采集诊断",
                  "onOpenCapture:", "onOpenSourceProfile:", "onOpenDiagnostics:"]:
    require(forbidden not in import_home,
            f"manual import page still contains capture-specific UI/callback: {forbidden}")

for text in ["抓取老师作业", "当前来源", "开始抓取", "抓取记录",
             "班级采集设置", "使用说明", "屏幕采集技术诊断", "不读取微信数据库",
             "不自动点击或滚动微信", "Accessibility"]:
    require(text in capture_home, f"capture home missing required UX/privacy content: {text}")
require("AppTheme.CAPTURE_HOME_READABLE_MAX_WIDTH" in capture_home,
        "capture home must keep a dedicated readable width on Pad")
require("Service.instance" not in capture_home and "Repository.instance" not in capture_home,
        "capture home page must access domain state through its ViewModel")
require("HomeworkSourceProfileService" in capture_home_vm and "FamilyContextRepository" in capture_home_vm,
        "capture home ViewModel must own SourceProfile/family access")
require("!this.hasSourceProfile()" in capture_home and "onOpenSourceProfile(true)" in capture_home,
        "first capture without a SourceProfile must route through setup")
require("onOpenSourceProfile(false)" in capture_home,
        "capture settings edit must not auto-start another capture")

require("PARENT_CAPTURE_HOME" in routes and "ParentCaptureHomeRouteParam" in routes,
        "capture home must have a dedicated route")
require("openCaptureHome" in navigator and "AppRoute.PARENT_CAPTURE_HOME" in navigator,
        "capture home route must be owned by ParentImportNavigator")
require("HomeworkCaptureHomePage" in shell and "name === AppRoute.PARENT_CAPTURE_HOME" in shell,
        "AppShell must compose the dedicated capture home destination")
require("onOpenCapture: () => ParentImportNavigator.openCaptureHome" in shell,
        "parent dashboard capture entry must open the dedicated capture home")
require("onStartCapture: () => ParentImportNavigator.openCapture" in shell,
        "capture home must reuse the existing capture session route")

if errors:
    print("ISSUE_270_CAPTURE_ENTRY_SPLIT_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("ISSUE_270_CAPTURE_ENTRY_SPLIT_PASS")
