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


decision = read("entry/src/main/ets/domain/model/AssignmentReviewDecision.ets")
repo_port = read("entry/src/main/ets/domain/port/AssignmentRepository.ets")
repo_impl = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
remote_api = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
view_model = read("entry/src/main/ets/features/parent/review/ParentReviewViewModel.ets")
controller = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentController.java")
dtos = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentDtos.java")
review_service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentReviewService.java")
e2e = read("backend/scripts/parent_review_e2e.py")

for token in ["APPROVE = 'APPROVE'", "RETURN_REWORK = 'RETURN_REWORK'"]:
    require(token in decision, f"AssignmentReviewDecision missing {token}")

require("review(assignmentId: string, decision: AssignmentReviewDecision, note: string): Promise<Assignment>" in repo_port,
        "AssignmentRepository must expose parent review command")
require("HomeworkRemoteApi.instance.review" in repo_impl,
        "real parent review must execute through the remote command API")
require("current.backing === AssignmentBacking.LOCAL_SEED" in repo_impl and
        "ensureRemoteCurrent" in repo_impl,
        "local review fallback must use explicit Assignment backing and shared remote hydration")
require("联网后才能验收作业" in repo_impl,
        "published assignments must not mutate review state locally while offline")
require("/review`" in remote_api and "decision: decision, version: version, note: note" in remote_api,
        "HomeworkRemoteApi must POST decision + optimistic version + note to /review")

require("class ParentReviewViewModel" in view_model and "this.repository.review" in view_model,
        "Parent Review must delegate decisions to AssignmentRepository")
require("HomeworkStore.instance" not in view_model,
        "new V2 Parent Review ViewModel must not access HomeworkStore directly")
require("退回订正时请填写原因" in view_model,
        "Parent Review ViewModel must reject empty rework reasons before command execution")

require('@PostMapping("/assignments/{id}/review")' in controller and
        "AssignmentDtos.ReviewRequest" in controller and "reviewService.review" in controller,
        "backend must expose parent review command endpoint")
require("record ReviewRequest(@NotBlank String decision, @NotNull Long version" in dtos,
        "parent review command must carry decision and optimistic version")
require('if (!"SUBMITTED".equals(assignment.status))' in review_service,
        "server review must only accept SUBMITTED assignments")
require("assignment.version != input.version()" in review_service,
        "server review must reject stale optimistic versions")
require('case "APPROVE"' in review_service and 'assignment.status = "COMPLETED"' in review_service,
        "APPROVE must transition to COMPLETED on the server")
require('case "RETURN_REWORK"' in review_service and 'assignment.status = "NEEDS_REWORK"' in review_service,
        "RETURN_REWORK must transition to NEEDS_REWORK on the server")
require("退回订正时必须填写原因" in review_service,
        "server must require a reason when returning work for rework")

for token in ["stale parent review version conflict", "APPROVE did not move assignment to COMPLETED",
              "RETURN_REWORK did not move assignment to NEEDS_REWORK", "reject review outside SUBMITTED"]:
    require(token in e2e, f"real parent review E2E missing coverage: {token}")

if errors:
    print("V2_SLICE4_PARENT_REVIEW_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_SLICE4_PARENT_REVIEW_GATE_PASS")
