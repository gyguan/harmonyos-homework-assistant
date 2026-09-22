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


detail = read("entry/src/main/ets/features/student/assignments/AssignmentDetailPane.ets")
page = read("entry/src/main/ets/features/student/assignments/StudentAssignmentDetailPage.ets")
models = read("entry/src/main/ets/domain/model/HomeworkModels.ets")

for token in ["老师要求", "教材 / 页码", "老师资料", "需要先订正"]:
    require(token in detail, f"Assignment Detail missing focused V2 content: {token}")

require("Text(item.instruction.length > 0 ? item.instruction" in detail,
        "teacher requirement must render the authoritative Assignment instruction")
require("if (item.textbookRef.length > 0)" in detail and "Text(item.textbookRef)" in detail,
        "textbook/page section must render only when Assignment.textbookRef exists")
require("if (item.resourceLabels.length > 0)" in detail and
        "ForEach(item.resourceLabels" in detail,
        "teacher resources must render existing Assignment.resourceLabels individually")
require("暂无老师资料" not in detail and "Text(item.textbookRef)" in detail,
        "Assignment Detail must not show empty optional-value cards to the student")
require("完成要求" not in detail and "提交方式" not in detail,
        "Assignment Detail must not repeat generic completion or submission instructions")
require(detail.find("需要先订正") < detail.find("老师要求"),
        "rework feedback must appear before the teacher instruction")
require("Scroll()" in detail and ".layoutWeight(1)" in detail and
        "Button(this.actionLabel(this.assignment()!)" in detail,
        "Assignment Detail must keep content scrollable with a fixed primary action")
require("HomeworkStore.instance" not in detail,
        "V2 Assignment Detail must stay behind AssignmentRepository cache instead of direct Store access")
require("AssignmentDetailPane" in page and "DeepPageHeader" in page,
        "standalone Assignment Detail must reuse the shared pane and deep-page chrome")
require("resourceLabels: string[]" in models,
        "Assignment domain must retain resource metadata used by Detail/Study")

# Resource labels have no URI in the current domain; they must remain non-clickable labels.
resource_section = detail.split("this.SectionTitle('老师资料');", 1)[-1].split(".backgroundColor(AppTheme.SURFACE_SUBTLE)", 1)[0]
require("onClick" not in resource_section,
        "label-only teacher resources must not pretend to be clickable without a real URI")

if errors:
    print("V2_ASSIGNMENT_DETAIL_CONTENT_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_ASSIGNMENT_DETAIL_CONTENT_GATE_PASS")
