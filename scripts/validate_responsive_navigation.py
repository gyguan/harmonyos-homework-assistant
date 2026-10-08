#!/usr/bin/env python3
from pathlib import Path
import re
import sys

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


app_shell = read("entry/src/main/ets/pages/AppShell.ets")
responsive = read("entry/src/main/ets/common/responsive/WindowSizeClass.ets")

# Shell navigation may use a shared window size class, but feature composition must not be
# coupled to device names or page-local magic breakpoints.
require("private BottomNavShell()" in app_shell,
        "AppShell must expose a bottom-navigation shell")
require("private SideNavShell()" in app_shell,
        "AppShell must expose a side-navigation shell")
require("this.SideNavShell();" in app_shell and "this.BottomNavShell();" in app_shell,
        "AppShell must retain both navigation forms during migration")
require("private CompactShell()" not in app_shell and "private WideShell()" not in app_shell,
        "navigation shell naming must describe navigation form, not device class")

# Identity context is hidden only while rendering the parent's TOEIC main tab.
# Other parent tabs, all student tabs and blocking states must retain the normal header.
guard = app_shell.split("private hideIdentityBarForToeic(): boolean {", 1)
require(len(guard) == 2, "AppShell must define the TOEIC-only identity row predicate")
if len(guard) == 2:
    guard_body = guard[1].split("\n  }", 1)[0]
    for condition in ["this.role === AppRole.PARENT",
                      "this.parentRoute === ParentRoute.TOEIC",
                      "!this.isBlockingPageState()"]:
        require(condition in guard_body,
                f"TOEIC identity suppression must stay narrowly scoped: {condition}")

bottom_shell = app_shell.split("private BottomNavShell()", 1)
require(len(bottom_shell) == 2, "AppShell compact navigation builder must exist")
if len(bottom_shell) == 2:
    bottom_content = bottom_shell[1].split("private SideNavShell()", 1)[0]
    require("if (!this.hideIdentityBarForToeic()) {\n        IdentityContextBar({" in bottom_content,
            "only compact TOEIC must skip the identity row, without changing the shared bar")
    require("this.PersonaContent();" in bottom_content and
            "this.BottomNavigation();" in bottom_content,
            "TOEIC compact layout must preserve full content height and bottom navigation")
require(app_shell.count("if (!this.hideIdentityBarForToeic())") == 1 and
        "this.SideNavigation();" in app_shell,
        "TOEIC identity suppression must not affect PAD side navigation or other shells")

for token in ["deviceType", "isPhone", "isTablet", "isPadDevice"]:
    require(token not in app_shell and token not in responsive,
            f"responsive infrastructure must not branch on device identity: {token}")

feature_root = ROOT / "entry/src/main/ets/features"
magic_breakpoint = re.compile(r"(?:<=|>=|<|>)\s*(?:600|840|1080)\b")
for file in feature_root.rglob("*.ets"):
    text = file.read_text(encoding="utf-8")
    relative = file.relative_to(ROOT).as_posix()
    require(magic_breakpoint.search(text) is None,
            f"feature must not define a private device-style breakpoint: {relative}")
    require("getDefaultDisplaySync" not in text,
            f"feature must not inspect the physical display directly: {relative}")

if errors:
    print("RESPONSIVE_NAVIGATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("RESPONSIVE_NAVIGATION_GATE_PASS")
