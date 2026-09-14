#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
ETS_ROOT = ROOT / "entry" / "src" / "main" / "ets"
errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def read(path: str) -> str:
    file = ROOT / path
    require(file.exists(), f"missing required file: {path}")
    return file.read_text(encoding="utf-8") if file.exists() else ""


build_profile = read("build-profile.json5")
hvigor_config = read("hvigor/hvigor-config.json5")
module_config = read("entry/src/main/module.json5")
app_shell = read("entry/src/main/ets/pages/AppShell.ets")
responsive = read("entry/src/main/ets/common/responsive/WindowSizeClass.ets")

require('"compileSdkVersion": "26.0.0"' in build_profile,
        "compileSdkVersion must match the DevEco Studio 26.0.0 toolchain")
require('"compatibleSdkVersion": "6.0.0(20)"' in build_profile,
        "compatibleSdkVersion must keep the V0.1 runtime baseline at HarmonyOS 6.0.0(20)")
require('"targetSdkVersion": "6.0.0(20)"' in build_profile,
        "targetSdkVersion must stay at HarmonyOS 6.0.0(20) until target-26 behavior adaptation is complete")

require('"modelVersion": "6.0.2"' in hvigor_config, "Hvigor modelVersion must be 6.0.2")
require('"hvigorVersion": "6.0.2"' in hvigor_config, "Hvigor version must be pinned to 6.0.2")
require('"@ohos/hvigor-ohos-plugin": "6.0.2"' in hvigor_config,
        "Hvigor OHOS plugin must be pinned to 6.0.2")

require('"phone"' in module_config and '"tablet"' in module_config,
        "entry module must declare both phone and tablet device types")
require("Navigation(this.navPathStack)" in app_shell,
        "AppShell must keep Navigation bound to NavPathStack")
require("ResponsiveContext.resolve(this.widthVp)" in app_shell,
        "AppShell must derive size class from the shared responsive resolver")

require("widthVp <= 600" in responsive and "widthVp <= 840" in responsive,
        "shared responsive breakpoints must remain 600vp / 840vp")

if ETS_ROOT.exists():
    for file in ETS_ROOT.rglob("*.ets"):
        text = file.read_text(encoding="utf-8")
        rel = file.relative_to(ROOT).as_posix()
        if "ContainerReader" in text:
            errors.append(f"API 26+ ContainerReader is not allowed in V0.1 runtime-compatible code: {rel}")
        if file.name != "WindowSizeClass.ets":
            if re.search(r"(?:<=|>=|<|>)\s*(?:600|840)\b", text):
                errors.append(f"responsive breakpoint duplicated outside WindowSizeClass: {rel}")

required_scenarios = ["LOADING", "EMPTY", "ERROR", "OFFLINE", "TUTOR_UNAVAILABLE"]
demo_scenario = read("entry/src/main/ets/common/state/DemoScenario.ets")
for scenario in required_scenarios:
    require(scenario in demo_scenario, f"missing reproducible demo scenario: {scenario}")

if errors:
    print("STATIC_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("STATIC_GATE_PASS")
