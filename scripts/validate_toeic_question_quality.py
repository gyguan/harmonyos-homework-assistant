#!/usr/bin/env python3
"""Audit every authored TOEIC question literal, not just selected daily samples.

This gate verifies deterministic source invariants. It does NOT infer the only
semantically correct answer; that requires separate editorial review.
"""
from __future__ import annotations
import ast
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "entry/src/main/ets/toeic/content"
FILES = (
    "PresetToeicContent", "ToeicWeekOneContent", "ToeicWeekTwoContent",
    "ToeicWeekThreeContent", "ToeicStandardDiagnosticContent",
    "ToeicExtraReadingContent", "ToeicExtraReadingBatchTwo",
    "ToeicExtraReadingBatchThree", "ToeicExtraReadingBatchFour",
    "ToeicExtraReadingBatchFive", "ToeicExtraReadingBatchSix",
)
DAY_ONE = (
    "R-P5-WF-0001", "R-P5-VOICE-0002", "R-P5-PREP-0003",
    "R-P5-CONJ-0004", "R-P5-COL-0005", "R-P5-VOC-0006",
    "R-DX-P5-01", "R-DX-P5-02", "R-DX-P5-03", "R-DX-P5-04",
    "R-P6-CTX-0001", "R-P6-WF-0002", "R-DX-P6-01", "R-DX-P6-02",
    "R-P7-DETAIL-0001", "R-P7-PURPOSE-0002",
    "R-P7-PARA-0003", "R-P7-DETAIL-0004",
    "R-DX-P7-03", "R-DX-P7-04",
)

@dataclass
class Item:
    id: str
    part: str
    passage: str
    stem: str
    choices: list[str]
    answer: int
    explanation: str
    evidence: str
    group: str
    version: int
    source: str

def literals_after(source: str, signature: str) -> list[str]:
    """Extract balanced call argument lists without matching parentheses in text."""
    output: list[str] = []
    current = 0
    while (start := source.find(signature, current)) >= 0:
        pos = start + len(signature)
        depth = 1
        quote = ""
        escaped = False
        for end in range(pos, len(source)):
            char = source[end]
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = ""
            elif char in ("'", '"'):
                quote = char
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    output.append(source[pos:end])
                    current = end + 1
                    break
        else:
            raise ValueError(f"unterminated call at position {start}")
    return output

def fields(text: str) -> list[str]:
    segments: list[str] = []
    quote = ""
    escaped = False
    nesting = 0
    start = 0
    for pos, char in enumerate(text):
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = ""
        elif char in ("'", '"'):
            quote = char
        elif char in "([{":
            nesting += 1
        elif char in ")]}":
            nesting -= 1
        elif char == "," and nesting == 0:
            segments.append(text[start:pos].strip())
            start = pos + 1
    segments.append(text[start:].strip())
    return segments

def parse_question(raw: list[str], source: str, wrapper: bool) -> Item | None:
    if not raw or not raw[0].startswith(("'", '"')):
        return None   # skip the ToeicQuestion constructor inside q() helpers
    try:
        values = [ast.literal_eval(x) if x.startswith(("'", '"', "[")) else x for x in raw]
        shift = 0 if wrapper else 1
        id = values[0]
        if not isinstance(id, str) or not id.startswith("R-"):
            return None
        part = values[1 + shift].split(".")[-1]
        version = values[15] if not wrapper and len(values) > 15 else 1
        group = values[20] if not wrapper and len(values) > 20 else ""
        return Item(id, part, values[3 + shift], values[4 + shift],
                    values[5 + shift], int(values[6 + shift]),
                    values[7 + shift], values[8 + shift],
                    group, int(version), source)
    except (ValueError, SyntaxError, TypeError, IndexError, AttributeError) as exc:
        raise ValueError(f"cannot parse question literal in {source}: {raw[:3]}") from exc

def wrapper_version_overrides(source: str) -> dict[str, int]:
    """Read the actual q() helper conditions, never fabricate known versions.

    Unknown version-assignment syntax must fail rather than silently report v1.
    """
    expression = re.compile(
        r"if\s*\((?P<condition>[^)]*)\)\s*\{?\s*"
        r"question\.version\s*=\s*(?P<version>\d+)\s*;"
    )
    matches = list(expression.finditer(source))
    if len(matches) != len(re.findall(r"question\.version\s*=", source)):
        raise ValueError("unrecognized ArkTS question.version override syntax")
    versions: dict[str, int] = {}
    for match in matches:
        ids = re.findall(r"id\s*===\s*'([^']+)'", match.group("condition"))
        if not ids or any(not question_id.startswith("R-") for question_id in ids):
            raise ValueError("unknown question.version override condition")
        version = int(match.group("version"))
        for question_id in ids:
            if question_id in versions:
                raise ValueError(f"duplicate version assignment for {question_id}")
            versions[question_id] = version
    return versions


def collect() -> tuple[list[Item], dict[str, str]]:
    questions: list[Item] = []
    contents: dict[str, str] = {}
    for basename in FILES:
        text = (CONTENT / f"{basename}.ets").read_text(encoding="utf-8")
        contents[basename] = text
        if basename in ("ToeicWeekTwoContent", "ToeicWeekThreeContent"):
            signature = f"{basename}.q("
            wrapper = True
            versions = wrapper_version_overrides(text)
        else:
            signature = "new ToeicQuestion("
            wrapper = False
            versions = {}
        seen: set[str] = set()
        for args in literals_after(text, signature):
            item = parse_question(fields(args), basename, wrapper)
            if item is not None:
                if wrapper:
                    item.version = versions.get(item.id, item.version)
                    seen.add(item.id)
                questions.append(item)
        if wrapper:
            missing = versions.keys() - seen
            if missing:
                raise ValueError(f"unmapped ArkTS version overrides: {sorted(missing)}")
    return questions, contents

def validate() -> dict[str, int]:
    questions, contents = collect()
    errors: list[str] = []
    counts = Counter(q.part for q in questions)
    ids = Counter(q.id for q in questions)
    for id, number in ids.items():
        if number != 1:
            errors.append(f"{id}: duplicate question ID x{number}")
    for q in questions:
        if q.part not in ("PART_5", "PART_6", "PART_7"):
            errors.append(f"{q.id}: unsupported part {q.part}")
        if not q.stem.strip() or re.search(r"题干待|待补充|TBD|TODO|placeholder|测试题干", q.stem, re.I):
            errors.append(f"{q.id}: incomplete or placeholder stem")
        if len(q.choices) != 4 or any(not isinstance(c, str) or not c.strip() for c in q.choices):
            errors.append(f"{q.id}: requires four non-empty options")
        if len(set(c.strip().casefold() for c in q.choices)) != len(q.choices):
            errors.append(f"{q.id}: duplicate answer options")
        if q.answer not in range(len(q.choices)):
            errors.append(f"{q.id}: invalid correct answer index")
        if not q.explanation.strip():
            errors.append(f"{q.id}: missing answer explanation")
        if q.part == "PART_5" and q.stem.count("_____") != 1:
            errors.append(f"{q.id}: Part 5 must show exactly one blank")
        if q.part == "PART_6" and ("_____" not in q.passage and not re.search(r"\[\d+\]\s+_____", q.passage)):
            errors.append(f"{q.id}: Part 6 missing completion blank in passage")
        if q.part == "PART_7" and not q.evidence.strip():
            errors.append(f"{q.id}: Part 7 missing supporting evidence")
        if q.part == "PART_7" and not q.passage.strip() and not q.group:
            errors.append(f"{q.id}: Part 7 missing its reading document")
        if q.version < 1:
            errors.append(f"{q.id}: invalid content version")
    expected_count = 431
    if len(questions) != expected_count:
        errors.append(f"full corpus missing items: expected {expected_count}, got {len(questions)}")
    id_map = {q.id: q for q in questions}
    for id in DAY_ONE:
        if id not in id_map:
            errors.append(f"Day 1 diagnostic missing {id}")
    preset = contents["PresetToeicContent"]
    day_one_source = contents["ToeicWeekOneContent"]
    day_one_match = re.search(
        r"new ToeicStudyDay\(1,.*?\[\],\[\],\[(.*?)\]\),",
        day_one_source, re.S,
    )
    selected_day_one = re.findall(r"'(R-[^']+)'", day_one_match.group(1)) if day_one_match else []
    if tuple(selected_day_one) != DAY_ONE:
        errors.append(f"Day 1 20-question plan content/order changed: {selected_day_one}")
    if "return PresetToeicContent.questionsForDay(1);" not in preset:
        errors.append("Day 1 diagnosis must use the study plan as its sole source of truth")
    if len({q.id for q in questions if q.id in DAY_ONE}) != 20:
        errors.append("Day 1 contains missing or duplicate question IDs")
    for group in (("R-DX-P6-01", "R-DX-P6-02"), ("R-DX-P7-03", "R-DX-P7-04")):
        indexes = [selected_day_one.index(id) for id in group if id in selected_day_one]
        if len(indexes) != 2 or indexes[1] != indexes[0]+1:
            errors.append(f"Day 1 shared reading pair not contiguous: {group}")
    if "Qualifyingly" in preset:
        errors.append("Day 1 contains a fabricated English distractor 'Qualifyingly'")
    for id in ("R-P6-CTX-0001", "R-P6-WF-0002"):
        item = id_map.get(id)
        if item and item.stem.startswith(("Choose the best ", "Choose the correct ")):
            errors.append(f"{id}: Day 1 generic question wording must be replaced")
    translations = (CONTENT / "ToeicQuestionTranslationWeekOneCatalog.ets").read_text(encoding="utf-8")
    day_one_translation = translations.split("new ToeicQuestionTranslation('R-P6-WF-0002'", 1)
    if len(day_one_translation) != 2:
        errors.append("Day 1 Chinese translation for R-P6-WF-0002 is missing")
    else:
        day_one_translation = day_one_translation[1].split("new ToeicQuestionTranslation(", 1)[0]
        if "为横线选择最合适的词" in day_one_translation or "合格地" in day_one_translation:
            errors.append("Day 1 Chinese translation still contains stale stem or deleted nonword distractor")
    translated_question_ids = re.findall(
        r"new ToeicQuestionTranslation\('([^']+)'", translations
    )
    for id in DAY_ONE:
        if id not in translated_question_ids:
            errors.append(f"{id}: Day 1 has no hidden Chinese translation")
    week_two_source = contents["ToeicWeekTwoContent"]
    for id in ("R-M1-P5-003", "R-M1-P7-086", "R-P7-DOUBLE-1104"):
        if f"id==='{id}'" not in week_two_source or "question.version=2" not in week_two_source:
            errors.append(f"{id}: version override for corrected published item is missing")
    if "if (id==='R-P7-DOUBLE-1102') question.version=3;" not in week_two_source:
        errors.append("R-P7-DOUBLE-1102: corrected published evidence requires version 3")
    for id, version in (("R-P6-CTX-0001", 2), ("R-P6-WF-0002", 2),
                        ("R-M1-P5-003", 2), ("R-M1-P7-086", 2),
                        ("R-P7-DOUBLE-1102", 3), ("R-P7-DOUBLE-1104", 2),
                        ("R-P5-SPRINT-1528", 2)):
        if id_map.get(id) is None or id_map[id].version < version:
            errors.append(f"{id}: corrected published item must increment version")
    if id_map.get("R-M1-P5-003") and "_____ users automatically" not in id_map["R-M1-P5-003"].stem:
        errors.append("R-M1-P5-003: notify must have an object")
    if id_map.get("R-M1-P7-086") and "latest shuttle" not in id_map["R-M1-P7-086"].stem:
        errors.append("R-M1-P7-086: two shuttles are feasible; question must ask for latest")
    if id_map.get("R-P7-DOUBLE-1102") and "by November 15" not in id_map["R-P7-DOUBLE-1102"].passage:
        errors.append("R-P7-DOUBLE-1102: booking deadline must be unambiguous")
    if id_map.get("R-P7-DOUBLE-1102") and "Book a two-night stay by November 15" not in id_map["R-P7-DOUBLE-1102"].evidence:
        errors.append("R-P7-DOUBLE-1102: evidence must quote the current source rather than stale wording")
    if id_map.get("R-P7-DOUBLE-1104") and "11:30–11:50 Cloud Operations" not in id_map["R-P7-DOUBLE-1104"].passage:
        errors.append("R-P7-DOUBLE-1104: seminar completion time must be stated")
    if "Each applicant must identify _____ with a photo ID" not in id_map["R-P5-SPRINT-1528"].stem:
        errors.append("R-P5-SPRINT-1528: use idiomatic identify oneself, not provide oneself with ID at reception")
    if "入选面试的申请人最迟会在 10 月 18 日当天收到联系。" not in contents["ToeicWeekTwoContent"]:
        errors.append("S-037: no later than October 18 must include the deadline date in Chinese")
    group_count = 0
    grouped_count = 0
    seen_members: set[str] = set()
    for basename in FILES:
        text = contents[basename]
        for raw in literals_after(text, "new ToeicReadingGroup("):
            args = fields(raw)
            if not args or not args[0].startswith(("'", '"')):
                continue
            name, members, passages = [ast.literal_eval(a) for a in args[:3]]
            group_count += 1
            if len(members) != 5 or len(passages) not in (2, 3):
                errors.append(f"{name}: expected five questions and two or three passages")
            for member in members:
                grouped_count += 1
                if member in seen_members or member not in id_map:
                    errors.append(f"{name}: duplicate/missing group member {member}")
                seen_members.add(member)
                if member in id_map and id_map[member].group != name:
                    errors.append(f"{name}: groupId mismatch for {member}")
    if group_count != 13 or grouped_count != 65:
        errors.append(f"published extra group integrity: {group_count} groups, {grouped_count} questions")
    for mock in ("R-M1-", "R-M2-"):
        subset = [q for q in questions if q.id.startswith(mock)]
        counted = Counter(q.part for q in subset)
        if counted != {"PART_5": 30, "PART_6": 16, "PART_7": 54}:
            errors.append(f"{mock} structure corrupted: {dict(counted)}")
    if errors:
        raise SystemExit("TOEIC_QUESTION_QUALITY_FAIL\n" + "\n".join("- " + e for e in errors[:100]))
    result = {"questions": len(questions), "part5": counts["PART_5"],
              "part6": counts["PART_6"], "part7": counts["PART_7"],
              "extra_groups": group_count, "extra_group_questions": grouped_count,
              "day1": len(DAY_ONE), "mock_sets": 2}
    print("TOEIC_QUESTION_QUALITY_PASS " + " ".join(f"{k}={v}" for k, v in result.items()))
    print("TOEIC_LEGACY_MOCK_V1_PRESERVED: authored R-M1/R-M2 Part7 article groups "
          "remain intact for historical drafts; active v2 papers are gated separately")
    return result

if __name__ == "__main__":
    validate()
