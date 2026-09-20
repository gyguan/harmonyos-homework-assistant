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


page = read("entry/src/main/ets/features/parent/confirmation/HomeworkConfirmationPage.ets")
components = read("entry/src/main/ets/features/parent/confirmation/ConfirmationCandidateComponents.ets")
parent_editor = read("entry/src/main/ets/features/parent/review/ParentAssignmentEditPanel.ets")
parent_review = read("entry/src/main/ets/features/parent/review/ParentReviewPane.ets")
deadline = read("entry/src/main/ets/components/assignment/DeadlinePickerField.ets")

# AI result cards: duration presets remain on one horizontal line and card height stays compact.
require("CandidateDurationControl" in components and "Scroll() {" in components and
        ".scrollable(ScrollDirection.Horizontal)" in components,
        "candidate duration presets must stay on one horizontal scroll row")
require("label: '10'" in components and "label: '15'" in components and
        "label: '20'" in components and "label: '30'" in components and "label: '45'" in components,
        "candidate cards must retain the common quick-duration presets")
card = components.split("export struct ConfirmationCandidateCard", 1)[1].split(
    "export struct ConfirmationCandidateEditor", 1)[0]
require("TextInput" not in card and "maxLines(1)" in card,
        "candidate card must not contain the tall custom minute input and should keep metadata compact")

# Primary actions: content scrolls independently while business actions stay fixed below it.
require("private BottomActionBar()" in page and "this.BottomActionBar();" in page and
        ".layoutWeight(1)" in page,
        "confirmation publish/batch actions must stay in a fixed bottom action bar")
require("private BottomActions()" in components and "this.BottomActions();" in components and
        components.index("Scroll() {") < components.index("this.BottomActions();"),
        "candidate editor must keep Complete/Delete outside the scroll area")
require("private BottomActions()" in parent_editor and "this.BottomActions();" in parent_editor and
        parent_editor.index("Scroll() {") < parent_editor.index("this.BottomActions();"),
        "published-task editor must keep Save outside the scroll area")
require("ParentAssignmentEditPanel({" in parent_review and
        "Scroll() {" not in parent_review.split("private AssignmentEditorSheet()", 1)[1].split(
            "@Builder", 1)[0],
        "parent review sheet must not wrap the fixed-action editor in a second scroll")

# Header exits: right-top exit is consistently Close; dirty edits warn before discard.
require("Text('关闭')" in components and "Text('关闭')" in parent_editor and "Text('关闭')" in deadline,
        "editor/picker headers must use the single Close exit label")
require("confirmDiscard" in components and "放弃修改" in components and "继续编辑" in components,
        "candidate editor must warn before closing dirty edits")
require("confirmDiscard" in parent_editor and "放弃修改" in parent_editor and "继续编辑" in parent_editor,
        "published-task editor must warn before closing dirty edits")
require("Button('完成'" in components and components.index("Button('完成'") > components.index("AssignmentEditForm({"),
        "Complete must be a bottom business action that saves and exits")

# Manual add belongs with list management, not after all cards.
require("private CandidateListHeader()" in page and "Text('＋ 新增')" in page and
        "Button('＋ 手工新增一项'" not in page,
        "manual add must live in the candidate list header")

# AI organized tasks support batch selection, select-all, confirmation, and deletion.
for token in [
    "@State private bulkMode",
    "@State private selectedCandidateIds",
    "@State private batchDeleteConfirm",
    "private toggleCandidateSelection",
    "private selectAllCandidates",
    "private removeSelectedCandidates",
    "Text('管理')",
    "Text('全选')",
    "确认删除",
]:
    require(token in page, f"candidate batch delete missing behavior: {token}")
require("for (let id of ids)" in page and "this.viewModel.removeCandidate(id)" in page,
        "batch delete must remove every selected candidate through the draft ViewModel")

if errors:
    print("CONFIRMATION_INTERACTION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("CONFIRMATION_INTERACTION_GATE_PASS")
