#!/usr/bin/env python3
"""Prevent the organizer from silently reintroducing teacher-specific Java fallbacks.

Java is responsible for the schema and structural integrity of generated
assignments; AI + enabled DB/parent experiences decide business meaning.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "backend/src/main/java/com/xiaoban/homework/organizer/"
          "ConfigurableHomeworkOrganizerModelClient.java").read_text(encoding="utf-8")

for symbol in (
    "splitShorthand(", "onlyVoiceMaterial(", "isVoiceMaterialEntry(",
    "refineDumpSubject(", "learningProgressLesson(", "applyLesson(",
    "splitNumbered(", "CHINESE_REGULAR_KEYWORDS", "shortTitle().replace(", "new ShorthandMatch("
):
    if symbol in SOURCE:
        raise SystemExit(f"ORGANIZER_SEMANTIC_BOUNDARY_FAIL: Java domain rewriting remains: {symbol}")

needed = (
    "reviewWithExperience(", "HomeworkTeacherExperienceService",
    "ruleSnapshot(", "instructionsWithShorthand(", "converted.unsupportedSubjectCount() > 0",
    "converted.blankTitleCount() > 0", "normalizeSubject(", "HomeworkQualityValidator",
)
for symbol in needed:
    if symbol not in SOURCE:
        raise SystemExit(f"ORGANIZER_SEMANTIC_BOUNDARY_FAIL: required safeguard missing: {symbol}")
print("ORGANIZER_SEMANTIC_BOUNDARY_PASS")
