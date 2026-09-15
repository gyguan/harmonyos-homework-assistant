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


store = read("entry/src/main/ets/data/HomeworkStore.ets")
cloud = read("entry/src/main/ets/application/remote/FamilyCloudService.ets")

require("replaceStudents(students: StudentProfile[])" in store,
        "HomeworkStore must own cloud student-list replacement")
replace_block = store.split("replaceStudents(students: StudentProfile[])", 1)
require(len(replace_block) == 2 and "this.cloneStudent(student)" in replace_block[1].split("getStudents()", 1)[0],
        "replaceStudents must clone incoming StudentProfile values")
require(len(replace_block) == 2 and "this.requestPersist();" in replace_block[1].split("getStudents()", 1)[0],
        "replaceStudents must persist the updated AppSettings snapshot")
require(len(replace_block) == 2 and "activeStudentId" in replace_block[1].split("getStudents()", 1)[0],
        "replaceStudents must preserve or repair activeStudentId")

require("HomeworkStore.instance.replaceStudents(students)" in cloud,
        "FamilyCloudService must apply remote students through HomeworkStore")
require("HomeworkStore.instance.getSettings()" not in cloud,
        "FamilyCloudService must not mutate HomeworkStore settings by reference")
require("settings.students" not in cloud,
        "FamilyCloudService must not splice/push Store-owned student arrays")
require("replaceRawImport(HomeworkStore.instance.getRawImport())" not in cloud,
        "FamilyCloudService must not use RawImport writes as a persistence trigger")

if errors:
    print("FAMILY_CLOUD_STORE_BOUNDARY_GATE_FAIL")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("FAMILY_CLOUD_STORE_BOUNDARY_GATE_PASS")
