#!/usr/bin/env python3
"""TOEIC deterministic display-option quality gate.

Authored options, correctIndex and persisted attempt.selectedIndex retain their
canonical order. Only rendered A/B/C/D choices are permuted. Audit the algorithm
and its effective answer distribution, not the intentionally unchanged source
answer indices. This is a statistical anti-guessing test, NOT semantic grading.
"""
from __future__ import annotations
from collections import Counter
from pathlib import Path
from validate_toeic_question_quality import collect

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
        count=Counter(display_order(q.id).index(q.answer) for q in group)
        print(f"TOEIC_DISPLAY_BALANCE {label} n={len(group)} "
              + " ".join(f"{chr(65+i)}={count[i]}" for i in range(4)))
        if label.startswith("mock") and not label.endswith("p7"):
            assert len(group)==100, f"{label}: missing exam questions"
            assert all(18<=count[i]<=32 for i in range(4)), f"{label}: severely skewed displayed answer position"
        if label.endswith("p7"):
            assert len(group)==54, f"{label}: missing part 7 questions"
            assert all(8<=count[i]<=19 for i in range(4)), f"{label}: skewed Part7 displayed answer position"
    print("TOEIC_ANSWER_DISPLAY_PASS canonical indexes preserved and choices/translations aligned")


if __name__=="__main__":
    verify()
