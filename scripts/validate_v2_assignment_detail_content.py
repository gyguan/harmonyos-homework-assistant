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

for token in ["老师要求", "完成要求", "教材 / 页码", "老师资料", "提交方式"]:
    require(token in detail, f"Assignment Detail missing V2 section: {token}")

require("this.assignment()!.instruction" in detail,
        "teacher requirement must render the authoritative Assignment instruction")
require("this.assignment()!.textbookRef" in detail,
        "textbook/page section must render Assignment.textbookRef")
require("ForEach(this.assignment()!.resourceLabels" in detail,
        "teacher resources must render existing Assignment.resourceLabels individually")
require("暂无老师资料" in detail,
        "Assignment Detail must expose an explicit empty resource state")
require("作业照片 1–6 张" in detail,
        "Assignment Detail must expose the current P0 submission method")
require("按老师要求完成本项作业" in detail and "完成后检查遗漏和订正" in detail,
        "Assignment Detail must expose a concise completion checklist")
require("HomeworkStore.instance" not in detail,
        "V2 Assignment Detail must stay behind AssignmentRepository cache instead of direct Store access")
require("AssignmentDetailPane" in page and "DeepPageHeader" in page,
        "standalone Assignment Detail must reuse the shared pane and deep-page chrome")
require("resourceLabels: string[]" in models,
        "Assignment domain must retain resource metadata used by Detail/Study")

# Resource labels currently have no URI in the V2 domain. Do not create fake clickable resources
# until the resource model is upgraded in a later vertical slice.
require("onClick" not in detail.split("this.SectionTitle('老师资料');", 1)[-1].split("if (this.assignment()!.reviewNote", 1)[0],
        "label-only teacher resources must not pretend to be clickable without a real URI")

if errors:
    print("V2_ASSIGNMENT_DETAIL_CONTENT_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_ASSIGNMENT_DETAIL_CONTENT_GATE_PASS")
