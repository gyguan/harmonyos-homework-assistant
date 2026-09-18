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


cloud = read("entry/src/main/ets/application/remote/FamilyCloudService.ets")
family_context_port = read("entry/src/main/ets/domain/port/FamilyContextRepository.ets")
family_context_adapter = read("entry/src/main/ets/data/repository/DefaultFamilyContextRepository.ets")

require("HomeworkStore" not in cloud and "FamilyContextRepository" in cloud,
        "FamilyCloudService must use FamilyContextRepository instead of accessing HomeworkStore directly")
require("setActiveStudent(studentId: string): boolean" in family_context_port and
        "replaceStudents(students: StudentProfile[]): void" in family_context_port,
        "FamilyContextRepository must own active-student and synced-student mutations")
require("HomeworkStore.instance.setActiveStudent(studentId)" in family_context_adapter and
        "HomeworkStore.instance.replaceStudents(copies)" in family_context_adapter,
        "legacy FamilyContext adapter must preserve Store-backed persistence semantics")
require("HomeworkStore.instance.getSettings()" not in cloud,
        "FamilyCloudService must not obtain mutable Store settings by reference")
require("settings.students" not in cloud,
        "FamilyCloudService must not splice/push a Store-owned student array")
require("replaceRawImport(HomeworkStore.instance.getRawImport())" not in cloud,
        "FamilyCloudService must not use RawImport writes as a persistence trigger")
require(".students.push(" not in cloud and ".students.splice(" not in cloud,
        "FamilyCloudService must not directly mutate student collections")

if errors:
    print("FAMILY_CLOUD_BOUNDARY_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("FAMILY_CLOUD_BOUNDARY_GATE_PASS")
