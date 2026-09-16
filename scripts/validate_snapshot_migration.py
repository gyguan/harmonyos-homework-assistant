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


migrator = read("entry/src/main/ets/domain/service/HomeworkSnapshotMigrator.ets")
store = read("entry/src/main/ets/data/HomeworkStore.ets")
persistence = read("entry/src/main/ets/infrastructure/persistence/PreferencesHomeworkPersistence.ets")

require("HOMEWORK_SNAPSHOT_SCHEMA_VERSION: number = 5" in migrator,
        "snapshot migration framework must advance the current schema from V4 to V5")
require("migrateV4ToV5" in migrator and "schemaVersion: 5" in migrator,
        "snapshot migrator must contain an explicit V4 -> V5 step")
for field in [
    "settings: snapshot.settings",
    "rawImports: snapshot.rawImports",
    "assignments: snapshot.assignments",
    "candidates: snapshot.candidates",
    "submissions: snapshot.submissions",
    "tutorSessions: snapshot.tutorSessions",
    "submissionSequence: snapshot.submissionSequence",
]:
    require(field in migrator, f"V4 -> V5 migration must preserve field: {field}")

require("HomeworkSnapshotMigrator.migrate(snapshot)" in store,
        "HomeworkStore must migrate an existing snapshot before restore")
require("if (snapshot === null)" in store,
        "HomeworkStore must distinguish first launch from an existing snapshot")
require("snapshot.schemaVersion ===" not in store,
        "HomeworkStore must not reset state merely because a snapshot version differs")
require("schemaVersion: HOMEWORK_SNAPSHOT_SCHEMA_VERSION" in store,
        "new snapshots must use the shared current schema version")

# An existing but corrupt snapshot must not be converted into a first-launch null result.
require(persistence.count("return null;") == 1,
        "persistence load must return null only when no snapshot exists")
require("本地作业数据损坏，已停止覆盖原数据" in persistence,
        "corrupt snapshot parsing must fail without overwriting stored data")
require("Homework snapshot exists but cannot be parsed" in persistence,
        "corrupt snapshot failure must be observable in logs")

# A schema-changing save must preserve the pre-migration payload once, and must not turn the
# backup into a second write path.
require("homework_snapshot_pre_migration_backup" in persistence,
        "persistence must reserve a pre-migration snapshot backup key")
require("existingVersion === snapshot.schemaVersion" in persistence,
        "backup must only be considered when the schema version changes")
require("await store.get(SNAPSHOT_BACKUP_KEY, '')" in persistence,
        "migration save must check whether a backup already exists")
require("await store.put(SNAPSHOT_BACKUP_KEY, existing)" in persistence,
        "migration save must preserve the original snapshot before overwriting the main key")
require(persistence.count("store.put(SNAPSHOT_BACKUP_KEY") == 1,
        "migration backup must not become a general dual-write path")
require(persistence.index("preservePreMigrationSnapshot") < persistence.index("store.put(SNAPSHOT_KEY"),
        "pre-migration backup must happen before writing the new snapshot")
require("本地作业数据无法验证，已停止覆盖原数据" in persistence,
        "unverifiable existing data must block schema-changing overwrite")

if errors:
    print("SNAPSHOT_MIGRATION_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    sys.exit(1)

print("SNAPSHOT_MIGRATION_GATE_PASS")
