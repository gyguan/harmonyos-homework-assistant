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

require("private AssignmentMasterDetail()" in page and
        "this.AssignmentDetailSidePane();" in page,
        "wide Assignment layout must keep the list + detail composition")
require("LayoutPolicy.canSplit" in page and "assignmentMasterDetailRequirement" in page,
        "Pad Assignment composition must remain capability-based")
require("PadExtraAssignmentsPane" not in page and "calendarMode" not in page and
        "AssignmentTypeFilter.EXTRA" not in page,
        "Pad Assignment surface must not retain calendar-only side panes or branches")
require("showChevron: !this.canUseMasterDetail()" in page,
        "Pad list items must select into the detail pane while Phone keeps deep navigation")
require("ExtraHomework" not in page,
        "Pad list-only simplification must not introduce a parallel extracurricular domain")
require("Validate V2 Slice 6 Pad calendar composition" in workflow and
        "validate_v2_slice6_pad_calendar.py" in workflow,
        "CI must continue guarding the simplified Pad Assignment composition")

if errors:
    print("V2_SLICE6_PAD_LIST_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_SLICE6_PAD_LIST_GATE_PASS")
