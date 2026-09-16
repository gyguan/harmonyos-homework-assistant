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
