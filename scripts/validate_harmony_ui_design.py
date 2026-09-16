#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def read_optional(path: str) -> str:
    file = ROOT / path
    return file.read_text(encoding="utf-8") if file.exists() else ""


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


theme_path = "entry/src/main/ets/common/theme/AppTheme.ets"
theme = read_optional(theme_path)
require(len(theme) > 0, f"missing required file: {theme_path}")

# Keep only durable design-system contracts here. Page-specific composition belongs to the
# V2 UI spec and DevEco acceptance, not to string assertions against V1 builders.
for token in [
    "SURFACE_SUBTLE",
    "SURFACE_EMPHASIS",
    "DIVIDER",
    "PAGE_PADDING",
    "SECTION_GAP",
    "CARD_RADIUS",
    "CONTROL_RADIUS",
    "MIN_TOUCH_TARGET",
    "BUTTON_HEIGHT",
    "PAGE_TITLE_SIZE",
    "SECTION_TITLE_SIZE",
]:
    require(f"static readonly {token}" in theme, f"AppTheme missing durable design token: {token}")

app_shell = read_optional("entry/src/main/ets/pages/AppShell.ets")
if app_shell:
    require("Text(active ? '●' : '○')" not in app_shell,
            "navigation must not regress to text-dot icons")

legacy_visual_literals = [
    "#F7F8FA",
    "#F4F6F9",
    "#F1F3F5",
    "#EEF9F3",
    "#FFF8E7",
    "#C9D1DD",
    "#6D8DFF",
]

ui_roots = [
    ROOT / "entry/src/main/ets/pages",
    ROOT / "entry/src/main/ets/features",
    ROOT / "entry/src/main/ets/components",
]
for ui_root in ui_roots:
    if not ui_root.exists():
        continue
    for file in ui_root.rglob("*.ets"):
        text = file.read_text(encoding="utf-8")
        relative = file.relative_to(ROOT).as_posix()
        for literal in legacy_visual_literals:
            require(literal not in text, f"legacy hardcoded visual color {literal} remains in {relative}")

        # Production UI must not introduce Preview/CI/device-only branches to make a layout pass.
        prohibited_branch = re.compile(r"\b(?:isPreview|isCI|deviceModel|deviceType)\b")
        require(prohibited_branch.search(text) is None,
                f"UI must not contain Preview/CI/device-specific production branching: {relative}")

# Preserve accessibility semantics while this shared component exists; V2 may replace it with
# another accessible component without keeping this filename alive forever.
assignment_list_item = read_optional("entry/src/main/ets/components/assignment/AssignmentListItem.ets")
if assignment_list_item:
    require("accessibilityRole(AccessibilityRoleType.BUTTON)" in assignment_list_item,
            "AssignmentListItem must expose button accessibility semantics while it exists")

if errors:
    print("HARMONY_UI_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("HARMONY_UI_GATE_PASS")
