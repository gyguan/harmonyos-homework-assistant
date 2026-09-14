#!/usr/bin/env python3
from pathlib import Path
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

require("widthVp <= 600" in responsive and "widthVp <= 840" in responsive,
        "responsive breakpoints must remain 600vp and 840vp")
require("private BottomNavShell()" in app_shell,
        "AppShell must name the bottom navigation shell by navigation form, not device type")
require("private SideNavShell()" in app_shell,
        "AppShell must name the side navigation shell by navigation form, not device type")
require("this.sizeClass === WindowSizeClass.EXPANDED" in app_shell,
        "side navigation must activate only for EXPANDED windows")
require("this.SideNavShell();" in app_shell and "this.BottomNavShell();" in app_shell,
        "AppShell must expose both side and bottom navigation shells")
require("this.sizeClass === WindowSizeClass.COMPACT" not in app_shell,
        "AppShell must not use COMPACT as the navigation switch because MEDIUM also uses bottom navigation")
require("private CompactShell()" not in app_shell and "private WideShell()" not in app_shell,
        "navigation shell naming must not imply phone/tablet device classes")
require("this.BottomNavigation();" in app_shell,
        "bottom-nav shell must retain bottom navigation")
require("this.SideNavigation();" in app_shell,
        "side-nav shell must retain side navigation")

if errors:
    print("RESPONSIVE_NAVIGATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("RESPONSIVE_NAVIGATION_GATE_PASS")
