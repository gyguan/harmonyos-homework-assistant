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


action_model = read("entry/src/main/ets/domain/model/AssignmentAction.ets")
repository_port = read("entry/src/main/ets/domain/port/AssignmentRepository.ets")
repository_impl = read("entry/src/main/ets/data/repository/DefaultAssignmentRepository.ets")
remote_api = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
study_vm = read("entry/src/main/ets/features/student/study/StudyWorkspaceViewModel.ets")
study = read("entry/src/main/ets/features/student/study/StudyWorkspacePage.ets")
submission = read("entry/src/main/ets/application/submission/HomeworkSubmissionService.ets")
controller = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentController.java")
dtos = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentDtos.java")
service = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentService.java")
e2e = read("backend/scripts/assignment_action_e2e.py")

for token in ["START = 'START'", "PAUSE = 'PAUSE'", "READY_TO_SUBMIT = 'READY_TO_SUBMIT'"]:
    require(token in action_model, f"AssignmentAction missing {token}")

require("performAction(assignmentId: string, action: AssignmentAction): Promise<Assignment>" in repository_port,
        "AssignmentRepository must expose execution commands")
require("HomeworkRemoteApi.instance.performAction" in repository_impl,
        "real V2 assignment actions must execute through remote command API")
require("HomeworkRemoteApi.instance.get(assignmentId)" in repository_impl and
        "latest.version === current.remoteVersion" in repository_impl and
        "HomeworkRemoteApi.instance.performAction(assignmentId, latest.version, action)" in repository_impl,
        "assignment actions must recover a stale optimistic version with one single-assignment read and one retry")
require("current.remoteVersion <= 0 && current.candidateId.length === 0" in repository_impl,
        "local action fallback must be explicitly limited to seed/demo assignments")
require("当前离线，只能查看已缓存作业" in repository_impl,
        "published assignments must not mutate execution state locally while offline")
require("/actions`" in remote_api and "http.RequestMethod.POST" in remote_api and
        "action: action, version: version" in remote_api,
        "HomeworkRemoteApi must POST action + optimistic version to /actions")
require("async get(assignmentId: string): Promise<RemoteAssignment>" in remote_api and
        "'assignment.get'" in remote_api,
        "HomeworkRemoteApi must support a single-assignment recovery read")

require("class StudyWorkspaceViewModel" in study_vm and "this.repository.performAction" in study_vm,
        "Study Workspace must delegate execution to AssignmentRepository")
require("HomeworkStore.instance" not in study,
        "V2 StudyWorkspace must not mutate or read HomeworkStore directly")
require("this.viewModel.performAction" in study and "AssignmentAction.START" in study and
        "AssignmentAction.PAUSE" in study and "AssignmentAction.READY_TO_SUBMIT" in study,
        "Study Workspace must use explicit server-backed assignment actions")
require("HomeworkSubmissionService.instance.listCached" in study,
        "Study Workspace submission reads must stay behind the submission application service")
require("TutorRemoteApi.instance" in study and "HomeworkSubmissionService.instance.submit" in study,
        "Slice 3 execution migration must preserve Tutor and Submission flows")
require("listCached(assignmentId: string): Submission[]" in submission,
        "submission application service must expose cached submissions to migrated UI")

require('@PostMapping("/assignments/{id}/actions")' in controller and
        "AssignmentDtos.ActionRequest" in controller and "service.action" in controller,
        "backend must expose assignment action command endpoint")
require('@GetMapping("/assignments/{id}")' in controller and "service.get" in controller,
        "backend must expose a single-assignment recovery read")
require("record ActionRequest(@NotBlank String action, @NotNull Long version)" in dtos,
        "assignment action command must carry action and optimistic version")
require("public AssignmentDtos.Response action" in service and "System.currentTimeMillis()" in service,
        "server command handler must own command execution time")
for command in ['case "START"', 'case "PAUSE"', 'case "READY_TO_SUBMIT"']:
    require(command in service, f"backend command handler missing {command}")
require("e.version != input.version()" in service,
        "assignment commands must reject stale optimistic versions")
require("pauseOtherActive(familyId, e.studentId, e.id, nowMs)" in service,
        "START command must preserve single-active-assignment invariant")
require("e.elapsedSeconds += Math.max(0, (nowMs - e.startedAtEpochMs) / 1000)" in service,
        "PAUSE/READY commands must accumulate elapsed time on the server")

for token in ["START", "PAUSE", "READY_TO_SUBMIT", "stale action version conflict",
              "starting second assignment did not server-pause",
              "auto-paused assignment stale resume conflict",
              "load single assignment for conflict recovery"]:
    require(token in e2e, f"real action E2E missing coverage: {token}")

if errors:
    print("V2_SLICE3_EXECUTION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("V2_SLICE3_EXECUTION_GATE_PASS")
