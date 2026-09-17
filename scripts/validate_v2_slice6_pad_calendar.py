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


page = read("entry/src/main/ets/features/student/assignments/StudentAssignmentsPage.ets")
workflow = read(".github/workflows/static-gate.yml")

require("PadExtraAssignmentsPane" in page and "padExtraAssignments" in page,
        "Pad calendar mode must provide an extracurricular task pane")
require("AssignmentTypeFilter.EXTRA" in page,
        "Pad extracurricular pane must reuse the existing Assignment EXTRA filter")
require("if (this.calendarMode)" in page and "this.PadExtraAssignmentsPane();" in page,
        "wide Assignment composition must swap the detail pane for extracurricular tasks in calendar mode")
require("this.AssignmentDetailSidePane();" in page,
        "list mode must preserve the existing Pad master/detail composition")
require("LayoutPolicy.canSplit" in page and "assignmentMasterDetailRequirement" in page,
        "Pad enhancement must remain capability-based")
require("this.onOpenDetail(item.id)" in page,
        "Pad extracurricular list must retain a path to the standard Assignment detail route")
require("ExtraHomework" not in page,
        "Pad enhancement must not introduce a parallel extracurricular domain")
require("Validate V2 Slice 6 Pad calendar composition" in workflow and
        "validate_v2_slice6_pad_calendar.py" in workflow,
        "CI must run the Slice 6 Pad composition gate")

if errors:
    print("V2_SLICE6_PAD_CALENDAR_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_SLICE6_PAD_CALENDAR_GATE_PASS")
