#!/usr/bin/env python3
"""Validate the runtime TOEIC multi-document release manifest.

The authored mock group catalogs intentionally retain historic IDs for saved
reports. Runtime publication maps them through evidence/P3 revisions and must
deduplicate the resulting active IDs. Each current multi-document group must
therefore resolve to exactly five unique questions.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "entry/src/main/ets/toeic/content"


def mappings(path: Path, parameter: str) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    pattern = rf"if \({parameter}==='([^']+)'\) return '([^']+)';"
    return dict(re.findall(pattern, text))


def active_id(question_id: str, evidence: dict[str, str], p3: dict[str, str]) -> str:
    return p3.get(evidence.get(question_id, question_id), evidence.get(question_id, question_id))


def source_groups(prefix: str, revised_groups: set[int]) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = {}
    for group in range(1, 6):
        ids = [f"R-{prefix}-P7-M{group}-{item:02d}" for item in range(1, 6)]
        if group in revised_groups:
            ids.append(f"R-{prefix}-P7-M{group}-06")
        groups[f"{prefix.replace('FM', 'FM')}-G{group}"] = ids
    return groups


def validate() -> None:
    evidence = mappings(CONTENT / "ToeicMockPart7EvidenceRevisionContent.ets", "originalId")
    p3 = mappings(CONTENT / "ToeicP3FinalCorrections.ets", "id")

    groups: dict[str, list[str]] = {}
    for group in range(1, 6):
        ids = [f"R-FM1-P7-M{group}-{item:02d}" for item in range(1, 6)]
        if group in {1, 4}:
            ids.append(f"R-FM1-P7-M{group}-06")
        groups[f"FM1-G{group}"] = ids
    for group in range(1, 6):
        ids = [f"R-FM2-P7-M{group}-{item:02d}" for item in range(1, 6)]
        if group in {1, 5}:
            ids.append(f"R-FM2-P7-M{group}-06")
        groups[f"FM2-G{group}"] = ids

    resolved: dict[str, list[str]] = {}
    for group_id, ids in groups.items():
        active: list[str] = []
        for question_id in ids:
            mapped = active_id(question_id, evidence, p3)
            if mapped not in active:
                active.append(mapped)
        if len(active) != 5 or len(set(active)) != 5:
            raise AssertionError(f"{group_id}: active release must contain exactly five unique IDs: {active}")
        resolved[group_id] = active

    assert resolved["FM1-G1"][0] == "R-FM1-P7-M1-06"
    assert resolved["FM1-G4"][0] == "R-FM1-P7-M4-06"
    assert resolved["FM2-G1"][0] == "R-FM2-P7-M1-06"
    assert resolved["FM2-G5"][2] == "R-FM2-P7-M5-06"
    assert "R-FP3-FM1-P7-M2-03" in resolved["FM1-G2"]

    preset = (CONTENT / "PresetToeicContent.ets").read_text(encoding="utf-8")
    assert "if (activeIds.indexOf(active)<0) activeIds.push(active);" in preset

    print("TOEIC_RUNTIME_GROUP_RELEASE_PASS groups=10 active_questions=50 unique_per_group=5")


if __name__ == "__main__":
    validate()
