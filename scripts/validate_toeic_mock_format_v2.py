#!/usr/bin/env python3
"""Strict ETS-style Day14 v2 mock format and verbatim evidence check.

The old published R-M1 bank stays immutable so saved drafts and mock reports
continue to resolve. The active paper is 30 P5, 16 P6 (4 passages x 4),
29 single P7 (10 passages with 2-4), and 25 multi P7 (5 sets x 5).
This checks structural/evidence properties, NOT independent semantic certainty.
"""
from __future__ import annotations
import ast
import json
import re
from collections import Counter
from pathlib import Path
from validate_toeic_question_quality import collect, fields, literals_after, parse_question

ROOT=Path(__file__).resolve().parents[1]
CONTENT=ROOT/"entry/src/main/ets/toeic/content"
V2=(CONTENT/"ToeicMockDay14V2Content.ets").read_text(encoding="utf-8")


def validate() -> None:
    questions,_=collect()
    legacy={item.id:item for item in questions}
    old_p5=[q for q in questions if q.id.startswith("R-M1-P5-")]
    old_p6=[q for q in questions if q.id.startswith("R-M1-P6-")]
    old_p7=[q for q in questions if q.id.startswith("R-M1-P7-")]
    assert len(old_p5)==30 and len(old_p6)==16 and len(old_p7)==54
    passage_counts=Counter(q.passage for q in old_p6)
    assert sorted(passage_counts.values())==[4,4,4,4], "Day14 P6 requires 4 coherent 4-blank texts"
    assert "for(let i=0;i<24;i++)" in V2 and "let q=legacy[46+i]" in V2
    assert "for(let group=0;group<5;group++)" in V2
    assert "original=legacy[70+group*3+item]" in V2
    assert "ToeicReadingGroup('FM1-G'+String(group+1)" in V2
    assert "String(Math.floor(i/3)+1).padStart(2,'0')" in V2
    assert "String(i%3+1).padStart(2,'0')" in V2
    assert "(original.correctIndex+item)%4" in V2 and "(o+4-item)%4" in V2
    assert "question.version=2" not in V2, "old content may not be silently rewritten"

    authored=[]
    for call in literals_after(V2,"new ToeicQuestion("):
        parts=fields(call)
        if parts and re.fullmatch(r"""(?:'[^']+'|"[^"]+")""",parts[0]):
            item=parse_question(parts,"ToeicMockDay14V2Content",False)
            assert item is not None
            authored.append(item)
    assert len(authored)==15,f"two extra singles (5) and ten multi items expected, got {len(authored)}"
    singles=[q for q in authored if q.id.startswith("R-FM1-P7-S")]
    multiples=[q for q in authored if q.id.startswith("R-FM1-P7-M")]
    assert len(singles)==5 and len(multiples)==10
    counts=Counter(q.id.split("-")[3] for q in singles)
    assert sorted(counts.values())==[2,3]
    assert any(q.id=="R-FM1-P7-S09-03" and q.answer==3 and
               "[4]" in q.passage and "[4]" in q.choices for q in singles), (
        "Day14 needs a real sentence-placement question with four marked positions")
    # Full active Day14 paper: 8*3 inherited single items + 3+2 new,
    # then five two-document passages with 3 legacy-derived + 2 new.
    active_ids=[f"R-FM1-P7-S{block:02d}-{q:02d}" for block in range(1,9) for q in range(1,4)]
    active_ids += [f"R-FM1-P7-S09-{q:02d}" for q in range(1,4)]
    active_ids += [f"R-FM1-P7-S10-{q:02d}" for q in range(1,3)]
    active_ids += [f"R-FM1-P7-M{block}-{q:02d}" for block in range(1,6) for q in range(1,6)]
    assert len(active_ids)==54 and len(set(active_ids))==54
    assert len([x for x in active_ids if "-S" in x])==29
    assert len([x for x in active_ids if "-M" in x])==25
    assert {q.id for q in authored}.issubset(set(active_ids))
    for q in authored:
        assert q.answer in range(4) and len(q.choices)==4 and len(set(q.choices))==4
        assert q.explanation and q.evidence
    match=re.search(r"let evidence:string\[\]\[\]=(\[\[.*?\]\]);",V2)
    assert match,"re-grounded legacy evidence matrix missing"
    evidence=json.loads(match.group(1))
    assert len(evidence)==5 and all(len(g)==3 for g in evidence)
    for block in range(5):
        source=legacy[f"R-M1-P7-{71+block*3:03d}"]
        docs=re.split(r"\n\n(?=DOCUMENT [23])",source.passage)
        assert len(docs)==2,f"multi block {block+1}: requires two linked documents"
        for q_index,raw in enumerate(evidence[block]):
            matching={i for fragment in raw.split(" || ") for i,doc in enumerate(docs)
                      if fragment in doc}
            assert all(any(f in d for d in docs) for f in raw.split(" || ")), (
                f"multi block {block+1}, source {q_index+1}: citation not in article")
            if q_index==0:
                assert matching=={0,1}, f"multi block {block+1}: CROSS_DOCUMENT must cite both docs"
        for q in multiples:
            if q.group==f"FM1-G{block+1}":
                assert all(any(fragment in doc for doc in docs)
                           for fragment in q.evidence.split(" || ")), f"{q.id}: orphan evidence"
    assert sorted(Counter(q.group for q in multiples).values())==[2]*5
    for block in range(5):
        group=next(q for q in questions if q.id==f"R-M1-P7-{71+block*3:03d}")
        assert group.passage.startswith("DOCUMENT 1")
    # Runtime wiring checks: the 100-question day uses v2 IDs, old 100 IDs
    # remain indexed by the all-questions catalog for saved drafts/history.
    preset=(CONTENT/"PresetToeicContent.ets").read_text(encoding="utf-8")
    service=(ROOT/"entry/src/main/ets/toeic/application/ToeicReadingGroupService.ets").read_text(encoding="utf-8")
    assert "ToeicWeekTwoContent.mockQuestionIds().slice(0,46)" in preset
    assert "for (let question of ToeicMockDay14V2Content.questions()) ids.push(question.id)" in preset
    assert "ToeicMockDay14V2Content.questions()" in preset
    assert "ToeicMockDay14V2Content.groups()" in preset
    assert "ToeicMockDay14V2Content.groups()" in service
    print("TOEIC_MOCK_DAY14_V2_FORMAT_PASS questions=100 P5=30 "
          "P6=16_4x4 P7_single=29_10sets P7_multi=25_5x5 "
          "group_docs=2 each evidence=verbatim legacy_v1=preserved")


if __name__=="__main__":
    validate()
