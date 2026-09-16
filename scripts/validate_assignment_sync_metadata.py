#!/usr/bin/env python3
from pathlib import Path

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


models = read("entry/src/main/ets/domain/model/HomeworkModels.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
mapper = read("entry/src/main/ets/application/remote/RemoteModels.ets")
sync = read("entry/src/main/ets/application/remote/HomeworkSyncService.ets")
remote_api = read("entry/src/main/ets/application/remote/HomeworkRemoteApi.ets")
controller = read("backend/src/main/java/com/xiaoban/homework/assignment/AssignmentController.java")

for field in ("remoteVersion: number", "syncDirty: boolean", "lastSyncedAtEpochMs: number"):
    require(field in models, f"Assignment must persist client sync field: {field}")

require("remoteVersion: source.remoteVersion > 0 ? source.remoteVersion : 0" in store,
        "snapshot clone must preserve/default remoteVersion")
require("syncDirty: source.syncDirty === true" in store,
        "snapshot clone must preserve/default syncDirty")
require("lastSyncedAtEpochMs: source.lastSyncedAtEpochMs > 0 ? source.lastSyncedAtEpochMs : 0" in store,
        "snapshot clone must preserve/default lastSyncedAtEpochMs")
for token in ["remoteVersion: 0", "syncDirty: true", "lastSyncedAtEpochMs: 0"]:
    require(token in store, f"newly published assignments must initialize sync metadata: {token}")
require("this.assignments[index].syncDirty = true" in store,
        "local assignment transitions must mark the assignment dirty")

for field in ("assignmentType", "subjectCode", "dueAtEpochMs", "dueTimezone"):
    require(field in mapper and field in remote_api,
            f"Assignment V2 field must survive remote sync: {field}")
require("remoteVersion: remote.version" in mapper,
        "remote refresh must establish the persisted server version")
require("syncDirty: false" in mapper,
        "remote refresh must clear local dirty state")
require("lastSyncedAtEpochMs: Date.now()" in mapper,
        "remote refresh must record the last sync time")

require("observedVersions" not in sync,
        "HomeworkSyncService must not keep process-local observedVersions")
require("assignment.syncDirty && assignment.remoteVersion === existing.version" in sync,
        "server update must require dirty local state and an exact version match")
require("HomeworkRemoteApi.instance.update(assignment, assignment.remoteVersion)" in sync,
        "remote update must use the assignment's persisted remoteVersion")
require("RemoteAssignmentMapper.toLocal" in sync and "replaceAssignmentsForActiveStudent(merged)" in sync,
        "final server refresh must remain authoritative after sync/conflict")

require("http.RequestMethod.PUT" in remote_api,
        "HarmonyOS assignment updates must use PUT for compatibleSdk 6.0.0(20)")
require("http.RequestMethod.PATCH" not in remote_api,
        "HarmonyOS client must not use PATCH because RequestMethod.PATCH requires SDK 26")
require("@PutMapping(\"/assignments/{id}\")" in controller,
        "backend must expose PUT for the compatible HarmonyOS client")
require("@PatchMapping(\"/assignments/{id}\")" in controller,
        "backend must retain the existing PATCH update endpoint during compatibility window")
require("remoteVersion" not in remote_api and "syncDirty" not in remote_api and "lastSyncedAtEpochMs" not in remote_api,
        "client sync metadata must never be sent as backend assignment fields")

if errors:
    print("ASSIGNMENT_SYNC_METADATA_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("ASSIGNMENT_SYNC_METADATA_GATE_PASS")
