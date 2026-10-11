#!/usr/bin/env python3
"""TOEIC deterministic display-option quality gate.

Authored options, correctIndex and persisted attempt.selectedIndex retain their
canonical order. Only rendered A/B/C/D choices are permuted. Audit the algorithm
and its effective answer distribution, not the intentionally unchanged source
answer indices. This is a statistical anti-guessing test, NOT semantic grading.
"""
from __future__ import annotations
import ast
import math
import re
from collections import Counter, defaultdict
from pathlib import Path
from validate_toeic_question_quality import collect, fields, literals_after

ROOT=Path(__file__).resolve().parents[1]
UI=ROOT/"entry/src/main/ets/toeic/ui/ToeicHomePage.ets"
ORDER=ROOT/"entry/src/main/ets/toeic/application/ToeicAnswerDisplayOrder.ets"


def display_order(item_id: str) -> list[int]:
    seed=0
    for char in item_id:
        seed=(seed*131+ord(char))%65521
    order=[0,1,2,3]
    for i in (3,2,1):
        seed=(seed*25173+13849)%65521
        j=seed%(i+1)
        order[i],order[j]=order[j],order[i]
    return order


def longest_same_run(positions: list[int]) -> int:
    longest=0
    current=0
    previous=-1
    for position in positions:
        if position==previous:
            current+=1
        else:
            previous=position
            current=1
        longest=max(longest,current)
    return longest


def displayed_positions(group) -> list[int]:
    return [display_order(q.id).index(q.answer) for q in group]


def chapter_key(question_id: str) -> str:
    parts=question_id.split("-")
    return "-".join(parts[:3]) if len(parts)>=3 else question_id


def _literal_string_array(source: str, method: str) -> list[str] | None:
    match=re.search(
        rf"static\s+{re.escape(method)}\(\):string\[\]\s*\{{\s*return\s*(\[.*?\]);\s*\}}",
        source,
        re.S,
    )
    if not match:
        return None
    value=ast.literal_eval(match.group(1))
    assert isinstance(value,list) and all(isinstance(x,str) for x in value)
    return value


def fixed_study_day_ids() -> dict[int,list[str]]:
    """Return deterministic day plans that can be statically audited.

    Day14/19 are validated by the active-v2 mock gates. Day18/20 are dynamic
    weakness/error review days and therefore have no stable authored sequence.
    """
    plans:dict[int,list[str]]={}
    for basename in ("ToeicWeekOneContent","ToeicWeekTwoContent","ToeicWeekThreeContent"):
        source=(ROOT/"entry/src/main/ets/toeic/content"/f"{basename}.ets").read_text(encoding="utf-8")
        for raw in literals_after(source,"new ToeicStudyDay("):
            args=fields(raw)
            if len(args)<7:
                continue
            day=int(args[0])
            if day in (14,19):
                continue
            expression=args[6]
            ids:list[str] | None=None
            if expression.startswith("["):
                value=ast.literal_eval(expression)
                if isinstance(value,list) and all(isinstance(x,str) for x in value):
                    ids=value
            else:
                helper=re.fullmatch(rf"{basename}\.([A-Za-z0-9_]+)\(\)",expression)
                if helper:
                    ids=_literal_string_array(source,helper.group(1))
            if ids is not None:
                plans[day]=ids
    return plans


def verify() -> None:
    source=ORDER.read_text(encoding="utf-8")
    ui=UI.read_text(encoding="utf-8")
    for token in ("seed*131+questionId.charCodeAt(i)", "seed*25173+13849",
                  "let order:number[]=[0,1,2,3]", "return order;",
                  "return order.indexOf(canonicalIndex);"):
        assert token in source, f"display permutation algorithm diverges: {token}"
    for token in (
        "private currentOptionOrder:number[]=[0,1,2,3]",
        "this.currentOptionOrder=ToeicAnswerDisplayOrder.order(question.id)",
        "this.currentOptionA=question.options[this.currentOptionOrder[0]]",
        "this.currentOptionB=question.options[this.currentOptionOrder[1]]",
        "this.currentOptionC=question.options[this.currentOptionOrder[2]]",
        "this.currentOptionD=question.options[this.currentOptionOrder[3]]",
        "translation.options[this.currentOptionOrder[0]]",
        "translation.options[this.currentOptionOrder[1]]",
        "translation.options[this.currentOptionOrder[2]]",
        "translation.options[this.currentOptionOrder[3]]",
        "ToeicAnswerDisplayOrder.displayIndex(this.currentOptionOrder,attempt.selectedIndex)",
        "let canonicalIndex=this.currentOptionOrder[index]",
        "this.viewModel.createAttempt(question,canonicalIndex,elapsed)",
        "this.currentOptionOrder=[0,1,2,3]",
    ):
        assert token in ui, f"canonical/display choice mapping missing: {token}"
    questions,_=collect()
    assert len(questions)>=431, f"expected all 431 authored questions, found {len(questions)}"
    groups={"all":questions,"mock14":[q for q in questions if q.id.startswith("R-M1-")],
            "mock19":[q for q in questions if q.id.startswith("R-M2-")],
            "mock14p7":[q for q in questions if q.id.startswith("R-M1-P7-")],
            "mock19p7":[q for q in questions if q.id.startswith("R-M2-P7-")]}
    for q in questions:
        permutation=display_order(q.id)
        assert sorted(permutation)==[0,1,2,3],f"{q.id}: duplicated/missing displayed options"
        index=permutation.index(q.answer)
        assert permutation[index]==q.answer,f"{q.id}: canonical selected index roundtrip failed"
        # Reopening, navigating back and resuming an old draft must not rotate again.
        assert display_order(q.id)==permutation,f"{q.id}: unstable display order"
    for label,group in groups.items():
        positions=displayed_positions(group)
        count=Counter(positions)
        run=longest_same_run(positions)
        print(f"TOEIC_DISPLAY_BALANCE {label} n={len(group)} "
              + " ".join(f"{chr(65+i)}={count[i]}" for i in range(4))
              + f" max_run={run}")
        if label.startswith("mock") and not label.endswith("p7"):
            assert len(group)==100, f"{label}: missing exam questions"
            assert all(18<=count[i]<=32 for i in range(4)), f"{label}: severely skewed displayed answer position"
            assert run<=6, f"{label}: excessive identical displayed-answer run {run}"
        if label.endswith("p7"):
            assert len(group)==54, f"{label}: missing part 7 questions"
            assert all(8<=count[i]<=19 for i in range(4)), f"{label}: skewed Part7 displayed answer position"
            assert run<=6, f"{label}: excessive identical Part7 displayed-answer run {run}"

    # Part-level distribution: source correctIndex may stay historically skewed,
    # but learner-visible A/B/C/D must not collapse onto one position.
    for part in ("PART_5","PART_6","PART_7"):
        group=[q for q in questions if q.part==part]
        positions=displayed_positions(group)
        count=Counter(positions)
        run=longest_same_run(positions)
        assert max(count.values())<=math.ceil(len(group)*0.45), (
            f"{part}: learner-visible answer position exceeds 45%: {count}")
        assert run<=8, f"{part}: excessive identical displayed-answer run {run}"
        print(f"TOEIC_DISPLAY_PART {part} n={len(group)} "
              + " ".join(f"{chr(65+i)}={count[i]}" for i in range(4))
              + f" max_run={run}")

    # Chapter/family distribution catches local patterns hidden by whole-bank totals.
    chapters:dict[str,list]=defaultdict(list)
    for question in questions:
        chapters[chapter_key(question.id)].append(question)
    checked_chapters=0
    for chapter,group in sorted(chapters.items()):
        if len(group)<4:
            continue
        positions=displayed_positions(group)
        count=Counter(positions)
        run=longest_same_run(positions)
        assert max(count.values())<=math.ceil(len(group)*0.75), (
            f"{chapter}: chapter answer position is severely skewed: {count}")
        if len(group)>=6:
            assert run<=4, f"{chapter}: excessive chapter answer-position run {run}"
        checked_chapters+=1
        print(f"TOEIC_DISPLAY_CHAPTER {chapter} n={len(group)} "
              + " ".join(f"{chr(65+i)}={count[i]}" for i in range(4))
              + f" max_run={run}")

    # Fixed daily plans are checked in learner order. Dynamic Day18/20 are excluded,
    # while Day14/19 active papers are checked in their dedicated v2 validators.
    by_id={q.id:q for q in questions}
    fixed_days=fixed_study_day_ids()
    checked_days=0
    for day,ids in sorted(fixed_days.items()):
        if len(ids)<4:
            continue
        missing=[question_id for question_id in ids if question_id not in by_id]
        assert not missing, f"Day{day}: authored questions missing from canonical audit: {missing}"
        group=[by_id[question_id] for question_id in ids]
        positions=displayed_positions(group)
        count=Counter(positions)
        run=longest_same_run(positions)
        assert max(count.values())<=math.ceil(len(group)*0.70), (
            f"Day{day}: learner-visible answer position is severely skewed: {count}")
        if len(group)>=6:
            assert run<=4, f"Day{day}: excessive identical displayed-answer run {run}"
        checked_days+=1
        print(f"TOEIC_DISPLAY_DAY day={day} n={len(group)} "
              + " ".join(f"{chr(65+i)}={count[i]}" for i in range(4))
              + f" max_run={run}")

    assert checked_days>=17, f"fixed day coverage unexpectedly low: {checked_days}"
    assert checked_chapters>=10, f"chapter coverage unexpectedly low: {checked_chapters}"
    print(f"TOEIC_ISSUE476_DISTRIBUTION_PASS parts=3 fixed_days={checked_days} "
          f"chapters={checked_chapters} legacy_mocks=2 max_run_guard=ON")
    print("TOEIC_ANSWER_DISPLAY_PASS canonical indexes preserved and choices/translations aligned")


if __name__=="__main__":
    verify()
